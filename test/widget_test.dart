import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oassis_app/app_routes.dart';
import 'package:oassis_app/main.dart';
import 'package:oassis_app/models/app_user.dart';
import 'package:oassis_app/models/knowledge_entry.dart';
import 'package:oassis_app/models/response_feedback.dart';
import 'package:oassis_app/services/auth_service.dart';
import 'package:oassis_app/services/chat_service.dart';

class _FakeAuthBackend implements AuthBackend {
  const _FakeAuthBackend(this.result);

  final AuthResult result;

  @override
  Future<AppUser?> refreshSession() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> activateStudent({
    required String email,
    required String activationCode,
    required String password,
  }) async => result;

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
    'demo Student activation and persistent chat flow works locally',
    () async {
      AuthService.instance.signOut();

      final provisioned = await AuthService.instance.signIn(
        email: 'provisioned@mail.com',
        password: 'anything',
      );
      expect(provisioned.failure, AuthFailure.accountNotActivated);

      final activated = await AuthService.instance.activateStudent(
        email: 'provisioned@mail.com',
        activationCode: 'OASSIS-123',
        password: 'new-password',
      );
      expect(activated.isSuccess, isTrue);
      expect(AuthService.instance.isStudent, isTrue);

      final chat = DemoChatService.instance;
      final conversation = await chat.getOrCreateStudentConversation(
        studentId: activated.user!.id,
      );
      final newestPage = await chat.fetchMessages(
        conversationId: conversation.id,
        pageSize: 30,
      );
      expect(newestPage.messages, hasLength(30));
      expect(newestPage.hasOlderMessages, isTrue);

      final olderPage = await chat.fetchMessages(
        conversationId: conversation.id,
        beforeCursor: newestPage.nextOlderCursor,
      );
      expect(
        olderPage.messages
            .map((message) => message.id)
            .toSet()
            .intersection(
              newestPage.messages.map((message) => message.id).toSet(),
            ),
        isEmpty,
      );

      final sent = await chat.sendStudentMessage(
        conversationId: conversation.id,
        content: 'Where is the admissions office?',
      );
      expect(sent, hasLength(2));
      expect(sent.last.isOassisResponse, isTrue);

      final edited = await chat.editStudentMessage(
        messageId: sent.first.id,
        content: 'Where is the admissions office today?',
      );
      expect(edited.editedAt, isNotNull);

      await chat.archiveStudentMessage(messageId: edited.id);
      final feedback = await chat.upsertResponseFeedback(
        responseMessageId: sent.last.id,
        rating: ResponseRating.up,
      );
      expect(feedback.rating, ResponseRating.up);
      expect(
        (await chat.fetchResponseFeedback(
          responseMessageId: sent.last.id,
        ))?.rating,
        ResponseRating.up,
      );
      AuthService.instance.signOut();
    },
  );

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
