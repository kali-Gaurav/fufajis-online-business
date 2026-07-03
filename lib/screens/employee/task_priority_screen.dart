import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import 'order_packing_screen.dart';
import 'inventory_audit_screen.dart';
import 'delivery_screen.dart';
import 'returns_screen.dart';

// ============================================================================
// EMPLOYEE TASK PRIORITIZATION — Simple, Clear Task List
// ============================================================================
// Shows: Tasks in priority order (Urgent → High → Medium → Low)
// With time estimates and quick "Start Task" actions
// Real-time Firestore data + local Firestore updates
// ============================================================================

class TaskPriorityScreen extends StatefulWidget {
  const TaskPriorityScreen({super.key});

  @override
  State<TaskPriorityScreen> createState() => _TaskPriorityScreenState();
}

class _TaskPriorityScreenState extends State<TaskPriorityScreen> {
  // Task counts from Firestore
  int _pendingOrders = 0;
  int _lowStockAlerts = 0;
  int _pendingReturns = 0;
  int _assignedDeliveries = 0;

  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startStreams());
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _startStreams() {
    final auth = context.read<AuthProvider>();
    final shopId = auth.currentShop?.id ?? 'shop_001';
    final branchId = auth.currentBranch?.id ?? '';
    final employeeId = auth.currentUser?.uid ?? '';

    if (shopId.isEmpty || employeeId.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final base = db.collection('shops').doc(shopId);

    // Pending orders for packing
    _subs.add(
      base
          .collection('orders')
          .where('branchId', isEqualTo: branchId)
          .where('status', whereIn: ['confirmed', 'processing'])
          .snapshots()
          .listen((snap) {
            if (mounted) setState(() => _pendingOrders = snap.docs.length);
          }),
    );

    // Low stock alerts
    _subs.add(
      base
          .collection('branches')
          .doc(branchId)
          .collection('products')
          .where('stockQuantity', isLessThan: 10)
          .snapshots()
          .listen((snap) {
            if (mounted) setState(() => _lowStockAlerts = snap.docs.length);
          }),
    );

    // Pending returns
    _subs.add(
      base
          .collection('return_requests')
          .where('branchId', isEqualTo: branchId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snap) {
            if (mounted) setState(() => _pendingReturns = snap.docs.length);
          }),
    );

    // Assigned deliveries
    _subs.add(
      base
          .collection('orders')
          .where('assignedRiderId', isEqualTo: employeeId)
          .where('status', isEqualTo: 'dispatched')
          .snapshots()
          .listen((snap) {
            if (mounted) setState(() => _assignedDeliveries = snap.docs.length);
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Tasks'),
        elevation: 0,
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shift Summary Card
            _buildShiftSummaryCard(),
            const SizedBox(height: 24),

            // URGENT Tasks Section
            _buildTaskSection(
              priority: 'URGENT',
              color: AppTheme.error,
              tasks: [
                if (_pendingOrders > 0)
                  _buildTaskCard(
                    icon: Icons.inventory_2,
                    label: 'Pack Orders',
                    count: _pendingOrders,
                    timeEstimate: '45 min',
                    priority: 'URGENT',
                    color: AppTheme.error,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrderPackingScreen()),
                    ),
                  ),
              ],
            ),

            // HIGH Priority Tasks
            _buildTaskSection(
              priority: 'HIGH',
              color: AppTheme.warning,
              tasks: [
                if (_lowStockAlerts > 0)
                  _buildTaskCard(
                    icon: Icons.warning_amber,
                    label: 'Stock Low Items',
                    count: _lowStockAlerts,
                    timeEstimate: '30 min',
                    priority: 'HIGH',
                    color: AppTheme.warning,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InventoryAuditScreen()),
                    ),
                  ),
              ],
            ),

            // MEDIUM Priority Tasks
            _buildTaskSection(
              priority: 'MEDIUM',
              color: AppTheme.info,
              tasks: [
                if (_pendingReturns > 0)
                  _buildTaskCard(
                    icon: Icons.undo,
                    label: 'Process Returns',
                    count: _pendingReturns,
                    timeEstimate: '20 min',
                    priority: 'MEDIUM',
                    color: AppTheme.info,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReturnsScreen()),
                    ),
                  ),
              ],
            ),

            // LOW Priority Tasks
            _buildTaskSection(
              priority: 'LOW',
              color: AppTheme.success,
              tasks: [
                if (_assignedDeliveries > 0)
                  _buildTaskCard(
                    icon: Icons.delivery_dining,
                    label: 'Assigned Deliveries',
                    count: _assignedDeliveries,
                    timeEstimate: '1-2 hours',
                    priority: 'LOW',
                    color: AppTheme.success,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DeliveryScreen()),
                    ),
                  ),
              ],
            ),

            // If no tasks
            if (_pendingOrders == 0 &&
                _lowStockAlerts == 0 &&
                _pendingReturns == 0 &&
                _assignedDeliveries == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 60, color: AppTheme.success),
                      SizedBox(height: 16),
                      Text(
                        'All caught up! ✓',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.success,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('No pending tasks for now', style: TextStyle(color: AppTheme.grey600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // SHIFT SUMMARY CARD
  // ─────────────────────────────────────────────────

  Widget _buildShiftSummaryCard() {
    final totalTasks = _pendingOrders + _lowStockAlerts + _pendingReturns + _assignedDeliveries;
    final completedEstimate = _estimateTotalTime();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Shift Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Tasks',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalTasks.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Est. Duration',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      completedEstimate,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // TASK SECTION BY PRIORITY
  // ─────────────────────────────────────────────────

  Widget _buildTaskSection({
    required String priority,
    required Color color,
    required List<Widget> tasks,
  }) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                priority,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                '${tasks.length} task${tasks.length > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Task Cards
        ...tasks,
        const SizedBox(height: 20),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // TASK CARD
  // ─────────────────────────────────────────────────

  Widget _buildTaskCard({
    required IconData icon,
    required String label,
    required int count,
    required String timeEstimate,
    required String priority,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),

            // Task Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count item${count > 1 ? 's' : ''} · ~$timeEstimate',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                  ),
                ],
              ),
            ),

            // Action Button & Indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: const Text(
                    'Start',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.arrow_forward_ios, size: 14, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────

  String _estimateTotalTime() {
    int totalMinutes = 0;

    if (_pendingOrders > 0) totalMinutes += 45; // Pack orders
    if (_lowStockAlerts > 0) totalMinutes += 30; // Stock low items
    if (_pendingReturns > 0) totalMinutes += 20; // Process returns
    if (_assignedDeliveries > 0) totalMinutes += 60; // Deliveries (1 hour avg)

    if (totalMinutes == 0) return 'No tasks';

    if (totalMinutes < 60) {
      return '$totalMinutes min';
    } else {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      if (mins == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${mins}m';
      }
    }
  }
}
