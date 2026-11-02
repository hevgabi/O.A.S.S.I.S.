import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oassis_app/app_routes.dart';
import 'package:oassis_app/main.dart';
import 'package:oassis_app/models/app_user.dart';
import 'package:oassis_app/services/auth_service.dart';

class _FakeAuthBackend implements AuthBackend {
  const _FakeAuthBackend(this.result);

  final AuthResult result;

  @override
  Future<AppUser?> refreshSession() async => null;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async => result;
}

Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'provisioned Students are directed to activation before sign-in',
    () async {
      final service = AuthService(
        backend: _FakeAuthBackend(
          const AuthResult.success(
            AppUser(
              id: 'student-1',
              email: 'student@example.com',
              role: AppUserRole.student,
              status: AccountStatus.provisioned,
            ),
          ),
        ),
      );

      final result = await service.signIn(
        email: 'student@example.com',
        password: 'password',
      );

      expect(result.failure, AuthFailure.accountNotActivated);
      expect(service.isSignedIn, isFalse);
    },
  );

  testWidgets('Signed-out users cannot open Student Chat', (
    WidgetTester tester,
  ) async {
    AuthService.instance.signOut();
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.studentChat);
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Student'), findsNothing);
  });

  testWidgets('Student login opens Student Chat and cannot open admin routes', (
    WidgetTester tester,
  ) async {
    AuthService.instance.signOut();
    await _pumpPastSplash(tester);

    await tester.enterText(find.byType(TextField).at(0), 'student@mail.com');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Student'), findsOneWidget);
    expect(find.text('OASSIS'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);

    Navigator.of(
      tester.element(find.text('Student')),
    ).pushNamed(AppRoutes.knowledgeBase);
    await tester.pumpAndSettle();

    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Knowledge Base'), findsNothing);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
  });

  testWidgets('Admin login opens the Knowledge Base', (
    WidgetTester tester,
  ) async {
    AuthService.instance.signOut();
    await _pumpPastSplash(tester);

    await tester.enterText(find.byType(TextField).at(0), 'admin@mail.com');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Add entry'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
  });
}
