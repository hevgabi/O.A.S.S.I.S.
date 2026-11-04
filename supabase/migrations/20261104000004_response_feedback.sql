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
