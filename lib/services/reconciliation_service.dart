import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'rds_database_service.dart';
import 'notification_retry_service.dart';
import 'wallet_reconciliation_service.dart';

/// Automated 5-Subsystem Nightly and Auto-Reconciliation Engine for Fufaji.
/// Reconciles:
///  1. Orders: Stuck statuses in transit or pending payment
///  2. Payments: Mismatches between Firestore and Postgres ledgers
///  3. Inventory: Stock quantity drifts between Firestore cache and Postgres events ledger
///  4. Wallet: Balances vs Transactions ledger consistency (Level 1/2/3 checks)
///  5. Delivery: Tasks completion alignment and COD Collections settlement validation
class ReconciliationService {
  static final ReconciliationService _instance = ReconciliationService._internal();
  factory ReconciliationService() => _instance;
  ReconciliationService._internal();

  FirebaseFirestore? _customDb;
  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;
  set db(FirebaseFirestore database) => _customDb = database;

  RDSDatabaseService? _customRds;
  RDSDatabaseService get _rds => _customRds ?? RDSDatabaseService();
  set rds(RDSDatabaseService rdsService) => _customRds = rdsService;

  WalletReconciliationService? _customWalletRecon;
  WalletReconciliationService get _walletRecon =>
      _customWalletRecon ?? WalletReconciliationService();
  set walletRecon(WalletReconciliationService reconService) => _customWalletRecon = reconService;

  /// Runs the full suite of nightly reconciliations across all 5 subsystems.
  Future<Map<String, dynamic>> runFullNightlyReconciliation() async {
    final start = DateTime.now();
    final runId = 'recon_run_${start.millisecondsSinceEpoch}';
    debugPrint('[ReconciliationService] Starting nightly run: $runId');

    // Record run initialization in Firestore
    await _db.collection('reconciliation_runs').doc(runId).set({
      'id': runId,
      'status': 'in_progress',
      'startedAt': Timestamp.fromDate(start),
    });

    final results = <String, dynamic>{};
    final anomalies = <Map<String, dynamic>>[];

    try {
      // Subsystem 1: Orders
      final orderRes = await reconcileOrders();
      results['orders'] = orderRes;
      anomalies.addAll(List<Map<String, dynamic>>.from(orderRes['anomalies'] as List));

      // Subsystem 2: Payments
      final paymentRes = await reconcilePayments();
      results['payments'] = paymentRes;
      anomalies.addAll(List<Map<String, dynamic>>.from(paymentRes['anomalies'] as List));

      // Subsystem 3: Inventory
      final inventoryRes = await reconcileInventory();
      results['inventory'] = inventoryRes;
      anomalies.addAll(List<Map<String, dynamic>>.from(inventoryRes['anomalies'] as List));

      // Subsystem 4: Wallet
      final walletRes = await reconcileWallet();
      results['wallet'] = walletRes;
      anomalies.addAll(List<Map<String, dynamic>>.from(walletRes['anomalies'] as List));

      // Subsystem 5: Delivery
      final deliveryRes = await reconcileDelivery();
      results['delivery'] = deliveryRes;
      anomalies.addAll(List<Map<String, dynamic>>.from(deliveryRes['anomalies'] as List));

      final end = DateTime.now();
      final durationMs = end.difference(start).inMilliseconds;

      // Update Firestore run status
      await _db.collection('reconciliation_runs').doc(runId).set({
        'id': runId,
        'status': anomalies.isEmpty ? 'clean' : 'anomalies_detected',
        'startedAt': Timestamp.fromDate(start),
        'completedAt': Timestamp.fromDate(end),
        'durationMs': durationMs,
        'results': results,
        'totalAnomalies': anomalies.length,
      });

      // Write summary to Postgres reconciliation_logs table
      await _rds.query(
        '''
        INSERT INTO reconciliation_logs (recon_type, level, stored_amount, calculated_amount, difference, status, resolved_by)
        VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7)
        ''',
        params: [
          'nightly_recon_run',
          anomalies.isEmpty ? 1 : 2,
          1.0,
          1.0,
          anomalies.length.toDouble(),
          anomalies.isEmpty ? 'RESOLVED' : 'UNRESOLVED',
          runId,
        ],
        allowWrite: true,
      );

      // Trigger critical alerts for any high severity anomaly
      if (anomalies.isNotEmpty) {
        await NotificationRetryService().triggerAdminAlert(
          type: 'NIGHTLY_RECON_ANOMALIES',
          severity: 'high',
          title: 'Nightly Reconciliation Anomalies Detected',
          description:
              'Reconciliation run $runId finished with ${anomalies.length} unresolved discrepancies across subsystems.',
        );
      }

      return {
        'runId': runId,
        'success': true,
        'anomaliesCount': anomalies.length,
        'results': results,
        'durationMs': durationMs,
      };
    } catch (e) {
      debugPrint('[ReconciliationService] Nightly run failed: $e');
      await _db.collection('reconciliation_runs').doc(runId).set({
        'id': runId,
        'status': 'failed',
        'error': e.toString(),
        'completedAt': Timestamp.fromDate(DateTime.now()),
      });
      return {'runId': runId, 'success': false, 'error': e.toString()};
    }
  }

  /// Subsystem 1: Reconcile stuck or mismatched order statuses
  Future<Map<String, dynamic>> reconcileOrders() async {
    final anomalies = <Map<String, dynamic>>[];
    int processed = 0;
    int autoResolved = 0;

    try {
      final startCutoff = DateTime.now().subtract(const Duration(hours: 4));
      final maxUnpaidCutoff = DateTime.now().subtract(const Duration(minutes: 30));

      final ordersSnap = await _db
          .collection('orders')
          .where(
            'status',
            whereIn: [
              'pending',
              'placed',
              'confirmed',
              'processing',
              'picked_up',
              'out_for_delivery',
            ],
          )
          .get();

      for (final doc in ordersSnap.docs) {
        processed++;
        final data = doc.data();
        final orderId = doc.id;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final status = data['status'] as String? ?? 'pending';
        final paymentStatus = data['paymentStatus'] as String? ?? 'pending';

        // Case A: Stuck unpaid order beyond 30 min (abandoned checkout)
        if (paymentStatus == 'pending' &&
            createdAt.isBefore(maxUnpaidCutoff) &&
            status == 'placed') {
          await _db.collection('orders').doc(orderId).update({
            'status': 'cancelled',
            'cancellationReason': 'payment_timeout_reconciliation',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          autoResolved++;
          debugPrint('[ReconciliationService] Auto-cancelled unpaid stuck order $orderId');
          continue;
        }

        // Case B: Stuck in transit beyond 4 hours
        if (createdAt.isBefore(startCutoff)) {
          const sql =
              "SELECT to_status FROM delivery_status_logs WHERE order_id = \$1 ORDER BY created_at DESC LIMIT 1";
          final rows = await _rds.rows(sql, params: [orderId]);

          if (rows.isNotEmpty) {
            final pgStatus = rows.first['to_status'] as String?;
            if (pgStatus == 'delivered' || pgStatus == 'DELIVERED') {
              await _db.collection('orders').doc(orderId).update({
                'status': 'delivered',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              autoResolved++;
              debugPrint(
                '[ReconciliationService] Synced forward delivered status for order $orderId',
              );
              continue;
            }
          }

          final anomaly = {
            'type': 'ORDER_STUCK_IN_TRANSIT',
            'orderId': orderId,
            'status': status,
            'createdAt': createdAt.toIso8601String(),
            'description':
                'Order has been in state "$status" since ${createdAt.toIso8601String()} (>4 hours).',
          };
          anomalies.add(anomaly);
          await _logAnomaly('ORDER_STUCK', 2, orderId, 0.0, 0.0, anomaly['description']!);
        }
      }
    } catch (e) {
      debugPrint('[ReconciliationService] Error in reconcileOrders: $e');
    }

    return {'processed': processed, 'autoResolved': autoResolved, 'anomalies': anomalies};
  }

  /// Subsystem 2: Reconcile Firestore payments collection with RDS payment_ledger
  Future<Map<String, dynamic>> reconcilePayments() async {
    final anomalies = <Map<String, dynamic>>[];
    int processed = 0;
    int syncRecovered = 0;

    try {
      final paymentsSnap = await _db.collection('payments').get();

      for (final doc in paymentsSnap.docs) {
        processed++;
        final data = doc.data();
        final paymentId = doc.id;
        final orderId = data['orderId'] as String? ?? '';
        final customerId = data['customerId'] as String? ?? '';
        final amount = ((data['amount'] as num?) ?? 0.0).toDouble();
        final status = data['status'] as String? ?? 'pending';
        final method = data['method'] as String? ?? 'unknown';

        const sql = "SELECT status, amount FROM payment_ledger WHERE payment_id = \$1";
        final rows = await _rds.rows(sql, params: [paymentId]);

        if (rows.isEmpty) {
          if (status == 'captured' || status == 'success') {
            await _rds.query(
              '''
              INSERT INTO payment_ledger (payment_id, order_id, customer_id, amount, payment_method, status)
              VALUES (\$1, \$2, \$3, \$4, \$5, \$6)
              ''',
              params: [paymentId, orderId, customerId, amount, method, status],
              allowWrite: true,
            );
            syncRecovered++;
            debugPrint(
              '[ReconciliationService] Restored missing payment ledger in Postgres for $paymentId',
            );
          }
        } else {
          final pgStatus = rows.first['status'] as String?;
          final pgAmount = ((rows.first['amount'] as num?) ?? 0.0).toDouble();

          if ((pgAmount - amount).abs() > 0.01) {
            final anomaly = {
              'type': 'PAYMENT_AMOUNT_MISMATCH',
              'paymentId': paymentId,
              'firestoreAmount': amount,
              'postgresAmount': pgAmount,
              'description':
                  'Payment $paymentId amount mismatch. Firestore: $amount, Postgres: $pgAmount',
            };
            anomalies.add(anomaly);
            await _logAnomaly(
              'PAYMENT_MISMATCH',
              3,
              paymentId,
              amount,
              pgAmount,
              anomaly['description'] as String,
            );
          } else if (pgStatus != status) {
            if (pgStatus == 'success' || pgStatus == 'captured') {
              await _db.collection('payments').doc(paymentId).update({'status': pgStatus});
              syncRecovered++;
              debugPrint(
                '[ReconciliationService] Updated status mismatch in Firestore for payment $paymentId to $pgStatus',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ReconciliationService] Error in reconcilePayments: $e');
    }

    return {'processed': processed, 'syncRecovered': syncRecovered, 'anomalies': anomalies};
  }

  /// Subsystem 3: Reconcile Firestore product stock with Postgres inventory table
  Future<Map<String, dynamic>> reconcileInventory() async {
    final anomalies = <Map<String, dynamic>>[];
    int processed = 0;
    int autoCorrected = 0;

    try {
      final productsSnap = await _db.collection('products').get();

      for (final doc in productsSnap.docs) {
        processed++;
        final data = doc.data();
        final productId = doc.id;
        final name = data['name'] as String? ?? '';
        final fsStock = (data['stockQuantity'] as num? ?? 0).toInt();

        const sql = "SELECT current_stock FROM inventory WHERE product_id = \$1";
        final rows = await _rds.rows(sql, params: [productId]);

        if (rows.isNotEmpty) {
          final pgStock = (rows.first['current_stock'] as num? ?? 0).toInt();

          if (fsStock != pgStock) {
            final anomaly = {
              'type': 'INVENTORY_STOCK_DRIFT',
              'productId': productId,
              'productName': name,
              'firestoreStock': fsStock,
              'postgresStock': pgStock,
              'description':
                  'Product "$name" ($productId) stock drift: Firestore $fsStock, Postgres $pgStock',
            };
            anomalies.add(anomaly);

            await _db.collection('products').doc(productId).update({
              'stockQuantity': pgStock,
              'isAvailable': pgStock > 0,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            autoCorrected++;

            await _logAnomaly(
              'INVENTORY_DRIFT',
              2,
              productId,
              fsStock.toDouble(),
              pgStock.toDouble(),
              anomaly['description'] as String,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ReconciliationService] Error in reconcileInventory: $e');
    }

    return {'processed': processed, 'autoCorrected': autoCorrected, 'anomalies': anomalies};
  }

  /// Subsystem 4: Reconcile wallet ledger consistency
  Future<Map<String, dynamic>> reconcileWallet() async {
    final anomalies = <Map<String, dynamic>>[];
    int userMismatches = 0;
    bool systemWideOk = false;
    bool gatewayOk = false;

    try {
      systemWideOk = await _walletRecon.reconcileSystemWide();
      if (!systemWideOk) {
        anomalies.add({
          'type': 'WALLET_SYSTEM_WIDE_MISMATCH',
          'description': 'Global wallet balance sum does not match global transactions sum.',
        });
      }

      gatewayOk = await _walletRecon.reconcilePaymentGateway();
      if (!gatewayOk) {
        anomalies.add({
          'type': 'WALLET_GATEWAY_MISMATCH',
          'description':
              'Total captured payments from gateway do not match orders paid + wallet topups expectation.',
        });
      }

      final usersSnap = await _db.collection('users').limit(30).get();
      for (final doc in usersSnap.docs) {
        final userId = doc.id;
        final ok = await _walletRecon.reconcileUserWallet(userId);
        if (!ok) {
          userMismatches++;
          anomalies.add({
            'type': 'USER_WALLET_BALANCE_MISMATCH',
            'userId': userId,
            'description': 'User $userId wallet balance does not match transactions ledger sum.',
          });
        }
      }
    } catch (e) {
      debugPrint('[ReconciliationService] Error in reconcileWallet: $e');
    }

    return {
      'systemWideOk': systemWideOk,
      'gatewayOk': gatewayOk,
      'userMismatchesFound': userMismatches,
      'anomalies': anomalies,
    };
  }

  /// Subsystem 5: Reconcile delivery tasks and COD collections
  Future<Map<String, dynamic>> reconcileDelivery() async {
    final anomalies = <Map<String, dynamic>>[];
    int processed = 0;
    int resolved = 0;

    try {
      final deliveryTasksSnap = await _db
          .collection('delivery_tasks')
          .where('status', isEqualTo: 'delivered')
          .limit(50)
          .get();

      for (final doc in deliveryTasksSnap.docs) {
        processed++;
        final data = doc.data();
        final orderId = data['orderId'] as String? ?? '';

        if (orderId.isNotEmpty) {
          final orderDoc = await _db.collection('orders').doc(orderId).get();
          if (orderDoc.exists) {
            final orderStatus = orderDoc.data()?['status'] as String? ?? '';
            if (orderStatus != 'delivered' && orderStatus != 'returned') {
              await _db.collection('orders').doc(orderId).update({
                'status': 'delivered',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              resolved++;
              debugPrint(
                '[ReconciliationService] Reconciled delivery mismatch: set order $orderId to delivered.',
              );
            }
          }
        }
      }

      const sql = "SELECT order_id, amount FROM cod_settlements_rds";
      final rows = await _rds.rows(sql);
      final pgCodOrders = rows.map((r) => r['order_id'] as String).toSet();

      final codOrdersSnap = await _db
          .collection('orders')
          .where('paymentMethod', isEqualTo: 'cod')
          .where('status', isEqualTo: 'delivered')
          .limit(50)
          .get();

      for (final doc in codOrdersSnap.docs) {
        final orderId = doc.id;
        final amount = ((doc.data()['totalAmount'] as num?) ?? 0.0).toDouble();

        if (!pgCodOrders.contains(orderId)) {
          final anomaly = {
            'type': 'COD_COLLECTION_MISSING_IN_RDS',
            'orderId': orderId,
            'amount': amount,
            'description':
                'Order $orderId was delivered via COD in Firestore, but has no record in cod_settlements_rds in Postgres.',
          };
          anomalies.add(anomaly);
          await _logAnomaly(
            'COD_MISSING',
            2,
            orderId,
            amount,
            0.0,
            anomaly['description'] as String,
          );
        }
      }
    } catch (e) {
      debugPrint('[ReconciliationService] Error in reconcileDelivery: $e');
    }

    return {'processed': processed, 'resolved': resolved, 'anomalies': anomalies};
  }

  /// Helper to write anomalies to reconciliation logs and transaction integrity events
  Future<void> _logAnomaly(
    String type,
    int level,
    String? referenceId,
    double stored,
    double calculated,
    String description,
  ) async {
    try {
      await _db.collection('transaction_integrity_events').add({
        'type': type,
        'level': level,
        'referenceId': referenceId,
        'storedAmount': stored,
        'calculatedAmount': calculated,
        'difference': stored - calculated,
        'description': description,
        'status': 'UNRESOLVED',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _rds.query(
        '''
        INSERT INTO reconciliation_logs (recon_type, level, user_id, stored_amount, calculated_amount, difference, status)
        VALUES (\$1, \$2, \$3, \$4, \$5, \$6, 'UNRESOLVED')
        ''',
        params: [type, level, referenceId, stored, calculated, stored - calculated],
        allowWrite: true,
      );
    } catch (e) {
      debugPrint('[ReconciliationService] Error logging anomaly: $e');
    }
  }
}
