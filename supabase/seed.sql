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
