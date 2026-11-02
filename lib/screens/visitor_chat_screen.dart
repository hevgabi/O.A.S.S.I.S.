import 'package:flutter/material.dart';

class VisitorMessage {
  final String text;
  final bool isUser;

  const VisitorMessage({required this.text, required this.isUser});
}

class VisitorChatScreen extends StatefulWidget {
  const VisitorChatScreen({super.key});

  @override
  State<VisitorChatScreen> createState() => _VisitorChatScreenState();
}

class _VisitorChatScreenState extends State<VisitorChatScreen> {
  static const Color black = Colors.black;
  static const Color bubbleGray = Color(0xFFEEEEEE);
  static const Color buttonGray = Color(0xFFE0E0E0);
  static const Color borderGray = Color(0xFF666666);

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<VisitorMessage> _messages = [
    const VisitorMessage(text: 'Where is the admissions office?', isUser: true),
    const VisitorMessage(text: 'I can help you find it.', isUser: false),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(VisitorMessage(text: text, isUser: true));
    });

    _inputController.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const VisitorMessage(text: 'I can help you find it.', isUser: false),
        );
      });

      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'OASSIS',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: black,
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: buttonGray,
                        foregroundColor: black,
                        side: const BorderSide(color: borderGray, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(fontSize: 17, color: black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: black),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Visitor',
                  style: TextStyle(fontSize: 18, color: black),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessage(_messages[index]);
                },
              ),
            ),
            const Divider(height: 1, thickness: 1, color: black),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: const TextStyle(
                          fontSize: 18,
                          color: Colors.black45,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 17,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(color: borderGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(
                            color: black,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonGray,
                        foregroundColor: black,
                        elevation: 0,
                        side: const BorderSide(color: borderGray),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text('Send', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(VisitorMessage message) {
    final isUser = message.isUser;

    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: bubbleGray,
      child: isUser
          ? const Icon(Icons.person, color: Colors.black45, size: 28)
          : const Text('O', style: TextStyle(fontSize: 23, color: black)),
    );

    final bubble = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bubbleGray,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            message.text,
            style: const TextStyle(fontSize: 17, color: black),
          ),
        ),
        if (!isUser)
          const Padding(
            padding: EdgeInsets.only(top: 5, left: 4),
            child: Text(
              'Sample response',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
            ),
          ),
      ],
    );

    return Padding(
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
    );
  }
}
