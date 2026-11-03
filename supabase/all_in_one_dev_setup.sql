-- GENERATED FILE. Do not edit; it is the concatenation of:
--   rollback/rollback_all.sql, migrations/*.sql (in order), seed.sql
-- DEVELOPMENT ONLY: it first DELETES every OASSIS table and its data.
-- Paste into the Supabase SQL Editor and click Run. The editor will warn
-- that the query is destructive; that is expected for a dev reset.

-- ===== rollback/rollback_all.sql =====
-- Rollback for ALL OASSIS migrations (development databases only).
-- Reverse order of the migrations. Deletes all data in these tables.
-- Also removes objects from the earlier prototype schema so a dev database can
-- be reset to a clean state before re-applying the migrations.

-- Earlier prototype trigger on auth.users (safe if it does not exist)
drop trigger if exists on_auth_user_created on auth.users;

-- Migration 10 (service functions)
drop function if exists public.record_unanswered_for_message(uuid);
drop function if exists public.record_oassis_response(uuid, text);
drop function if exists public.admin_get_unanswered_inquiries(integer, timestamptz);
drop function if exists public.admin_get_interaction_logs(integer, timestamptz);
drop function if exists public.log_visitor_question(text, boolean);
drop function if exists public.get_published_knowledge(text, integer);
drop function if exists public.submit_response_feedback(uuid, text);
drop function if exists public.archive_my_message(uuid);
drop function if exists public.edit_my_message(uuid, text);
drop function if exists public.get_my_messages(integer, timestamptz, uuid);
drop function if exists public.send_student_message(text);
drop function if exists public.get_or_create_my_conversation();
drop function if exists public.activate_my_account();
drop function if exists public.get_my_profile();
drop function if exists public.close_idle_chat_sessions(interval, uuid);
drop function if exists public.extract_session_keywords(uuid, timestamptz);

-- Migrations 8 .. 1 (tables, reverse order; policies and triggers go with them)
drop table if exists public.chat_messages        cascade;  -- earlier prototype table
drop table if exists public.chat_sessions        cascade;
drop table if exists public.interaction_logs     cascade;
drop table if exists public.unanswered_inquiries cascade;
drop table if exists public.knowledge_entries    cascade;
drop table if exists public.response_feedback    cascade;
drop table if exists public.messages             cascade;
drop table if exists public.conversations        cascade;
drop table if exists public.profiles             cascade;

-- Trigger helpers and access helpers (migration 9)
drop function if exists public.touch_updated_at();
drop function if exists public.enforce_entry_creator_is_admin();
drop function if exists public.enforce_feedback_targets_oassis_message();
drop function if exists public.stamp_message_edit();
drop function if exists public.enforce_conversation_owner_is_student();
drop function if exists public.is_admin();
drop function if exists public.current_student_profile_id();
drop function if exists public.current_profile_id();

-- Earlier prototype function (safe if it does not exist)
drop function if exists public.handle_new_user();

-- ===== migrations/20261104000001_profiles.sql =====
-- Migration 1: profiles
-- Provisioned Student and Admin profiles. No password column: passwords live in
-- the authentication provider (Supabase Auth). A profile is mapped to its auth
-- account by the school email.

create table public.profiles (
  profile_id     uuid        primary key default gen_random_uuid(),
  email          text        not null unique,
  role           varchar(10) not null
                 check (role in ('student', 'admin')),
  account_status varchar(16) not null default 'provisioned'
                 check (account_status in ('provisioned', 'active', 'disabled')),
  activated_at   timestamptz,
  created_at     timestamptz not null default now(),
  constraint profiles_email_lowercase check (email = lower(email)),
  constraint profiles_email_not_blank  check (length(btrim(email)) > 0),
  constraint profiles_provisioned_not_activated
    check (account_status <> 'provisioned' or activated_at is null)
);

comment on table public.profiles is
  'Authorized Student/Admin profiles. Visitors never have a profile.';

-- ===== migrations/20261104000002_conversations.sql =====
-- Migration 2: conversations
-- One persistent conversation per Student (UNIQUE student_profile_id).

create table public.conversations (
  conversation_id    uuid        primary key default gen_random_uuid(),
  student_profile_id uuid        not null unique
                     references public.profiles (profile_id) on delete restrict,
  created_at         timestamptz not null default now(),
  last_activity_at   timestamptz not null default now()
);

-- Only a profile with role = 'student' may own a conversation.
create function public.enforce_conversation_owner_is_student()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.profiles
    where profile_id = new.student_profile_id and role = 'student'
  ) then
    raise exception 'conversation owner must be a Student profile'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger conversations_owner_is_student
  before insert or update of student_profile_id on public.conversations
  for each row execute function public.enforce_conversation_owner_is_student();

-- ===== migrations/20261104000003_messages.sql =====
-- Migration 3: messages
-- Student messages and OASSIS responses. archived_at is a soft delete.

create table public.messages (
  message_id      uuid        primary key default gen_random_uuid(),
  conversation_id uuid        not null
                  references public.conversations (conversation_id) on delete restrict,
  sender_type     varchar(10) not null
                  check (sender_type in ('student', 'oassis')),
  content         text        not null
                  check (length(btrim(content)) > 0),
  sent_at         timestamptz not null default now(),
  edited_at       timestamptz,
  archived_at     timestamptz,
  -- Only Student-sent messages can be edited or archived.
  constraint messages_only_student_edited
    check (sender_type = 'student' or (edited_at is null and archived_at is null))
);

-- History pagination: newest first, keyset on (sent_at, message_id).
create index messages_conversation_history_idx
  on public.messages (conversation_id, sent_at desc, message_id desc);

-- Stamp edited_at whenever the text of a message changes.
create function public.stamp_message_edit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.content is distinct from old.content then
    new.edited_at := now();
  end if;
  return new;
end;
$$;

create trigger messages_stamp_edit
  before update on public.messages
  for each row execute function public.stamp_message_edit();

-- ===== migrations/20261104000004_response_feedback.sql =====
-- Migration 4: response_feedback
-- At most one rating per OASSIS response (UNIQUE response_message_id).

create table public.response_feedback (
  feedback_id         uuid        primary key default gen_random_uuid(),
  response_message_id uuid        not null unique
                      references public.messages (message_id) on delete restrict,
  rating              varchar(10) not null check (rating in ('up', 'down')),
  submitted_at        timestamptz not null default now()
);

-- Feedback must target an OASSIS response, never a Student message.
create function public.enforce_feedback_targets_oassis_message()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.messages
    where message_id = new.response_message_id and sender_type = 'oassis'
  ) then
    raise exception 'feedback must target an OASSIS response message'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger response_feedback_targets_oassis
  before insert or update of response_message_id on public.response_feedback
  for each row execute function public.enforce_feedback_targets_oassis_message();

-- ===== migrations/20261104000005_knowledge_entries.sql =====
-- Migration 5: knowledge_entries
-- Campus information managed by Admins. Only 'published' entries are retrievable
-- by OASSIS (enforced by the access rules in migration 9/10).

create table public.knowledge_entries (
  entry_id              uuid         primary key default gen_random_uuid(),
  created_by_profile_id uuid         not null
                        references public.profiles (profile_id) on delete restrict,
  title                 varchar(200) not null check (length(btrim(title)) > 0),
  content               text         not null check (length(btrim(content)) > 0),
  publication_status    varchar(20)  not null default 'draft'
                        check (publication_status in ('draft', 'pending_approval', 'published')),
  created_at            timestamptz  not null default now(),
  updated_at            timestamptz  not null default now()
);

create index knowledge_entries_status_idx
  on public.knowledge_entries (publication_status);

-- The creator must be an Admin profile.
create function public.enforce_entry_creator_is_admin()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.profiles
    where profile_id = new.created_by_profile_id and role = 'admin'
  ) then
    raise exception 'knowledge entry creator must be an Admin profile'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger knowledge_entries_creator_is_admin
  before insert or update of created_by_profile_id on public.knowledge_entries
  for each row execute function public.enforce_entry_creator_is_admin();

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger knowledge_entries_touch
  before update on public.knowledge_entries
  for each row execute function public.touch_updated_at();

-- ===== migrations/20261104000006_unanswered_inquiries.sql =====
-- Migration 6: unanswered_inquiries
-- message_id IS NULL means the inquiry came from a Visitor (by design, not a
-- broken foreign key).

create table public.unanswered_inquiries (
  inquiry_id   uuid        primary key default gen_random_uuid(),
  message_id   uuid        references public.messages (message_id) on delete restrict,
  inquiry_text text        not null check (length(btrim(inquiry_text)) > 0),
  recorded_at  timestamptz not null default now()
);

create index unanswered_inquiries_recorded_idx
  on public.unanswered_inquiries (recorded_at desc);

-- ===== migrations/20261104000007_interaction_logs.sql =====
-- Migration 7: interaction_logs
-- Read-only audit records. message_id IS NULL means a Visitor question.

create table public.interaction_logs (
  log_id        uuid        primary key default gen_random_uuid(),
  message_id    uuid        references public.messages (message_id) on delete restrict,
  question_text text        not null check (length(btrim(question_text)) > 0),
  recorded_at   timestamptz not null default now()
);

create index interaction_logs_recorded_idx
  on public.interaction_logs (recorded_at desc);

-- ===== migrations/20261104000008_chat_sessions.sql =====
-- Migration 8: chat_sessions
-- Internal record that supports the one-hour inactivity procedure. It is not
-- exposed to users as a use case.

create table public.chat_sessions (
  session_id         uuid        primary key default gen_random_uuid(),
  conversation_id    uuid        not null
                     references public.conversations (conversation_id) on delete restrict,
  started_at         timestamptz not null default now(),
  last_activity_at   timestamptz not null default now(),
  ended_at           timestamptz,
  extracted_keywords jsonb
                     check (extracted_keywords is null
                            or jsonb_typeof(extracted_keywords) = 'array')
);

-- At most one open (not ended) session per conversation.
create unique index chat_sessions_one_open_per_conversation
  on public.chat_sessions (conversation_id)
  where ended_at is null;

-- Finds idle open sessions quickly.
create index chat_sessions_open_activity_idx
  on public.chat_sessions (last_activity_at)
  where ended_at is null;

-- ===== migrations/20261104000009_access_rules.sql =====
-- Migration 9: least-privilege access rules (helpers, Row Level Security, grants)
--
-- Identity model: a Supabase Auth account is mapped to a profile by email.
-- Only profiles with account_status = 'active' get any access. Anonymous
-- (Visitor) sessions never match a profile.
--
-- Write model: Students never write tables directly. They call the functions in
-- migration 10. Admins write knowledge_entries directly (RLS-checked) and can
-- only read logs, inquiries and sessions.

-- ---------- identity helpers ----------
create function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.profile_id
  from public.profiles p
  where p.account_status = 'active'
    and p.email = lower(auth.jwt() ->> 'email')
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
$$;

create function public.current_student_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.profile_id
  from public.profiles p
  where p.role = 'student'
    and p.account_status = 'active'
    and p.email = lower(auth.jwt() ->> 'email')
    and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
$$;

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.role = 'admin'
      and p.account_status = 'active'
      and p.email = lower(auth.jwt() ->> 'email')
      and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  )
$$;

revoke all on function public.current_profile_id()         from public;
revoke all on function public.current_student_profile_id() from public;
revoke all on function public.is_admin()                   from public;
grant execute on function public.current_profile_id()         to anon, authenticated, service_role;
grant execute on function public.current_student_profile_id() to anon, authenticated, service_role;
grant execute on function public.is_admin()                   to anon, authenticated, service_role;

-- Creator of a knowledge entry defaults to the signed-in Admin.
alter table public.knowledge_entries
  alter column created_by_profile_id set default public.current_profile_id();

-- ---------- table privileges ----------
revoke all on table
  public.profiles, public.conversations, public.messages,
  public.response_feedback, public.knowledge_entries,
  public.unanswered_inquiries, public.interaction_logs, public.chat_sessions
from anon, authenticated;

-- Visitors (anon) get no direct table access at all.
-- Signed-in users get SELECT only; Row Level Security narrows it per role.
grant select on
  public.profiles, public.conversations, public.messages,
  public.response_feedback, public.unanswered_inquiries,
  public.interaction_logs, public.chat_sessions
to authenticated;

-- Admins manage knowledge entries (column-limited writes; RLS requires Admin).
grant select, delete on public.knowledge_entries to authenticated;
grant insert (created_by_profile_id, title, content, publication_status)
  on public.knowledge_entries to authenticated;
grant update (title, content, publication_status)
  on public.knowledge_entries to authenticated;

-- Server-side code (service_role) has full access.
grant all on
  public.profiles, public.conversations, public.messages,
  public.response_feedback, public.knowledge_entries,
  public.unanswered_inquiries, public.interaction_logs, public.chat_sessions
to service_role;

-- ---------- Row Level Security ----------
alter table public.profiles             enable row level security;
alter table public.conversations        enable row level security;
alter table public.messages             enable row level security;
alter table public.response_feedback    enable row level security;
alter table public.knowledge_entries    enable row level security;
alter table public.unanswered_inquiries enable row level security;
alter table public.interaction_logs     enable row level security;
alter table public.chat_sessions        enable row level security;

-- profiles: a user sees their own profile; an Admin sees all.
create policy profiles_select on public.profiles
  for select to authenticated
  using (profile_id = public.current_profile_id() or public.is_admin());

-- conversations: a Student sees only their own.
create policy conversations_select_own on public.conversations
  for select to authenticated
  using (student_profile_id = public.current_student_profile_id());

-- messages: a Student sees only non-archived messages in their own conversation.
create policy messages_select_own on public.messages
  for select to authenticated
  using (
    archived_at is null
    and exists (
      select 1 from public.conversations c
      where c.conversation_id = messages.conversation_id
        and c.student_profile_id = public.current_student_profile_id()
    )
  );

-- response_feedback: a Student sees feedback on their own conversation.
create policy feedback_select_own on public.response_feedback
  for select to authenticated
  using (
    exists (
      select 1
      from public.messages m
      join public.conversations c on c.conversation_id = m.conversation_id
      where m.message_id = response_feedback.response_message_id
        and c.student_profile_id = public.current_student_profile_id()
    )
  );

-- knowledge_entries: Admin only. Everyone else reads published entries through
-- public.get_published_knowledge() (migration 10), never the table.
create policy entries_admin_select on public.knowledge_entries
  for select to authenticated using (public.is_admin());
create policy entries_admin_insert on public.knowledge_entries
  for insert to authenticated
  with check (public.is_admin() and created_by_profile_id = public.current_profile_id());
create policy entries_admin_update on public.knowledge_entries
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy entries_admin_delete on public.knowledge_entries
  for delete to authenticated using (public.is_admin());

-- unanswered_inquiries, interaction_logs, chat_sessions: Admin read-only.
create policy inquiries_admin_select on public.unanswered_inquiries
  for select to authenticated using (public.is_admin());
create policy logs_admin_select on public.interaction_logs
  for select to authenticated using (public.is_admin());
create policy sessions_admin_select on public.chat_sessions
  for select to authenticated using (public.is_admin());

-- ===== migrations/20261104000010_service_functions.sql =====
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

-- ===== seed.sql =====
-- Development seed data. Safe to re-run (fixed IDs, ON CONFLICT DO NOTHING).
-- Run AFTER all migrations, as the postgres role (SQL Editor or psql).
--
-- To sign in as a seeded user, create a Supabase Auth user with the SAME email
-- (Dashboard -> Authentication -> Users). Profiles map to auth accounts by email.
--
--   admin@mail.com        Admin, active
--   student@mail.com      Student, active
--   newstudent@mail.com   Student, provisioned (must call activate_my_account())

-- ---------- profiles ----------
insert into public.profiles (profile_id, email, role, account_status, activated_at, created_at) values
  ('00000000-0000-4000-8000-0000000000a1', 'admin@mail.com',      'admin',   'active',      '2026-10-01 08:00+00', '2026-10-01 07:00+00'),
  ('00000000-0000-4000-8000-0000000000b1', 'student@mail.com',    'student', 'active',      '2026-10-02 08:00+00', '2026-10-01 07:00+00'),
  ('00000000-0000-4000-8000-0000000000b2', 'newstudent@mail.com', 'student', 'provisioned', null,                  '2026-10-01 07:00+00')
on conflict do nothing;

-- ---------- conversation for the active Student ----------
insert into public.conversations (conversation_id, student_profile_id, created_at, last_activity_at) values
  ('00000000-0000-4000-8000-0000000000c1', '00000000-0000-4000-8000-0000000000b1',
   '2026-10-05 09:00+00', '2026-10-05 09:03+00')
on conflict do nothing;

-- ---------- messages ----------
-- m1: Student question (answered)      m2: OASSIS response (rated up)
-- m3: Student question (unanswered)    m4: OASSIS fallback response
insert into public.messages (message_id, conversation_id, sender_type, content, sent_at) values
  ('00000000-0000-4000-8000-0000000000d1', '00000000-0000-4000-8000-0000000000c1', 'student',
   'What documents do I need for enrollment?', '2026-10-05 09:00+00'),
  ('00000000-0000-4000-8000-0000000000d2', '00000000-0000-4000-8000-0000000000c1', 'oassis',
   'Bring your report card, a valid ID, and two recent photos to the Registrar.', '2026-10-05 09:00:20+00'),
  ('00000000-0000-4000-8000-0000000000d3', '00000000-0000-4000-8000-0000000000c1', 'student',
   'Is the gym open for the Saturday review session?', '2026-10-05 09:03+00'),
  ('00000000-0000-4000-8000-0000000000d4', '00000000-0000-4000-8000-0000000000c1', 'oassis',
   'I could not find that information. Your question was sent to an Admin for review.', '2026-10-05 09:03:15+00')
on conflict do nothing;

-- ---------- feedback ----------
insert into public.response_feedback (feedback_id, response_message_id, rating, submitted_at) values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000d2', 'up', '2026-10-05 09:01+00')
on conflict do nothing;

-- ---------- knowledge entries ----------
insert into public.knowledge_entries
  (entry_id, created_by_profile_id, title, content, publication_status, created_at, updated_at) values
  ('00000000-0000-4000-8000-0000000000f1', '00000000-0000-4000-8000-0000000000a1',
   'Enrollment requirements',
   'Bring your report card, a valid ID, and two recent photos to the Registrar.',
   'published', '2026-10-03 10:00+00', '2026-10-03 10:00+00'),
  ('00000000-0000-4000-8000-0000000000f2', '00000000-0000-4000-8000-0000000000a1',
   'Library hours',
   'The library is open Monday to Friday, 8:00 AM to 6:00 PM. Saturday hours are being confirmed.',
   'pending_approval', '2026-10-04 10:00+00', '2026-10-04 10:00+00'),
  ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-4000-8000-0000000000a1',
   'Campus directions (draft)',
   'Draft directions from the main gate to the Registrar.',
   'draft', '2026-10-04 11:00+00', '2026-10-04 11:00+00')
on conflict do nothing;

-- ---------- unanswered inquiries (Student-originated and Visitor-originated) ----------
insert into public.unanswered_inquiries (inquiry_id, message_id, inquiry_text, recorded_at) values
  ('00000000-0000-4000-8000-000000000a11', '00000000-0000-4000-8000-0000000000d3',
   'Is the gym open for the Saturday review session?', '2026-10-05 09:03:15+00'),
  ('00000000-0000-4000-8000-000000000a12', null,
   'Where can I get a visitor parking pass?', '2026-10-05 10:15+00')
on conflict do nothing;

-- ---------- interaction logs (Student x2, Visitor x1) ----------
insert into public.interaction_logs (log_id, message_id, question_text, recorded_at) values
  ('00000000-0000-4000-8000-000000000b11', '00000000-0000-4000-8000-0000000000d1',
   'What documents do I need for enrollment?', '2026-10-05 09:00+00'),
  ('00000000-0000-4000-8000-000000000b12', '00000000-0000-4000-8000-0000000000d3',
   'Is the gym open for the Saturday review session?', '2026-10-05 09:03+00'),
  ('00000000-0000-4000-8000-000000000b13', null,
   'Where can I get a visitor parking pass?', '2026-10-05 10:15+00')
on conflict do nothing;

-- ---------- closed chat session ----------
insert into public.chat_sessions
  (session_id, conversation_id, started_at, last_activity_at, ended_at, extracted_keywords) values
  ('00000000-0000-4000-8000-000000000c11', '00000000-0000-4000-8000-0000000000c1',
   '2026-10-05 09:00+00', '2026-10-05 09:03+00', '2026-10-05 10:03+00',
   '["documents","enrollment","gym","review","saturday","session"]'::jsonb)
on conflict do nothing;
