import '../models/knowledge_entry.dart';

/// In-memory sample store for the first OASSIS prototype.
/// Replace this implementation with the agreed backend when it is available.
class KnowledgeBaseService {
  KnowledgeBaseService._();

  static final KnowledgeBaseService instance = KnowledgeBaseService._();

  final List<KnowledgeEntry> _entries = [
    const KnowledgeEntry(
      id: 'kb-enrollment',
      title: 'Enrollment requirements',
      content:
          'Prepare your completed enrollment form, latest report card, and '
          'proof of identity. Confirm the current requirements with the '
          'Registrar before your visit.',
      status: KnowledgeEntryStatus.needsVerification,
    ),
    const KnowledgeEntry(
      id: 'kb-directions',
      title: 'Campus directions',
      content:
          'The Student Affairs Office is in the main administration building. '
          'Ask the campus guard for directions when you arrive.',
      status: KnowledgeEntryStatus.published,
    ),
  ];

  List<KnowledgeEntry> getEntries() => List.unmodifiable(_entries);

  void addEntry({required String title, required String content}) {
    _entries.insert(
      0,
      KnowledgeEntry(
        id: 'kb-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        content: content,
        status: KnowledgeEntryStatus.needsVerification,
      ),
    );
  }

  void updateEntry(
    String id, {
    required String title,
    required String content,
  }) {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) return;

    _entries[index] = _entries[index].copyWith(
      title: title,
      content: content,
      status: KnowledgeEntryStatus.needsVerification,
    );
  }

  void deleteEntry(String id) =>
      _entries.removeWhere((entry) => entry.id == id);

  void updateStatus(String id, KnowledgeEntryStatus status) {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    _entries[index] = _entries[index].copyWith(status: status);
  }
}
