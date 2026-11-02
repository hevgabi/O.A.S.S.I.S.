import '../models/app_user.dart';

enum AuthFailure {
  invalidCredentials,
  accountNotActivated,
  accountDisabled,
  invalidActivationCode,
  signedOut,
  network,
  backend,
}

class AuthResult {
  const AuthResult.success(this.user, {this.email}) : failure = null;

  const AuthResult.failure(this.failure, {this.email}) : user = null;

  final AppUser? user;
  final AuthFailure? failure;
  final String? email;

  bool get isSuccess => user != null && failure == null;
}

/// Contract for the approved authentication backend.
///
/// A production implementation must authenticate only provisioned accounts,
/// return the account status, and persist its own session securely.
abstract interface class AuthBackend {
  Future<AuthResult> signIn({required String email, required String password});

  Future<AuthResult> activateStudent({
    required String email,
    required String activationCode,
    required String password,
  });

  Future<AppUser?> refreshSession();
}

/// Temporary demo implementation. Keep it until the approved backend is ready.
class DemoAuthBackend implements AuthBackend {
  final Map<String, _DemoAccount> _accounts = {
    'admin@mail.com': _DemoAccount(
      id: 'demo-admin',
      role: AppUserRole.admin,
      status: AccountStatus.active,
      password: '123',
    ),
    'student@mail.com': _DemoAccount(
      id: 'demo-student',
      role: AppUserRole.student,
      status: AccountStatus.active,
      password: '123',
    ),
    'provisioned@mail.com': _DemoAccount(
      id: 'demo-provisioned-student',
      role: AppUserRole.student,
      status: AccountStatus.provisioned,
    ),
    'disabled@mail.com': _DemoAccount(
      id: 'demo-disabled-student',
      role: AppUserRole.student,
      status: AccountStatus.disabled,
      password: '123',
    ),
  };

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final account = _accounts[normalizedEmail];
    if (account == null) {
      return const AuthResult.failure(AuthFailure.invalidCredentials);
    }
    if (account.status == AccountStatus.provisioned) {
      return AuthResult.success(account.toUser(normalizedEmail));
    }
    if (account.password != password) {
      return const AuthResult.failure(AuthFailure.invalidCredentials);
    }

    return AuthResult.success(account.toUser(normalizedEmail));
  }

  @override
  Future<AuthResult> activateStudent({
    required String email,
    required String activationCode,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final account = _accounts[normalizedEmail];
    if (account == null || activationCode != 'OASSIS-123') {
      return const AuthResult.failure(AuthFailure.invalidActivationCode);
    }
    if (account.status == AccountStatus.disabled) {
      return const AuthResult.failure(AuthFailure.accountDisabled);
    }
    if (account.status != AccountStatus.provisioned) {
      return const AuthResult.failure(AuthFailure.invalidActivationCode);
    }

    account
      ..password = password
      ..status = AccountStatus.active;
    return AuthResult.success(account.toUser(normalizedEmail));
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
        return AuthResult.failure(
          AuthFailure.accountNotActivated,
          email: user.email,
        );
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

  Future<AuthResult> activateStudent({
    required String email,
    required String activationCode,
    required String password,
  }) async {
    try {
      final result = await _backend.activateStudent(
        email: email,
        activationCode: activationCode,
        password: password,
      );
      final user = result.user;
      if (user == null) return result;
      if (user.status == AccountStatus.disabled) {
        return const AuthResult.failure(AuthFailure.accountDisabled);
      }
      if (user.status != AccountStatus.active) {
        return AuthResult.failure(
          AuthFailure.accountNotActivated,
          email: user.email,
        );
      }
      _currentUser = user;
      return AuthResult.success(user);
    } on AuthNetworkException {
      return const AuthResult.failure(AuthFailure.network);
    } catch (_) {
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

class _DemoAccount {
  _DemoAccount({
    required this.id,
    required this.role,
    required this.status,
    this.password,
  });

  final String id;
  final AppUserRole role;
  AccountStatus status;
  String? password;

  AppUser toUser(String email) =>
      AppUser(id: id, email: email, role: role, status: status);
}
