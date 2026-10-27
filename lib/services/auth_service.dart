import '../models/app_user.dart';

/// Temporary in-memory authentication for the prototype demo only.
/// Replace this with backend authentication before production use.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  bool get isAdmin => _currentUser?.role == AppUserRole.admin;

  bool get isStudent => _currentUser?.role == AppUserRole.student;

  AppUser? signIn({required String email, required String password}) {
    if (password != '123') return null;

    final normalizedEmail = email.trim().toLowerCase();
    _currentUser = switch (normalizedEmail) {
      'admin@mail.com' => const AppUser(
        email: 'admin@mail.com',
        role: AppUserRole.admin,
      ),
      'student@mail.com' => const AppUser(
        email: 'student@mail.com',
        role: AppUserRole.student,
      ),
      _ => null,
    };

    return _currentUser;
  }

  void signOut() {
    _currentUser = null;
  }
}
