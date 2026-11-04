import 'package:flutter/material.dart';
import 'response_feedback_controls.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.feedback,
    this.onFeedbackChanged,
    this.isPending = false,
    this.isFailed = false,
    this.isArchived = false,
    this.onRetry,
    this.onEdit,
    this.onArchive,
  });
  final String text;
  final bool isUser;
  final FeedbackType? feedback;
  final ValueChanged<FeedbackType>? onFeedbackChanged;
  final bool isPending;
  final bool isFailed;
  final bool isArchived;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bubble(
                isArchived ? 'This message was archived.' : text,
                archived: isArchived,
              ),
              if (isPending) ...[
                const SizedBox(height: 4),
                const Text('Sending...', style: TextStyle(fontSize: 12)),
              ],
              if (isFailed) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
              if (!isPending &&
                  !isFailed &&
                  !isArchived &&
                  (onEdit != null || onArchive != null))
                PopupMenuButton<_MessageAction>(
                  tooltip: 'Message options',
                  onSelected: (action) {
                    if (action == _MessageAction.edit) onEdit?.call();
                    if (action == _MessageAction.archive) onArchive?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: _MessageAction.edit,
                        child: Text('Edit message'),
                      ),
                    if (onArchive != null)
                      const PopupMenuItem(
                        value: _MessageAction.archive,
                        child: Text('Archive message'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8, top: 2),
          decoration: const BoxDecoration(
            color: Color(0xFFE5E5E5),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'O',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OASSIS',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                child: _bubble(text),
              ),
              if (onFeedbackChanged != null) ...[
                const SizedBox(height: 8),
                ResponseFeedbackControls(
                  value: feedback,
                  onChanged: onFeedbackChanged!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(String value, {bool archived = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: archived ? const Color(0xFFF5F5F5) : const Color(0xFFE5E5E5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      value,
      style: TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontStyle: archived ? FontStyle.italic : FontStyle.normal,
      ),
    ),
  );
}

enum _MessageAction { edit, archive }
