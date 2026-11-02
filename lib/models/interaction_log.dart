import 'unanswered_inquiry.dart';

class InteractionLog {
  const InteractionLog({
    required this.id,
    required this.question,
    required this.recordedAt,
    required this.sourceType,
    this.studentIdentity,
  });

  final String id;
  final String question;
  final DateTime recordedAt;
  final InquirySourceType sourceType;

  /// Populated only when a persistent Student profile is available.
  final String? studentIdentity;

  String get sourceLabel => switch (sourceType) {
    InquirySourceType.student => 'Student',
    InquirySourceType.visitor => 'Visitor · anonymous',
    InquirySourceType.unknown => 'Source unavailable',
  };
}
