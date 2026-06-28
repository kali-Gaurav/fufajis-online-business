import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../models/chat_message_model.dart';
import '../../utils/app_theme.dart';

class RiderSupportConsole extends StatefulWidget {
  const RiderSupportConsole({super.key});

  @override
  State<RiderSupportConsole> createState() => _RiderSupportConsoleState();
}

class _RiderSupportConsoleState extends State<RiderSupportConsole> {
  final ChatService _chatService = ChatService();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedChannelId;
  String? _selectedRiderName;

  // Administrative canned replies for quick assistance
  final List<String> _cannedReplies = [
    'Got it, please proceed.',
    'Map route updated, check your trip worksheet.',
    'Call the customer once more; I am notifying them.',
    'Assistance has been dispatched to your location.',
    'Verify OTP directly with customer card.',
  ];

  @override
  void dispose() {
    _replyController.dispose();
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

  Future<void> _sendReply(String text) async {
    if (text.trim().isEmpty || _selectedChannelId == null) return;

    final riderId = _selectedChannelId!;
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final replyMsg = ChatMessageModel(
      id: msgId,
      senderId: 'owner_admin',
      senderName: 'Store Owner',
      receiverId: riderId,
      message: text.trim(),
      timestamp: DateTime.now(),
      isRead: false,
      chatChannelId: riderId,
    );

    _replyController.clear();

    try {
      await _chatService.sendSupportMessage(replyMsg);
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send reply: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: Row(
        children: [
          // Left Sidebar: Active Channels list
          Expanded(flex: 3, child: _buildSidebar()),
          const VerticalDivider(thickness: 1, width: 1),

          // Right Chat Window: Message thread
          Expanded(flex: 7, child: _buildChatWindow()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return StreamBuilder<List<ChatMessageModel>>(
      stream: _chatService.getOwnerChatChannelsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        final allMessages = snapshot.data ?? [];

        // Group messages by chatChannelId (riderId) to find unique conversations
        final Map<String, List<ChatMessageModel>> grouped = {};
        for (var msg in allMessages) {
          if (msg.chatChannelId.isNotEmpty) {
            grouped.putIfAbsent(msg.chatChannelId, () => []).add(msg);
          }
        }

        // Create list of channel descriptors
        final channels = grouped.entries.map((entry) {
          final msgs = entry.value;
          // Sorted by timestamp descending, so first is latest
          msgs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final latestMsg = msgs.first;
          final unreadCount = msgs
              .where((m) => !m.isRead && m.senderId != 'owner_admin')
              .length;

          return {
            'channelId': entry.key,
            'riderName': latestMsg.senderId == 'owner_admin'
                ? latestMsg.receiverId
                : latestMsg.senderName,
            'latestText': latestMsg.message,
            'timestamp': latestMsg.timestamp,
            'unreadCount': unreadCount,
          };
        }).toList();

        // Sort channels by latest message time
        channels.sort(
          (a, b) => (b['timestamp'] as DateTime).compareTo(
            a['timestamp'] as DateTime,
          ),
        );

        return Container(
          color: AppTheme.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neighborhood Chats',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Support for Customers & Riders',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: channels.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_outlined,
                              size: 40,
                              color: AppTheme.grey300,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No active support chats.',
                              style: TextStyle(
                                color: AppTheme.grey400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: channels.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final channel = channels[index];
                          final id = channel['channelId'] as String;
                          final isSelected = _selectedChannelId == id;
                          final unreadCount = channel['unreadCount'] as int;
                          final riderName = channel['riderName'] as String;

                          return ListTile(
                            tileColor: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.05)
                                : Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.grey200,
                              foregroundColor: isSelected
                                  ? AppTheme.white
                                  : AppTheme.grey700,
                              child: Text(
                                riderName.isNotEmpty
                                    ? riderName[0].toUpperCase()
                                    : 'R',
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    riderName,
                                    style: TextStyle(
                                      fontWeight: isSelected || unreadCount > 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: AppTheme.grey900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'hh:mm a',
                                  ).format(channel['timestamp'] as DateTime),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.grey400,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    channel['latestText'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: unreadCount > 0
                                          ? AppTheme.grey800
                                          : AppTheme.grey500,
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _selectedChannelId = id;
                                _selectedRiderName = riderName;
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatWindow() {
    if (_selectedChannelId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 64,
                color: AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select a Conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a neighborhood thread from the sidebar to view history.',
              style: TextStyle(fontSize: 13, color: AppTheme.grey500),
            ),
          ],
        ),
      );
    }

    final channelId = _selectedChannelId!;
    final riderName = _selectedRiderName ?? 'Rider';

    // Mark incoming messages as read
    _chatService.markMessagesAsRead(channelId, 'owner');

    return Column(
      children: [
        // Thread Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: AppTheme.white,
            border: Border(bottom: BorderSide(color: AppTheme.grey200)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    riderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.grey900,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Active Thread',
                        style: TextStyle(fontSize: 11, color: AppTheme.grey500),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Messages Area
        Expanded(
          child: StreamBuilder<List<ChatMessageModel>>(
            stream: _chatService.getRiderChatStream(channelId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
              }

              final messages = snapshot.data ?? [];

              if (messages.isNotEmpty) {
                _scrollToBottom();
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == 'owner_admin';

                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.45,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? AppTheme.primary : AppTheme.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isMe
                              ? const Radius.circular(12)
                              : Radius.zero,
                          bottomRight: isMe
                              ? Radius.zero
                              : const Radius.circular(12),
                        ),
                        border: isMe
                            ? null
                            : Border.all(color: AppTheme.grey200),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.black.withValues(alpha: 0.02),
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
                                  color: isMe
                                      ? AppTheme.white.withValues(alpha: 0.7)
                                      : AppTheme.grey400,
                                  fontSize: 10,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.done_all,
                                  size: 12,
                                  color: message.isRead
                                      ? AppTheme.ownerAccent
                                      : AppTheme.white.withValues(alpha: 0.7),
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

        // Canned Replies Panel
        Container(
          height: 44,
          color: AppTheme.grey100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _cannedReplies.length,
            itemBuilder: (context, index) {
              final text = _cannedReplies[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  backgroundColor: AppTheme.white,
                  side: const BorderSide(color: AppTheme.grey300),
                  label: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey700,
                    ),
                  ),
                  onPressed: () => _sendReply(text),
                ),
              );
            },
          ),
        ),

        // Reply Input Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.white,
            border: Border(top: BorderSide(color: AppTheme.grey200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: InputDecoration(
                    hintText: 'Type your reply...',
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppTheme.grey300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.grey800 : AppTheme.grey50,
                  ),
                  onSubmitted: (text) => _sendReply(text),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.small(
                onPressed: () => _sendReply(_replyController.text),
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.white,
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
