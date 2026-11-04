enum KnowledgeEntryStatus { draft, pendingApproval, published }

class KnowledgeEntry {
  const KnowledgeEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final KnowledgeEntryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get statusLabel => switch (status) {
    KnowledgeEntryStatus.draft => 'Draft',
    KnowledgeEntryStatus.pendingApproval => 'Pending approval',
    KnowledgeEntryStatus.published => 'Published',
  };

  KnowledgeEntry copyWith({
    String? title,
    String? content,
    KnowledgeEntryStatus? status,
    DateTime? updatedAt,
  }) => KnowledgeEntry(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
