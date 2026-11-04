# OASSIS Flutter Project Structure

The Flutter app contains entry, Visitor chat, Student chat, and Admin prototype
screens. Admin data is currently held in local in-memory services; it is sample
data and is lost when the app process ends.

- `lib/main.dart` and `lib/app_routes.dart`: app startup, navigation, and the
  Admin route guard.
- `lib/screens/`: entry, chat, and Admin knowledge/review screens.
- `lib/models/`: UI/domain objects for chat, knowledge entries, inquiries, and
  interaction logs.
- `lib/services/`: demo authentication and in-memory chat/Admin data adapters.
- `lib/widgets/` and `lib/theme/`: shared presentation components and styling.
- `test/`: Flutter widget and service tests.
- `docs/admin_crud_regression.md`: Admin verification steps and prototype limits.

No persistent backend contract is configured. The Admin in-memory adapters
should be replaced only after the team approves the API/database contract and
access rules. Current route checks are client-side navigation controls; they do
not replace server-side authorization or database security policies.
