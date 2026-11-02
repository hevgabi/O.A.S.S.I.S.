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
- Kept `DemoAuthBackend` as the active implementation. It intentionally keeps
  the current demo credentials until the approved backend is available.
- Added `AuthService.refreshSession()` as the session-restoration hook. It
  clears in-memory session data when no active session can be restored.

### Login and route behavior

- The sign-in button is disabled while a request is in progress and changes to
  `Signing in...`.
- The login screen gives a distinct message for each supported authentication
  failure state.
- Student Chat is route-guarded. A signed-out user, Visitor, or Admin who
  attempts to open `/student-chat` is sent to the entry screen.
- Existing Admin-route protection remains in place.

### Persistent-chat data and backend contract

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

### Validation completed

- `flutter analyze` completed with no issues.
- `flutter test` passed with four tests:
  - provisioned Student is blocked from sign-in pending activation;
  - signed-out user is denied Student Chat access;
  - Student login enters Student Chat and is denied Admin routes;
  - Admin login enters the Knowledge Base.

## Not completed yet

These items require a confirmed backend contract and must not be simulated as
production behavior in the client.

- Provisioned-account activation screen and activation request.
- Real backend implementation of `AuthBackend`.
- Secure token/session storage and actual session refresh.
- Persistent conversation creation/loading.
- Newest-first message loading and upward history pagination UI.
- Pending, retry, and error UI for a real message-send operation.
- Edit controls and save flow for Student-authored messages.
- Archive confirmation and soft-archive UI behavior.
- Read/create/update feedback behavior in the UI.
- Real ownership checks, role checks, and server-side authorization.
- Full seed-data integration test sequence.

## Backend information needed before integration

1. Backend platform and client setup: Supabase, Firebase, or REST API.
2. Authentication endpoints, request fields, response payloads, and error
   codes for sign-in, session refresh, sign-out, disabled accounts, and
   provisioned accounts.
3. Activation design: token/link or activation code, required fields, expiry,
   and the backend operation that saves the Student-selected password.
4. Student Profile and Conversation schema or API payloads, including the
   rule that enforces one conversation per Student.
5. Message pagination format and cursor semantics.
6. Send-message request/response format, including OASSIS response creation.
7. Authorization and error responses for edit, archive, and feedback actions.
8. Seed credentials and test records for an active Student, provisioned
   Student, disabled Student, conversation, messages, and feedback.

## Current demo behavior

Until the backend is connected, use these demo credentials:

| Role | Email | Password |
|---|---|---|
| Student | `student@mail.com` | `123` |
| Admin | `admin@mail.com` | `123` |

Run the current web app with:

```powershell
flutter run -d chrome
```

The Windows desktop build was not verified because this computer does not have
the Visual Studio C++ toolchain required by Flutter Windows builds. This is an
environment setup issue, not an analyzer or Flutter-test failure.
