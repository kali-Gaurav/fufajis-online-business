import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/chat_conversation_model.dart';
import '../../models/canned_response_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/canned_response_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/canned_response_picker.dart';

/// Employee-facing chat screen.
/// Shows only assigned conversations and allows replying.
/// Cannot close tickets or assign others.
class EmployeeChatScreen extends StatefulWidget {
  final String chatId;

  const EmployeeChatScreen({super.key, required this.chatId});

  @override
  State<EmployeeChatScreen> createState() => _EmployeeChatScreenState();
}

class _EmployeeChatScreenState extends State<EmployeeChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      // Employee sees customer messages + internal notes but cannot send to customer directly
      chatProvider.listenToMessages(widget.chatId, customerView: false);
      chatProvider.listenToConversationMeta(widget.chatId);
      chatProvider.markAsRead(widget.chatId, SenderRole.employee);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    Provider.of<ChatProvider>(context, listen: false).clearActiveChat();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    _controller.clear();
    HapticFeedback.lightImpact();

    await Provider.of<ChatProvider>(context, listen: false).sendMessage(
      chatId: widget.chatId,
      senderId: user.id,
      senderName: user.name ?? 'Staff',
      senderRole: SenderRole.employee,
      text: text,
    );
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.grey900 : const Color(0xFFF5F0FF),
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildCustomerBanner(isDark),
          Expanded(child: _buildMessages(isDark)),
          _buildQuickReplies(isDark),
          _buildInput(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Consumer<ChatProvider>(
      builder: (ctx, chatProvider, _) {
        final conv = chatProvider.activeConversation;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (conv?.customerName.isNotEmpty == true)
                            ? conv!.customerName[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conv?.customerName ?? 'Customer',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (conv?.orderNumber != null)
                          Text(
                            'Order #${conv!.orderNumber}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  // Assigned badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.badge_outlined, color: Colors.white70, size: 12),
                        SizedBox(width: 4),
                        Text('Assigned', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerBanner(bool isDark) {
    return Consumer<ChatProvider>(
      builder: (ctx, chatProvider, _) {
        final conv = chatProvider.activeConversation;
        if (conv == null) return const SizedBox.shrink();
        return Container(
          color: isDark ? AppTheme.grey800 : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppTheme.grey400),
              const SizedBox(width: 6),
              Text(
                'Customer: ${conv.customerPhone}',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
              const Spacer(),
              if (conv.isTypingCustomer) ...[
                const Icon(Icons.edit, size: 13, color: AppTheme.info),
                const SizedBox(width: 4),
                const Text('typing...', style: TextStyle(fontSize: 11, color: AppTheme.info)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessages(bool isDark) {
    return Consumer<ChatProvider>(
      builder: (ctx, chatProvider, _) {
        if (chatProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final msgs = chatProvider.messages;
        if (msgs.isEmpty) {
          return const Center(
            child: Text('No messages yet', style: TextStyle(color: AppTheme.grey400)),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: msgs.length,
          itemBuilder: (context, index) {
            final msg = msgs[index];
            return _buildMsgItem(msg, isDark);
          },
        );
      },
    );
  }

  Widget _buildMsgItem(ChatMessage msg, bool isDark) {
    if (msg.messageType == MessageType.systemMessage) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.grey800 : const Color(0xFFEDF4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
            ),
            child: Text(
              msg.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    }

    if (msg.isInternalNote) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD54F)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 14, color: Color(0xFFF57F17)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${msg.senderName} — Note',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF57F17),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(msg.text, style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037))),
                ],
              ),
            ),
            Text(
              DateFormat('hh:mm a').format(msg.timestamp),
              style: const TextStyle(fontSize: 10, color: AppTheme.grey500),
            ),
          ],
        ),
      );
    }

    final isCustomer = msg.senderRole == SenderRole.customer;
    return Align(
      alignment: isCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: isCustomer ? 0 : 60,
          right: isCustomer ? 60 : 0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isCustomer
                ? (isDark ? AppTheme.grey800 : Colors.white)
                : AppTheme.employeeAccent,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isCustomer ? 4 : 16),
              bottomRight: Radius.circular(isCustomer ? 16 : 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: isCustomer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                msg.text,
                style: TextStyle(
                  color: isCustomer ? (isDark ? Colors.white : AppTheme.grey900) : Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('hh:mm a').format(msg.timestamp),
                style: TextStyle(
                  color: isCustomer ? AppTheme.grey400 : Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Task #66: Quick-reply chip bar backed by live Firestore canned responses.
  /// Shows the first 4 results as tappable chips; "⚡" opens the full picker.
  Widget _buildQuickReplies(bool isDark) {
    return Container(
      height: 44,
      color: isDark ? AppTheme.grey800 : const Color(0xFFF3E5F5),
      child: StreamBuilder<List<CannedResponseModel>>(
        stream: CannedResponseService().watchAll(),
        builder: (context, snapshot) {
          final previews = snapshot.data?.take(4).toList() ?? [];

          return Row(
            children: [
              // Chip strip (horizontally scrollable)
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: previews
                      .map(
                        (r) => GestureDetector(
                          onTap: () {
                            _controller.text = r.text;
                            _focusNode.requestFocus();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.employeeAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppTheme.employeeAccent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              r.title,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.grey200 : AppTheme.employeeAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              // "More" button opens full picker (employee — read-only)
              GestureDetector(
                onTap: () async {
                  final text = await CannedResponsePicker.show(
                    context,
                    allowManage: false,
                    accentColor: AppTheme.employeeAccent,
                  );
                  if (text != null && mounted) {
                    _controller.text = text;
                    _focusNode.requestFocus();
                  }
                },
                child: Container(
                  width: 44,
                  height: double.infinity,
                  color: AppTheme.employeeAccent.withValues(alpha: 0.08),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: AppTheme.employeeAccent,
                    size: 20,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInput(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.grey900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.grey800 : AppTheme.grey100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: isDark ? Colors.white : AppTheme.grey900, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Reply to customer...',
                      hintStyle: TextStyle(color: AppTheme.grey400),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Consumer<ChatProvider>(
                builder: (ctx, chatProvider, _) {
                  return GestureDetector(
                    onTap: chatProvider.isSending ? null : _sendReply,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppTheme.employeeAccent,
                        shape: BoxShape.circle,
                      ),
                      child: chatProvider.isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
