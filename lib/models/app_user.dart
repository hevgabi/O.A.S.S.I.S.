enum AppUserRole { student, admin }

enum AccountStatus { provisioned, active, disabled }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
  });

  final String id;
  final String email;
  final AppUserRole role;
  final AccountStatus status;

  bool get isActive => status == AccountStatus.active;
}
