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
