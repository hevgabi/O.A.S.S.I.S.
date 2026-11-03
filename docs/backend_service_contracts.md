# OASSIS Backend Service Contracts

How other members call the backend. All calls use the Supabase client, which
sends the signed-in user's token (or the anon key for Visitors). **No direct
database edits are needed.**

```dart
final supabase = Supabase.instance.client;
final msg = await supabase.rpc('send_student_message', params: {'p_content': 'Hello'});
```

## Conventions

* **Errors.** Failures throw a `PostgrestException`; match on `code`/`message`:

  | `code` | `message` starts with | Meaning |
  |--------|----------------------|---------|
  | `42501` | `forbidden`, or `permission denied` | not signed in, wrong role, inactive account, or function not allowed for this role |
  | `P0002` | `not_found` | row does not exist **or is not yours** (never reveals which) |
  | `22023` | `invalid_input: ...` | bad parameter (blank/over-long text, bad rating) |

* **Identity.** Roles come from `profiles` (email match). Only `active`
  accounts have access. Visitors have no profile.
* **Timestamps** are UTC ISO-8601. Row fields use the data-dictionary names.
* **Pagination** is keyset (stable under new messages); see `get_my_messages`.

## Account

| Operation | Call | Who | Returns |
|-----------|------|-----|---------|
| Activate account (first sign-in) | `rpc('activate_my_account')` | signed-in user with a `provisioned` profile | `profiles` row (now `active`). `not_found` if there is nothing to activate |
| Who am I | `rpc('get_my_profile')` | active Student/Admin | own `profiles` row: `profile_id, email, role, account_status, activated_at, created_at`. `forbidden` if inactive/disabled |

**Login flow:** `auth.signInWithPassword` → try `activate_my_account` (ignore
`not_found`) → `get_my_profile` → route by `role` (`student` / `admin`).
Sign out with `auth.signOut()`.

## Student chat (role `student`, active)

| Operation | Call and params | Returns | Notes |
|-----------|-----------------|---------|-------|
| Get/create conversation | `rpc('get_or_create_my_conversation')` | `conversations` row | creates the one allowed conversation on first use |
| Send message | `rpc('send_student_message', {p_content})` | the new `messages` row | content 1–4000 chars. Also logs the question and updates the chat session. Closes the sender's session first if idle ≥ 1 h |
| Load history | `rpc('get_my_messages', {p_limit?, p_before_sent_at?, p_before_message_id?})` | list of `messages`, **newest first** | see pagination below |
| Edit own message | `rpc('edit_my_message', {p_message_id, p_content})` | updated `messages` row (`edited_at` set) | Student messages only, not archived. OASSIS messages → `not_found` |
| Delete (archive) own message | `rpc('archive_my_message', {p_message_id})` | `messages` row with `archived_at` set | soft delete; the row is hidden from history, not removed |
| Rate an OASSIS response | `rpc('submit_response_feedback', {p_response_message_id, p_rating})` | `response_feedback` row | `p_rating` = `'up'` or `'down'`. Calling again changes the rating (one record per response). Rating a Student message → `invalid_input` |

**Pagination (history).** `p_limit` default 30, clamped to 1–100.
First page: no cursor. Next (older) page: pass the `sent_at` and `message_id`
of the **last item** of the previous page:

```dart
final page = await supabase.rpc('get_my_messages', params: {
  'p_limit': 30,
  'p_before_sent_at': last['sent_at'],
  'p_before_message_id': last['message_id'],
});
// An empty list means there is no older history. Reverse for display.
```

Message fields: `message_id, conversation_id, sender_type ('student'|'oassis'),
content, sent_at, edited_at, archived_at`.

## Knowledge retrieval (Visitor, Student, Admin)

| Operation | Call | Returns |
|-----------|------|---------|
| Published knowledge | `rpc('get_published_knowledge', {p_search?, p_limit?})` | `entry_id, title, content, updated_at`; **published entries only**; `p_search` is a case-insensitive substring match on title/content; `p_limit` default 20, max 100 |

## Admin (role `admin`, active)

| Operation | Call | Returns / rules |
|-----------|------|-----------------|
| List all entries | `from('knowledge_entries').select()` | all statuses |
| Create entry | `from('knowledge_entries').insert({'title','content','publication_status'})` | `publication_status`: `draft` (default), `pending_approval`, `published`. Creator is set to the signed-in Admin automatically |
| Update entry | `from('knowledge_entries').update({...}).eq('entry_id', id)` | only `title`, `content`, `publication_status` are writable |
| Delete entry | `from('knowledge_entries').delete().eq('entry_id', id)` | |
| Interaction logs | `rpc('admin_get_interaction_logs', {p_limit?, p_before_recorded_at?})` | `log_id, question_text, recorded_at, source ('student'\|'visitor'), student_email, message_id`; newest first; limit default 50, max 200; page with the last `recorded_at` |
| Unanswered inquiries | `rpc('admin_get_unanswered_inquiries', {p_limit?, p_before_recorded_at?})` | `inquiry_id, inquiry_text, recorded_at, source, student_email, message_id` |

Logs are **read-only audit data**: no Admin or Student can edit or delete them.
Admins cannot read Student conversations or messages.

## Visitor (no sign-in, anon key)

| Operation | Call | Returns / rules |
|-----------|------|-----------------|
| Log a question | `rpc('log_visitor_question', {p_question, p_answered})` | nothing. 1–2000 chars. Writes an `interaction_logs` row with `message_id = NULL`; if `p_answered` is `false` also writes an `unanswered_inquiries` row. Visitors get no conversation or profile |
| Read knowledge | `get_published_knowledge` (above) | |

## Server-side only (`service_role`; e.g. an Edge Function)

Never call these from the Flutter app; the service-role key must stay on the server.

| Operation | Call | Returns |
|-----------|------|---------|
| Save an OASSIS answer | `record_oassis_response(p_conversation_id, p_content)` | `messages` row (`sender_type = 'oassis'`); updates conversation/session activity |
| Record the fallback | `record_unanswered_for_message(p_message_id)` | `inquiry_id` (idempotent); `not_found` unless it is a Student message |
| Close idle sessions | `close_idle_chat_sessions(p_idle = '1 hour', p_conversation_id = null)` | number of sessions closed; stores `extracted_keywords` |

**Typical chat turn:** the app calls `send_student_message` → a server
function finds an answer in `get_published_knowledge` → saves it with
`record_oassis_response` (or, if none is found, saves a fallback reply and calls
`record_unanswered_for_message`) → the app reloads with `get_my_messages`.
