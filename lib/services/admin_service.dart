import '../models/interaction_log.dart';
import '../models/unanswered_inquiry.dart';

/// In-memory, read-only prototype data. Replace with the approved backend
/// adapter when its contract is available.
class AdminService {
  AdminService._();

  static final AdminService instance = AdminService._();

  final List<UnansweredInquiry> _unansweredInquiries = [
    UnansweredInquiry(
      id: 'inq-001',
      question: 'Can I enroll if my Form 137 is still being processed?',
      sourceType: InquirySourceType.student,
      recordedAt: DateTime.utc(2026, 10, 25, 9, 15),
    ),
    UnansweredInquiry(
      id: 'inq-002',
      question: 'Where can parents request a certificate of enrollment?',
      sourceType: InquirySourceType.visitor,
      recordedAt: DateTime.utc(2026, 10, 24, 14, 30),
    ),
    UnansweredInquiry(
      id: 'inq-003',
      question: 'Is the library open during the Saturday review session?',
      sourceType: InquirySourceType.student,
      recordedAt: DateTime.utc(2026, 10, 23, 11, 5),
    ),
  ];

  final List<InteractionLog> _interactionLogs = [
    InteractionLog(
      id: 'log-001',
      question: 'What documents do I need to enroll?',
      sourceType: InquirySourceType.student,
      recordedAt: DateTime.utc(2026, 10, 25, 8, 42),
    ),
    InteractionLog(
      id: 'log-002',
      question: 'Where is the Student Affairs Office?',
      sourceType: InquirySourceType.visitor,
      recordedAt: DateTime.utc(2026, 10, 24, 16, 18),
    ),
    InteractionLog(
      id: 'log-003',
      question: 'What time does the Registrar open?',
      sourceType: InquirySourceType.student,
      recordedAt: DateTime.utc(2026, 10, 24, 7, 55),
    ),
  ];

  Future<List<UnansweredInquiry>> getUnansweredInquiries() async =>
      List.unmodifiable(_unansweredInquiries);

  Future<List<InteractionLog>> getInteractionLogs() async =>
      List.unmodifiable(_interactionLogs);
}
