import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufajis_online/services/reconciliation_service.dart';
import 'package:fufajis_online/services/rds_database_service.dart';
import 'package:fufajis_online/services/wallet_reconciliation_service.dart';

class FakeRDSDatabaseService extends RDSDatabaseService {
  FakeRDSDatabaseService() : super.forTesting();

  List<Map<String, dynamic>> mockRows = [];
  List<Map<String, dynamic>> mockQueryResult = [];
  String? lastSql;
  List<dynamic>? lastParams;

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? params,
    bool allowWrite = false,
  }) async {
    lastSql = sql;
    lastParams = params;
    return mockQueryResult;
  }

  @override
  Future<List<Map<String, dynamic>>> rows(
    String sql, {
    List<dynamic>? params,
  }) async {
    lastSql = sql;
    lastParams = params;
    return mockRows;
  }
}

class FakeWalletReconciliationService extends WalletReconciliationService {
  FakeWalletReconciliationService() : super.forTesting();

  bool systemWideResult = true;
  bool gatewayResult = true;
  bool userWalletResult = true;

  @override
  Future<bool> reconcileSystemWide() async => systemWideResult;

  @override
  Future<bool> reconcilePaymentGateway() async => gatewayResult;

  @override
  Future<bool> reconcileUserWallet(String userId) async => userWalletResult;
}

void main() {
  group('Stabilization & Reconciliation Engine Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeRDSDatabaseService fakeRds;
    late FakeWalletReconciliationService fakeWalletRecon;
    late ReconciliationService reconciliationService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeRds = FakeRDSDatabaseService();
      fakeWalletRecon = FakeWalletReconciliationService();
      fakeWalletRecon.db = fakeFirestore;

      reconciliationService = ReconciliationService();
      reconciliationService.db = fakeFirestore;
      reconciliationService.rds = fakeRds;
      reconciliationService.walletRecon = fakeWalletRecon;
    });

    test('1. Stuck Order Reconciliation - Unpaid Timeout & Delivery Sync Forward', () async {
      // Order A: Stuck unpaid for 45 minutes
      const stuckUnpaidId = 'order_stuck_unpaid';
      await fakeFirestore.collection('orders').doc(stuckUnpaidId).set({
        'status': 'placed',
        'paymentStatus': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 45))),
      });

      // Order B: Stuck in transit for 5 hours, but Postgres shows delivered
      const stuckTransitId = 'order_stuck_transit';
      await fakeFirestore.collection('orders').doc(stuckTransitId).set({
        'status': 'processing',
        'paymentStatus': 'paid',
        'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 5))),
      });

      // Postgres mock response for Order B status log
      fakeRds.mockRows = [
        {'to_status': 'delivered'}
      ];

      final res = await reconciliationService.reconcileOrders();

      expect(res['processed'], equals(2));
      expect(res['autoResolved'], equals(2));
      expect(res['anomalies'].length, equals(0));

      // Verify Order A is now cancelled
      final orderADoc = await fakeFirestore.collection('orders').doc(stuckUnpaidId).get();
      expect(orderADoc.data()?['status'], equals('cancelled'));
      expect(orderADoc.data()?['cancellationReason'], equals('payment_timeout_reconciliation'));

      // Verify Order B is now marked delivered
      final orderBDoc = await fakeFirestore.collection('orders').doc(stuckTransitId).get();
      expect(orderBDoc.data()?['status'], equals('delivered'));
    });

    test('2. Payment Reconciliation - Restores missing SQL payment ledger records', () async {
      const paymentId = 'pay_firestore_only';
      await fakeFirestore.collection('payments').doc(paymentId).set({
        'orderId': 'order_123',
        'customerId': 'user_123',
        'amount': 250.0,
        'status': 'captured',
        'method': 'razorpay',
      });

      // Postgres returns empty indicating missing ledger entry
      fakeRds.mockRows = [];

      final res = await reconciliationService.reconcilePayments();

      expect(res['processed'], equals(1));
      expect(res['syncRecovered'], equals(1));
      expect(res['anomalies'].length, equals(0));

      // Verify insert query was triggered against RDS
      expect(fakeRds.lastSql, contains('INSERT INTO payment_ledger'));
      expect(fakeRds.lastParams, contains(paymentId));
      expect(fakeRds.lastParams, contains(250.0));
    });

    test('3. Inventory Reconciliation - Stock Drift Auto-Correction', () async {
      const productId = 'prod_drift';
      await fakeFirestore.collection('products').doc(productId).set({
        'name': 'Fufaji Premium Rice',
        'stockQuantity': 100, // Firestore baseline
      });

      // Postgres inventory table says baseline is 85
      fakeRds.mockRows = [
        {'current_stock': 85}
      ];

      final res = await reconciliationService.reconcileInventory();

      expect(res['processed'], equals(1));
      expect(res['autoCorrected'], equals(1));

      // Verify Firestore stock level was corrected to match Postgres
      final prodDoc = await fakeFirestore.collection('products').doc(productId).get();
      expect(prodDoc.data()?['stockQuantity'], equals(85));
    });

    test('4. Wallet Reconciliation - Level 1/2/3 checks integration', () async {
      fakeWalletRecon.systemWideResult = true;
      fakeWalletRecon.gatewayResult = true;

      // Seed a user to check Level 1
      await fakeFirestore.collection('users').doc('user_wallet_test').set({
        'name': 'Ramesh Kumar',
      });

      final res = await reconciliationService.reconcileWallet();

      expect(res['systemWideOk'], isTrue);
      expect(res['gatewayOk'], isTrue);
      expect(res['anomalies'].length, equals(0));
    });

    test('5. Delivery Reconciliation - Missing COD ledger detection', () async {
      const orderId = 'order_cod_recon';
      
      // Seed a delivered COD order in Firestore
      await fakeFirestore.collection('orders').doc(orderId).set({
        'paymentMethod': 'cod',
        'status': 'delivered',
        'totalAmount': 500.0,
      });

      // Postgres COD settlements empty (missing collection settlement)
      fakeRds.mockRows = [];

      final res = await reconciliationService.reconcileDelivery();

      expect(res['processed'], equals(0)); // no delivery tasks seeded
      expect(res['anomalies'].length, equals(1));
      expect(res['anomalies'].first['type'], equals('COD_COLLECTION_MISSING_IN_RDS'));
    });
  });
}
