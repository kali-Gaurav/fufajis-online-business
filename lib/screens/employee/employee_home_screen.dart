import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/scanner_service.dart';
import '../../providers/auth_provider.dart';
import 'unified_scanner_hub.dart';
import 'inventory_receiving_screen.dart';
import 'order_packing_screen.dart';
import 'delivery_screen.dart';
import 'inventory_audit_screen.dart';
import 'damage_reporting_screen.dart';
import 'attendance_screen.dart';
import 'cash_collection_screen.dart';
import 'returns_screen.dart';
import 'shelf_refill_screen.dart';
import 'expiry_management_screen.dart';
import 'inventory_transfer_screen.dart';
import 'dispatch_scanner_screen.dart';
import 'customer_membership_scanner_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployeeHomeScreen — task-focused shift dashboard
//
// Shows: live task counts, shift status, quick scanner, full task grid.
// All counts are real-time Firestore streams scoped to this employee's branch.
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _pendingOrders = 0;
  int _assignedDeliveries = 0;
  int _lowStockAlerts = 0;
  int _pendingReturns = 0;
  bool _isCheckedIn = false;

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

    // Pending packed orders (waiting for this employee to handle)
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

    // Attendance / check-in status (today)
    final today = DateTime.now();
    final dayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    _subs.add(
      db
          .collection('attendance')
          .where('employeeId', isEqualTo: employeeId)
          .where('date', isEqualTo: dayStr)
          .limit(1)
          .snapshots()
          .listen((snap) {
        if (mounted) {
          setState(() {
            _isCheckedIn = snap.docs.isNotEmpty &&
                snap.docs.first.data()['checkInTime'] != null;
          });
        }
      }),
    );
  }

  void _openScanner({String? mode}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedScannerHub(initialMode: mode),
        fullscreenDialog: true,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final employeeName = user?.name ?? 'Employee';
    final branchName = auth.currentBranch?.name ?? 'Branch';
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Fufaji — Employee'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212121),
        elevation: 0,
        actions: [
          // Attendance quick-status dot
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _isCheckedIn ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Open Scanner Hub',
            onPressed: () => _openScanner(),
          ),
        ],
      ),
      // FAB — quick scan
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openScanner(),
        backgroundColor: const Color(0xFFFF5722),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _startStreams(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header greeting ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          const Color(0xFFFF5722).withValues(alpha: 0.12),
                      child: Text(
                        employeeName.isNotEmpty
                            ? employeeName[0].toUpperCase()
                            : 'E',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF5722),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting, $employeeName',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.store_outlined,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                branchName,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _isCheckedIn
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _isCheckedIn ? 'On Shift' : 'Not Checked In',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _isCheckedIn
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Live counters ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _CounterCard(
                      label: 'Pack',
                      value: _pendingOrders,
                      icon: Icons.inventory_outlined,
                      color: const Color(0xFF6A1B9A),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OrderPackingScreen()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CounterCard(
                      label: 'Deliver',
                      value: _assignedDeliveries,
                      icon: Icons.delivery_dining,
                      color: const Color(0xFF2E7D32),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DeliveryScreen()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CounterCard(
                      label: 'Low Stock',
                      value: _lowStockAlerts,
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFF57F17),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ShelfRefillScreen()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CounterCard(
                      label: 'Returns',
                      value: _pendingReturns,
                      icon: Icons.assignment_return_outlined,
                      color: const Color(0xFFB71C1C),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReturnsScreen()),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Scanner modes ─────────────────────────────────────────────────
              _SectionHeader(title: 'Scanner Modes'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  _QuickScanTile(
                    label: 'Product',
                    labelHi: 'उत्पाद खोज',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF1565C0),
                    onTap: () =>
                        _openScanner(mode: ScanMode.productSearch),
                  ),
                  _QuickScanTile(
                    label: 'Pack Order',
                    labelHi: 'पैकिंग',
                    icon: Icons.inventory_outlined,
                    color: const Color(0xFF6A1B9A),
                    badge: _pendingOrders,
                    onTap: () =>
                        _openScanner(mode: ScanMode.orderPacking),
                  ),
                  _QuickScanTile(
                    label: 'Dispatch',
                    labelHi: 'डिस्पैच',
                    icon: Icons.local_shipping_outlined,
                    color: const Color(0xFFE65100),
                    onTap: () =>
                        _openScanner(mode: ScanMode.dispatch),
                  ),
                  _QuickScanTile(
                    label: 'Receive',
                    labelHi: 'स्टॉक प्राप्ति',
                    icon: Icons.move_to_inbox_outlined,
                    color: const Color(0xFF00695C),
                    onTap: () =>
                        _openScanner(mode: ScanMode.inventoryReceiving),
                  ),
                  _QuickScanTile(
                    label: 'Stock Audit',
                    labelHi: 'ऑडिट',
                    icon: Icons.assignment_outlined,
                    color: const Color(0xFF558B2F),
                    onTap: () =>
                        _openScanner(mode: ScanMode.inventoryAudit),
                  ),
                  _QuickScanTile(
                    label: 'Shelf',
                    labelHi: 'शेल्फ',
                    icon: Icons.shelves,
                    color: const Color(0xFFF57F17),
                    badge: _lowStockAlerts,
                    onTap: () =>
                        _openScanner(mode: ScanMode.shelfAudit),
                  ),
                  _QuickScanTile(
                    label: 'Member',
                    labelHi: 'सदस्य',
                    icon: Icons.card_membership_outlined,
                    color: const Color(0xFFAD1457),
                    onTap: () =>
                        _openScanner(mode: ScanMode.customerMembership),
                  ),
                  _QuickScanTile(
                    label: 'Payment',
                    labelHi: 'भुगतान',
                    icon: Icons.qr_code_scanner,
                    color: const Color(0xFF4527A0),
                    onTap: () =>
                        _openScanner(mode: ScanMode.paymentQr),
                  ),
                  _QuickScanTile(
                    label: 'Attendance',
                    labelHi: 'उपस्थिति',
                    icon: Icons.fingerprint,
                    color: const Color(0xFF37474F),
                    onTap: () =>
                        _openScanner(mode: ScanMode.attendance),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Other tasks ──────────────────────────────────────────────────
              _SectionHeader(title: 'All Tasks'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _TaskRow(
                      icon: Icons.assignment_return_outlined,
                      label: 'Process Returns',
                      labelHi: 'रिटर्न',
                      badge: _pendingReturns,
                      color: Colors.red,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReturnsScreen()),
                      ),
                    ),
                    _TaskRow(
                      icon: Icons.dangerous_outlined,
                      label: 'Report Damage',
                      labelHi: 'नुकसान रिपोर्ट',
                      color: Colors.deepOrange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DamageReportingScreen()),
                      ),
                    ),
                    _TaskRow(
                      icon: Icons.event_repeat,
                      label: 'Expiry Management',
                      labelHi: 'एक्सपायरी',
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExpiryManagementScreen()),
                      ),
                    ),
                    _TaskRow(
                      icon: Icons.swap_horiz,
                      label: 'Inventory Transfer',
                      labelHi: 'ट्रांसफर',
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const InventoryTransferScreen()),
                      ),
                    ),
                    _TaskRow(
                      icon: Icons.payments_outlined,
                      label: 'Cash Collection',
                      labelHi: 'कैश',
                      color: Colors.green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CashCollectionScreen()),
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CounterCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (value > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$value',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                )
              else
                Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickScanTile extends StatelessWidget {
  final String label;
  final String labelHi;
  final IconData icon;
  final Color color;
  final int badge;
  final VoidCallback onTap;

  const _QuickScanTile({
    required this.label,
    required this.labelHi,
    required this.icon,
    required this.color,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    labelHi,
                    style:
                        const TextStyle(fontSize: 9, color: Colors.grey),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String labelHi;
  final Color color;
  final int badge;
  final VoidCallback onTap;

  const _TaskRow({
    required this.icon,
    required this.label,
    required this.labelHi,
    required this.color,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          labelHi,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: badge > 0
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              )
            : const Icon(Icons.chevron_right, color: Colors.grey),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
