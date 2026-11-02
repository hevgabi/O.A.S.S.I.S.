enum ResponseRating { up, down }

/// A Student's thumbs-up or thumbs-down feedback on one OASSIS response.
class ResponseFeedback {
  const ResponseFeedback({
    required this.id,
    required this.messageId,
    required this.studentId,
    required this.rating,
    required this.updatedAt,
  });

  final String id;
  final String messageId;
  final String studentId;
  final ResponseRating rating;
  final DateTime updatedAt;
}
