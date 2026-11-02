/// The single persistent chat conversation owned by one Student.
class Conversation {
  const Conversation({
    required this.id,
    required this.studentId,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final DateTime createdAt;
}
