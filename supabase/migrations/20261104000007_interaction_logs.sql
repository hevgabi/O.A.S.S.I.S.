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
