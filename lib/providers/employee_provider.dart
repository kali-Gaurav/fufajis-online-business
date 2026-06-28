import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provider for employee operations
class EmployeeProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _shopId;
  final String _branchId;
  final String _employeeId;

  EmployeeProvider({
    String? shopId,
    String? branchId,
    String? employeeId,
    String? employeeName,
  })  : _shopId = shopId ?? '',
        _branchId = branchId ?? '',
        _employeeId = employeeId ?? '';

  final int _pendingTaskCount = 0;
  int get pendingTaskCount => _pendingTaskCount;

  // Inventory Alerts
  Stream<QuerySnapshot> getInventoryAlerts() {
    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_alerts')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> dismissAlert(String alertId) async {
    await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_alerts')
        .doc(alertId)
        .update({'status': 'dismissed'});
  }

  // Expiry Alerts
  Stream<QuerySnapshot> getExpiringProducts() {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('products')
        .where('expiryDate', isGreaterThan: now)
        .where('expiryDate', isLessThan: weekFromNow)
        .snapshots();
  }

  // Shelf Refill Alerts
  Stream<QuerySnapshot> getShelfRefillAlerts() {
    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('shelf_refill_alerts')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> completeShelfRefill(String alertId) async {
    await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('shelf_refill_alerts')
        .doc(alertId)
        .update({'status': 'completed'});
  }

  // Damage Reports
  Stream<QuerySnapshot> getDamageReports() {
    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('damage_reports')
        .orderBy('reportDate', descending: true)
        .limit(20)
        .snapshots();
  }

  // Returns
  Stream<QuerySnapshot> getReturns() {
    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('returns')
        .orderBy('returnDate', descending: true)
        .limit(20)
        .snapshots();
  }

  // Cash Collections
  Stream<QuerySnapshot> getCashCollections() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('cash_collections')
        .where('collectionTime', isGreaterThan: startOfDay)
        .snapshots();
  }

  double getTodayTotalCollection(List<QueryDocumentSnapshot> docs) {
    return docs.fold(0.0, (total, doc) => total + (doc['amount'] as num).toDouble());
  }

  // Attendance
  Stream<QuerySnapshot> getAttendanceHistory({int days = 7}) {
    final startDate = DateTime.now().subtract(Duration(days: days));

    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('attendance')
        .where('employeeId', isEqualTo: _employeeId)
        .where('date', isGreaterThan: startDate)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Inventory Transfers
  Stream<QuerySnapshot> getPendingTransfers() {
    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_transfers')
        .where('status',
            whereIn: ['pending', 'shipped', 'inTransit']).snapshots();
  }

  // Audit History
  Stream<QuerySnapshot> getAuditHistory() {
    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_audits')
        .orderBy('auditDate', descending: true)
        .limit(50)
        .snapshots();
  }

  // Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    final stats = <String, dynamic>{};

    // Today's collections
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final collections = await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('cash_collections')
        .where('collectionTime', isGreaterThan: startOfDay)
        .get();

    stats['todayCollections'] = collections.docs
        .fold(0.0, (total, doc) => total + (doc['amount'] as num).toDouble());
    stats['collectionCount'] = collections.docs.length;

    // Pending deliveries
    final deliveries = await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('orders')
        .where('deliveryEmployeeId', isEqualTo: _employeeId)
        .where('status', whereIn: ['assigned', 'out_for_delivery']).get();

    stats['pendingDeliveries'] = deliveries.docs.length;

    // Pending alerts
    final alerts = await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_alerts')
        .where('status', isEqualTo: 'pending')
        .get();

    stats['pendingAlerts'] = alerts.docs.length;

    return stats;
  }
}
