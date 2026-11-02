import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/response_feedback.dart';
import 'auth_service.dart';

/// Cursor page returned when history is fetched newest-first.
class MessagePage {
  const MessagePage({required this.messages, required this.nextOlderCursor});

  final List<ChatMessage> messages;
  final String? nextOlderCursor;

  bool get hasOlderMessages => nextOlderCursor != null;
}

/// Contract for Student persistent-chat operations.
///
/// The eventual backend implementation must enforce ownership and account
/// boundaries on every operation. The client must not infer authorization.
abstract interface class ChatService {
  /// Returns the Student's only conversation, creating it once when absent.
  Future<Conversation> getOrCreateStudentConversation({
    required String studentId,
  });

  /// Fetches a newest-first page. [beforeCursor] asks for older messages.
  Future<MessagePage> fetchMessages({
    required String conversationId,
    String? beforeCursor,
    int pageSize = 30,
  });

  /// Sends a Student message and returns the saved Student message plus the
  /// resulting OASSIS response in the returned page order.
  Future<List<ChatMessage>> sendStudentMessage({
    required String conversationId,
    required String content,
  });

  /// Saves revised Student-authored content and its edited timestamp.
  Future<ChatMessage> editStudentMessage({
    required String messageId,
    required String content,
  });

  /// Soft-deletes a message by setting archived_at. It never deletes rows.
  Future<void> archiveStudentMessage({required String messageId});

  /// Creates feedback when absent or changes the existing feedback value.
  Future<ResponseFeedback> upsertResponseFeedback({
    required String responseMessageId,
    required ResponseRating rating,
  });

  Future<ResponseFeedback?> fetchResponseFeedback({
    required String responseMessageId,
  });
}

/// Raised while no approved persistent-chat backend is configured.
class ChatBackendUnavailableException implements Exception {
  const ChatBackendUnavailableException();
}

/// In-memory demonstration of the persistent-chat contract.
///
/// This exists for UI development only. A real backend must replace it before
/// release because its data is local to the running app and not secure.
class DemoChatService implements ChatService {
  DemoChatService._();

  static final DemoChatService instance = DemoChatService._();

  final Map<String, Conversation> _conversationsByStudent = {};
  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  final Map<String, ResponseFeedback> _feedbackByResponse = {};
  int _nextId = 1;

  @override
  Future<Conversation> getOrCreateStudentConversation({
    required String studentId,
  }) async {
    _requireStudent(studentId);
    await _delay();
    return _conversationsByStudent.putIfAbsent(studentId, () {
      final conversation = Conversation(
        id: 'conversation-$studentId',
        studentId: studentId,
        createdAt: DateTime.now(),
      );
      _messagesByConversation[conversation.id] = _seedMessages(conversation);
      return conversation;
    });
  }

  @override
  Future<MessagePage> fetchMessages({
    required String conversationId,
    String? beforeCursor,
    int pageSize = 30,
  }) async {
    final messages = _messagesForCurrentStudent(conversationId)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _delay();
    final start = int.tryParse(beforeCursor ?? '') ?? 0;
    final end = (start + pageSize).clamp(0, messages.length);
    return MessagePage(
      messages: List.unmodifiable(messages.sublist(start, end)),
      nextOlderCursor: end < messages.length ? '$end' : null,
    );
  }

  @override
  Future<List<ChatMessage>> sendStudentMessage({
    required String conversationId,
    required String content,
  }) async {
    final messages = _messagesForCurrentStudent(conversationId);
    if (content.toLowerCase().contains('fail')) {
      throw const ChatOperationException(
        'Demo send failure. Remove the word "fail" and retry.',
      );
    }
    await _delay();
    final now = DateTime.now();
    final studentMessage = ChatMessage(
      id: _id('student-message'),
      conversationId: conversationId,
      author: MessageAuthor.student,
      content: content,
      createdAt: now,
    );
    final response = ChatMessage(
      id: _id('oassis-response'),
      conversationId: conversationId,
      author: MessageAuthor.oassis,
      content: _responseFor(content),
      createdAt: now.add(const Duration(milliseconds: 1)),
    );
    messages.addAll([studentMessage, response]);
    return [studentMessage, response];
  }

  @override
  Future<ChatMessage> editStudentMessage({
    required String messageId,
    required String content,
  }) async {
    final messages = _allMessagesForCurrentStudent();
    final index = messages.indexWhere((message) => message.id == messageId);
    if (index < 0 ||
        !messages[index].isStudentMessage ||
        messages[index].isArchived) {
      throw const ChatOperationException(
        'This message can no longer be edited.',
      );
    }
    await _delay();
    final updated = messages[index].copyWith(
      content: content,
      editedAt: DateTime.now(),
    );
    messages[index] = updated;
    return updated;
  }

  @override
  Future<void> archiveStudentMessage({required String messageId}) async {
    final messages = _allMessagesForCurrentStudent();
    final index = messages.indexWhere((message) => message.id == messageId);
    if (index < 0 || !messages[index].isStudentMessage) {
      throw const ChatOperationException('This message cannot be archived.');
    }
    await _delay();
    messages[index] = messages[index].copyWith(archivedAt: DateTime.now());
  }

  @override
  Future<ResponseFeedback?> fetchResponseFeedback({
    required String responseMessageId,
  }) async {
    _responseForCurrentStudent(responseMessageId);
    await _delay();
    return _feedbackByResponse[responseMessageId];
  }

  @override
  Future<ResponseFeedback> upsertResponseFeedback({
    required String responseMessageId,
    required ResponseRating rating,
  }) async {
    _responseForCurrentStudent(responseMessageId);
    await _delay();
    final current = _feedbackByResponse[responseMessageId];
    final feedback = ResponseFeedback(
      id: current?.id ?? _id('feedback'),
      messageId: responseMessageId,
      studentId: AuthService.instance.currentUser!.id,
      rating: rating,
      updatedAt: DateTime.now(),
    );
    _feedbackByResponse[responseMessageId] = feedback;
    return feedback;
  }

  List<ChatMessage> _seedMessages(Conversation conversation) {
    final now = DateTime.now();
    final messages = <ChatMessage>[];
    for (var index = 0; index < 44; index++) {
      final isStudent = index.isEven;
      messages.add(
        ChatMessage(
          id: _id(isStudent ? 'seed-student' : 'seed-oassis'),
          conversationId: conversation.id,
          author: isStudent ? MessageAuthor.student : MessageAuthor.oassis,
          content: isStudent
              ? 'Sample Student question ${index ~/ 2 + 1}'
              : 'Sample OASSIS response ${index ~/ 2 + 1}',
          createdAt: now.subtract(Duration(minutes: 44 - index)),
        ),
      );
    }
    final firstResponse = messages.firstWhere(
      (message) => message.isOassisResponse,
    );
    _feedbackByResponse[firstResponse.id] = ResponseFeedback(
      id: _id('feedback'),
      messageId: firstResponse.id,
      studentId: conversation.studentId,
      rating: ResponseRating.up,
      updatedAt: now,
    );
    return messages;
  }

  List<ChatMessage> _messagesForCurrentStudent(String conversationId) {
    Conversation? conversation;
    for (final item in _conversationsByStudent.values) {
      if (item.id == conversationId) {
        conversation = item;
        break;
      }
    }
    if (conversation == null) {
      throw const ChatOperationException('Conversation was not found.');
    }
    _requireStudent(conversation.studentId);
    return _messagesByConversation[conversationId]!;
  }

  List<ChatMessage> _allMessagesForCurrentStudent() {
    final user = AuthService.instance.currentUser;
    if (user == null || !AuthService.instance.isStudent) {
      throw const ChatOperationException('Sign in as a Student to use chat.');
    }
    final conversation = _conversationsByStudent[user.id];
    if (conversation == null) {
      throw const ChatOperationException('Conversation was not found.');
    }
    return _messagesByConversation[conversation.id]!;
  }

  ChatMessage _responseForCurrentStudent(String messageId) {
    final message = _allMessagesForCurrentStudent().firstWhere(
      (item) => item.id == messageId,
      orElse: () =>
          throw const ChatOperationException('Message was not found.'),
    );
    if (!message.isOassisResponse) {
      throw const ChatOperationException(
        'Feedback applies only to OASSIS responses.',
      );
    }
    return message;
  }

  void _requireStudent(String studentId) {
    final user = AuthService.instance.currentUser;
    if (user == null ||
        !AuthService.instance.isStudent ||
        user.id != studentId) {
      throw const ChatOperationException('Student access is required.');
    }
  }

  Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 180));

  String _id(String prefix) => '$prefix-${_nextId++}';

  String _responseFor(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('admission') || lower.contains('office')) {
      return 'You can visit the admissions office at the main campus building on weekdays from 8:00 AM to 5:00 PM.';
    }
    if (lower.contains('deadline') || lower.contains('due')) {
      return 'I can help you review the upcoming deadlines and important dates.';
    }
    if (lower.contains('schedule') || lower.contains('class')) {
      return 'I can help you check your enrollment schedule and class timings.';
    }
    return 'I can help with that. This response is from the local demo service.';
  }
}

class ChatOperationException implements Exception {
  const ChatOperationException(this.message);

  final String message;

  @override
  String toString() => message;
}
