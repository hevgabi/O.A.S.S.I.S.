import 'package:flutter_test/flutter_test.dart';
import 'package:oassis_app/models/knowledge_entry.dart';
import 'package:oassis_app/services/knowledge_base_service.dart';

void main() {
  test('KnowledgeEntry CRUD timestamps and published-only retrieval', () async {
    final original = KnowledgeEntry(
      id: 'entry-1',
      title: 'Existing',
      content: 'Approved text',
      status: KnowledgeEntryStatus.published,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final service = KnowledgeBaseService.forTesting(initialEntries: [original]);

    expect((await service.getPublishedEntries()).map((entry) => entry.id), [
      'entry-1',
    ]);

    final created = await service.addEntry(title: 'New', content: 'Guidance');
    expect(created.status, KnowledgeEntryStatus.draft);
    expect(created.createdAt.isUtc, isTrue);
    expect(created.updatedAt, created.createdAt);
    expect((await service.getPublishedEntries()).map((entry) => entry.id), [
      'entry-1',
    ]);

    final updated = await service.updateEntry(
      'entry-1',
      title: 'Revised',
      content: 'Updated guidance',
      status: KnowledgeEntryStatus.pendingApproval,
    );
    expect(updated.title, 'Revised');
    expect(updated.createdAt, original.createdAt);
    expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
    expect(await service.getPublishedEntries(), isEmpty);

    await service.updateEntry(
      'entry-1',
      title: 'Revised',
      content: 'Updated guidance',
      status: KnowledgeEntryStatus.published,
    );
    expect((await service.getPublishedEntries()).single.id, 'entry-1');

    await service.deleteEntry('entry-1');
    expect(await service.getEntries(), hasLength(1));
  });
}
