import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/response_feedback.dart';

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
}

/// Raised while no approved persistent-chat backend is configured.
class ChatBackendUnavailableException implements Exception {
  const ChatBackendUnavailableException();
}
