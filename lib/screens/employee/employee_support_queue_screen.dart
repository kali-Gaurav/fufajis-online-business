import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/chat_conversation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';

/// Task #65 — Employee Support Queue & Routing
///
/// Two-tab screen for support staff:
///   • "My Queue" — conversations already assigned to this employee
///   • "Unassigned" — open conversations with no assignee; employee can claim
///
/// Tapping any conversation tile navigates to /employee/chat/:chatId
/// (the existing EmployeeChatScreen).
class EmployeeSupportQueueScreen extends StatefulWidget {
  const EmployeeSupportQueueScreen({super.key});

  @override
  State<EmployeeSupportQueueScreen> createState() => _EmployeeSupportQueueScreenState();
}

class _EmployeeSupportQueueScreenState extends State<EmployeeSupportQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    final auth = context.read<AuthProvider>();
    final employeeId = auth.currentUser?.uid ?? '';
    if (employeeId.isEmpty) return;

    final chat = context.read<ChatProvider>();
    // Listen to assigned (My Queue) and unassigned (claimable) in parallel
    chat.listenToAssignedConversations(employeeId);
    chat.listenToUnassignedConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        title: const Text('Support Queue', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            _buildTab(label: 'My Queue', icon: Icons.inbox_outlined),
            _buildTab(label: 'Unassigned', icon: Icons.all_inbox_outlined),
          ],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_MyQueueTab(), _UnassignedTab()]),
    );
  }

  Tab _buildTab({required String label, required IconData icon}) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── My Queue Tab ─────────────────────────────────────────────────────────────

class _MyQueueTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        final assigned = chat.conversations.where((c) => c.status != ChatStatus.closed).toList();

        if (assigned.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No assigned conversations',
            subtitle: 'Pick from the Unassigned tab to get started',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: assigned.length,
          itemBuilder: (context, i) => _ConversationTile(conv: assigned[i], showClaimButton: false),
        );
      },
    );
  }
}

// ─── Unassigned Tab ───────────────────────────────────────────────────────────

class _UnassignedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        final unassigned = chat.unassignedConversations;

        if (unassigned.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline,
            title: 'Queue is clear!',
            subtitle: 'All conversations have been assigned',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: unassigned.length,
          itemBuilder: (context, i) =>
              _ConversationTile(conv: unassigned[i], showClaimButton: true),
        );
      },
    );
  }
}

// ─── Conversation Tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ChatConversationModel conv;
  final bool showClaimButton;

  const _ConversationTile({required this.conv, required this.showClaimButton});

  @override
  Widget build(BuildContext context) {
    final chat = context.read<ChatProvider>();
    final auth = context.read<AuthProvider>();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: showClaimButton
            ? null // unassigned: don't navigate; tap Claim first
            : () => context.push('/employee/chat/${conv.chatId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: const Color(0xFF6A1B9A).withOpacity(0.1),
                child: Text(
                  conv.customerName.isNotEmpty ? conv.customerName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Text(
                          _formatTime(conv.lastUpdated),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (conv.orderId != null)
                      Text(
                        'Order #${conv.orderNumber ?? conv.orderId}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      conv.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusBadge(status: conv.status),
                        const Spacer(),
                        if (conv.unreadCountOwner > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${conv.unreadCountOwner} new',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (showClaimButton) ...[
                          const SizedBox(width: 6),
                          _ClaimButton(
                            onClaim: () async {
                              final user = auth.currentUser;
                              if (user == null) return;
                              try {
                                await chat.claimConversation(
                                  chatId: conv.chatId,
                                  employeeId: user.id,
                                  employeeName: user.name ?? 'Staff',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Conversation claimed!'),
                                      backgroundColor: Color(0xFF6A1B9A),
                                    ),
                                  );
                                  // Navigate directly into the conversation
                                  context.push('/employee/chat/${conv.chatId}');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ] else ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('d MMM').format(dt);
  }
}

// ─── Claim Button ──────────────────────────────────────────────────────────────

class _ClaimButton extends StatefulWidget {
  final Future<void> Function() onClaim;

  const _ClaimButton({required this.onClaim});

  @override
  State<_ClaimButton> createState() => _ClaimButtonState();
}

class _ClaimButtonState extends State<_ClaimButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        onPressed: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                await widget.onClaim();
                if (mounted) setState(() => _loading = false);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        child: _loading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Claim'),
      ),
    );
  }
}

// ─── Status Badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ChatStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case ChatStatus.open:
        color = AppTheme.warning;
        label = '🔴 New';
        break;
      case ChatStatus.active:
        color = AppTheme.success;
        label = '🟢 Active';
        break;
      case ChatStatus.closed:
        color = Colors.grey;
        label = '⚪ Closed';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
