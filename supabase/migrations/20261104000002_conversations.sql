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
