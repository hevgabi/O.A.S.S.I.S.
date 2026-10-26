import 'package:flutter/material.dart';

import '../../models/unanswered_inquiry.dart';
import '../../services/admin_service.dart';
import 'interaction_logs_screen.dart';
import 'knowledge_base_screen.dart';

class UnansweredInquiriesScreen extends StatelessWidget {
  const UnansweredInquiriesScreen({super.key});

  static const Color _ink = Color(0xFF17333D);
  static const Color _teal = Color(0xFF176B67);

  void _showDetails(BuildContext context, UnansweredInquiry inquiry) {
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
            Text('From: ${inquiry.questioner} (${inquiry.role})'),
            const SizedBox(height: 6),
            Text('Received: ${_formatDate(inquiry.submittedAt)}'),
            const SizedBox(height: 12),
            const Text(
              'Sample inquiry — add an approved answer to the knowledge base.',
              style: TextStyle(color: Color(0xFF64747A), fontSize: 12),
            ),
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

  static String _formatDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year} · '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  void _navigateTo(BuildContext context, int index) {
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

  @override
  Widget build(BuildContext context) {
    final inquiries = AdminService.instance.getUnansweredInquiries();
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          _sampleBanner(),
          const SizedBox(height: 14),
          if (inquiries.isEmpty)
            const Center(child: Text('No unanswered inquiries.'))
          else
            ...inquiries.map(
              (inquiry) => Card(
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
                        '${inquiry.questioner} · ${inquiry.role}',
                        style: const TextStyle(
                          color: Color(0xFF64747A),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _showDetails(context, inquiry),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('View Details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) => _navigateTo(context, index),
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

  Widget _sampleBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3F1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: _teal),
        SizedBox(width: 7),
        Text(
          'Sample inquiries for the prototype.',
          style: TextStyle(color: _ink, fontSize: 12),
        ),
      ],
    ),
  );
}
