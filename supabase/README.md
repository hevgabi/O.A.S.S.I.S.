# OASSIS Backend (Supabase / PostgreSQL)

Owner: Naval (Database and Backend) · Branch: `naval-supabase-backend`
Source of truth: the approved ERD and `OASSIS Data Dictionary`. Every table and
column below matches the dictionary; anything added on top (defaults, triggers,
indexes, extra checks) is additive and listed under "Decisions".

## Layout

```
supabase/
  migrations/      10 ordered SQL files (apply in filename order)
  rollback/        rollback_all.sql (reverse order, dev only)
  seed.sql         development data for every role
  tests/           access_checks.sql (112 PASS/FAIL checks, self-cleaning)
  all_in_one_dev_setup.sql   generated: rollback + migrations + seed
docs/backend_service_contracts.md   what other members call
env.example.json                    variable names only (no secrets)
```

## Migration order

| # | File | Creates |
|---|------|---------|
| 1 | `..._profiles.sql` | `profiles` |
| 2 | `..._conversations.sql` | `conversations` (one per Student) |
| 3 | `..._messages.sql` | `messages` (soft delete via `archived_at`) |
| 4 | `..._response_feedback.sql` | `response_feedback` |
| 5 | `..._knowledge_entries.sql` | `knowledge_entries` |
| 6 | `..._unanswered_inquiries.sql` | `unanswered_inquiries` |
| 7 | `..._interaction_logs.sql` | `interaction_logs` |
| 8 | `..._chat_sessions.sql` | `chat_sessions` |
| 9 | `..._access_rules.sql` | identity helpers, Row Level Security, grants |
| 10 | `..._service_functions.sql` | the callable backend functions |

## Environment variable names (values never go in Git)

| Name | Used by | Notes |
|------|---------|-------|
| `SUPABASE_URL` | Flutter app | project URL |
| `SUPABASE_ANON_KEY` | Flutter app | publishable key; safe in the app |
| `SUPABASE_SERVICE_ROLE_KEY` | server-side only (Edge Function / cron) | **never** in the app or Git |
| `SUPABASE_DB_URL` | optional, for `psql` | contains the DB password |

The app reads the first two with `--dart-define-from-file=env.json`.
`env.json` is git-ignored; copy `env.example.json` and fill it in.

## Set up a clean development database

### Option A: Supabase SQL Editor (no tools needed)

1. Supabase Dashboard → SQL Editor → new query.
2. Paste the contents of `supabase/all_in_one_dev_setup.sql` and click **Run**.
   The editor warns the query is destructive; that is expected (it resets the
   OASSIS tables). It is **safe to re-run** but wipes data each time.
3. Open a new query, paste `supabase/tests/access_checks.sql`, click **Run**.
   The last row must read `ALL PASS`.

Prefer step-by-step? Run `migrations/*.sql` one by one in order, then `seed.sql`.

### Option B: psql / Supabase CLI

```bash
psql "$SUPABASE_DB_URL" -f supabase/rollback/rollback_all.sql   # optional reset
for f in supabase/migrations/*.sql; do psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f "$f"; done
psql "$SUPABASE_DB_URL" -f supabase/seed.sql                    # seed command
psql "$SUPABASE_DB_URL" -f supabase/tests/access_checks.sql     # access checks
```

## Required Supabase Auth settings

The access rules map an auth account to a profile **by email**, so:

1. **Authentication → Sign In / Providers → Email:** turn **off**
   "Allow new users to sign up". Accounts are provisioned, not self-registered.
   (With open sign-up, someone could register a Student's email.)
2. Keep **Confirm email** on for any user you create outside the dashboard.
3. Leave **Anonymous sign-ins off.** Visitors use the anon key with no sign-in
   and have no profile.
4. To sign in as a seeded user, create an Auth user with the same email
   (Dashboard → Authentication → Users → Add user, tick *Auto Confirm User*):
   `admin@mail.com`, `student@mail.com`, `newstudent@mail.com`.

## Rollback approach

`rollback/rollback_all.sql` drops functions, tables, and helpers in reverse
migration order (and removes the earlier prototype schema and its `auth.users`
trigger). It is for **development databases only**; it deletes all OASSIS data.
Auth users are never touched. After production data exists, replace it with
forward-only corrective migrations.

## Seed data (`seed.sql`)

Re-runnable. Provides: one **provisioned** Student, one **active** Student, one
Admin; **published**, **pending_approval**, and **draft** knowledge entries;
Student messages, OASSIS responses, one feedback record; a Student-originated
and a Visitor-originated unanswered inquiry; Student and Visitor logs; a closed
chat session with keywords.

## Test results (item 15)

`tests/access_checks.sql` covers: unique conversation, feedback uniqueness and
target validation, role limits, nullable Visitor `message_id`, soft archive,
published-only retrieval, one-hour inactivity, and access-denied cases for
Student, Admin, Visitor, disabled and provisioned accounts.

* **Verified here:** 112/112 pass on PostgreSQL 16 with Supabase's
  `anon` / `authenticated` / `service_role` roles and `auth.jwt()` emulated.
  The suite was mutation-checked (deliberately broken rules make it fail), and
  the upgrade path (prototype schema → rollback → migrations → seed → checks)
  and a repeat run both pass.
* **Still to do before merge:** run Option A or B on the team's real Supabase
  development project and give the Project Lead the SUMMARY row. I could not
  run it against a real Supabase project from where I worked.

## Decisions and known limitations

* **Auth link.** `profiles` has no auth-user column (dictionary has none), so the
  mapping is by lower-cased email. Requires the Auth settings above.
* **Writes go through functions.** Students never write tables directly; they
  call the functions in `docs/backend_service_contracts.md`. Admins write
  `knowledge_entries` directly (column-limited, RLS-checked).
* **OASSIS replies are server-side.** `record_oassis_response` and
  `record_unanswered_for_message` are `service_role` only. An Edge Function that
  calls them is **not** part of this branch.
* **Visitor logging is unauthenticated** (`log_visitor_question` is granted to
  `anon`) with length limits but **no rate limiting**. Add CAPTCHA or an Edge
  Function proxy before production.
* **Profile provisioning and disabling** are done with the service role or the
  dashboard; the dictionary defines no Admin account-management operation.
* **Idle sessions** close lazily on the Student's next message and when
  `close_idle_chat_sessions()` runs. Schedule it (pg_cron or an Edge Function)
  for tidy keyword extraction. `ended_at` is the closing time, not
  last-activity + 1 hour.
* **Status mapping for the UI.** Old `needsVerification` ↔ `pending_approval`;
  new Admin entries may also be `draft`. The Admin lists return
  `source` ('student'/'visitor') and `student_email`; the old `questioner` and
  free-text `role` fields do not exist in the dictionary.
* **Additive decisions:** lower-case email check, message length limits (4000
  chars, 2000 for Visitor questions), history/log indexes, `updated_at` /
  `started_at` / `last_activity_at` defaults, creator defaults to the signed-in
  Admin, audit logs have no UPDATE/DELETE grant for any user role.

## Checklist status

| # | Item | Status |
|---|------|--------|
| 1 | Secrets out of Git, names documented | Done (`env.json` ignored, `env.example.json`, table above) |
| 2 | Ordered migration plan | Done (10 files; order matches the assignment) |
| 3 | `profiles` | Done |
| 4 | `conversations`, one per Student, Student-only | Done (UNIQUE + trigger) |
| 5 | `messages` | Done |
| 6 | `response_feedback` | Done (UNIQUE + OASSIS-target trigger) |
| 7 | `knowledge_entries`, published-only retrieval | Done |
| 8 | Inquiries and logs, nullable `message_id` | Done |
| 9 | `chat_sessions`, one-hour procedure | Done (not a user use case) |
| 10 | Seed data for each role | Done |
| 11 | Least-privilege rules | Done (RLS + column grants) |
| 12 | Service contracts | Done (`docs/backend_service_contracts.md`) |
| 13 | Test queries | Done (112 checks) |
| 14 | Backend README | Done (this file) |
| 15 | Clean-DB run with results | Verified on emulated Postgres; **run on the real dev project and report** |
