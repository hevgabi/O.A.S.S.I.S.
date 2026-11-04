import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../models/chat_message.dart';
import '../models/response_feedback.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_message_input.dart';
import '../widgets/response_feedback_controls.dart';

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({super.key});

  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}

class _StudentChatScreenState extends State<StudentChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final ChatService _chatService = StudentChatServices.current;
  final Map<String, ResponseRating> _ratings = {};

  List<ChatMessage> _messages = [];
  String? _conversationId;
  String? _olderCursor;
  String? _loadError;
  bool _isLoading = true;
  bool _isLoadingOlder = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    final user = AuthService.instance.currentUser;
    if (user == null || !AuthService.instance.isStudent) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final conversation = await _chatService.getOrCreateStudentConversation(
        studentId: user.id,
      );
      final page = await _chatService.fetchMessages(
        conversationId: conversation.id,
      );
      final ratings = await _readRatings(page.messages);
      if (!mounted) return;
      setState(() {
        _conversationId = conversation.id;
        _messages = page.messages.reversed.toList();
        _olderCursor = page.nextOlderCursor;
        _ratings
          ..clear()
          ..addAll(ratings);
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ChatOperationException catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Unable to load your Student conversation.';
        });
      }
    }
  }

  Future<Map<String, ResponseRating>> _readRatings(
    Iterable<ChatMessage> messages,
  ) async {
    final responses = messages.where((message) => message.isOassisResponse);
    final entries = await Future.wait(
      responses.map((message) async {
        final feedback = await _chatService.fetchResponseFeedback(
          responseMessageId: message.id,
        );
        return MapEntry(message.id, feedback?.rating);
      }),
    );
    return {
      for (final entry in entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 80) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    final cursor = _olderCursor;
    final conversationId = _conversationId;
    if (_isLoadingOlder || cursor == null || conversationId == null) return;
    setState(() => _isLoadingOlder = true);
    final oldPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    final oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    try {
      final page = await _chatService.fetchMessages(
        conversationId: conversationId,
        beforeCursor: cursor,
      );
      final ratings = await _readRatings(page.messages);
      if (!mounted) return;
      setState(() {
        final existingIds = _messages.map((message) => message.id).toSet();
        final older = page.messages.reversed.where(
          (message) => !existingIds.contains(message.id),
        );
        _messages = [...older, ..._messages];
        _olderCursor = page.nextOlderCursor;
        _ratings.addAll(ratings);
        _isLoadingOlder = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final addedExtent =
            _scrollController.position.maxScrollExtent - oldMaxExtent;
        _scrollController.jumpTo(oldPixels + addedExtent);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _isLoadingOlder = false);
        _showMessage('Unable to load older messages. Please try again.');
      }
    }
  }

  Future<void> _handleSend({ChatMessage? retryMessage}) async {
    final conversationId = _conversationId;
    final content = retryMessage?.content ?? _messageController.text.trim();
    if (_isSending || conversationId == null || content.isEmpty) return;

    final pending =
        retryMessage?.copyWith(deliveryState: MessageDeliveryState.pending) ??
        ChatMessage(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          conversationId: conversationId,
          author: MessageAuthor.student,
          content: content,
          createdAt: DateTime.now(),
          deliveryState: MessageDeliveryState.pending,
        );
    setState(() {
      _isSending = true;
      _messages = retryMessage == null
          ? [..._messages, pending]
          : _messages
                .map(
                  (message) =>
                      message.id == retryMessage.id ? pending : message,
                )
                .toList();
      _messageController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final savedMessages = await _chatService.sendStudentMessage(
        conversationId: conversationId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final message in _messages)
            if (message.id == pending.id) savedMessages.first else message,
          if (savedMessages.length > 1) ...savedMessages.skip(1),
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _isSending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map(
              (message) => message.id == pending.id
                  ? message.copyWith(deliveryState: MessageDeliveryState.failed)
                  : message,
            )
            .toList();
        _isSending = false;
      });
      _showMessage(
        error is ChatOperationException
            ? error.message
            : 'Message failed to send.',
      );
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.content);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Update your message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || text == message.content) return;
    try {
      final updated = await _chatService.editStudentMessage(
        messageId: message.id,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
    } catch (error) {
      _showMessage('Unable to save that edit.');
    }
  }

  Future<void> _archiveMessage(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive message?'),
        content: const Text(
          'This hides the message from the active chat view without permanently deleting it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _chatService.archiveStudentMessage(messageId: message.id);
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map(
              (item) => item.id == message.id
                  ? item.copyWith(archivedAt: DateTime.now())
                  : item,
            )
            .toList();
      });
    } catch (_) {
      _showMessage('Unable to archive that message.');
    }
  }

  Future<void> _saveFeedback(ChatMessage message, FeedbackType value) async {
    try {
      final feedback = await _chatService.upsertResponseFeedback(
        responseMessageId: message.id,
        rating: value == FeedbackType.up
            ? ResponseRating.up
            : ResponseRating.down,
      );
      if (mounted) setState(() => _ratings[message.id] = feedback.rating);
    } catch (_) {
      _showMessage('Unable to save feedback.');
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _logOut() {
    setState(() {
      _messages = [];
      _ratings.clear();
    });
    AuthService.instance.signOut();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.entry, (route) => false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          _header(),
          const Divider(color: Color(0xFFE0E0E0), thickness: 1, height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Student',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(child: _messageList()),
          const Divider(color: Color(0xFFE0E0E0), thickness: 1, height: 1),
          ChatMessageInput(
            controller: _messageController,
            onSend: _handleSend,
            isSending: _isSending,
          ),
        ],
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'OASSIS',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        TextButton(onPressed: _logOut, child: const Text('Log out')),
      ],
    ),
  );

  Widget _messageList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadInitialMessages,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('Start a conversation with OASSIS.'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _messages.length + (_isLoadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingOlder && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final message = _messages[index - (_isLoadingOlder ? 1 : 0)];
        final rating = _ratings[message.id];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ChatMessageBubble(
            text: message.content,
            isUser: message.isStudentMessage,
            isPending: message.deliveryState == MessageDeliveryState.pending,
            isFailed: message.deliveryState == MessageDeliveryState.failed,
            isArchived: message.isArchived,
            onRetry: message.deliveryState == MessageDeliveryState.failed
                ? () => _handleSend(retryMessage: message)
                : null,
            onEdit: message.isStudentMessage && !message.isArchived
                ? () => _editMessage(message)
                : null,
            onArchive: message.isStudentMessage && !message.isArchived
                ? () => _archiveMessage(message)
                : null,
            feedback: rating == ResponseRating.up
                ? FeedbackType.up
                : rating == ResponseRating.down
                ? FeedbackType.down
                : null,
            onFeedbackChanged: message.isOassisResponse
                ? (value) => _saveFeedback(message, value)
                : null,
          ),
        );
      },
    );
  }
}
