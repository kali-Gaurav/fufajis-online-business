import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_widgets.dart';

// In a real app, you would fetch from ApprovalService.
// For now, this is the UI shell.

class ApprovalDashboardScreen extends StatefulWidget {
  const ApprovalDashboardScreen({super.key});

  @override
  State<ApprovalDashboardScreen> createState() => _ApprovalDashboardScreenState();
}

class _ApprovalDashboardScreenState extends State<ApprovalDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Staff Approvals', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.ownerAccent,
          unselectedLabelColor: subTextColor,
          indicatorColor: AppTheme.ownerAccent,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(isDark),
          _buildApprovedList(isDark),
          _buildRejectedList(isDark),
        ],
      ),
    );
  }

  Widget _buildPendingList(bool isDark) {
    // Placeholder for actual Firestore data
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRequestCard(
          name: 'Rahul Kumar',
          role: 'Employee',
          date: 'Oct 12, 2026',
          status: 'pending',
          isDark: isDark,
        ),
        _buildRequestCard(
          name: 'Amit Singh',
          role: 'Delivery Agent',
          date: 'Oct 12, 2026',
          status: 'pending',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildApprovedList(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRequestCard(
          name: 'Suresh Verma',
          role: 'Employee',
          date: 'Oct 10, 2026',
          status: 'approved',
          loginId: 'EMP001',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildRejectedList(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRequestCard(
          name: 'Unknown User',
          role: 'Employee',
          date: 'Oct 09, 2026',
          status: 'rejected',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildRequestCard({
    required String name,
    required String role,
    required String date,
    required String status,
    String? loginId,
    required bool isDark,
  }) {
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2C) : AppTheme.grey200;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    
    final roleColor = role == 'Employee' ? AppTheme.employeeAccent : AppTheme.deliveryAccent;

    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(color: roleColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Requested: $date', style: TextStyle(color: isDark ? AppTheme.grey400 : AppTheme.grey600, fontSize: 13)),
            
            if (loginId != null) ...[
              const SizedBox(height: 4),
              Text('ID: $loginId', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],

            const SizedBox(height: 16),
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Implement Reject
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement Approve & Generate ID/PIN
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Approve', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              )
            ] else if (status == 'approved') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement Deactivate
                  },
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Deactivate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
