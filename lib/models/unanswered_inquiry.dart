enum InquirySourceType { student, visitor, unknown }

class UnansweredInquiry {
  const UnansweredInquiry({
    required this.id,
    required this.question,
    required this.recordedAt,
    required this.sourceType,
  });

  final String id;
  final String question;
  final DateTime recordedAt;
  final InquirySourceType sourceType;

  String get sourceLabel => switch (sourceType) {
    InquirySourceType.student => 'Student',
    InquirySourceType.visitor => 'Visitor',
    InquirySourceType.unknown => 'Source unavailable',
  };
}
