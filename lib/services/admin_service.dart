import '../models/interaction_log.dart';
import '../models/unanswered_inquiry.dart';

/// In-memory sample records for the initial admin prototype.
/// Replace this with the selected data source when the backend is agreed.
class AdminService {
  AdminService._();

  static final AdminService instance = AdminService._();

  final List<UnansweredInquiry> _unansweredInquiries = [
    UnansweredInquiry(
      id: 'inq-001',
      question: 'Can I enroll if my Form 137 is still being processed?',
      questioner: 'Jamie Santos',
      role: 'Student',
      submittedAt: DateTime(2026, 10, 25, 9, 15),
    ),
    UnansweredInquiry(
      id: 'inq-002',
      question: 'Where can parents request a certificate of enrollment?',
      questioner: 'Alex Reyes',
      role: 'Parent / Guardian',
      submittedAt: DateTime(2026, 10, 24, 14, 30),
    ),
    UnansweredInquiry(
      id: 'inq-003',
      question: 'Is the library open during the Saturday review session?',
      questioner: 'Morgan Cruz',
      role: 'Student',
      submittedAt: DateTime(2026, 10, 23, 11, 5),
    ),
  ];

  final List<InteractionLog> _interactionLogs = [
    InteractionLog(
      id: 'log-001',
      questioner: 'Jamie Santos',
      email: 'jamie.santos@example.edu',
      role: 'Student',
      inquiry: 'What documents do I need to enroll?',
      submittedAt: DateTime(2026, 10, 25, 8, 42),
    ),
    InteractionLog(
      id: 'log-002',
      questioner: 'Alex Reyes',
      email: 'alex.reyes@example.com',
      role: 'Parent / Guardian',
      inquiry: 'Where is the Student Affairs Office?',
      submittedAt: DateTime(2026, 10, 24, 16, 18),
    ),
    InteractionLog(
      id: 'log-003',
      questioner: 'Morgan Cruz',
      email: 'morgan.cruz@example.edu',
      role: 'Student',
      inquiry: 'What time does the Registrar open?',
      submittedAt: DateTime(2026, 10, 24, 7, 55),
    ),
  ];

  List<UnansweredInquiry> getUnansweredInquiries() =>
      List.unmodifiable(_unansweredInquiries);

  List<InteractionLog> getInteractionLogs() =>
      List.unmodifiable(_interactionLogs);
}
