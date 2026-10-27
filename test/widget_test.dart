// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oassis_app/app_routes.dart';
import 'package:oassis_app/main.dart';
import 'package:oassis_app/services/auth_service.dart';

void main() {
  testWidgets('Student login opens Student Chat and cannot open admin routes', (
    WidgetTester tester,
  ) async {
    AuthService.instance.signOut();
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byType(TextField).at(0), 'student@mail.com');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Student'), findsOneWidget);

    Navigator.of(
      tester.element(find.text('Student')),
    ).pushNamed(AppRoutes.knowledgeBase);
    await tester.pumpAndSettle();

    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Knowledge Base'), findsNothing);
  });

  testWidgets('Admin login opens the Knowledge Base', (
    WidgetTester tester,
  ) async {
    AuthService.instance.signOut();
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byType(TextField).at(0), 'admin@mail.com');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Add entry'), findsOneWidget);
  });
}
