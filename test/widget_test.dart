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
import 'package:oassis_app/models/knowledge_entry.dart';
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

  testWidgets('Visitor cannot open an Admin route directly', (
    WidgetTester tester,
  ) async {
    AuthService.instance.signOut();
    await _pumpPastSplash(tester);

    Navigator.of(
      tester.element(find.text('Welcome')),
    ).pushNamed(AppRoutes.interactionLogs);
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Interaction Logs'), findsNothing);
  });

  testWidgets('Admin can create, edit, publish, and delete an entry', (
    WidgetTester tester,
  ) async {
    AuthService.instance.signOut();
    await _pumpPastSplash(tester);

    await tester.enterText(find.byType(TextField).at(0), 'admin@mail.com');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(find.text('Enter the entry content.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Test entry');
    await tester.enterText(find.byType(TextFormField).at(1), 'Test guidance');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Test entry'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);

    await tester.ensureVisible(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Revised entry');
    await tester.tap(
      find.byType(DropdownButtonFormField<KnowledgeEntryStatus>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Published').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Revised entry'), findsOneWidget);

    final revisedEntryCard = find.ancestor(
      of: find.text('Revised entry'),
      matching: find.byType(Card),
    );
    final deleteRevisedEntry = find.descendant(
      of: revisedEntryCard,
      matching: find.text('Delete'),
    );
    await tester.ensureVisible(deleteRevisedEntry);
    await tester.pumpAndSettle();
    await tester.tap(deleteRevisedEntry);
    await tester.pumpAndSettle();
    expect(
      find.text(
        '“Revised entry” will be permanently removed from the knowledge base.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Revised entry'), findsNothing);

    await tester.tap(find.text('Unanswered').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Can I enroll if my Form 137 is still being processed?'),
      findsOneWidget,
    );
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);

    await tester.tap(find.text('Logs').last);
    await tester.pumpAndSettle();
    expect(find.text('What documents do I need to enroll?'), findsOneWidget);
    expect(find.textContaining('Visitor · anonymous'), findsOneWidget);
    expect(find.text('Contact:'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });
}
