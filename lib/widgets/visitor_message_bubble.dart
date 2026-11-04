import 'package:flutter/material.dart';

import '../theme/ui_constants.dart';

/// Message bubble for the Visitor Chat. Kept separate from ChatMessageBubble,
/// which has feedback controls for the Student chat.
class VisitorMessageBubble extends StatelessWidget {
  const VisitorMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.sentAt,
    this.isSample = false,
  });

  final String text;
  final bool isUser;
  final DateTime sentAt;
  final bool isSample;

  static String formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final time = formatTime(sentAt);

    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: UiConstants.bubbleGray,
      child: isUser
          ? const Icon(Icons.person, color: Colors.black45, size: 28)
          : const Text(
              'O',
              style: TextStyle(fontSize: 23, color: UiConstants.black),
            ),
    );

    final bubble = Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: UiConstants.bubbleGray,
            borderRadius: BorderRadius.circular(UiConstants.bubbleRadius),
          ),
          child: Text(
            text,
            softWrap: true,
            style: const TextStyle(
              fontSize: UiConstants.bodySize,
              color: UiConstants.black,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: UiConstants.spaceXs,
            left: 4,
            right: 4,
          ),
          child: Text(
            isSample ? 'Sample response  |  $time' : time,
            style: const TextStyle(
              fontSize: UiConstants.captionSize,
              fontStyle: FontStyle.italic,
              color: UiConstants.mutedText,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${isUser ? 'You' : 'OASSIS'} said: $text. '
          '${isSample ? 'Sample response. ' : ''}Sent at $time.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: isUser
              ? [Flexible(child: bubble), const SizedBox(width: 12), avatar]
              : [avatar, const SizedBox(width: 12), Flexible(child: bubble)],
        ),
      ),
    );
  }
}
