import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oassis_app/app_routes.dart';
import 'package:oassis_app/main.dart';
import 'package:oassis_app/services/auth_service.dart';

Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
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

  testWidgets('Admin login opens the Knowledge Base', (WidgetTester tester) async {
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
