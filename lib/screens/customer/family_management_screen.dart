import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/family_group_model.dart';
import '../../services/family_account_service.dart';

/// Full family management screen with create/join, member list, shared cart, approvals,
/// spending dashboards, and settings — production-grade for Fufaji households.
class FamilyManagementScreen extends StatefulWidget {
  const FamilyManagementScreen({super.key});

  @override
  State<FamilyManagementScreen> createState() => _FamilyManagementScreenState();
}

class _FamilyManagementScreenState extends State<FamilyManagementScreen>
    with SingleTickerProviderStateMixin {
  final FamilyAccountService _familyService = FamilyAccountService();
  late TabController _tabController;
  FamilyGroup? _familyGroup;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFamilyGroup();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyGroup() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      final group = await _familyService.getFamilyGroupForUser(userId);
      setState(() {
        _familyGroup = group;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Account')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Family Account')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFamilyGroup,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_familyGroup == null) {
      return _buildCreateFamilyScreen();
    }

    return _buildFamilyDashboard();
  }

  // ===== NO FAMILY — CREATE SCREEN =====
  Widget _buildCreateFamilyScreen() {
    final nameController = TextEditingController();
    final budgetController = TextEditingController(text: '10000');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Family Account'),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      backgroundColor: const Color(0xFF0F0F1A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3F3D9E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.family_restroom, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Shop Together as a Family',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a shared household cart, set spending limits for kids, and manage family grocery orders together.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Features List
            _buildFeatureRow(Icons.shopping_cart, 'Shared Family Cart', 'Everyone adds items, checkout together'),
            _buildFeatureRow(Icons.approval, 'Parental Approval', 'Kids need approval to place orders'),
            _buildFeatureRow(Icons.account_balance_wallet, 'Spending Limits', 'Set monthly budgets per member'),
            _buildFeatureRow(Icons.analytics, 'Family Analytics', 'Track who spends what'),

            const SizedBox(height: 32),

            // Create Form
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Family Name',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                hintText: 'e.g., Nagar Family',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: const Icon(Icons.home, color: Color(0xFF6C63FF)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Monthly Budget (₹)',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                hintText: 'Leave 0 for unlimited',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF6C63FF)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a family name')),
                    );
                    return;
                  }
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  try {
                    await _familyService.createFamilyGroup(
                      ownerUserId: user.uid,
                      ownerName: user.displayName ?? 'Owner',
                      ownerPhone: user.phoneNumber ?? '',
                      familyName: nameController.text.trim(),
                      monthlyBudget: double.tryParse(budgetController.text) ?? 0.0,
                    );
                    _loadFamilyGroup();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Create Family Group',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== FAMILY DASHBOARD =====
  Widget _buildFamilyDashboard() {
    final group = _familyGroup!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: Text(group.familyName),
        backgroundColor: const Color(0xFF1A1A2E),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Members'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Cart'),
            Tab(icon: Icon(Icons.approval), text: 'Approvals'),
            Tab(icon: Icon(Icons.analytics), text: 'Budget'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembersTab(group),
          _buildSharedCartTab(group),
          _buildApprovalsTab(group),
          _buildBudgetTab(group),
        ],
      ),
    );
  }

  // ===== MEMBERS TAB =====
  Widget _buildMembersTab(FamilyGroup group) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final currentMember = group.members.cast<FamilyMember?>().firstWhere(
      (m) => m?.userId == currentUserId,
      orElse: () => null,
    );

    return RefreshIndicator(
      onRefresh: _loadFamilyGroup,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Family stats card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D2B55), Color(0xFF1A1A2E)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Members', '${group.activeMemberCount}', Icons.people),
                _buildStatItem(
                  'Budget',
                  group.monthlyBudget > 0
                      ? '₹${group.monthlyBudget.toStringAsFixed(0)}'
                      : '∞',
                  Icons.account_balance_wallet,
                ),
                _buildStatItem(
                  'Spent',
                  '₹${group.currentMonthSpending.toStringAsFixed(0)}',
                  Icons.trending_up,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Member List
          ...group.members.map((member) => _buildMemberCard(member, currentMember)),

          // Add Member Button
          if (currentMember?.hasPermission(FamilyPermission.manageMembers) == true)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: () => _showAddMemberDialog(group),
                icon: const Icon(Icons.person_add, color: Color(0xFF6C63FF)),
                label: const Text('Add Family Member', style: TextStyle(color: Color(0xFF6C63FF))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6C63FF), size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      ],
    );
  }

  Widget _buildMemberCard(FamilyMember member, FamilyMember? currentMember) {
    final roleColors = {
      FamilyRole.owner: const Color(0xFFFFD700),
      FamilyRole.parent: const Color(0xFF6C63FF),
      FamilyRole.adult: const Color(0xFF4ECDC4),
      FamilyRole.child: const Color(0xFFFF6B6B),
      FamilyRole.guest: const Color(0xFF95A5A6),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: roleColors[member.role]!.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColors[member.role]!.withValues(alpha: 0.2),
            child: Text(
              member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: roleColors[member.role],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColors[member.role]!.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        member.role.name.toUpperCase(),
                        style: TextStyle(
                          color: roleColors[member.role],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  member.monthlySpendingLimit > 0
                      ? 'Budget: ₹${member.currentMonthSpending.toStringAsFixed(0)} / ₹${member.monthlySpendingLimit.toStringAsFixed(0)}'
                      : 'Unlimited budget',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                if (member.monthlySpendingLimit > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (member.currentMonthSpending / member.monthlySpendingLimit).clamp(0, 1),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(
                        member.currentMonthSpending > member.monthlySpendingLimit * 0.9
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF6C63FF),
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (currentMember?.hasPermission(FamilyPermission.setSpendingLimits) == true &&
              member.role != FamilyRole.owner)
            IconButton(
              onPressed: () => _showMemberSettingsDialog(member),
              icon: Icon(
                Icons.settings,
                color: Colors.white.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  // ===== SHARED CART TAB =====
  Widget _buildSharedCartTab(FamilyGroup group) {
    if (group.sharedCart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'Family cart is empty',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Items added by family members will appear here',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cart total header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF3F3D9E)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Family Cart Total', style: TextStyle(color: Colors.white, fontSize: 16)),
              Text(
                '₹${group.sharedCartTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Cart items
        ...group.sharedCart.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Added by ${item.addedByName} • Qty: ${item.quantity}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    ),
                    if (item.note != null)
                      Text(
                        '📝 ${item.note}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                      ),
                  ],
                ),
              ),
              Text(
                '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        )),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to checkout with shared cart items
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proceeding to checkout with family cart...')),
              );
            },
            icon: const Icon(Icons.payment, color: Colors.white),
            label: const Text(
              'Checkout Family Cart',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // ===== APPROVALS TAB =====
  Widget _buildApprovalsTab(FamilyGroup group) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final currentMember = group.members.cast<FamilyMember?>().firstWhere(
      (m) => m?.userId == currentUserId,
      orElse: () => null,
    );

    if (group.pendingApprovals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No pending approvals',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: group.pendingApprovals.length,
      itemBuilder: (context, index) {
        final approval = group.pendingApprovals[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: approval.isPending
                  ? const Color(0xFFFFD93D).withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pending_actions, color: Color(0xFFFFD93D), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${approval.requestedByName} wants to order',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '₹${approval.orderAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: approval.itemNames.map((name) => Chip(
                  label: Text(name, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  backgroundColor: const Color(0xFF2D2B55),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              if (approval.isPending &&
                  currentMember?.hasPermission(FamilyPermission.approveChildOrders) == true) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await _familyService.resolveApproval(
                            familyId: group.id,
                            approvalId: approval.id,
                            resolverUserId: currentUserId!,
                            approved: false,
                            rejectionReason: 'Not needed right now',
                          );
                          _loadFamilyGroup();
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF6B6B)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Reject', style: TextStyle(color: Color(0xFFFF6B6B))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _familyService.resolveApproval(
                            familyId: group.id,
                            approvalId: approval.id,
                            resolverUserId: currentUserId!,
                            approved: true,
                          );
                          _loadFamilyGroup();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECDC4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Approve', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ===== BUDGET TAB =====
  Widget _buildBudgetTab(FamilyGroup group) {
    final budgetUsed = group.monthlyBudget > 0
        ? (group.currentMonthSpending / group.monthlyBudget).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Budget ring
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: budgetUsed,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(
                          budgetUsed > 0.9
                              ? const Color(0xFFFF6B6B)
                              : budgetUsed > 0.7
                                  ? const Color(0xFFFFD93D)
                                  : const Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '₹${group.currentMonthSpending.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          group.monthlyBudget > 0
                              ? 'of ₹${group.monthlyBudget.toStringAsFixed(0)}'
                              : 'This Month',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Monthly Family Spending',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Per-member breakdown
        const Text(
          'Member Breakdown',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...group.members.map((m) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                child: Text(
                  m.name.isNotEmpty ? m.name[0] : '?',
                  style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    Text(
                      m.role.name,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${m.currentMonthSpending.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // ===== DIALOGS =====
  void _showAddMemberDialog(FamilyGroup group) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final limitController = TextEditingController(text: '0');
    FamilyRole selectedRole = FamilyRole.adult;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Add Family Member', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FamilyRole>(
                  initialValue: selectedRole,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: [FamilyRole.parent, FamilyRole.adult, FamilyRole.child, FamilyRole.guest]
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.name.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Monthly Limit (₹0 = unlimited)',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                Navigator.pop(context);

                try {
                  // For demo, we use phone as userId lookup
                  final newUserId = 'user_${phoneController.text.replaceAll('+', '').replaceAll(' ', '')}';
                  await _familyService.addMember(
                    familyId: group.id,
                    requestingUserId: user.uid,
                    newUserId: newUserId,
                    newUserName: nameController.text,
                    newUserPhone: phoneController.text,
                    role: selectedRole,
                    monthlySpendingLimit: double.tryParse(limitController.text) ?? 0.0,
                  );
                  _loadFamilyGroup();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberSettingsDialog(FamilyMember member) {
    final limitController = TextEditingController(
      text: member.monthlySpendingLimit.toStringAsFixed(0),
    );
    FamilyRole selectedRole = member.role;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text('Edit ${member.name}', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<FamilyRole>(
                initialValue: selectedRole,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Role',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                items: [FamilyRole.parent, FamilyRole.adult, FamilyRole.child, FamilyRole.guest]
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.name.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Monthly Spending Limit (₹)',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                Navigator.pop(context);

                try {
                  await _familyService.updateMemberSettings(
                    familyId: _familyGroup!.id,
                    requestingUserId: user.uid,
                    targetUserId: member.userId,
                    newRole: selectedRole,
                    monthlySpendingLimit: double.tryParse(limitController.text) ?? 0.0,
                  );
                  _loadFamilyGroup();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
