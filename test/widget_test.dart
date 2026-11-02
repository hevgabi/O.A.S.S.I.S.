import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oassis_app/main.dart';

void main() {
  testWidgets('Student chat screen shows OASSIS header, student label, input, and send button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('OASSIS'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
  });
}
