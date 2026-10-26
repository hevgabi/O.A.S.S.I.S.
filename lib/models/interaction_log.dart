class InteractionLog {
  const InteractionLog({
    required this.id,
    required this.questioner,
    required this.email,
    required this.role,
    required this.inquiry,
    required this.submittedAt,
  });

  final String id;
  final String questioner;
  final String email;
  final String role;
  final String inquiry;
  final DateTime submittedAt;
}
