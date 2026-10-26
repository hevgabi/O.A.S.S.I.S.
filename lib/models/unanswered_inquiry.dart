class UnansweredInquiry {
  const UnansweredInquiry({
    required this.id,
    required this.question,
    required this.questioner,
    required this.role,
    required this.submittedAt,
  });

  final String id;
  final String question;
  final String questioner;
  final String role;
  final DateTime submittedAt;
}
