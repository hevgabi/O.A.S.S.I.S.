import '../models/app_user.dart';

enum AuthFailure {
  invalidCredentials,
  accountNotActivated,
  accountDisabled,
  signedOut,
  network,
  backend,
}

class AuthResult {
  const AuthResult.success(this.user) : failure = null;

  const AuthResult.failure(this.failure) : user = null;

  final AppUser? user;
  final AuthFailure? failure;

  bool get isSuccess => user != null && failure == null;
}

/// Contract for the approved authentication backend.
///
/// A production implementation must authenticate only provisioned accounts,
/// return the account status, and persist its own session securely.
abstract interface class AuthBackend {
  Future<AuthResult> signIn({required String email, required String password});

  Future<AppUser?> refreshSession();
}

/// Temporary demo implementation. Keep it until the approved backend is ready.
class DemoAuthBackend implements AuthBackend {
  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (password != '123') {
      return const AuthResult.failure(AuthFailure.invalidCredentials);
    }

    final user = switch (email.trim().toLowerCase()) {
      'admin@mail.com' => const AppUser(
        id: 'demo-admin',
        email: 'admin@mail.com',
        role: AppUserRole.admin,
        status: AccountStatus.active,
      ),
      'student@mail.com' => const AppUser(
        id: 'demo-student',
        email: 'student@mail.com',
        role: AppUserRole.student,
        status: AccountStatus.active,
      ),
      _ => null,
    };

    return user == null
        ? const AuthResult.failure(AuthFailure.invalidCredentials)
        : AuthResult.success(user);
  }

  @override
  Future<AppUser?> refreshSession() async => null;
}

class AuthService {
  AuthService({AuthBackend? backend}) : _backend = backend ?? DemoAuthBackend();

  static final AuthService instance = AuthService();

  final AuthBackend _backend;

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  bool get isAdmin => _currentUser?.role == AppUserRole.admin;

  bool get isStudent => _currentUser?.role == AppUserRole.student;

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _backend.signIn(email: email, password: password);
      final user = result.user;
      if (user == null) {
        _currentUser = null;
        return result;
      }

      if (user.status == AccountStatus.provisioned) {
        _currentUser = null;
        return const AuthResult.failure(AuthFailure.accountNotActivated);
      }
      if (user.status == AccountStatus.disabled) {
        _currentUser = null;
        return const AuthResult.failure(AuthFailure.accountDisabled);
      }

      _currentUser = user;
      return AuthResult.success(user);
    } on AuthNetworkException {
      _currentUser = null;
      return const AuthResult.failure(AuthFailure.network);
    } catch (_) {
      _currentUser = null;
      return const AuthResult.failure(AuthFailure.backend);
    }
  }

  Future<bool> refreshSession() async {
    try {
      final user = await _backend.refreshSession();
      if (user == null || !user.isActive) {
        _currentUser = null;
        return false;
      }
      _currentUser = user;
      return true;
    } catch (_) {
      _currentUser = null;
      return false;
    }
  }

  void signOut() {
    _currentUser = null;
  }
}

/// Backends throw this when a request could not reach the service.
class AuthNetworkException implements Exception {
  const AuthNetworkException();
}
