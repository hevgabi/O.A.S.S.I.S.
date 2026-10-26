import 'package:flutter/material.dart';

enum FeedbackType { up, down }

class ResponseFeedbackControls extends StatelessWidget {
  const ResponseFeedbackControls({super.key, required this.value, required this.onChanged});
  final FeedbackType? value;
  final ValueChanged<FeedbackType> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
    _FeedbackButton(icon: Icons.thumb_up_outlined, selected: value == FeedbackType.up, onTap: () => onChanged(FeedbackType.up)),
    const SizedBox(width: 8),
    _FeedbackButton(icon: Icons.thumb_down_outlined, selected: value == FeedbackType.down, onTap: () => onChanged(FeedbackType.down)),
  ]);
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({required this.icon, required this.selected, required this.onTap});
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE5E5E5) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? Colors.black : const Color(0xFFBDBDBD)),
      ),
      child: Icon(icon, color: Colors.black, size: 18),
    ),
  );
}
