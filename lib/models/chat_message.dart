enum MessageAuthor { student, oassis }

enum MessageDeliveryState { pending, sent, failed }

/// Persistent message data returned by the Student chat backend.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.author,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.archivedAt,
    this.deliveryState = MessageDeliveryState.sent,
  });

  final String id;
  final String conversationId;
  final MessageAuthor author;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? archivedAt;
  final MessageDeliveryState deliveryState;

  bool get isStudentMessage => author == MessageAuthor.student;

  bool get isOassisResponse => author == MessageAuthor.oassis;

  bool get isArchived => archivedAt != null;

  ChatMessage copyWith({
    String? content,
    DateTime? editedAt,
    DateTime? archivedAt,
    MessageDeliveryState? deliveryState,
  }) => ChatMessage(
    id: id,
    conversationId: conversationId,
    author: author,
    content: content ?? this.content,
    createdAt: createdAt,
    editedAt: editedAt ?? this.editedAt,
    archivedAt: archivedAt ?? this.archivedAt,
    deliveryState: deliveryState ?? this.deliveryState,
  );
}
