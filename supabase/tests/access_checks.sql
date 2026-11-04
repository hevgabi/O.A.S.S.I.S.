-- =====================================================================
-- OASSIS access and constraint checks
--
-- Run AFTER the migrations and seed.sql, as the postgres role
-- (Supabase SQL Editor, or: psql -f supabase/tests/access_checks.sql).
-- Every check runs inside its own sub-transaction that is rolled back, so the
-- database is left exactly as it was. The final result table lists PASS/FAIL
-- per check plus a SUMMARY row.
--
-- Each check runs as a role: 'anon' (Visitor), 'authenticated' with an email
-- (Student/Admin), 'service_role' (server), or 'postgres' (constraint tests).
--   expect 'ok'    -> the SQL must succeed
--   expect 'rows'  -> must succeed and touch/return exactly expect_rows rows
--   expect 'error' -> must fail (optionally with a message fragment)
-- =====================================================================

create temp table checks (
  seq         int generated always as identity,
  name        text not null,
  run_as      text not null,
  email       text,
  setup       text,
  sql         text not null,
  expect      text not null check (expect in ('ok', 'rows', 'error')),
  expect_rows bigint,
  expect_msg  text
);

create function pg_temp.chk(
  p_name text, p_run_as text, p_email text, p_sql text, p_expect text,
  p_rows bigint default null, p_msg text default null, p_setup text default null
) returns void language sql as $$
  insert into pg_temp.checks (name, run_as, email, setup, sql, expect, expect_rows, expect_msg)
  values (p_name, p_run_as, p_email, p_setup, p_sql, p_expect, p_rows, p_msg);
$$;

-- Handy ids from seed.sql
--   admin a1, active student b1, provisioned student b2, conversation c1
--   messages d1 (student) d2 (oassis, rated) d3 (student, unanswered) d4 (oassis)
--   entries f1 published, f2 pending_approval, f3 draft

-- ===================== 1. SCHEMA CONSTRAINTS (as postgres) =====================
select pg_temp.chk('profiles: email must be unique', 'postgres', null,
  $s$insert into public.profiles (email, role, account_status) values ('admin@mail.com','student','active')$s$,
  'error', null, 'duplicate key');
select pg_temp.chk('profiles: role limited to student/admin', 'postgres', null,
  $s$insert into public.profiles (email, role) values ('v@mail.com','visitor')$s$,
  'error', null, 'check constraint');
select pg_temp.chk('profiles: account_status limited to provisioned/active/disabled', 'postgres', null,
  $s$insert into public.profiles (email, role, account_status) values ('x@mail.com','student','banned')$s$,
  'error', null, 'check constraint');
select pg_temp.chk('profiles: no password column', 'postgres', null,
  $s$select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name ilike '%pass%'$s$,
  'rows', 0);
select pg_temp.chk('conversations: one conversation per Student', 'postgres', null,
  $s$insert into public.conversations (student_profile_id) values ('00000000-0000-4000-8000-0000000000b1')$s$,
  'error', null, 'duplicate key');
select pg_temp.chk('conversations: owner must be a Student, not an Admin', 'postgres', null,
  $s$insert into public.conversations (student_profile_id) values ('00000000-0000-4000-8000-0000000000a1')$s$,
  'error', null, 'must be a Student');
select pg_temp.chk('messages: sender_type limited to student/oassis', 'postgres', null,
  $s$insert into public.messages (conversation_id, sender_type, content) values ('00000000-0000-4000-8000-0000000000c1','visitor','hi')$s$,
  'error', null, 'check constraint');
select pg_temp.chk('messages: content must be non-empty', 'postgres', null,
  $s$insert into public.messages (conversation_id, sender_type, content) values ('00000000-0000-4000-8000-0000000000c1','student','   ')$s$,
  'error', null, 'check constraint');
select pg_temp.chk('messages: OASSIS responses cannot be archived', 'postgres', null,
  $s$update public.messages set archived_at = now() where message_id = '00000000-0000-4000-8000-0000000000d2'$s$,
  'error', null, 'check constraint');
select pg_temp.chk('messages: OASSIS responses cannot be edited', 'postgres', null,
  $s$update public.messages set edited_at = now() where message_id = '00000000-0000-4000-8000-0000000000d2'$s$,
  'error', null, 'check constraint');
select pg_temp.chk('feedback: at most one record per response', 'postgres', null,
  $s$insert into public.response_feedback (response_message_id, rating) values ('00000000-0000-4000-8000-0000000000d2','down')$s$,
  'error', null, 'duplicate key');
select pg_temp.chk('feedback: must target an OASSIS response, not a Student message', 'postgres', null,
  $s$insert into public.response_feedback (response_message_id, rating) values ('00000000-0000-4000-8000-0000000000d1','up')$s$,
  'error', null, 'OASSIS response');
select pg_temp.chk('feedback: rating limited to up/down', 'postgres', null,
  $s$insert into public.response_feedback (response_message_id, rating) values ('00000000-0000-4000-8000-0000000000d4','meh')$s$,
  'error', null, 'check constraint');
select pg_temp.chk('knowledge: creator must be an Admin profile', 'postgres', null,
  $s$insert into public.knowledge_entries (created_by_profile_id, title, content) values ('00000000-0000-4000-8000-0000000000b1','T','C')$s$,
  'error', null, 'must be an Admin');
select pg_temp.chk('knowledge: publication_status limited to draft/pending_approval/published', 'postgres', null,
  $s$insert into public.knowledge_entries (created_by_profile_id, title, content, publication_status) values ('00000000-0000-4000-8000-0000000000a1','T','C','archived')$s$,
  'error', null, 'check constraint');
select pg_temp.chk('unanswered_inquiries: NULL message_id allowed (Visitor)', 'postgres', null,
  $s$insert into public.unanswered_inquiries (message_id, inquiry_text) values (null, 'Visitor question')$s$,
  'ok');
select pg_temp.chk('interaction_logs: NULL message_id allowed (Visitor)', 'postgres', null,
  $s$insert into public.interaction_logs (message_id, question_text) values (null, 'Visitor question')$s$,
  'ok');
select pg_temp.chk('unanswered_inquiries: non-NULL message_id must exist', 'postgres', null,
  $s$insert into public.unanswered_inquiries (message_id, inquiry_text) values (gen_random_uuid(), 'x')$s$,
  'error', null, 'foreign key');
select pg_temp.chk('chat_sessions: extracted_keywords must be a JSON array', 'postgres', null,
  $s$insert into public.chat_sessions (conversation_id, extracted_keywords) values ('00000000-0000-4000-8000-0000000000c1','{"a":1}'::jsonb)$s$,
  'error', null, 'check constraint');
select pg_temp.chk('chat_sessions: only one open session per conversation', 'postgres', null,
  $s$insert into public.chat_sessions (conversation_id) values ('00000000-0000-4000-8000-0000000000c1')$s$,
  'error', null, 'duplicate key',
  $s$insert into public.chat_sessions (conversation_id) values ('00000000-0000-4000-8000-0000000000c1')$s$);

-- ===================== 2. ACTIVE STUDENT (student@mail.com) =====================
select pg_temp.chk('student: sees only own conversation', 'authenticated', 'student@mail.com',
  $s$select * from public.conversations$s$, 'rows', 1);
select pg_temp.chk('student: sees own messages', 'authenticated', 'student@mail.com',
  $s$select * from public.messages$s$, 'rows', 4);
select pg_temp.chk('student: sees own feedback', 'authenticated', 'student@mail.com',
  $s$select * from public.response_feedback$s$, 'rows', 1);
select pg_temp.chk('student: sees only own profile', 'authenticated', 'student@mail.com',
  $s$select * from public.profiles$s$, 'rows', 1);
select pg_temp.chk('student: cannot read knowledge_entries table', 'authenticated', 'student@mail.com',
  $s$select * from public.knowledge_entries$s$, 'rows', 0);
select pg_temp.chk('student: cannot read interaction_logs', 'authenticated', 'student@mail.com',
  $s$select * from public.interaction_logs$s$, 'rows', 0);
select pg_temp.chk('student: cannot read unanswered_inquiries', 'authenticated', 'student@mail.com',
  $s$select * from public.unanswered_inquiries$s$, 'rows', 0);
select pg_temp.chk('student: cannot read chat_sessions', 'authenticated', 'student@mail.com',
  $s$select * from public.chat_sessions$s$, 'rows', 0);
select pg_temp.chk('student: cannot insert messages directly', 'authenticated', 'student@mail.com',
  $s$insert into public.messages (conversation_id, sender_type, content) values ('00000000-0000-4000-8000-0000000000c1','student','direct')$s$,
  'error', null, 'permission denied');
select pg_temp.chk('student: cannot update messages directly', 'authenticated', 'student@mail.com',
  $s$update public.messages set content = 'hacked' where message_id = '00000000-0000-4000-8000-0000000000d1'$s$,
  'error', null, 'permission denied');
select pg_temp.chk('student: cannot escalate own role', 'authenticated', 'student@mail.com',
  $s$update public.profiles set role = 'admin' where profile_id = '00000000-0000-4000-8000-0000000000b1'$s$,
  'error', null, 'permission denied');
select pg_temp.chk('student: cannot create knowledge entries', 'authenticated', 'student@mail.com',
  $s$insert into public.knowledge_entries (title, content) values ('T','C')$s$,
  'error', null, 'permission denied|row-level security|Admin');
select pg_temp.chk('student: cannot edit/delete audit logs', 'authenticated', 'student@mail.com',
  $s$delete from public.interaction_logs$s$, 'error', null, 'permission denied');
select pg_temp.chk('student: history page 1 respects limit', 'authenticated', 'student@mail.com',
  $s$select * from public.get_my_messages(2)$s$, 'rows', 2);
select pg_temp.chk('student: history page 2 via cursor (older than m3)', 'authenticated', 'student@mail.com',
  $s$select * from public.get_my_messages(10, '2026-10-05 09:03:00+00'::timestamptz, '00000000-0000-4000-8000-0000000000d3'::uuid)$s$,
  'rows', 2);
select pg_temp.chk('student: send_student_message works', 'authenticated', 'student@mail.com',
  $s$select * from public.send_student_message('Where is the clinic?')$s$, 'rows', 1);
select pg_temp.chk('student: sending logs the question with its message_id', 'postgres', null,
  $s$select 1 from public.interaction_logs where question_text = 'Where is the clinic?' and message_id is not null$s$,
  'rows', 1,
  null, $s$select set_config('request.jwt.claims','{"email":"student@mail.com","role":"authenticated"}',true), (public.send_student_message('Where is the clinic?')).message_id$s$);
select pg_temp.chk('student: sending opens a chat session', 'postgres', null,
  $s$select 1 from public.chat_sessions where ended_at is null$s$, 'rows', 1,
  null, $s$select set_config('request.jwt.claims','{"email":"student@mail.com","role":"authenticated"}',true), (public.send_student_message('Hello')).message_id$s$);
select pg_temp.chk('student: blank message rejected', 'authenticated', 'student@mail.com',
  $s$select * from public.send_student_message('   ')$s$, 'error', null, 'invalid_input');
select pg_temp.chk('student: over-long message rejected', 'authenticated', 'student@mail.com',
  $s$select * from public.send_student_message(repeat('a', 4001))$s$, 'error', null, 'invalid_input');
select pg_temp.chk('student: can edit own message', 'authenticated', 'student@mail.com',
  $s$select * from public.edit_my_message('00000000-0000-4000-8000-0000000000d1','Updated question')$s$, 'rows', 1);
select pg_temp.chk('student: edit stamps edited_at', 'postgres', null,
  $s$select 1 from public.messages where message_id='00000000-0000-4000-8000-0000000000d1' and edited_at is not null and content='Updated question'$s$,
  'rows', 1, null,
  $s$select set_config('request.jwt.claims','{"email":"student@mail.com","role":"authenticated"}',true), (public.edit_my_message('00000000-0000-4000-8000-0000000000d1','Updated question')).message_id$s$);
select pg_temp.chk('student: cannot edit an OASSIS response', 'authenticated', 'student@mail.com',
  $s$select * from public.edit_my_message('00000000-0000-4000-8000-0000000000d2','x')$s$, 'error', null, 'not_found');
select pg_temp.chk('student: can archive own message', 'authenticated', 'student@mail.com',
  $s$select * from public.archive_my_message('00000000-0000-4000-8000-0000000000d1')$s$, 'rows', 1);
select pg_temp.chk('student: archived message is hidden from the student', 'authenticated', 'student@mail.com',
  $s$select 1 from public.messages where message_id='00000000-0000-4000-8000-0000000000d1'$s$, 'rows', 0, null,
  $s$select set_config('request.jwt.claims','{"email":"student@mail.com","role":"authenticated"}',true), (public.archive_my_message('00000000-0000-4000-8000-0000000000d1')).message_id$s$);
select pg_temp.chk('soft archive: archived row still exists in the table', 'postgres', null,
  $s$select 1 from public.messages where message_id='00000000-0000-4000-8000-0000000000d1' and archived_at is not null$s$, 'rows', 1, null,
  $s$select set_config('request.jwt.claims','{"email":"student@mail.com","role":"authenticated"}',true), (public.archive_my_message('00000000-0000-4000-8000-0000000000d1')).message_id$s$);
select pg_temp.chk('student: archived message excluded from history', 'authenticated', 'student@mail.com',
  $s$select * from public.get_my_messages(50)$s$, 'rows', 3, null,
  $s$select set_config('request.jwt.claims','{"email":"student@mail.com","role":"authenticated"}',true), (public.archive_my_message('00000000-0000-4000-8000-0000000000d1')).message_id$s$);
select pg_temp.chk('student: cannot archive an OASSIS response', 'authenticated', 'student@mail.com',
  $s$select * from public.archive_my_message('00000000-0000-4000-8000-0000000000d2')$s$, 'error', null, 'not_found');
select pg_temp.chk('student: can rate an OASSIS response', 'authenticated', 'student@mail.com',
  $s$select * from public.submit_response_feedback('00000000-0000-4000-8000-0000000000d4','down')$s$, 'rows', 1);
select pg_temp.chk('student: cannot rate a Student message', 'authenticated', 'student@mail.com',
  $s$select * from public.submit_response_feedback('00000000-0000-4000-8000-0000000000d1','up')$s$, 'error', null, 'invalid_input');
select pg_temp.chk('student: invalid rating rejected', 'authenticated', 'student@mail.com',
  $s$select * from public.submit_response_feedback('00000000-0000-4000-8000-0000000000d4','meh')$s$, 'error', null, 'invalid_input');
select pg_temp.chk('student: re-rating updates the single feedback record', 'postgres', null,
  $s$select 1 from public.response_feedback where response_message_id='00000000-0000-4000-8000-0000000000d2' and rating='down' having count(*) = 1$s$,
  'rows', 1, null,
  $s$select set_config('request.jwt.claims','{"email":"student@mail.com","role":"authenticated"}',true), (public.submit_response_feedback('00000000-0000-4000-8000-0000000000d2','down')).feedback_id$s$);
select pg_temp.chk('student: cannot call Admin functions', 'authenticated', 'student@mail.com',
  $s$select * from public.admin_get_interaction_logs()$s$, 'error', null, 'forbidden');
select pg_temp.chk('student: cannot call server-only functions', 'authenticated', 'student@mail.com',
  $s$select * from public.record_oassis_response('00000000-0000-4000-8000-0000000000c1','fake answer')$s$, 'error', null, 'permission denied');
select pg_temp.chk('student: cannot run session-closing procedure', 'authenticated', 'student@mail.com',
  $s$select public.close_idle_chat_sessions()$s$, 'error', null, 'permission denied');
select pg_temp.chk('student: get_published_knowledge returns published only', 'authenticated', 'student@mail.com',
  $s$select * from public.get_published_knowledge()$s$, 'rows', 1);
select pg_temp.chk('student: pending entry not retrievable by search', 'authenticated', 'student@mail.com',
  $s$select * from public.get_published_knowledge('library')$s$, 'rows', 0);
select pg_temp.chk('student: activating an already-active account is refused', 'authenticated', 'student@mail.com',
  $s$select * from public.activate_my_account()$s$, 'error', null, 'not_found');

select pg_temp.chk('student: get_my_profile returns own active profile', 'authenticated', 'student@mail.com',
  $s$select * from public.get_my_profile() where role = 'student' and email = 'student@mail.com'$s$, 'rows', 1);
select pg_temp.chk('admin: get_my_profile returns own profile (single row)', 'authenticated', 'admin@mail.com',
  $s$select * from public.get_my_profile() where role = 'admin'$s$, 'rows', 1);
select pg_temp.chk('provisioned student: get_my_profile refused until activated', 'authenticated', 'newstudent@mail.com',
  $s$select * from public.get_my_profile()$s$, 'error', null, 'forbidden');
select pg_temp.chk('visitor: get_my_profile refused', 'anon', null,
  $s$select * from public.get_my_profile()$s$, 'error', null, 'permission denied');

-- ===================== 3. DISABLED / PROVISIONED ACCOUNTS =====================
select pg_temp.chk('disabled student: loses history access', 'authenticated', 'student@mail.com',
  $s$select * from public.get_my_messages()$s$, 'error', null, 'forbidden',
  $s$update public.profiles set account_status='disabled' where email='student@mail.com'$s$);
select pg_temp.chk('disabled student: sees no conversations', 'authenticated', 'student@mail.com',
  $s$select * from public.conversations$s$, 'rows', 0, null,
  $s$update public.profiles set account_status='disabled' where email='student@mail.com'$s$);
select pg_temp.chk('provisioned student: cannot send messages', 'authenticated', 'newstudent@mail.com',
  $s$select * from public.send_student_message('Hi')$s$, 'error', null, 'forbidden');
select pg_temp.chk('provisioned student: sees no data', 'authenticated', 'newstudent@mail.com',
  $s$select * from public.profiles$s$, 'rows', 0);
select pg_temp.chk('provisioned student: can activate own account', 'authenticated', 'newstudent@mail.com',
  $s$select * from public.activate_my_account()$s$, 'rows', 1);
select pg_temp.chk('activated student: can then send a message', 'authenticated', 'newstudent@mail.com',
  $s$select * from public.send_student_message('Hello after activation')$s$, 'rows', 1, null,
  $s$select set_config('request.jwt.claims','{"email":"newstudent@mail.com","role":"authenticated"}',true), (public.activate_my_account()).profile_id$s$);
select pg_temp.chk('activated student gets their own single conversation', 'postgres', null,
  $s$select 1 from public.conversations where student_profile_id='00000000-0000-4000-8000-0000000000b2' having count(*) = 1$s$,
  'rows', 1, null,
  $s$select set_config('request.jwt.claims','{"email":"newstudent@mail.com","role":"authenticated"}',true), (public.activate_my_account()).profile_id, (public.send_student_message('a')).message_id, (public.send_student_message('b')).message_id$s$);

-- ===================== 4. ADMIN (admin@mail.com) =====================
select pg_temp.chk('admin: reads all knowledge entries', 'authenticated', 'admin@mail.com',
  $s$select * from public.knowledge_entries$s$, 'rows', 3);
select pg_temp.chk('admin: can create an entry (creator defaults to self)', 'authenticated', 'admin@mail.com',
  $s$insert into public.knowledge_entries (title, content) values ('New entry','Body') returning created_by_profile_id$s$, 'rows', 1);
select pg_temp.chk('admin: cannot forge another creator', 'authenticated', 'admin@mail.com',
  $s$insert into public.knowledge_entries (created_by_profile_id, title, content) values ('00000000-0000-4000-8000-0000000000b1','T','C')$s$, 'error');
select pg_temp.chk('admin: can publish a pending entry', 'authenticated', 'admin@mail.com',
  $s$update public.knowledge_entries set publication_status='published' where entry_id='00000000-0000-4000-8000-0000000000f2'$s$, 'rows', 1);
select pg_temp.chk('admin: publishing makes entry retrievable', 'anon', null,
  $s$select * from public.get_published_knowledge('library')$s$, 'rows', 1, null,
  $s$update public.knowledge_entries set publication_status='published' where entry_id='00000000-0000-4000-8000-0000000000f2'$s$);
select pg_temp.chk('admin: cannot change an entry creator', 'authenticated', 'admin@mail.com',
  $s$update public.knowledge_entries set created_by_profile_id='00000000-0000-4000-8000-0000000000b1' where entry_id='00000000-0000-4000-8000-0000000000f1'$s$,
  'error', null, 'permission denied');
select pg_temp.chk('admin: can delete an entry', 'authenticated', 'admin@mail.com',
  $s$delete from public.knowledge_entries where entry_id='00000000-0000-4000-8000-0000000000f3'$s$, 'rows', 1);
select pg_temp.chk('admin: reads interaction logs', 'authenticated', 'admin@mail.com',
  $s$select * from public.interaction_logs$s$, 'rows', 3);
select pg_temp.chk('admin: reads unanswered inquiries', 'authenticated', 'admin@mail.com',
  $s$select * from public.unanswered_inquiries$s$, 'rows', 2);
select pg_temp.chk('admin: reads chat sessions', 'authenticated', 'admin@mail.com',
  $s$select * from public.chat_sessions$s$, 'rows', 1);
select pg_temp.chk('admin: reads all profiles', 'authenticated', 'admin@mail.com',
  $s$select * from public.profiles$s$, 'rows', 3);
select pg_temp.chk('admin: cannot edit audit logs', 'authenticated', 'admin@mail.com',
  $s$update public.interaction_logs set question_text='x'$s$, 'error', null, 'permission denied');
select pg_temp.chk('admin: cannot delete audit logs', 'authenticated', 'admin@mail.com',
  $s$delete from public.interaction_logs$s$, 'error', null, 'permission denied');
select pg_temp.chk('admin: cannot read Student conversations', 'authenticated', 'admin@mail.com',
  $s$select * from public.conversations$s$, 'rows', 0);
select pg_temp.chk('admin: cannot read Student messages', 'authenticated', 'admin@mail.com',
  $s$select * from public.messages$s$, 'rows', 0);
select pg_temp.chk('admin: cannot send Student messages', 'authenticated', 'admin@mail.com',
  $s$select * from public.send_student_message('hi')$s$, 'error', null, 'forbidden');
select pg_temp.chk('admin: log list returns all rows', 'authenticated', 'admin@mail.com',
  $s$select * from public.admin_get_interaction_logs()$s$, 'rows', 3);
select pg_temp.chk('admin: log list marks Visitor rows (NULL message_id)', 'authenticated', 'admin@mail.com',
  $s$select * from public.admin_get_interaction_logs() where source='visitor' and student_email is null$s$, 'rows', 1);
select pg_temp.chk('admin: log list shows Student email for Student rows', 'authenticated', 'admin@mail.com',
  $s$select * from public.admin_get_interaction_logs() where source='student' and student_email='student@mail.com'$s$, 'rows', 2);
select pg_temp.chk('admin: unanswered list returns all rows', 'authenticated', 'admin@mail.com',
  $s$select * from public.admin_get_unanswered_inquiries()$s$, 'rows', 2);
select pg_temp.chk('admin: log list paginates', 'authenticated', 'admin@mail.com',
  $s$select * from public.admin_get_interaction_logs(1)$s$, 'rows', 1);

-- ===================== 5. VISITOR (anon, no profile) =====================
select pg_temp.chk('visitor: no access to profiles', 'anon', null,
  $s$select * from public.profiles$s$, 'error', null, 'permission denied');
select pg_temp.chk('visitor: no access to conversations', 'anon', null,
  $s$select * from public.conversations$s$, 'error', null, 'permission denied');
select pg_temp.chk('visitor: no access to messages', 'anon', null,
  $s$select * from public.messages$s$, 'error', null, 'permission denied');
select pg_temp.chk('visitor: no access to knowledge_entries table', 'anon', null,
  $s$select * from public.knowledge_entries$s$, 'error', null, 'permission denied');
select pg_temp.chk('visitor: no access to interaction_logs table', 'anon', null,
  $s$select * from public.interaction_logs$s$, 'error', null, 'permission denied');
select pg_temp.chk('visitor: can read published knowledge only', 'anon', null,
  $s$select * from public.get_published_knowledge()$s$, 'rows', 1);
select pg_temp.chk('visitor: knowledge search works', 'anon', null,
  $s$select * from public.get_published_knowledge('enrollment')$s$, 'rows', 1);
select pg_temp.chk('visitor: can log an answered question', 'anon', null,
  $s$select public.log_visitor_question('Where is the registrar?', true)$s$, 'ok');
select pg_temp.chk('visitor: unanswered question stored with NULL message_id', 'postgres', null,
  $s$select 1 from public.unanswered_inquiries where inquiry_text='Visitor asks' and message_id is null$s$, 'rows', 1, null,
  $s$select public.log_visitor_question('Visitor asks', false)$s$);
select pg_temp.chk('visitor: log row stored with NULL message_id', 'postgres', null,
  $s$select 1 from public.interaction_logs where question_text='Visitor asks' and message_id is null$s$, 'rows', 1, null,
  $s$select public.log_visitor_question('Visitor asks', false)$s$);
select pg_temp.chk('visitor: empty question rejected', 'anon', null,
  $s$select public.log_visitor_question('  ', true)$s$, 'error', null, 'invalid_input');
select pg_temp.chk('visitor: cannot send Student messages', 'anon', null,
  $s$select * from public.send_student_message('hi')$s$, 'error', null, 'permission denied');
select pg_temp.chk('visitor: cannot call Admin functions', 'anon', null,
  $s$select * from public.admin_get_interaction_logs()$s$, 'error', null, 'permission denied');
select pg_temp.chk('visitor: cannot call server-only functions', 'anon', null,
  $s$select * from public.record_oassis_response('00000000-0000-4000-8000-0000000000c1','x')$s$, 'error', null, 'permission denied');
select pg_temp.chk('anonymous-flagged session never matches a profile', 'postgres', null,
  $s$select public.current_profile_id() is null$s$, 'ok', null, null,
  $s$select set_config('request.jwt.claims','{"email":"admin@mail.com","role":"authenticated","is_anonymous":true}',true)$s$);

-- ===================== 6. SERVER (service_role) =====================
select pg_temp.chk('server: can record an OASSIS response', 'service_role', null,
  $s$select * from public.record_oassis_response('00000000-0000-4000-8000-0000000000c1','Here is the answer.')$s$, 'rows', 1);
select pg_temp.chk('server: unknown conversation rejected', 'service_role', null,
  $s$select * from public.record_oassis_response(gen_random_uuid(),'x')$s$, 'error', null, 'not_found');
select pg_temp.chk('server: records unanswered inquiry for a Student message', 'service_role', null,
  $s$select public.record_unanswered_for_message('00000000-0000-4000-8000-0000000000d1')$s$, 'rows', 1);
select pg_temp.chk('server: unanswered recording is idempotent', 'postgres', null,
  $s$select 1 from public.unanswered_inquiries where message_id='00000000-0000-4000-8000-0000000000d3' having count(*) = 1$s$, 'rows', 1, null,
  $s$select public.record_unanswered_for_message('00000000-0000-4000-8000-0000000000d3')$s$);
select pg_temp.chk('server: cannot record unanswered for an OASSIS message', 'service_role', null,
  $s$select public.record_unanswered_for_message('00000000-0000-4000-8000-0000000000d2')$s$, 'error', null, 'not_found');

-- ===================== 7. ONE-HOUR INACTIVITY PROCEDURE =====================
select pg_temp.chk('idle session (2h) is closed with keywords', 'service_role', null,
  $s$select 1 from public.chat_sessions where last_activity_at = now() - interval '2 hours' and ended_at is not null and extracted_keywords ? 'enrollment'$s$,
  'rows', 1, null,
  $s$do $d$ begin
       insert into public.messages (conversation_id, sender_type, content, sent_at)
       values ('00000000-0000-4000-8000-0000000000c1','student','Enrollment documents schedule?', now() - interval '150 minutes');
       insert into public.chat_sessions (conversation_id, started_at, last_activity_at)
       values ('00000000-0000-4000-8000-0000000000c1', now() - interval '3 hours', now() - interval '2 hours');
       perform public.close_idle_chat_sessions();
     end $d$$s$);
select pg_temp.chk('recent session (30 min) stays open', 'service_role', null,
  $s$select 1 from public.chat_sessions where last_activity_at = now() - interval '30 minutes' and ended_at is null$s$,
  'rows', 1, null,
  $s$do $d$ begin
       insert into public.chat_sessions (conversation_id, started_at, last_activity_at)
       values ('00000000-0000-4000-8000-0000000000c1', now() - interval '1 hour', now() - interval '30 minutes');
       perform public.close_idle_chat_sessions();
     end $d$$s$);

-- ===================== runner =====================
create function pg_temp.run_checks()
returns table (seq int, name text, result text, detail text)
language plpgsql as $$
declare
  c record;
  n bigint;
  v_err text;
  v_setup_err text;
  v_ran boolean;
  v_pass boolean;
  v_detail text;
  v_claims text;
begin
  for c in select * from pg_temp.checks order by checks.seq loop
    v_err := null; v_setup_err := null; v_ran := false; n := null;
    begin
      if c.setup is not null then
        execute c.setup;
      end if;

      v_claims := case
        when c.email is not null
          then json_build_object('role', c.run_as, 'email', c.email)::text
        else json_build_object('role', c.run_as)::text end;
      perform set_config('request.jwt.claims', v_claims, true);
      execute format('set local role %I', c.run_as);

      begin
        v_ran := true;
        execute c.sql;
        get diagnostics n = row_count;
      exception when others then
        v_err := sqlerrm;
      end;

      reset role;
      raise exception 'rollback_check';   -- undo everything this check did
    exception when others then
      if sqlerrm <> 'rollback_check' then
        v_setup_err := sqlerrm;
      end if;
    end;

    if not v_ran then
      v_pass := false;
      v_detail := 'setup failed: ' || coalesce(v_setup_err, '?');
    elsif c.expect = 'ok' then
      v_pass := v_err is null;
      v_detail := coalesce(v_err, 'succeeded');
    elsif c.expect = 'rows' then
      v_pass := v_err is null and n = c.expect_rows;
      v_detail := coalesce('error: ' || v_err, 'got ' || n || ' rows, expected ' || c.expect_rows);
    else
      v_pass := v_err is not null
                and (c.expect_msg is null or v_err ~* c.expect_msg);
      v_detail := coalesce(v_err, 'expected an error but the statement succeeded');
    end if;

    seq := c.seq; name := c.name;
    result := case when v_pass then 'PASS' else 'FAIL' end;
    detail := v_detail;
    return next;
  end loop;
end;
$$;

with r as (select * from pg_temp.run_checks())
select seq, name, result, detail from r
union all
select 9999, 'SUMMARY',
       case when count(*) filter (where result = 'FAIL') = 0 then 'ALL PASS' else 'FAILURES' end,
       count(*) filter (where result = 'PASS') || ' passed, '
         || count(*) filter (where result = 'FAIL') || ' failed, ' || count(*) || ' total'
from r
order by seq;
