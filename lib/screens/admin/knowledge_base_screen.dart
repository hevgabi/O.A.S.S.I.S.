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
  late Future<List<KnowledgeEntry>> _entriesFuture;

  static const Color _ink = Color(0xFF17333D);
  static const Color _teal = Color(0xFF176B67);

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    _entriesFuture = _service.getEntries();
  }

  Future<void> _showEntryForm({KnowledgeEntry? entry}) async {
    final result = await showDialog<(String, String, KnowledgeEntryStatus)>(
      context: context,
      builder: (_) => _KnowledgeEntryFormDialog(entry: entry),
    );

    if (result == null || !mounted) return;

    try {
      if (entry == null) {
        await _service.addEntry(
          title: result.$1,
          content: result.$2,
          status: result.$3,
        );
      } else {
        await _service.updateEntry(
          entry.id,
          title: result.$1,
          content: result.$2,
          status: result.$3,
        );
      }
      if (!mounted) return;
      setState(_loadEntries);
    } catch (error) {
      if (mounted) _showError('Could not save the entry', error);
    }
  }

  Future<void> _deleteEntry(KnowledgeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          '“${entry.title}” will be permanently removed from the knowledge base.',
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
    try {
      await _service.deleteEntry(entry.id);
      if (mounted) setState(_loadEntries);
    } catch (error) {
      if (mounted) _showError('Could not delete the entry', error);
    }
  }

  void _showError(String action, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$action: $error')));
  }

  static String _statusLabel(KnowledgeEntryStatus status) => switch (status) {
    KnowledgeEntryStatus.draft => 'Draft',
    KnowledgeEntryStatus.pendingApproval => 'Pending approval',
    KnowledgeEntryStatus.published => 'Published',
  };

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year} · '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
    ).pushNamedAndRemoveUntil(AppRoutes.entry, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFEFE),
      appBar: AppBar(
        title: const Text('Knowledge Base'),
        titleTextStyle: const TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: const Color(0xFFFDFEFE),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _logOut,
            icon: const Icon(Icons.logout_outlined, size: 18),
            label: const Text('Log out'),
            style: TextButton.styleFrom(foregroundColor: _ink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          const Text(
            'Only published entries are available to OASSIS retrieval.',
            style: TextStyle(color: Color(0xFF64747A), fontSize: 14),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _showEntryForm(),
            icon: const Icon(Icons.add),
            label: const Text('Add entry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          _sampleNotice(),
          const SizedBox(height: 12),
          FutureBuilder<List<KnowledgeEntry>>(
            future: _entriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _stateMessage(
                  'Could not load knowledge entries.',
                  action: TextButton(
                    onPressed: () => setState(_loadEntries),
                    child: const Text('Retry'),
                  ),
                );
              }
              final entries = snapshot.data ?? const <KnowledgeEntry>[];
              if (entries.isEmpty) {
                return _stateMessage(
                  'No entries yet. Add the first one above.',
                );
              }
              return Column(children: entries.map(_buildEntryCard).toList());
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
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
      ),
    );
  }

  Widget _buildEntryCard(KnowledgeEntry entry) {
    final statusColor = switch (entry.status) {
      KnowledgeEntryStatus.published => const Color(0xFFE6F3EC),
      KnowledgeEntryStatus.pendingApproval => const Color(0xFFFFF2D8),
      KnowledgeEntryStatus.draft => const Color(0xFFEAF0F2),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFD8DFDF)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64747A), fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(entry.statusLabel),
                  backgroundColor: statusColor,
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  'Updated ${_formatDate(entry.updatedAt)}',
                  style: const TextStyle(
                    color: Color(0xFF64747A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _showEntryForm(entry: entry),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteEntry(entry),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sampleNotice() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
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
            'Prototype sample data only. This list shows all records in the local in-memory store; backend pagination is not configured.',
            style: TextStyle(color: _ink, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _stateMessage(String message, {Widget? action}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}

class _KnowledgeEntryFormDialog extends StatefulWidget {
  const _KnowledgeEntryFormDialog({this.entry});

  final KnowledgeEntry? entry;

  @override
  State<_KnowledgeEntryFormDialog> createState() =>
      _KnowledgeEntryFormDialogState();
}

class _KnowledgeEntryFormDialogState extends State<_KnowledgeEntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late KnowledgeEntryStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _contentController = TextEditingController(
      text: widget.entry?.content ?? '',
    );
    _selectedStatus = widget.entry?.status ?? KnowledgeEntryStatus.draft;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.entry == null ? 'Add knowledge entry' : 'Edit entry'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Entry title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contentController,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Official answer or guidance',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the entry content.'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<KnowledgeEntryStatus>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Publication status',
                  border: OutlineInputBorder(),
                ),
                items: KnowledgeEntryStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(
                          _KnowledgeBaseScreenState._statusLabel(status),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (status) {
                  if (status != null) setState(() => _selectedStatus = status);
                },
              ),
              if (widget.entry == null) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'New entries start as drafts.',
                    style: TextStyle(color: Color(0xFF64747A), fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (
            _titleController.text.trim(),
            _contentController.text.trim(),
            _selectedStatus,
          ));
        },
        child: const Text('Save'),
      ),
    ],
  );
}
