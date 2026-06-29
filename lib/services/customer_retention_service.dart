import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'audit_service.dart';
import 'wallet_service.dart';

class CustomerRetentionService {
  static final CustomerRetentionService _instance = CustomerRetentionService._internal();
  factory CustomerRetentionService() => _instance;
  CustomerRetentionService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WalletService _walletService = WalletService();

  // ─── CHURN PREDICTION & ANALYSIS ──────────────────────────────────

  /// Gets users who haven't ordered in [daysThreshold] days
  Future<List<Map<String, dynamic>>> getAtRiskCustomers(int daysThreshold) async {
    final thresholdDate = DateTime.now().subtract(Duration(days: daysThreshold));
    
    try {
      // In a robust implementation, we would query an aggregated 'customer_stats' collection
      // For this example, we assume users collection has a 'lastOrderAt' timestamp
      final snap = await _db.collection('users')
          .where('role', isEqualTo: 'UserRole.customer')
          .where('lastOrderAt', isLessThanOrEqualTo: Timestamp.fromDate(thresholdDate))
          .orderBy('lastOrderAt', descending: true)
          .limit(50) // Limit for UI performance
          .get();
          
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('[CustomerRetentionService] Error getting at-risk customers: $e');
      return [];
    }
  }

  /// Calculates churn risk score (0.0 to 1.0) based on recency and frequency
  double calculateChurnRisk(DateTime? lastOrderAt, int orderCount, DateTime accountCreatedAt) {
    if (lastOrderAt == null) return 0.0; // Never ordered
    
    final daysSinceLastOrder = DateTime.now().difference(lastOrderAt).inDays;
    
    if (orderCount < 2) {
      // Low engagement, high churn risk if days > 14
      return daysSinceLastOrder > 14 ? 0.8 : (daysSinceLastOrder / 14.0).clamp(0.0, 0.5);
    }
    
    // Average days between orders
    final daysSinceAccountCreation = lastOrderAt.difference(accountCreatedAt).inDays;
    if (daysSinceAccountCreation <= 0) return 0.0;
    
    final avgDaysBetweenOrders = daysSinceAccountCreation / orderCount;
    
    // If it's been more than 2x their average buying cycle, they are at risk
    final riskRatio = daysSinceLastOrder / (avgDaysBetweenOrders > 0 ? avgDaysBetweenOrders : 7.0);
    
    // Normalize to 0.0 - 1.0
    return (riskRatio / 3.0).clamp(0.0, 1.0);
  }

  // ─── AUTOMATED REACTIVATION TRIGGERS ─────────────────────────────

  /// Sends a targeted wallet top-up to dormant users to incentivize a return
  Future<void> sendReactivationIncentive({
    required String userId,
    required double amount,
    required String message,
    required String adminId,
    required String adminName,
  }) async {
    try {
      await _walletService.addToWallet(
        userId: userId,
        amount: amount,
        transactionType: WalletTransactionType.cashback,
        description: message,
      );
      
      // 2. Queue notification
      await _db.collection('notification_queue').add({
        'type': 'retention_incentive',
        'userId': userId,
        'payload': {
          'title': 'We Miss You! ₹${amount.toInt()} Free Balance 🎁',
          'body': message,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // 3. Log the audit event
      await AuditService().logAction(
        userId: adminId,
        userName: adminName,
        action: AuditAction.adminAction, // Fallback
        description: 'Sent ₹$amount reactivation incentive to customer',
        targetId: userId,
        metadata: {'amount': amount, 'type': 'retention'},
      );
      
      // 4. Update user record to prevent spamming incentives
      await _db.collection('users').doc(userId).update({
        'lastIncentiveSentAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      debugPrint('[CustomerRetentionService] Error sending incentive: $e');
      throw Exception('Failed to send reactivation incentive');
    }
  }

  /// Evaluates the effectiveness of retention campaigns by checking if
  /// incentivized users placed an order within 7 days of receiving the incentive.
  Future<Map<String, dynamic>> calculateRecoveryStats() async {
    try {
      // Find users who received incentives in the last 30 days
      final recentIncentivesSnap = await _db.collection('users')
          .where('lastIncentiveSentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))))
          .get();
          
      int totalIncentivized = recentIncentivesSnap.docs.length;
      int successfullyRecovered = 0;
      double recoveredRevenue = 0.0;
      
      for (final doc in recentIncentivesSnap.docs) {
        final data = doc.data();
        final lastOrderAt = (data['lastOrderAt'] as Timestamp?)?.toDate();
        final lastIncentiveAt = (data['lastIncentiveSentAt'] as Timestamp?)?.toDate();
        
        // If they ordered AFTER the incentive was sent, it's a recovery
        if (lastOrderAt != null && lastIncentiveAt != null && lastOrderAt.isAfter(lastIncentiveAt)) {
          successfullyRecovered++;
          
          // Fetch that specific order to get revenue
          final orderSnap = await _db.collection('orders')
              .where('customerId', isEqualTo: doc.id)
              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastIncentiveAt))
              .orderBy('createdAt', descending: false)
              .limit(1)
              .get();
              
          if (orderSnap.docs.isNotEmpty) {
            recoveredRevenue += ((orderSnap.docs.first.data()['totalAmount'] as num?) ?? 0.0).toDouble();
          }
        }
      }
      
      return {
        'totalIncentivized': totalIncentivized,
        'successfullyRecovered': successfullyRecovered,
        'recoveryRate': totalIncentivized > 0 ? (successfullyRecovered / totalIncentivized) * 100 : 0.0,
        'recoveredRevenue': recoveredRevenue,
      };
    } catch (e) {
      debugPrint('[CustomerRetentionService] Error calculating recovery stats: $e');
      return {
        'totalIncentivized': 0,
        'successfullyRecovered': 0,
        'recoveryRate': 0.0,
        'recoveredRevenue': 0.0,
      };
    }
  }
}
