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
