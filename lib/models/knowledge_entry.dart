enum KnowledgeEntryStatus { needsVerification, published }

class KnowledgeEntry {
  const KnowledgeEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.status,
  });

  final String id;
  final String title;
  final String content;
  final KnowledgeEntryStatus status;

  String get statusLabel => switch (status) {
    KnowledgeEntryStatus.needsVerification => 'Needs verification',
    KnowledgeEntryStatus.published => 'Published',
  };

  KnowledgeEntry copyWith({
    String? title,
    String? content,
    KnowledgeEntryStatus? status,
  }) => KnowledgeEntry(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    status: status ?? this.status,
  );
}
