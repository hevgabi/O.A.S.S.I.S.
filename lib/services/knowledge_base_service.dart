import '../models/knowledge_entry.dart';

/// In-memory prototype store. Replace this adapter when the backend contract
/// is approved; its current list contains only local sample records.
class KnowledgeBaseService {
  KnowledgeBaseService._() : _entries = _sampleEntries();

  KnowledgeBaseService.forTesting({
    List<KnowledgeEntry> initialEntries = const [],
  }) : _entries = List.of(initialEntries);

  static final KnowledgeBaseService instance = KnowledgeBaseService._();

  final List<KnowledgeEntry> _entries;

  static List<KnowledgeEntry> _sampleEntries() => [
    KnowledgeEntry(
      id: 'kb-enrollment',
      title: 'Enrollment requirements',
      content:
          'Prepare your completed enrollment form, latest report card, and '
          'proof of identity. Confirm the current requirements with the '
          'Registrar before your visit.',
      status: KnowledgeEntryStatus.draft,
      createdAt: DateTime.utc(2026, 10, 20, 8),
      updatedAt: DateTime.utc(2026, 10, 25, 9, 15),
    ),
    KnowledgeEntry(
      id: 'kb-directions',
      title: 'Campus directions',
      content:
          'The Student Affairs Office is in the main administration building. '
          'Ask the campus guard for directions when you arrive.',
      status: KnowledgeEntryStatus.published,
      createdAt: DateTime.utc(2026, 10, 18, 8),
      updatedAt: DateTime.utc(2026, 10, 24, 14, 30),
    ),
  ];

  Future<List<KnowledgeEntry>> getEntries() async {
    final entries = List<KnowledgeEntry>.of(_entries)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(entries);
  }

  /// Retrieval callers must use this published-only view.
  Future<List<KnowledgeEntry>> getPublishedEntries() async => List.unmodifiable(
    _entries.where((entry) => entry.status == KnowledgeEntryStatus.published),
  );

  Future<KnowledgeEntry> addEntry({
    required String title,
    required String content,
    KnowledgeEntryStatus status = KnowledgeEntryStatus.draft,
  }) async {
    final now = DateTime.now().toUtc();
    final entry = KnowledgeEntry(
      id: 'kb-${now.microsecondsSinceEpoch}',
      title: title,
      content: content,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
    _entries.insert(0, entry);
    return entry;
  }

  Future<KnowledgeEntry> updateEntry(
    String id, {
    required String title,
    required String content,
    required KnowledgeEntryStatus status,
  }) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) throw StateError('Knowledge entry no longer exists.');

    final updated = _entries[index].copyWith(
      title: title,
      content: content,
      status: status,
      updatedAt: DateTime.now().toUtc(),
    );
    _entries[index] = updated;
    return updated;
  }

  Future<void> deleteEntry(String id) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) throw StateError('Knowledge entry no longer exists.');
    _entries.removeAt(index);
  }
}
