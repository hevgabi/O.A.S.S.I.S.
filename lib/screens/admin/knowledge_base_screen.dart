import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/knowledge_entry.dart';
import '../../services/auth_service.dart';
import '../../services/knowledge_base_service.dart';
import 'interaction_logs_screen.dart';
import 'unanswered_inquiries_screen.dart';

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  final KnowledgeBaseService _service = KnowledgeBaseService.instance;

  List<KnowledgeEntry> get _entries => _service.getEntries();

  static const Color _ink = Color(0xFF17333D);
  static const Color _teal = Color(0xFF176B67);
  static const Color _surface = Color(0xFFF7F9F8);

  Future<void> _showEntryForm({KnowledgeEntry? entry}) async {
    final titleController = TextEditingController(text: entry?.title ?? '');
    final contentController = TextEditingController(text: entry?.content ?? '');

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry == null ? 'Add knowledge entry' : 'Edit entry'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Entry title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contentController,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Official answer or guidance',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty || content.isEmpty) return;
              Navigator.pop(dialogContext, (title, content));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    titleController.dispose();
    contentController.dispose();
    if (result == null || !mounted) return;

    setState(() {
      if (entry == null) {
        _service.addEntry(title: result.$1, content: result.$2);
      } else {
        _service.updateEntry(entry.id, title: result.$1, content: result.$2);
      }
    });
  }

  Future<void> _deleteEntry(KnowledgeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          '“${entry.title}” will be removed from this sample list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _service.deleteEntry(entry.id));
  }

  void _updateStatus(KnowledgeEntry entry, bool publish) {
    final status = publish
        ? KnowledgeEntryStatus.published
        : KnowledgeEntryStatus.needsVerification;
    setState(() => _service.updateStatus(entry.id, status));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          publish
              ? 'Entry marked as published.'
              : 'Entry moved back to verification.',
        ),
      ),
    );
  }

  void _navigateTo(int index) {
    final page = switch (index) {
      1 => const UnansweredInquiriesScreen(),
      2 => const InteractionLogsScreen(),
      _ => null,
    };
    if (page != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
    }
  }

  void _logOut() {
    AuthService.instance.signOut();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.entry, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFEFE),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Knowledge Base',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _logOut,
                        icon: const Icon(Icons.logout_outlined, size: 18),
                        label: const Text('Log out'),
                        style: TextButton.styleFrom(foregroundColor: _ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Only verified and published answers are shared with students.',
                    style: TextStyle(color: Color(0xFF64747A), fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => _showEntryForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add entry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      backgroundColor: _surface,
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: Color(0xFFCBD4D5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: _teal),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Sample data — confirm answers with school offices.',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text('No entries yet. Add the first one above.'),
                      ),
                    )
                  else
                    ..._entries.map(_buildEntryCard),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildEntryCard(KnowledgeEntry entry) {
    final isPublished = entry.status == KnowledgeEntryStatus.published;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFD8DFDF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64747A),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: isPublished
                    ? const Color(0xFFE6F3EC)
                    : const Color(0xFFFFF2D8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isPublished
                        ? Icons.verified_outlined
                        : Icons.fact_check_outlined,
                    size: 18,
                    color: isPublished
                        ? const Color(0xFF276443)
                        : const Color(0xFF845B13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPublished
                          ? 'Published · visible to students'
                          : 'Needs verification · not published',
                      style: TextStyle(
                        color: isPublished
                            ? const Color(0xFF276443)
                            : const Color(0xFF845B13),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: isPublished,
                    onChanged: (value) => _updateStatus(entry, value),
                    activeTrackColor: _teal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _showEntryForm(entry: entry),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(72, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      foregroundColor: _ink,
                    ),
                    child: const Text('Edit'),
                  ),
                  OutlinedButton(
                    onPressed: () => _deleteEntry(entry),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(76, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: const Color(0xFF9C3434),
                      side: const BorderSide(color: Color(0xFFDABABA)),
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() => NavigationBar(
    selectedIndex: 0,
    onDestinationSelected: _navigateTo,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book),
        label: 'Knowledge Base',
      ),
      NavigationDestination(
        icon: Icon(Icons.help_outline),
        selectedIcon: Icon(Icons.help),
        label: 'Unanswered',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Logs',
      ),
    ],
  );
}
