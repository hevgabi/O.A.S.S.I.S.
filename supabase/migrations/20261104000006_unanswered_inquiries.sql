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
