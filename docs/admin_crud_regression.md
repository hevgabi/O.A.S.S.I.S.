# Admin CRUD Regression Checklist

Run `flutter analyze` and `flutter test` from the project root before handoff.
The current Admin services use local in-memory sample records; CRUD results do
not persist across app restarts, and no backend authorization is implemented.

## Prototype behavior to replace with the backend

- Knowledge entries, unanswered inquiries, and interaction logs are local
  sample lists; changes disappear on app restart and do not affect shared data.
- Authentication is a hardcoded demo sign-in; it is not linked to provisioned
  `profiles` or an authentication provider.
- Lists show all in-memory sample records. There is no remote pagination,
  incremental loading, or live service failure source.
- The published-only service accessor is ready for a retrieval adapter, but the
  current chat service is a placeholder and does not perform knowledge retrieval.

## Automated coverage

- [ ] Admin can sign in and open the Knowledge Base.
- [ ] Student and Visitor sessions are redirected away from Admin routes.
- [ ] Knowledge entry create, validation, edit, status handling, and delete.
- [ ] Only entries with `published` status are returned by the retrieval view.
- [ ] Inquiry and interaction-log views render as read-only lists.
- [ ] Visitor interaction logs remain anonymous.

## Manual Admin regression steps

1. Sign in using the prototype Admin account (`admin@mail.com`, password `123`).
2. Open Knowledge Base. Confirm title, status, updated time, create action, and
   the prototype-data/pagination notice are visible.
3. Add an entry with blank title/content. Confirm validation appears and the
   form remains open. Add valid values and save; a new entry defaults to Draft.
4. Edit the entry. Confirm existing values/status load, change a field/status,
   save, and confirm the updated time changes.
5. Delete the entry. Confirm the dialog names it and states that it is removed
   from the knowledge base. Cancel once, then confirm deletion.
6. Open Unanswered Inquiries. Confirm question, source when available, and
   recorded time are shown; confirm there are no resolve or update actions.
7. Open Interaction Logs. Confirm question and recorded time are shown,
   Visitor entries are anonymous, and no edit/delete actions are present.
8. Sign out. Attempt to open each `/admin/...` route directly as Student and as
   Visitor. Confirm neither role can see an Admin screen.

## Backend handoff checks

Repeat the CRUD and access-denied flows against the approved backend before
merge. Verify pagination/incremental loading against its contract, ensure only
published knowledge is retrievable, and confirm interaction-log endpoints do
not expose update/delete operations. The client route guard alone is not a
security boundary.
