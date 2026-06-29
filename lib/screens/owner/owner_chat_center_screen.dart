import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/chat_conversation_model.dart';
import '../../providers/chat_provider.dart';
import '../../utils/app_theme.dart';

class OwnerChatCenterScreen extends StatefulWidget {
  const OwnerChatCenterScreen({super.key});

  @override
  State<OwnerChatCenterScreen> createState() => _OwnerChatCenterScreenState();
}

class _OwnerChatCenterScreenState extends State<OwnerChatCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Task #67 — "Closed" tab is the archive; search bar over all tabs.
  final List<String> _tabs = ['All', 'New', 'Active', 'Archive'];

  bool _searchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false)
          .listenToAllConversations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ChatConversationModel> _filterConversations(
      List<ChatConversationModel> all, String tab) {
    List<ChatConversationModel> list;
    switch (tab) {
      case 'New':
        list = all
            .where((c) =>
                c.status == ChatStatus.open && c.unreadCountOwner > 0)
            .toList();
        break;
      case 'Active':
        list = all.where((c) => c.status == ChatStatus.active).toList();
        break;
      case 'Archive':
        list = all.where((c) => c.status == ChatStatus.closed).toList();
        break;
      default:
        list = all;
    }
    // Apply search query on top of tab filter (Task #67)
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((c) =>
              c.customerName.toLowerCase().contains(q) ||
              (c.orderNumber?.toLowerCase().contains(q) ?? false) ||
              (c.orderId?.toLowerCase().contains(q) ?? false) ||
              c.lastMessage.toLowerCase().contains(q) ||
              (c.assignedToName?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.grey900 : AppTheme.grey50,
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildTabBar(isDark),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (ctx, chatProvider, _) {
                return TabBarView(
                  controller: _tabController,
                  children: _tabs.map((tab) {
                    final filtered =
                        _filterConversations(chatProvider.conversations, tab);
                    return _buildConversationList(filtered, isDark);
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
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
          padding: const EdgeInsets.fromLTRB(4, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──────────────────────────────────────────────────
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customer Conversations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Manage support & order queries',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Search toggle
                  IconButton(
                    icon: Icon(
                      _searchActive ? Icons.search_off : Icons.search,
                      color: Colors.white,
                    ),
                    tooltip: _searchActive ? 'Close search' : 'Search chats',
                    onPressed: () => setState(() {
                      _searchActive = !_searchActive;
                      if (!_searchActive) _searchCtrl.clear();
                    }),
                  ),
                  // Unread badge
                  Consumer<ChatProvider>(builder: (ctx, chatProvider, _) {
                    final newCount = chatProvider.conversations
                        .where((c) =>
                            c.status == ChatStatus.open &&
                            c.unreadCountOwner > 0)
                        .length;
                    return newCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$newCount new',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          )
                        : const SizedBox.shrink();
                  }),
                ],
              ),
              // ── Search field (Task #67) ────────────────────────────────────
              if (_searchActive)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                          'Search by name, order #, message…',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white70, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white70, size: 18),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Consumer<ChatProvider>(builder: (ctx, chatProvider, _) {
      return Container(
        color: isDark ? AppTheme.grey800 : Colors.white,
        child: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) {
            final count = _filterConversations(
                    chatProvider.conversations, tab)
                .length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab),
                  if (tab != 'All' && count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: tab == 'New'
                            ? AppTheme.error
                            : AppTheme.ownerAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          labelColor: AppTheme.ownerAccent,
          unselectedLabelColor: AppTheme.grey500,
          indicatorColor: AppTheme.ownerAccent,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
        ),
      );
    });
  }

  Widget _buildConversationList(
      List<ChatConversationModel> conversations, bool isDark) {
    if (conversations.isEmpty) {
      return _buildEmptyState(isDark);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(
          height: 1, indent: 80, endIndent: 16, color: AppTheme.grey200),
      itemBuilder: (ctx, i) =>
          _buildConversationTile(conversations[i], isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.ownerAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('💬', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations here',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.grey700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Customer chats will appear here',
            style: TextStyle(color: AppTheme.grey500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(
      ChatConversationModel conv, bool isDark) {
    final statusColor = _statusColor(conv.status);
    final statusIcon = _statusIcon(conv.status);
    final timeStr = _formatTime(conv.lastUpdated);
    final hasUnread = conv.unreadCountOwner > 0;

    return InkWell(
      onTap: () => context.push('/owner/chat/${conv.chatId}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: hasUnread
            ? AppTheme.ownerAccent.withValues(alpha: 0.04)
            : Colors.transparent,
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.ownerAccent.withValues(alpha: 0.15),
                  child: Text(
                    conv.customerName.isNotEmpty
                        ? conv.customerName[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      color: AppTheme.ownerAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isDark ? AppTheme.grey800 : Colors.white,
                          width: 2),
                    ),
                    child: Center(
                      child: Text(
                        statusIcon,
                        style: const TextStyle(fontSize: 7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.customerName,
                          style: TextStyle(
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 15,
                            color: isDark ? Colors.white : AppTheme.grey900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? AppTheme.ownerAccent
                              : AppTheme.grey400,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (conv.orderNumber != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${conv.orderNumber}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          conv.lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? (isDark ? Colors.white70 : AppTheme.grey700)
                                : AppTheme.grey500,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (conv.assignedToName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 12, color: AppTheme.grey400),
                        const SizedBox(width: 3),
                        Text(
                          'Assigned to ${conv.assignedToName}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.grey400),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Task #68 — Sentiment badge (only when data present)
            if (conv.overallSentiment != null && conv.status != ChatStatus.closed)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _SentimentBadge(sentiment: conv.overallSentiment!),
              ),
            // Unread badge
            if (hasUnread)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppTheme.ownerAccent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    conv.unreadCountOwner > 99
                        ? '99+'
                        : '${conv.unreadCountOwner}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ChatStatus status) {
    switch (status) {
      case ChatStatus.open:
        return AppTheme.error;
      case ChatStatus.active:
        return AppTheme.info;
      case ChatStatus.closed:
        return AppTheme.grey400;
    }
  }

  String _statusIcon(ChatStatus status) {
    switch (status) {
      case ChatStatus.open:
        return '🔴';
      case ChatStatus.active:
        return '🟢';
      case ChatStatus.closed:
        return '⚪';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return DateFormat('hh:mm a').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM').format(dt);
  }
}

// ── Task #68: Sentiment badge widget ─────────────────────────────────────────

class _SentimentBadge extends StatelessWidget {
  final SentimentLabel sentiment;
  const _SentimentBadge({required this.sentiment});

  Color get _color {
    switch (sentiment) {
      case SentimentLabel.positive: return const Color(0xFF2E7D32);
      case SentimentLabel.neutral:  return const Color(0xFF757575);
      case SentimentLabel.negative: return const Color(0xFFE65100);
      case SentimentLabel.angry:    return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${sentiment.label} sentiment',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: Text(
          sentiment.emoji,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}
