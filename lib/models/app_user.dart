enum AppUserRole { student, admin }

class AppUser {
  const AppUser({required this.email, required this.role});

  final String email;
  final AppUserRole role;
}
