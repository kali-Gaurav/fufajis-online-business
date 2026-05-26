import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/app_theme.dart';
import '../../services/firestore_service.dart';

class SupportChatScreen extends StatefulWidget {
  final String? orderId;

  const SupportChatScreen({
    super.key,
    this.orderId,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      Provider.of<ChatProvider>(context, listen: false).listenToChat(user.id);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final user = Provider.of<AuthProvider>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Fufaji'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                final msg = chatProvider.messages[index];
                final isMe = msg.senderId == user?.id;
                return _buildMessageBubble(msg, isMe);
              },
            ),
          ),
          _buildInputArea(user),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : AppTheme.grey200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.message,
              style: TextStyle(color: isMe ? Colors.white : AppTheme.grey900, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(msg.timestamp),
              style: TextStyle(color: (isMe ? Colors.white : AppTheme.grey600).withValues(alpha: 0.7), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppTheme.grey200))),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              // TODO: Implement Voice Note shortcut
            },
            icon: const Icon(Icons.mic, color: AppTheme.secondary),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask Fufaji something...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                fillColor: AppTheme.grey100,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.primary,
            child: IconButton(
              onPressed: () {
                if (_controller.text.isNotEmpty && user != null) {
                  Provider.of<ChatProvider>(context, listen: false).sendMessage(
                    senderId: user.id,
                    senderName: user.name ?? 'Customer',
                    receiverId: 'shop_owner',
                    message: _controller.text,
                    channelId: user.id,
                  );
                  _controller.clear();
                  _scrollToBottom();
                }
              },
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

