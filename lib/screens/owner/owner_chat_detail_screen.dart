import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/chat_conversation_model.dart';
import '../../models/employee_model.dart';
import '../../models/faq_article_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/employee_auth_service.dart';
import '../../services/faq_service.dart';
import '../../services/chat_export_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/navigation_helper.dart';
import '../../widgets/canned_response_picker.dart';
import '../../widgets/faq_article_card.dart';

class OwnerChatDetailScreen extends StatefulWidget {
  final String chatId;

  const OwnerChatDetailScreen({super.key, required this.chatId});

  @override
  State<OwnerChatDetailScreen> createState() => _OwnerChatDetailScreenState();
}

class _OwnerChatDetailScreenState extends State<OwnerChatDetailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late TabController _viewTabController;

  bool _isInternalNote = false;
  List<String> _mentions = [];

  // Task #69 — FAQ auto-link state
  FaqArticleModel? _suggestedFaq;
  final FaqService _faqService = FaqService();
  List<FaqArticleModel> _faqCache = [];

  static const List<String> _mentionOptions = [
    '@owner',
    '@employee',
    '@delivery',
    '@billing',
    '@warehouse',
  ];

  /// Task #66: Opens the shared CannedResponsePicker with owner-manage
  /// privileges (add / edit / delete). Owner picks a response → it is
  /// pasted into the compose field.
  Future<void> _showCannedResponses() async {
    final text = await CannedResponsePicker.show(
      context,
      allowManage: true,
      accentColor: AppTheme.primary,
    );
    if (text != null && mounted) {
      setState(() => _controller.text = text);
    }
  }

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      // Show all messages (including internal notes) for staff
      chatProvider.listenToMessages(widget.chatId, customerView: false);
      chatProvider.listenToConversationMeta(widget.chatId);
      chatProvider.markAsRead(widget.chatId, SenderRole.owner);
    });
    // Task #69 — seed FAQ defaults + pre-load into cache for sync matching
    _faqService.seedDefaults().then((_) {
      _faqService.watchAll().listen((articles) {
        if (mounted) setState(() => _faqCache = articles);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _viewTabController.dispose();
    Provider.of<ChatProvider>(context, listen: false).clearActiveChat();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    _controller.clear();
    HapticFeedback.lightImpact();

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (_isInternalNote) {
      await chatProvider.sendInternalNote(
        chatId: widget.chatId,
        senderId: user.id,
        senderName: user.name ?? 'Owner',
        senderRole: SenderRole.owner,
        text: text,
        mentions: _mentions,
      );
    } else {
      await chatProvider.sendMessage(
        chatId: widget.chatId,
        senderId: user.id,
        senderName: 'Fufaji Store',
        senderRole: SenderRole.owner,
        text: text,
      );
    }

    setState(() {
      _mentions = [];
    });
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
      backgroundColor: isDark ? AppTheme.grey900 : const Color(0xFFF0F4F8),
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildCustomerInfo(isDark),
          _buildViewTabs(isDark),
          Expanded(child: _buildMessageArea(isDark)),
          _buildQuickActions(isDark),
          _buildInputArea(isDark),
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
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => NavigationHelper.safePop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conv?.customerName ?? 'Customer',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (conv?.orderNumber != null)
                          Text(
                            'Order #${conv!.orderNumber}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  // Status chip
                  if (conv != null) _StatusChip(status: conv.status),
                  const SizedBox(width: 8),
                  // Overflow menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (val) => _handleMenuAction(val, conv),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'assign', child: Text('Assign Staff')),
                      if (conv?.status != ChatStatus.closed) ...[
                        const PopupMenuItem(value: 'close', child: Text('Close Ticket')),
                        // Task #67 — Archive moves conversation to Archive tab
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(
                                Icons.archive_outlined,
                                size: 18,
                                color: AppTheme.ownerAccentGrey,
                              ),
                              SizedBox(width: 8),
                              Text('Archive Chat'),
                            ],
                          ),
                        ),
                      ],
                      const PopupMenuItem(value: 'invoice', child: Text('Send Invoice')),
                      // Task #69 — FAQ management
                      const PopupMenuItem(
                        value: 'faq',
                        child: Row(
                          children: [
                            Icon(Icons.menu_book_outlined, size: 18, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('FAQ Knowledgebase'),
                          ],
                        ),
                      ),
                      // Task #70 — Export chat transcript (compliance)
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.download_outlined, size: 18, color: AppTheme.ownerAccent),
                            SizedBox(width: 8),
                            Text('Export Chat'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerInfo(bool isDark) {
    return Consumer<ChatProvider>(
      builder: (ctx, chatProvider, _) {
        final conv = chatProvider.activeConversation;
        if (conv == null) return const SizedBox.shrink();
        return Container(
          color: isDark ? AppTheme.grey800 : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppTheme.grey400),
              const SizedBox(width: 6),
              Text(
                conv.customerPhone,
                style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
              const Spacer(),
              // Task #68 — Sentiment indicator in the info bar
              if (conv.overallSentiment != null) ...[
                _SentimentPill(sentiment: conv.overallSentiment!),
                const SizedBox(width: 8),
              ],
              if (conv.isTypingCustomer) ...[
                const Icon(Icons.edit, size: 14, color: AppTheme.info),
                const SizedBox(width: 4),
                const Text(
                  'Customer is typing...',
                  style: TextStyle(fontSize: 11, color: AppTheme.info),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewTabs(bool isDark) {
    return Container(
      color: isDark ? AppTheme.grey800 : Colors.white,
      child: TabBar(
        controller: _viewTabController,
        tabs: const [
          Tab(text: 'Customer Messages'),
          Tab(text: 'Internal Notes'),
        ],
        labelColor: AppTheme.ownerAccent,
        unselectedLabelColor: AppTheme.grey500,
        indicatorColor: AppTheme.ownerAccent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        onTap: (index) {
          setState(() => _isInternalNote = index == 1);
        },
      ),
    );
  }

  Widget _buildMessageArea(bool isDark) {
    return Consumer<ChatProvider>(
      builder: (ctx, chatProvider, _) {
        if (chatProvider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        final allMsgs = chatProvider.messages;
        final viewIndex = _viewTabController.index;

        final msgs = viewIndex == 1
            ? allMsgs.where((m) => m.isInternalNote).toList()
            : allMsgs.where((m) => !m.isInternalNote).toList();

        // Task #69 — FAQ auto-link: check latest customer message against cache
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_faqCache.isNotEmpty && msgs.isNotEmpty) {
            final last = msgs.lastWhere(
              (m) => m.senderRole == SenderRole.customer,
              orElse: () => msgs.last,
            );
            if (last.senderRole == SenderRole.customer) {
              final match = _faqService.findMatchSync(last.text, _faqCache);
              if (match?.id != _suggestedFaq?.id) {
                setState(() => _suggestedFaq = match);
              }
            }
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        if (msgs.isEmpty) {
          return Center(
            child: Text(
              viewIndex == 1 ? 'No internal notes yet' : 'No messages yet',
              style: const TextStyle(color: AppTheme.grey400),
            ),
          );
        }

        return Column(
          children: [
            // Task #69 — Suggested FAQ banner (above messages)
            if (_suggestedFaq != null && viewIndex == 0) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: FaqArticleCard(
                  article: _suggestedFaq!,
                  accentColor: Colors.teal,
                  initiallyExpanded: false,
                  onDismiss: () => setState(() => _suggestedFaq = null),
                ),
              ),
            ],
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: msgs.length,
                itemBuilder: (context, index) {
                  final msg = msgs[index];
                  final isOwnerOrStaff =
                      msg.senderRole != SenderRole.customer && msg.senderRole != SenderRole.system;
                  return _buildMessageItem(msg, isOwnerOrStaff, isDark);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageItem(ChatMessage msg, bool isStaff, bool isDark) {
    if (msg.messageType == MessageType.systemMessage) {
      return _buildSystemMsg(msg, isDark);
    }
    if (msg.isInternalNote) {
      return _buildInternalNoteMsg(msg, isDark);
    }
    return _buildBubble(msg, isStaff, isDark);
  }

  Widget _buildSystemMsg(ChatMessage msg, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.grey800 : const Color(0xFFEDF4FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
          ),
          child: Text(
            msg.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTheme.grey300 : const Color(0xFF1A237E),
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInternalNoteMsg(ChatMessage msg, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 13, color: Color(0xFFF57F17)),
              const SizedBox(width: 5),
              Text(
                '${msg.senderName} — Internal Note',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF57F17),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('hh:mm a').format(msg.timestamp),
                style: const TextStyle(fontSize: 10, color: AppTheme.grey500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            msg.text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037), height: 1.4),
          ),
          if (msg.mentions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: msg.mentions
                  .map(
                    (m) => Chip(
                      label: Text(m, style: const TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: AppTheme.ownerAccent,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg, bool isStaff, bool isDark) {
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
        child: Column(
          crossAxisAlignment: isCustomer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
              child: Text(
                isCustomer ? msg.senderName : '${msg.senderName} (Staff)',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.grey400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCustomer
                    ? (isDark ? AppTheme.grey800 : Colors.white)
                    : AppTheme.ownerAccent,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isCustomer ? 4 : 18),
                  bottomRight: Radius.circular(isCustomer ? 18 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
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
          ],
        ),
      ),
    );
  }

  // ─── Quick actions ────────────────────────────────────────────────────────
  Widget _buildQuickActions(bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.grey800 : const Color(0xFFEEF2FF),
        border: Border(top: BorderSide(color: isDark ? AppTheme.grey700 : AppTheme.grey200)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _QuickChip(
            label: '🔖 Order Confirmed',
            onTap: () =>
                _insertQuickReply('Your order has been confirmed! We\'re preparing it now. 🎉'),
          ),
          _QuickChip(
            label: '🚚 Out for Delivery',
            onTap: () =>
                _insertQuickReply('Your order is out for delivery and will arrive shortly! 🚚'),
          ),
          _QuickChip(
            label: '✅ Delivered',
            onTap: () => _insertQuickReply(
              'Your order has been delivered successfully. Thank you for shopping with Fufaji! 🙏',
            ),
          ),
          _QuickChip(
            label: '📄 Invoice Sent',
            onTap: () =>
                _insertQuickReply('Your invoice has been shared in this chat. Please check above.'),
          ),
          _QuickChip(
            label: '⏳ Slight Delay',
            onTap: () => _insertQuickReply(
              'We\'re sorry for the slight delay in your order. It will reach you very soon!',
            ),
          ),
        ],
      ),
    );
  }

  void _insertQuickReply(String text) {
    _controller.text = text;
    _focusNode.requestFocus();
  }

  // ─── Input area ───────────────────────────────────────────────────────────
  Widget _buildInputArea(bool isDark) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Note toggle + @mention bar
            if (_isInternalNote) _buildMentionBar(isDark),
            // Mode toggle
            Container(
              color: _isInternalNote
                  ? const Color(0xFFFFF9C4)
                  : (isDark ? AppTheme.grey900 : Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      _isInternalNote = !_isInternalNote;
                      _viewTabController.animateTo(_isInternalNote ? 1 : 0);
                    }),
                    child: Row(
                      children: [
                        Icon(
                          _isInternalNote ? Icons.lock : Icons.reply,
                          size: 16,
                          color: _isInternalNote ? const Color(0xFFF57F17) : AppTheme.ownerAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isInternalNote
                              ? 'Internal Note (hidden from customer)'
                              : 'Reply to Customer',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isInternalNote ? const Color(0xFFF57F17) : AppTheme.ownerAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: _isInternalNote,
                    onChanged: (val) {
                      setState(() => _isInternalNote = val);
                      _viewTabController.animateTo(val ? 1 : 0);
                    },
                    activeColor: const Color(0xFFF57F17),
                  ),
                ],
              ),
            ),
            // Message row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isInternalNote
                            ? const Color(0xFFFFFDE7)
                            : (isDark ? AppTheme.grey800 : AppTheme.grey100),
                        borderRadius: BorderRadius.circular(24),
                        border: _isInternalNote ? Border.all(color: const Color(0xFFFFD54F)) : null,
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: 5,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.grey900,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: IconButton(
                            icon: const Icon(Icons.flash_on, color: AppTheme.ownerAccent),
                            onPressed: _showCannedResponses,
                            tooltip: 'Quick responses',
                          ),
                          hintText: _isInternalNote
                              ? 'Add internal note...'
                              : 'Reply to customer...',
                          hintStyle: const TextStyle(color: AppTheme.grey400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Consumer<ChatProvider>(
                    builder: (ctx, chatProvider, _) {
                      return GestureDetector(
                        onTap: chatProvider.isSending ? null : _sendMessage,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _isInternalNote ? const Color(0xFFF57F17) : AppTheme.ownerAccent,
                            shape: BoxShape.circle,
                          ),
                          child: chatProvider.isSending
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _isInternalNote ? Icons.lock_outline : Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentionBar(bool isDark) {
    return Container(
      height: 38,
      color: const Color(0xFFFFF9C4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text(
            'Tag:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF57F17)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _mentionOptions.map((m) {
                final isSelected = _mentions.contains(m);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _mentions.remove(m);
                    } else {
                      _mentions.add(m);
                    }
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6, top: 5, bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.ownerAccent : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.ownerAccent : AppTheme.grey300,
                      ),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppTheme.grey700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, ChatConversationModel? conv) async {
    if (conv == null) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    switch (action) {
      case 'close':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Close Ticket', style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text('Are you sure you want to close this conversation?'),
            actions: [
              TextButton(
                onPressed: () => NavigationHelper.safePopWithResult(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => NavigationHelper.safePopWithResult(context, true),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await chatProvider.closeConversation(widget.chatId);
          if (mounted) NavigationHelper.safePop(context);
        }
        break;
      case 'archive':
        // Task #67 — Archive is the same as close (status = closed), which
        // moves the conversation to the Archive tab in the chat center.
        final archiveConfirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.archive_outlined, color: AppTheme.ownerAccentGrey),
                SizedBox(width: 8),
                Text('Archive Chat'),
              ],
            ),
            content: const Text(
              'This conversation will move to the Archive tab. '
              'It can still be searched and viewed.',
            ),
            actions: [
              TextButton(
                onPressed: () => NavigationHelper.safePopWithResult(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.ownerAccentGrey),
                onPressed: () => NavigationHelper.safePopWithResult(context, true),
                child: const Text('Archive'),
              ),
            ],
          ),
        );
        if (archiveConfirmed == true) {
          await chatProvider.closeConversation(widget.chatId);
          if (mounted) NavigationHelper.safePop(context);
        }
        break;
      case 'faq':
        // Task #69 — open FAQ management sheet
        FaqManagerSheet.show(context, accentColor: AppTheme.ownerAccent);
        break;
      case 'assign':
        _showAssignDialog(chatProvider);
        break;
      case 'invoice':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice will be sent automatically after order confirmation.'),
            backgroundColor: AppTheme.info,
          ),
        );
        break;
      case 'export':
        // Task #70 — Export full chat transcript as CSV for compliance
        try {
          await ChatExportService().exportAsCsv(widget.chatId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.error),
            );
          }
        }
        break;
    }
  }

  /// Task #65: Assign-to-staff picker — sourced live from the `employees`
  /// collection (active employees only) instead of free-text entry, so
  /// assignments always map to a real, valid staff member.
  void _showAssignDialog(ChatProvider chatProvider) {
    Employee? selected;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Assign to Staff', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<List<Employee>>(
              stream: EmployeeAuthService.streamActiveEmployees(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent)),
                  );
                }
                final employees = snapshot.data!;
                if (employees.isEmpty) {
                  return const Text(
                    'No active employees found. Add staff in Employee Management first.',
                  );
                }
                return DropdownButtonFormField<Employee>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Staff Member',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: employees
                      .map(
                        (e) => DropdownMenuItem<Employee>(
                          value: e,
                          child: Text('${e.name} (${e.role.displayName})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => selected = value),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => NavigationHelper.safePop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      await chatProvider.assignConversation(
                        chatId: widget.chatId,
                        assignedToId: selected!.uid.isNotEmpty
                            ? selected!.uid
                            : selected!.employeeId,
                        assignedToName: selected!.name,
                      );
                      if (mounted) NavigationHelper.safePop(context);
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final ChatStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case ChatStatus.open:
        color = AppTheme.error;
        label = '🔴 New';
        break;
      case ChatStatus.active:
        color = AppTheme.info;
        label = '🟢 Active';
        break;
      case ChatStatus.closed:
        color = AppTheme.grey400;
        label = '⚪ Closed';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Task #68: Sentiment pill for detail screen customer-info bar ──────────────

class _SentimentPill extends StatelessWidget {
  final SentimentLabel sentiment;
  const _SentimentPill({required this.sentiment});

  Color get _color {
    switch (sentiment) {
      case SentimentLabel.positive:
        return const Color(0xFF2E7D32);
      case SentimentLabel.neutral:
        return const Color(0xFF757575);
      case SentimentLabel.negative:
        return const Color(0xFFE65100);
      case SentimentLabel.angry:
        return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(sentiment.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(
            sentiment.label,
            style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, top: 7, bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.ownerAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.ownerAccent.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.ownerAccent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
