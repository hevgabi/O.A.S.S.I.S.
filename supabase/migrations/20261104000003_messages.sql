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
