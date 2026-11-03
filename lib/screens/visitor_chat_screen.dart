import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../theme/ui_constants.dart';
import '../widgets/visitor_message_bubble.dart';

class VisitorMessage {
  VisitorMessage({required this.text, required this.isUser, DateTime? sentAt})
    : sentAt = sentAt ?? DateTime.now();

  final String text;
  final bool isUser;
  final DateTime sentAt;
}

class VisitorChatScreen extends StatefulWidget {
  const VisitorChatScreen({super.key});

  @override
  State<VisitorChatScreen> createState() => _VisitorChatScreenState();
}

class _VisitorChatScreenState extends State<VisitorChatScreen> {
  // Set to true to open the chat with a sample exchange instead of the empty state.
  static const bool _startWithSampleExchange = false;

  static const Duration _replyDelay = Duration(milliseconds: 1500);
  static const String _sampleReply = 'I can help you find it.';
  static const List<String> _suggestions = [
    'Where is the admissions office?',
    'Where can I find the registrar?',
  ];

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<VisitorMessage> _messages = [];

  bool _isSending = false;
  bool _hasError = false;
  String? _failedText;

  bool get _canSend => _inputController.text.trim().isNotEmpty && !_isSending;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() => setState(() {}));

    if (_startWithSampleExchange) {
      _messages.addAll([
        VisitorMessage(text: _suggestions.first, isUser: true),
        VisitorMessage(text: _sampleReply, isUser: false),
      ]);
    }
  }

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

  void _sendFromInput() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;
    _inputController.clear();
    _submit(text);
  }

  void _submit(String text) {
    if (_isSending) return;

    setState(() {
      _messages.add(VisitorMessage(text: text, isUser: true));
      _isSending = true;
      _hasError = false;
      _failedText = null;
    });
    _scrollToBottom();
    _respond(text, isRetry: false);
  }

  // Simulated response. A message containing "error" fails once so the
  // error and retry state can be shown in the demo.
  void _respond(String text, {required bool isRetry}) {
    Future.delayed(_replyDelay, () {
      if (!mounted) return;

      final shouldFail = !isRetry && text.toLowerCase().contains('error');

      setState(() {
        _isSending = false;
        if (shouldFail) {
          _hasError = true;
          _failedText = text;
        } else {
          _hasError = false;
          _failedText = null;
          _messages.add(VisitorMessage(text: _sampleReply, isUser: false));
        }
      });
      _scrollToBottom();
    });
  }

  void _retry() {
    final text = _failedText;
    if (text == null || _isSending) return;

    setState(() {
      _hasError = false;
      _isSending = true;
    });
    _scrollToBottom();
    _respond(text, isRetry: true);
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: UiConstants.maxChatWidth,
            ),
            child: Column(
              children: [
                _buildHeader(),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: UiConstants.black,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Visitor',
                      style: TextStyle(
                        fontSize: UiConstants.labelSize,
                        color: UiConstants.black,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessageList(),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: UiConstants.black,
                ),
                _buildInputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UiConstants.screenPadding,
        vertical: 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'OASSIS',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: UiConstants.black,
            ),
          ),
          const SizedBox(width: UiConstants.spaceSm),
          Flexible(
            child: SizedBox(
              height: 44,
              child: Semantics(
                button: true,
                label: 'Back to sign in',
                child: OutlinedButton(
                  onPressed: _goBack,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: UiConstants.lightButtonGray,
                    foregroundColor: UiConstants.black,
                    minimumSize: const Size(
                      UiConstants.minTapTarget,
                      UiConstants.minTapTarget - 4,
                    ),
                    side: const BorderSide(
                      color: UiConstants.borderGray,
                      width: UiConstants.borderWidth,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UiConstants.radius),
                    ),
                  ),
                  child: const Text(
                    'Back to sign in',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: UiConstants.black),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(UiConstants.dialogSpacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ask OASSIS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: UiConstants.titleSize,
                fontWeight: FontWeight.w700,
                color: UiConstants.black,
              ),
            ),
            const SizedBox(height: UiConstants.spaceSm),
            const Text(
              'Type a question about the campus below, or tap one of these to start.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: UiConstants.bodySize,
                color: UiConstants.mutedText,
              ),
            ),
            const SizedBox(height: UiConstants.spaceMd),
            for (final question in _suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: UiConstants.spaceSm),
                child: SizedBox(
                  height: UiConstants.minTapTarget + 4,
                  child: OutlinedButton(
                    onPressed: () => _submit(question),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UiConstants.black,
                      side: const BorderSide(
                        color: UiConstants.black,
                        width: UiConstants.borderWidth,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(UiConstants.radius),
                      ),
                    ),
                    child: Text(
                      question,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final extra = (_isSending || _hasError) ? 1 : 0;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: UiConstants.screenPadding,
        vertical: UiConstants.spaceSm,
      ),
      itemCount: _messages.length + extra,
      itemBuilder: (context, index) {
        if (index < _messages.length) {
          final message = _messages[index];
          return VisitorMessageBubble(
            text: message.text,
            isUser: message.isUser,
            sentAt: message.sentAt,
            isSample: !message.isUser,
          );
        }
        return _isSending ? _buildTypingIndicator() : _buildErrorState();
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Semantics(
      liveRegion: true,
      label: 'OASSIS is typing',
      excludeSemantics: true,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: UiConstants.bubbleGray,
              child: Text(
                'O',
                style: TextStyle(fontSize: 23, color: UiConstants.black),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'OASSIS is typing...',
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: UiConstants.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(UiConstants.spaceMd),
        decoration: BoxDecoration(
          border: Border.all(
            color: UiConstants.black,
            width: UiConstants.borderWidth,
          ),
          borderRadius: BorderRadius.circular(UiConstants.bubbleRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OASSIS could not respond.',
              style: TextStyle(
                fontSize: UiConstants.bodySize,
                fontWeight: FontWeight.w700,
                color: UiConstants.black,
              ),
            ),
            const SizedBox(height: UiConstants.spaceXs),
            const Text(
              'Check your connection, then tap Retry to send your question again.',
              style: TextStyle(fontSize: 15, color: UiConstants.mutedText),
            ),
            const SizedBox(height: UiConstants.spaceSm),
            Semantics(
              button: true,
              label: 'Retry sending your question',
              child: OutlinedButton(
                onPressed: _retry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: UiConstants.black,
                  minimumSize: const Size(
                    UiConstants.minTapTarget,
                    UiConstants.minTapTarget,
                  ),
                  side: const BorderSide(
                    color: UiConstants.black,
                    width: UiConstants.borderWidth,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UiConstants.radius),
                  ),
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.all(UiConstants.spaceMd),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Type a message',
              textField: true,
              child: TextField(
                controller: _inputController,
                onSubmitted: (_) => _sendFromInput(),
                textInputAction: TextInputAction.send,
                decoration: UiConstants.inputDecoration('Type a message'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: UiConstants.inputHeight,
            child: Semantics(
              button: true,
              label: 'Send message',
              child: ElevatedButton(
                onPressed: _canSend ? _sendFromInput : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiConstants.lightButtonGray,
                  foregroundColor: UiConstants.black,
                  disabledBackgroundColor: const Color(0xFFF2F2F2),
                  disabledForegroundColor: Colors.black38,
                  minimumSize: const Size(80, UiConstants.inputHeight),
                  elevation: 0,
                  side: const BorderSide(color: UiConstants.borderGray),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UiConstants.radius),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: UiConstants.black,
                        ),
                      )
                    : const Text('Send', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
