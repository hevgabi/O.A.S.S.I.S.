import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> signOut();
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

  @override
  Future<void> signOut() async {}
}

/// Supabase implementation of the approved account flow.
class SupabaseAuthBackend implements AuthBackend {
  const SupabaseAuthBackend(this._client);

  final SupabaseClient _client;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user == null) {
        return const AuthResult.failure(AuthFailure.invalidCredentials);
      }
      await _activateIfProvisioned();
      return AuthResult.success(await _getProfile());
    } on AuthException {
      return const AuthResult.failure(AuthFailure.invalidCredentials);
    } on PostgrestException catch (error) {
      return AuthResult.failure(_failureFor(error), email: email.trim());
    } catch (_) {
      return const AuthResult.failure(AuthFailure.network);
    }
  }

  @override
  Future<AuthResult> activateStudent({
    required String email,
    required String activationCode,
    required String password,
  }) async {
    try {
      if (_client.auth.currentSession == null) {
        return const AuthResult.failure(AuthFailure.signedOut);
      }
      await _activateIfProvisioned();
      return AuthResult.success(await _getProfile());
    } on PostgrestException catch (error) {
      return AuthResult.failure(_failureFor(error), email: email.trim());
    } catch (_) {
      return const AuthResult.failure(AuthFailure.network);
    }
  }

  @override
  Future<AppUser?> refreshSession() async {
    if (_client.auth.currentSession == null) return null;
    try {
      return await _getProfile();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  Future<void> _activateIfProvisioned() async {
    try {
      await _client.rpc('activate_my_account');
    } on PostgrestException catch (error) {
      if (error.code != 'P0002') rethrow;
    }
  }

  Future<AppUser> _getProfile() async {
    final response = await _client.rpc('get_my_profile');
    final profile = Map<String, dynamic>.from(response as Map);
    final role = profile['role'] as String;
    final status = profile['account_status'] as String;
    return AppUser(
      id: profile['profile_id'] as String,
      email: profile['email'] as String,
      role: role == 'admin' ? AppUserRole.admin : AppUserRole.student,
      status: switch (status) {
        'active' => AccountStatus.active,
        'disabled' => AccountStatus.disabled,
        _ => AccountStatus.provisioned,
      },
    );
  }

  AuthFailure _failureFor(PostgrestException error) {
    if (error.code == '42501') return AuthFailure.accountDisabled;
    if (error.code == 'P0002') return AuthFailure.accountNotActivated;
    if (error.code == '22023') return AuthFailure.invalidActivationCode;
    return AuthFailure.backend;
  }
}

class AuthService {
  AuthService({AuthBackend? backend}) : _backend = backend ?? DemoAuthBackend();

  static final AuthService instance = AuthService();

  AuthBackend _backend;

  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  bool get isAdmin => _currentUser?.role == AppUserRole.admin;

  bool get isStudent => _currentUser?.role == AppUserRole.student;

  void configureBackend(AuthBackend backend) {
    _currentUser = null;
    _backend = backend;
  }

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

  Future<void> signOut() async {
    _currentUser = null;
    try {
      await _backend.signOut();
    } catch (_) {
      // The local protected state is already cleared even if remote sign-out fails.
    }
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
