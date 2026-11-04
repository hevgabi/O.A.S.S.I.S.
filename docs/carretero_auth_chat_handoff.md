# Carretero Auth and Student Chat Handoff

## Scope

This work prepares the Student authentication and persistent-chat client for an
approved backend. It does not add public registration, change database schema,
or modify Admin CRUD screens.

Branch: `carretero-auth-chat`  
Foundation commit: `534420a Prepare auth and student chat backend integration`

## Completed

### Authentication foundation

- Added `AccountStatus` values for `provisioned`, `active`, and `disabled`.
- Added a stable Student/Admin identifier to `AppUser`.
- Added `AuthResult` and `AuthFailure` so the UI can distinguish invalid
  credentials, unactivated accounts, disabled accounts, signed-out state,
  network failures, and backend failures.
- Added the `AuthBackend` contract with `signIn` and `refreshSession` methods.
- Added `SupabaseAuthBackend`. When the app receives both `SUPABASE_URL` and
  `SUPABASE_ANON_KEY`, it signs in with Supabase Auth, activates a provisioned
  profile through `activate_my_account`, then loads the authenticated profile.
- The app keeps `DemoAuthBackend` only when Supabase environment values are not
  supplied, so local UI testing remains possible.
- Added `AuthService.refreshSession()` as the session-restoration hook. It
  clears in-memory session data when no active session can be restored.
- Added a local activation flow for provisioned Student accounts. The demo
  accepts `provisioned@mail.com` with activation code `OASSIS-123` and lets the
  Student choose a password.

### Login and route behavior

- The sign-in button is disabled while a request is in progress and changes to
  `Signing in...`.
- The login screen gives a distinct message for each supported authentication
  failure state.
- Added password visibility control and a password-help dialog that explains
  the backend dependency for real account recovery.
- Added a dedicated activation screen with email, activation-code, password,
  validation, loading, and error states.
- Student Chat is route-guarded. A signed-out user, Visitor, or Admin who
  attempts to open `/student-chat` is sent to the entry screen.
- Existing Admin-route protection remains in place.

### Local persistent-chat demo and backend contract

- Added persistent data models for `Conversation`, `ChatMessage`, and
  `ResponseFeedback`.
- Added message metadata needed for persistence: message ID, conversation ID,
  author, creation time, edit time, archive time, and delivery state.
- Added `ChatService`, the backend contract for the following operations:

| Method | Required parameters | Expected result |
|---|---|---|
| `getOrCreateStudentConversation` | `studentId` | The Student's one persistent conversation, created once only if absent |
| `fetchMessages` | `conversationId`, optional `beforeCursor`, optional `pageSize` | Newest-first message page and cursor for the next older page |
| `sendStudentMessage` | `conversationId`, `content` | Saved Student message and returned OASSIS response |
| `editStudentMessage` | `messageId`, `content` | Updated Student-authored message with `edited_at` data |
| `archiveStudentMessage` | `messageId` | Soft archive only; no client-side permanent deletion |
| `upsertResponseFeedback` | `responseMessageId`, `rating` | Creates feedback if absent or changes the existing rating |

`ChatBackendUnavailableException` records the expected state while no approved
persistent-chat backend is configured.

`SupabaseChatService` now calls the approved RPCs for conversation creation,
message history, sending, editing, archiving, and response feedback. It uses
the backend keyset cursor for older history and reads existing ratings through
the row-level-security protected `response_feedback` table.

`DemoChatService` now implements the contract locally for Student UI work. It
creates one in-memory conversation per Student, seeds enough history for
pagination, and enforces the current signed-in Student in the demo layer.

- Newest messages load first, while the UI displays messages chronologically.
- Scrolling to the top loads older pages without duplicates and preserves the
  visible scroll position.
- Sending uses a visible pending state and disables duplicate sends. Typing a
  message containing `fail` intentionally produces a recoverable demo failure
  with a Retry button.
- Student-authored messages have Edit and Archive actions. Archive is shown as
  a soft-deleted message, never removed from the local service.
- Thumbs-up/down controls appear only on OASSIS response messages. Existing
  local ratings are read on load and updated when the Student changes a rating.

### Validation completed

- `flutter analyze` completed with no issues.
- `flutter test` passed with five tests:
  - activation, conversation creation, pagination, send, edit, archive, and
    feedback work through the local demo service;
  - provisioned Student is blocked from sign-in pending activation;
  - signed-out user is denied Student Chat access;
  - Student login enters Student Chat and is denied Admin routes;
  - Admin login enters the Knowledge Base.

## Not completed yet

These items require a confirmed backend contract and must not be simulated as
production behavior in the client.

- Apply the backend migrations and seed data to the team's real Supabase
  development project.
- Create matching Supabase Auth users for the seeded profile emails.
- Add the OASSIS Edge Function. The RPC `send_student_message` saves a Student
  message, but the server-side function must still save the OASSIS response.
- Run the full seed-data integration sequence against the real development
  project, including auth, activation, pagination, edit, archive, and feedback.

## Supabase setup required before live mode

1. Run `supabase/all_in_one_dev_setup.sql` in the development project, then
   run `supabase/tests/access_checks.sql` and confirm its `ALL PASS` result.
2. Create auto-confirmed Supabase Auth users matching the seeded profile
   emails: `admin@mail.com`, `student@mail.com`, and `newstudent@mail.com`.
3. Copy `env.example.json` to a local, git-ignored `env.json`.
4. Run the app with `flutter run -d chrome --dart-define-from-file=env.json`.
5. Keep public self-registration and anonymous sign-ins disabled in Supabase.

## Current demo behavior

Until the backend is connected, use these demo credentials:

| Role | Email | Password |
|---|---|---|
| Student | `student@mail.com` | `123` |
| Admin | `admin@mail.com` | `123` |
| Provisioned Student | `provisioned@mail.com` | Activate with code `OASSIS-123` and choose a password |
| Disabled Student | `disabled@mail.com` | `123` |

Run the current web app with:

```powershell
flutter run -d chrome
```

To use the real Supabase backend after completing the setup above:

```powershell
flutter run -d chrome --dart-define-from-file=env.json
```

The Windows desktop build was not verified because this computer does not have
the Visual Studio C++ toolchain required by Flutter Windows builds. This is an
environment setup issue, not an analyzer or Flutter-test failure.
