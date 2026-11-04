-- Migration 10: backend service functions
-- These are the documented operations other members call (see
-- docs/backend_service_contracts.md). From Flutter:
--   supabase.rpc('send_student_message', params: {'p_content': 'Hello'});
--
-- Error convention (SQLSTATE -> meaning):
--   42501 forbidden / not signed in     P0002 not_found     22023 invalid_input

-- ---------- internal helpers ----------
create function public.extract_session_keywords(p_conversation_id uuid, p_since timestamptz)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(k.word order by k.cnt desc, k.word), '[]'::jsonb)
  from (
    select t.word, count(*) as cnt
    from (
      select regexp_split_to_table(lower(m.content), '[^a-z0-9]+') as word
      from public.messages m
      where m.conversation_id = p_conversation_id
        and m.sender_type = 'student'
        and m.sent_at >= p_since
    ) t
    where length(t.word) >= 4
      and t.word <> all (array[
        'what','when','where','which','with','that','this','have','from','your',
        'about','does','will','there','their','they','them','than','then','into',
        'would','could','should','please','know','need','want','tell','here',
        'much','many','some','been','were','also','just','only','more','like'])
    group by t.word
    order by count(*) desc, t.word
    limit 10
  ) k
$$;

-- Closes Student chat sessions idle for p_idle (default one hour) and stores the
-- keywords extracted from the session. Server-side only (cron / Edge Function);
-- also called by send_student_message for the sender's own conversation.
create function public.close_idle_chat_sessions(
  p_idle interval default interval '1 hour',
  p_conversation_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_closed integer;
begin
  with closing as (
    select s.session_id
    from public.chat_sessions s
    where s.ended_at is null
      and s.last_activity_at <= now() - p_idle
      and (p_conversation_id is null or s.conversation_id = p_conversation_id)
    for update
  ), done as (
    update public.chat_sessions s
    set ended_at = now(),
        extracted_keywords =
          public.extract_session_keywords(s.conversation_id, s.started_at)
    from closing
    where s.session_id = closing.session_id
    returning 1
  )
  select count(*) into v_closed from done;
  return v_closed;
end;
$$;

-- ---------- Student / Admin: account ----------
create function public.activate_my_account()
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(auth.jwt() ->> 'email');
  v_profile public.profiles;
begin
  if v_email is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update public.profiles
  set account_status = 'active', activated_at = now()
  where email = v_email and account_status = 'provisioned'
  returning * into v_profile;

  if not found then
    raise exception 'not_found: no provisioned account for this email'
      using errcode = 'P0002';
  end if;
  return v_profile;
end;
$$;

-- Who am I? Returns the caller's own ACTIVE profile (role, status). Use this
-- right after sign-in to decide which screens to show.
create function public.get_my_profile()
returns public.profiles
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
begin
  select p.* into v_profile
  from public.profiles p
  where p.profile_id = public.current_profile_id();

  if not found then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return v_profile;
end;
$$;

-- ---------- Student: conversation and messages ----------
create function public.get_or_create_my_conversation()
returns public.conversations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pid uuid := public.current_student_profile_id();
  v_conv public.conversations;
begin
  if v_pid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  insert into public.conversations (student_profile_id)
  values (v_pid)
  on conflict (student_profile_id) do nothing;

  select * into v_conv
  from public.conversations
  where student_profile_id = v_pid;
  return v_conv;
end;
$$;

-- Saves the Student's message, logs the question, and keeps the chat session
-- (one-hour inactivity) up to date.
create function public.send_student_message(p_content text)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pid  uuid := public.current_student_profile_id();
  v_text text := btrim(coalesce(p_content, ''));
  v_conv public.conversations;
  v_msg  public.messages;
begin
  if v_pid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_text = '' or length(v_text) > 4000 then
    raise exception 'invalid_input: content must be 1 to 4000 characters'
      using errcode = '22023';
  end if;

  v_conv := public.get_or_create_my_conversation();
  perform public.close_idle_chat_sessions(interval '1 hour', v_conv.conversation_id);

  insert into public.messages (conversation_id, sender_type, content)
  values (v_conv.conversation_id, 'student', v_text)
  returning * into v_msg;

  update public.conversations
  set last_activity_at = v_msg.sent_at
  where conversation_id = v_conv.conversation_id;

  insert into public.chat_sessions (conversation_id, started_at, last_activity_at)
  values (v_conv.conversation_id, v_msg.sent_at, v_msg.sent_at)
  on conflict (conversation_id) where ended_at is null
  do update set last_activity_at = excluded.last_activity_at;

  insert into public.interaction_logs (message_id, question_text)
  values (v_msg.message_id, v_text);

  return v_msg;
end;
$$;

-- Student history, newest first, keyset pagination. To load the next (older)
-- page pass the sent_at and message_id of the LAST row of the previous page.
create function public.get_my_messages(
  p_limit integer default 30,
  p_before_sent_at timestamptz default null,
  p_before_message_id uuid default null
)
returns setof public.messages
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pid uuid := public.current_student_profile_id();
begin
  if v_pid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  select m.*
  from public.messages m
  join public.conversations c on c.conversation_id = m.conversation_id
  where c.student_profile_id = v_pid
    and m.archived_at is null
    and (
      p_before_sent_at is null
      or m.sent_at < p_before_sent_at
      or (m.sent_at = p_before_sent_at
          and p_before_message_id is not null
          and m.message_id < p_before_message_id)
    )
  order by m.sent_at desc, m.message_id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$$;

create function public.edit_my_message(p_message_id uuid, p_content text)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pid  uuid := public.current_student_profile_id();
  v_text text := btrim(coalesce(p_content, ''));
  v_msg  public.messages;
begin
  if v_pid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_text = '' or length(v_text) > 4000 then
    raise exception 'invalid_input: content must be 1 to 4000 characters'
      using errcode = '22023';
  end if;

  update public.messages m
  set content = v_text
  from public.conversations c
  where m.message_id = p_message_id
    and c.conversation_id = m.conversation_id
    and c.student_profile_id = v_pid
    and m.sender_type = 'student'
    and m.archived_at is null
  returning m.* into v_msg;

  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  return v_msg;
end;
$$;

create function public.archive_my_message(p_message_id uuid)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pid uuid := public.current_student_profile_id();
  v_msg public.messages;
begin
  if v_pid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update public.messages m
  set archived_at = now()
  from public.conversations c
  where m.message_id = p_message_id
    and c.conversation_id = m.conversation_id
    and c.student_profile_id = v_pid
    and m.sender_type = 'student'
    and m.archived_at is null
  returning m.* into v_msg;

  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  return v_msg;
end;
$$;

-- Thumbs up/down on an OASSIS response. Calling again changes the rating.
create function public.submit_response_feedback(
  p_response_message_id uuid,
  p_rating text
)
returns public.response_feedback
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pid    uuid := public.current_student_profile_id();
  v_sender text;
  v_fb     public.response_feedback;
begin
  if v_pid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_rating is null or p_rating not in ('up', 'down') then
    raise exception 'invalid_input: rating must be up or down'
      using errcode = '22023';
  end if;

  select m.sender_type into v_sender
  from public.messages m
  join public.conversations c on c.conversation_id = m.conversation_id
  where m.message_id = p_response_message_id
    and c.student_profile_id = v_pid
    and m.archived_at is null;

  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;
  if v_sender <> 'oassis' then
    raise exception 'invalid_input: feedback must target an OASSIS response'
      using errcode = '22023';
  end if;

  insert into public.response_feedback (response_message_id, rating)
  values (p_response_message_id, p_rating)
  on conflict (response_message_id)
  do update set rating = excluded.rating, submitted_at = now()
  returning * into v_fb;
  return v_fb;
end;
$$;

-- ---------- Everyone (Visitor, Student, Admin): knowledge retrieval ----------
-- Published entries only. Optional case-insensitive search on title/content.
create function public.get_published_knowledge(
  p_search text default null,
  p_limit integer default 20
)
returns table (entry_id uuid, title varchar, content text, updated_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select e.entry_id, e.title, e.content, e.updated_at
  from public.knowledge_entries e
  where e.publication_status = 'published'
    and (
      nullif(btrim(p_search), '') is null
      or position(lower(btrim(p_search)) in lower(e.title)) > 0
      or position(lower(btrim(p_search)) in lower(e.content)) > 0
    )
  order by e.updated_at desc, e.entry_id
  limit least(greatest(coalesce(p_limit, 20), 1), 100)
$$;

-- ---------- Visitor: audit log and unanswered inquiries ----------
-- Visitor conversations are never stored. Only the question is recorded, with
-- message_id = NULL.
create function public.log_visitor_question(
  p_question text,
  p_answered boolean default true
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_text text := btrim(coalesce(p_question, ''));
begin
  if v_text = '' or length(v_text) > 2000 then
    raise exception 'invalid_input: question must be 1 to 2000 characters'
      using errcode = '22023';
  end if;

  insert into public.interaction_logs (message_id, question_text)
  values (null, v_text);

  if not coalesce(p_answered, true) then
    insert into public.unanswered_inquiries (message_id, inquiry_text)
    values (null, v_text);
  end if;
end;
$$;

-- ---------- Admin: review lists ----------
create function public.admin_get_interaction_logs(
  p_limit integer default 50,
  p_before_recorded_at timestamptz default null
)
returns table (
  log_id uuid, question_text text, recorded_at timestamptz,
  source text, student_email text, message_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  select l.log_id, l.question_text, l.recorded_at,
         case when l.message_id is null then 'visitor' else 'student' end,
         p.email::text, l.message_id
  from public.interaction_logs l
  left join public.messages m on m.message_id = l.message_id
  left join public.conversations c on c.conversation_id = m.conversation_id
  left join public.profiles p on p.profile_id = c.student_profile_id
  where p_before_recorded_at is null or l.recorded_at < p_before_recorded_at
  order by l.recorded_at desc, l.log_id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

create function public.admin_get_unanswered_inquiries(
  p_limit integer default 50,
  p_before_recorded_at timestamptz default null
)
returns table (
  inquiry_id uuid, inquiry_text text, recorded_at timestamptz,
  source text, student_email text, message_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
  select u.inquiry_id, u.inquiry_text, u.recorded_at,
         case when u.message_id is null then 'visitor' else 'student' end,
         p.email::text, u.message_id
  from public.unanswered_inquiries u
  left join public.messages m on m.message_id = u.message_id
  left join public.conversations c on c.conversation_id = m.conversation_id
  left join public.profiles p on p.profile_id = c.student_profile_id
  where p_before_recorded_at is null or u.recorded_at < p_before_recorded_at
  order by u.recorded_at desc, u.inquiry_id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

-- ---------- Server-side only (service_role): OASSIS answers ----------
create function public.record_oassis_response(p_conversation_id uuid, p_content text)
returns public.messages
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_text text := btrim(coalesce(p_content, ''));
  v_msg  public.messages;
begin
  if v_text = '' then
    raise exception 'invalid_input: content is required' using errcode = '22023';
  end if;
  if not exists (select 1 from public.conversations
                 where conversation_id = p_conversation_id) then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  insert into public.messages (conversation_id, sender_type, content)
  values (p_conversation_id, 'oassis', v_text)
  returning * into v_msg;

  update public.conversations
  set last_activity_at = v_msg.sent_at
  where conversation_id = p_conversation_id;

  update public.chat_sessions
  set last_activity_at = v_msg.sent_at
  where conversation_id = p_conversation_id and ended_at is null;

  return v_msg;
end;
$$;

-- Records the fallback: OASSIS could not answer this Student message.
create function public.record_unanswered_for_message(p_message_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_text text;
  v_id   uuid;
begin
  select m.content into v_text
  from public.messages m
  where m.message_id = p_message_id and m.sender_type = 'student';

  if not found then
    raise exception 'not_found' using errcode = 'P0002';
  end if;

  select u.inquiry_id into v_id
  from public.unanswered_inquiries u
  where u.message_id = p_message_id;
  if found then
    return v_id;  -- already recorded
  end if;

  insert into public.unanswered_inquiries (message_id, inquiry_text)
  values (p_message_id, v_text)
  returning inquiry_id into v_id;
  return v_id;
end;
$$;

-- ---------- function privileges ----------
revoke all on function
  public.extract_session_keywords(uuid, timestamptz),
  public.close_idle_chat_sessions(interval, uuid),
  public.activate_my_account(),
  public.get_my_profile(),
  public.get_or_create_my_conversation(),
  public.send_student_message(text),
  public.get_my_messages(integer, timestamptz, uuid),
  public.edit_my_message(uuid, text),
  public.archive_my_message(uuid),
  public.submit_response_feedback(uuid, text),
  public.get_published_knowledge(text, integer),
  public.log_visitor_question(text, boolean),
  public.admin_get_interaction_logs(integer, timestamptz),
  public.admin_get_unanswered_inquiries(integer, timestamptz),
  public.record_oassis_response(uuid, text),
  public.record_unanswered_for_message(uuid)
from public, anon, authenticated;

grant execute on function
  public.extract_session_keywords(uuid, timestamptz),
  public.close_idle_chat_sessions(interval, uuid),
  public.record_oassis_response(uuid, text),
  public.record_unanswered_for_message(uuid)
to service_role;

grant execute on function
  public.activate_my_account(),
  public.get_my_profile(),
  public.get_or_create_my_conversation(),
  public.send_student_message(text),
  public.get_my_messages(integer, timestamptz, uuid),
  public.edit_my_message(uuid, text),
  public.archive_my_message(uuid),
  public.submit_response_feedback(uuid, text),
  public.admin_get_interaction_logs(integer, timestamptz),
  public.admin_get_unanswered_inquiries(integer, timestamptz)
to authenticated, service_role;

grant execute on function public.get_published_knowledge(text, integer)
  to anon, authenticated, service_role;

grant execute on function public.log_visitor_question(text, boolean)
  to anon, service_role;
