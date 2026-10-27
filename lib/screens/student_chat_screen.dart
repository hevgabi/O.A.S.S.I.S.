import 'package:flutter/material.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_message_input.dart';
import '../widgets/response_feedback_controls.dart';

class ChatMessage {
  ChatMessage({required this.text, required this.isUser, this.feedback});
  final String text;
  final bool isUser;
  FeedbackType? feedback;
}

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({super.key});
  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(text: 'Where is the admissions office?', isUser: true),
    ChatMessage(text: 'I can help you find it.', isUser: false),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _handleSend() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages
        ..add(ChatMessage(text: text, isUser: true))
        ..add(ChatMessage(text: _getPlaceholderResponse(text), isUser: false));
      _messageController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _getPlaceholderResponse(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('admission') || lower.contains('office')) {
      return 'You can visit the admissions office at the main campus building on weekdays from 8:00 AM to 5:00 PM.';
    }
    if (lower.contains('deadline') || lower.contains('due')) {
      return 'I can help you review the upcoming deadlines and important dates.';
    }
    if (lower.contains('schedule') || lower.contains('class')) {
      return 'I can help you check your enrollment schedule and class timings.';
    }
    return 'I am sorry, I do not understand. Can you please rephrase your question?';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Expanded(child: Text('OASSIS', style: TextStyle(
                color: Colors.black, fontSize: 30,
                fontWeight: FontWeight.w800, letterSpacing: -0.5,
              ))),
              TextButton(
                onPressed: () { if (Navigator.canPop(context)) Navigator.pop(context); },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF4F4F4),
                  side: const BorderSide(color: Color(0xFFBDBDBD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Profile', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
          const Divider(color: Color(0xFFE0E0E0), thickness: 1, height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('Student', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600))),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ChatMessageBubble(
                    text: message.text,
                    isUser: message.isUser,
                    feedback: message.feedback,
                    onFeedbackChanged: (feedback) => setState(() => message.feedback = feedback),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Color(0xFFE0E0E0), thickness: 1, height: 1),
          ChatMessageInput(controller: _messageController, onSend: _handleSend),
        ],
      ),
    ),
  );
}
