import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../models/chat_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class RiderChatScreen extends StatefulWidget {
  const RiderChatScreen({super.key});

  @override
  State<RiderChatScreen> createState() => _RiderChatScreenState();
}

class _RiderChatScreenState extends State<RiderChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Quick reply presets for on-the-road delivery riders
  final List<String> _quickReplies = [
    'I have arrived at store.',
    'Stuck in heavy traffic.',
    'Tyre puncture / vehicle breakdown.',
    'Customer is not answering call.',
    'Incorrect delivery address.',
    'Delivered successfully!',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, String riderId, String riderName) async {
    if (text.trim().isEmpty) return;

    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final chatMsg = ChatMessageModel(
      id: msgId,
      senderId: riderId,
      senderName: riderName,
      receiverId: 'owner_admin',
      message: text.trim(),
      timestamp: DateTime.now(),
      isRead: false,
      chatChannelId: riderId, // Using riderId as channel ID
    );

    _messageController.clear();

    try {
      await _chatService.sendSupportMessage(chatMsg);
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final rider = authProvider.currentUser;
    final riderId = rider?.id ?? 'demo_rider';
    final riderName = rider?.name ?? 'Rahul';

    // Mark incoming messages as read when opening chat
    _chatService.markMessagesAsRead(riderId, riderId);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.support_agent, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fufaji Rider Support',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Typically replies instantly',
                  style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Real-time Chat Messages Stream
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatService.getRiderChatStream(riderId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                // Schedule scroll-to-bottom on new messages
                if (messages.isNotEmpty) {
                  _scrollToBottom();
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: AppTheme.grey300),
                          SizedBox(height: 16),
                          Text(
                            'Support Channel Active',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey700),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Need help with directions, payments, or orders? Send a message below and the shop owner will assist you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppTheme.grey500),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == riderId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primary : AppTheme.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                          ),
                          border: isMe ? null : Border.all(color: AppTheme.grey200),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.message,
                              style: TextStyle(
                                color: isMe ? AppTheme.white : AppTheme.grey900,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('hh:mm a').format(message.timestamp),
                                  style: TextStyle(
                                    color: isMe ? AppTheme.white.withValues(alpha: 0.7) : AppTheme.grey400,
                                    fontSize: 10,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.done_all,
                                    size: 12,
                                    color: message.isRead ? Colors.blue : AppTheme.white.withValues(alpha: 0.7),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Quick Replies Toolbar
          Container(
            height: 48,
            color: AppTheme.grey100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: _quickReplies.length,
              itemBuilder: (context, index) {
                final text = _quickReplies[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    backgroundColor: AppTheme.white,
                    side: const BorderSide(color: AppTheme.grey300),
                    label: Text(
                      text,
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                    ),
                    onPressed: () => _sendMessage(text, riderId, riderName),
                  ),
                );
              },
            ),
          ),

          // Input Message Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.white,
              border: Border(top: BorderSide(color: AppTheme.grey200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.grey300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                      filled: true,
                      fillColor: AppTheme.grey50,
                    ),
                    onSubmitted: (text) => _sendMessage(text, riderId, riderName),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: () => _sendMessage(_messageController.text, riderId, riderName),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.white,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
