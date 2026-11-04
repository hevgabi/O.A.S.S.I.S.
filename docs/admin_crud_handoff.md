# OASSIS Admin CRUD Handoff

**Status date:** November 3, 2026
**Feature branch:** `bonifacio-admin-screens`
**Admin feature commit:** `656e636` — `Implement Admin CRUD and read-only views`

## Summary

The Admin prototype now supports KnowledgeEntry create, read, update, and delete;
publication statuses; published-only retrieval data access; and read-only views
for unanswered inquiries and interaction logs. The implementation uses local
in-memory sample data. It is not connected to a database or backend service, so
changes disappear when the app process ends.

The Admin feature is on `bonifacio-admin-screens`. This branch was
fast-forwarded to `origin/almene-integration` before the feature commit so it
uses the integrated app, routes, and demo authentication. The current local
branch and its `origin/bonifacio-admin-screens` tracking ref both point to
`656e636`. Its history contains the 10 commits already on
`almene-integration`, followed by the Admin feature commit. `almene-integration`
was not changed by this work. The local config/generated-file changes are
unstaged and are not part of the Admin feature commit.

## Assignment checklist status

| # | Checklist item | Status | Notes |
|---|---|---|---|
| 1 | Inspect existing Admin routes, screens, services, and demo data | Done | Existing in-memory behavior and its replacement boundary are listed in [admin_crud_regression.md](admin_crud_regression.md). |
| 2 | Block Student and Visitor access to Admin routes | Done in integrated app | `main.dart` redirects non-Admin sessions from `/admin/...`; widget tests cover Student and Visitor direct navigation. This route guard is part of the integrated base. |
| 3 | KnowledgeEntry list fields, states, and create action | Done | Shows title, status, update time, create action, loading/error/empty states, and a local-data/pagination notice. |
| 4 | KnowledgeEntry create and validation | Done with an assumption | Title and content are required; Save and Cancel are clear. New entries default to `draft` because no team-approved default workflow was specified. Confirm this default with the team. |
| 5 | KnowledgeEntry edit behavior | Done for in-memory service | Existing values/status load; validation keeps the dialog open and preserves values; `updatedAt` changes on save; failures are reported in the UI. A real backend failure has not been exercised. |
| 6 | Three publication statuses and published-only retrieval | Partial | Only `draft`, `pending_approval`, and `published` are modeled. `getPublishedEntries()` returns published entries only and has a service test. The current chat service is a placeholder, so the retrieval flow does not call this accessor yet. |
| 7 | KnowledgeEntry delete confirmation | Done | Dialog names the entry and explains that deletion permanently removes it from the knowledge base. The prototype removes it from the in-memory list. |
| 8 | Read-only unanswered inquiry review | Done for sample data | Shows question, recorded time, and source when available; includes loading/error/empty states and no resolve/update controls. |
| 9 | Read-only interaction log view and identity handling | Done for sample data | Shows question and recorded time. Student identity is optional and displayed only when supplied; Visitor records are anonymous. No persistent Student-profile join exists yet. |
| 10 | Keep audit logs immutable in Admin UI | Done | No edit/delete controls or mutation methods are exposed by the Admin log service. There are no backend endpoints yet. |
| 11 | Pagination or explicit list behavior | Done for prototype | Lists explicitly state that all locally available records are shown and backend pagination is not configured. |
| 12 | Authorization checks for Admin and Student | Done for demo authentication | Automated widget tests cover Admin CRUD and Student/Visitor route denial. These are hardcoded demo accounts, not real provisioned accounts. |
| 13 | Update CRUD matrix, ERD, and data dictionary only for approved changes | Not changed | No team-approved schema or use-case change was introduced. The supplied matrix/ERD are screenshots and the data dictionary is outside this repo; they were not edited. |
| 14 | Capture evidence for CRUD, retrieval, read-only views, and denied access | Partially done | Automated Flutter tests provide evidence for CRUD, published-only filtering, inquiry/log display, anonymous Visitor logs, and role-route denial. No manual screenshots or backend test evidence were captured. |
| 15 | Analyzer/build, audit-control review, and Project Lead handoff | Partially done | Analyzer, tests, and Web release build passed. UI has no audit mutation controls. Regression steps are documented below; a Project Lead handoff has not been sent. |

## Decisions and inputs still needed

1. **Approval workflow:** Confirm whether new entries should start as `draft` or
   `pending_approval`, who can approve/publish, and which status transitions are
   allowed. The current demo permits an Admin to select any of the three
   statuses directly.
2. **Backend contract:** Select the API/database contract for knowledge
   entries, unanswered inquiries, interaction logs, account identity, and
   failure/pagination behavior. The current adapters are in-memory only.
3. **Retrieval integration:** Connect the chat/retrieval service to
   `getPublishedEntries()` once that service exists; verify no non-published
   entry can reach retrieval.
4. **Identity and source mapping:** Decide how the backend will derive Student
   identity from the message/conversation/profile relationship and how inquiry
   source type will be obtained. The data dictionary uses nullable
   `message_id`; it does not define a separate `source_type` field. Do not add a
   table or field without team approval.
5. **Pagination:** Add paging/incremental loading only after the backend
   contract specifies it.
6. **Production authorization:** Replace demo sign-in and enforce Admin access
   in backend/database policies. The Flutter route guard is a UI safeguard,
   not a server security boundary.
7. **Documentation alignment:** If the team approves a workflow or schema
   change, update the source CRUD matrix, ERD, and data dictionary. Those source
   files were not available in the repository during this implementation.
8. **Final handoff evidence:** Run regression steps against the integrated
   backend with real Admin and Student test accounts, capture the requested
   evidence, and give the Project Lead the branch name and completed checklist.

## Verification recorded

The Admin feature code was verified on November 3, 2026:

- `flutter analyze` — no issues found.
- `flutter test` — all tests passed, including CRUD/status service coverage,
  Admin CRUD widget flow, Student/Visitor route denial, inquiry/log views, and
  Visitor anonymity.
- `flutter build web --release` — succeeded (`build/web`).
- `git diff --check` — passed.

These checks use the prototype and its in-memory services. They do not verify
backend persistence, production authorization, real pagination, or live
service-failure handling.

## Regression steps

See [admin_crud_regression.md](admin_crud_regression.md) for manual Admin steps
and backend handoff checks. The demo credentials are `admin@mail.com` and
`student@mail.com`, both with password `123`; do not use them as production
accounts.
