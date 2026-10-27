mimport 'package:flutter/material.dart';
import 'response_feedback_controls.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.text, required this.isUser, this.feedback, this.onFeedbackChanged});
  final String text;
  final bool isUser;
  final FeedbackType? feedback;
  final ValueChanged<FeedbackType>? onFeedbackChanged;

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          child: _bubble(text),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32, margin: const EdgeInsets.only(right: 8, top: 2),
          decoration: const BoxDecoration(color: Color(0xFFE5E5E5), shape: BoxShape.circle),
          child: const Center(child: Text('O', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w800))),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OASSIS', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                child: _bubble(text),
              ),
              const SizedBox(height: 8),
              ResponseFeedbackControls(value: feedback, onChanged: onFeedbackChanged ?? (_) {}),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFFE5E5E5), borderRadius: BorderRadius.circular(12)),
    child: Text(value, style: const TextStyle(color: Colors.black, fontSize: 16)),
  );
}
