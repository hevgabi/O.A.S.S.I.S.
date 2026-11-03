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
