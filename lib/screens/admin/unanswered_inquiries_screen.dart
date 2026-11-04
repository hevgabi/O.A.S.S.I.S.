import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/unanswered_inquiry.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'interaction_logs_screen.dart';
import 'knowledge_base_screen.dart';

class UnansweredInquiriesScreen extends StatefulWidget {
  const UnansweredInquiriesScreen({super.key});

  @override
  State<UnansweredInquiriesScreen> createState() =>
      _UnansweredInquiriesScreenState();
}

class _UnansweredInquiriesScreenState extends State<UnansweredInquiriesScreen> {
  late Future<List<UnansweredInquiry>> _inquiriesFuture;

  static const Color _ink = Color(0xFF17333D);
  static const Color _teal = Color(0xFF176B67);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _inquiriesFuture = AdminService.instance.getUnansweredInquiries();
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year} · '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showDetails(UnansweredInquiry inquiry) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Inquiry details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(inquiry.question, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Text('Source: ${inquiry.sourceLabel}'),
            const SizedBox(height: 6),
            Text('Recorded: ${_formatDate(inquiry.recordedAt)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateTo(int index) {
    final page = switch (index) {
      0 => const KnowledgeBaseScreen(),
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
        title: const Text('Unanswered Inquiries'),
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
          _sampleNotice(),
          const SizedBox(height: 14),
          FutureBuilder<List<UnansweredInquiry>>(
            future: _inquiriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _state(
                  'Could not load unanswered inquiries.',
                  action: TextButton(
                    onPressed: () => setState(_load),
                    child: const Text('Retry'),
                  ),
                );
              }
              final inquiries = snapshot.data ?? const <UnansweredInquiry>[];
              if (inquiries.isEmpty) return _state('No unanswered inquiries.');
              return Column(
                children: inquiries.map(_buildInquiryCard).toList(),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
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

  Widget _buildInquiryCard(UnansweredInquiry inquiry) => Card(
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
            inquiry.question,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${inquiry.sourceLabel} · ${_formatDate(inquiry.recordedAt)}',
            style: const TextStyle(color: Color(0xFF64747A), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showDetails(inquiry),
              icon: const Icon(Icons.visibility_outlined, size: 17),
              label: const Text('View details'),
            ),
          ),
        ],
      ),
    ),
  );

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
            'Prototype sample data only. All locally available records are shown; backend pagination is not configured.',
            style: TextStyle(color: _ink, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _state(String message, {Widget? action}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        ?action,
      ],
    ),
  );
}
