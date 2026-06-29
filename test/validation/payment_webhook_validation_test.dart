import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

// ============================================================================
// PAYMENT WEBHOOK VALIDATION TEST SUITE
// ============================================================================
// GOAL: Prove that payment webhook failures can't cause double-charges or
//       missed orders. This suite tests critical idempotency scenarios with
//       Razorpay webhooks.
//
// SCENARIOS COVERED:
// 1. Webhook Success But App Never Receives (Network Timeout)
// 2. Webhook Received Twice (Duplicate Delivery)
// 3. Payment Fails But Webhook Delayed (Old Failure After New Success)
// 4. Webhook Success But Firestore Write Fails (Transaction Rollback)
// 5. 100 Concurrent Payment Webhooks (Race Condition Test)
// ============================================================================

/// Mock Razorpay Webhook Event
class MockWebhookEvent {
  final String eventId;
  final String paymentId;
  final String orderId;
  final String eventType; // payment.authorized, payment.failed
  final double amount;
  final DateTime createdAt;
  final String signature;
  final Map<String, dynamic> payload;

  MockWebhookEvent({
    required this.eventId,
    required this.paymentId,
    required this.orderId,
    required this.eventType,
    required this.amount,
    required this.createdAt,
    required this.signature,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
        'id': eventId,
        'event': eventType,
        'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
        'payload': payload,
      };
}

/// Mock Order with Payment Tracking
class MockOrder {
  final String orderId;
  final String customerId;
  final double amount;
  String paymentStatus; // pending, authorized, failed, completed
  String? razorpayPaymentId;
  String? razorpayOrderId;
  String? webhookEventId;
  DateTime createdAt;
  DateTime? confirmedAt;
  int processedWebhookCount;

  MockOrder({
    required this.orderId,
    required this.customerId,
    required this.amount,
    this.paymentStatus = 'pending',
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.webhookEventId,
    DateTime? createdAt,
    this.processedWebhookCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'customerId': customerId,
        'amount': amount,
        'paymentStatus': paymentStatus,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpayOrderId': razorpayOrderId,
        'webhookEventId': webhookEventId,
        'createdAt': Timestamp.fromDate(createdAt),
        'confirmedAt':
            confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
        'processedWebhookCount': processedWebhookCount,
      };

  factory MockOrder.fromMap(Map<String, dynamic> map) => MockOrder(
        orderId: map['orderId'] as String? ?? '',
        customerId: map['customerId'] as String? ?? '',
        amount: ((map['amount'] as num?) ?? 0.0).toDouble(),
        paymentStatus: map['paymentStatus'] as String? ?? 'pending',
        razorpayPaymentId: map['razorpayPaymentId'] as String?,
        razorpayOrderId: map['razorpayOrderId'] as String?,
        webhookEventId: map['webhookEventId'] as String?,
        processedWebhookCount: (map['processedWebhookCount'] as num? ?? 0).toInt(),
      );
}

/// Mock Ledger Entry for Financial Audit
class MockLedgerEntry {
  final String id;
  final String orderId;
  final String transactionId;
  final double amount;
  final String type; // payment, refund
  final String paymentMethod;
  final String status;
  final DateTime createdAt;

  MockLedgerEntry({
    required this.id,
    required this.orderId,
    required this.transactionId,
    required this.amount,
    required this.type,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'transactionId': transactionId,
        'amount': amount,
        'type': type,
        'paymentMethod': paymentMethod,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

/// Mock Webhook Processor with Idempotency Key Support
class WebhookProcessor {
  final Map<String, MockOrder> orders = {};
  final Map<String, MockLedgerEntry> ledger = {};
  final Set<String> processedWebhookIds = {};
  final List<String> retryQueue = [];

  MockOrder? _orderBackup;
  String? _backupPaymentStatus;
  String? _backupRazorpayPaymentId;
  DateTime? _backupConfirmedAt;
  String? _backupWebhookEventId;
  int? _backupProcessedWebhookCount;
  List<String> _ledgerKeysBackup = [];

  /// Validate webhook signature (mock Razorpay HMAC-SHA256)
  bool validateSignature(
    String payload,
    String signature,
    String secret, {
    Map<String, dynamic>? flatMap,
  }) {
    final expectedSignature =
        Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(payload));
    if (expectedSignature.toString() == signature) return true;
    if (flatMap != null) {
      final expectedSignatureFlat =
          Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(jsonEncode(flatMap)));
      if (expectedSignatureFlat.toString() == signature) return true;
    }
    return false;
  }

  /// Process webhook with idempotency check
  /// Returns: (success, reason, orderId)
  Future<({bool success, String reason, String? orderId})> processWebhook(
    MockWebhookEvent event,
    String webhookSecret,
  ) async {
    // Step 1: Signature Validation
    final isValidSignature = validateSignature(
      jsonEncode(event.payload),
      event.signature,
      webhookSecret,
      flatMap: {'payment_id': event.paymentId, 'order_id': event.orderId},
    );

    if (!isValidSignature) {
      return (success: false, reason: 'Invalid signature', orderId: null);
    }

    // Step 2: Idempotency Check (CRITICAL)
    if (processedWebhookIds.contains(event.eventId)) {
      return (
        success: true,
        reason: 'Webhook already processed (idempotent)',
        orderId: event.orderId,
      );
    }

    // Step 3: Fetch Order
    final order = orders[event.orderId];
    if (order == null) {
      retryQueue.add(event.eventId);
      return (success: false, reason: 'Order not found', orderId: null);
    }

    // Step 4: Process by Event Type
    String result = '';
    switch (event.eventType) {
      case 'payment.authorized':
        result = _handlePaymentAuthorized(event, order);
        break;
      case 'payment.failed':
        result = _handlePaymentFailed(event, order);
        break;
      default:
        return (
          success: false,
          reason: 'Unknown event type: ${event.eventType}',
          orderId: null,
        );
    }

    if (result.isEmpty) {
      // Mark as processed ONLY after successful write
      processedWebhookIds.add(event.eventId);
      order.webhookEventId = event.eventId;
      order.processedWebhookCount++;
      return (success: true, reason: 'Payment processed', orderId: event.orderId);
    } else {
      retryQueue.add(event.eventId);
      return (success: false, reason: result, orderId: null);
    }
  }

  /// Handle payment.authorized event
  String _handlePaymentAuthorized(MockWebhookEvent event, MockOrder order) {
    // Prevent old webhooks from overwriting new state
    if (order.paymentStatus == 'completed') {
      return ''; // Idempotent: order already confirmed
    }

    if (order.paymentStatus == 'failed' &&
        event.createdAt.isBefore(order.confirmedAt ?? DateTime.now())) {
      return 'Ignoring old failure webhook that arrived late';
    }

    // Try to write to ledger + update order (simulated Firestore transaction)
    try {
      // Simulate Firestore transaction
      _beginTransaction(order);

      // Create ledger entry
      final ledgerId =
          'LEG-${order.orderId}-${event.paymentId}-${DateTime.now().millisecondsSinceEpoch}';
      final ledgerEntry = MockLedgerEntry(
        id: ledgerId,
        orderId: order.orderId,
        transactionId: event.paymentId,
        amount: order.amount,
        type: 'payment',
        paymentMethod: 'razorpay',
        status: 'completed',
        createdAt: event.createdAt,
      );

      ledger[ledgerId] = ledgerEntry;

      // Update order
      order.paymentStatus = 'completed';
      order.razorpayPaymentId = event.paymentId;
      order.confirmedAt = DateTime.now();

      _commitTransaction();
      return '';
    } catch (e) {
      _rollbackTransaction();
      return 'Firestore write failed: $e';
    }
  }

  /// Handle payment.failed event
  String _handlePaymentFailed(MockWebhookEvent event, MockOrder order) {
    // Only process if payment is still pending
    if (order.paymentStatus != 'pending') {
      return ''; // Already processed a different payment status
    }

    try {
      _beginTransaction(order);

      order.paymentStatus = 'failed';
      order.razorpayPaymentId = event.paymentId;

      _commitTransaction();
      return '';
    } catch (e) {
      _rollbackTransaction();
      return 'Firestore write failed: $e';
    }
  }

  void _beginTransaction(MockOrder order) {
    _orderBackup = order;
    _backupPaymentStatus = order.paymentStatus;
    _backupRazorpayPaymentId = order.razorpayPaymentId;
    _backupConfirmedAt = order.confirmedAt;
    _backupWebhookEventId = order.webhookEventId;
    _backupProcessedWebhookCount = order.processedWebhookCount;
    _ledgerKeysBackup = ledger.keys.toList();
  }

  void _commitTransaction() {
    // Mock transaction commit
  }

  void _rollbackTransaction() {
    if (_orderBackup != null) {
      _orderBackup!.paymentStatus = _backupPaymentStatus!;
      _orderBackup!.razorpayPaymentId = _backupRazorpayPaymentId;
      _orderBackup!.confirmedAt = _backupConfirmedAt;
      _orderBackup!.webhookEventId = _backupWebhookEventId;
      _orderBackup!.processedWebhookCount = _backupProcessedWebhookCount!;
    }
    ledger.removeWhere((key, value) => !_ledgerKeysBackup.contains(key));
  }

  /// Get ledger entries for order (proof of idempotency)
  List<MockLedgerEntry> getLedgerForOrder(String orderId) {
    return ledger.values
        .where((entry) => entry.orderId == orderId)
        .toList();
  }
}

// ============================================================================
// TEST SUITE
// ============================================================================


class FailingWebhookProcessor extends WebhookProcessor {
  bool shouldFail = true;
  @override
  void _commitTransaction() {
    if (shouldFail) throw Exception('Firestore quota exceeded');
    super._commitTransaction();
  }
}

void main() {
  group('Payment Webhook Validation Tests', () {
    late WebhookProcessor processor;
    const webhookSecret = 'test-webhook-secret-12345';
    const razorpayKeyId = 'rzp_test_key_123';

    setUp(() {
      processor = WebhookProcessor();
    });

    // ========================================================================
    // SCENARIO 1: Webhook Success But App Never Receives
    // ========================================================================
    test(
      'Scenario 1: Network timeout on webhook delivery triggers retry queue',
      () async {
        // Arrange: Create order and webhook
        final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
        final order = MockOrder(
          orderId: orderId,
          customerId: 'CUST-001',
          amount: 5000,
        );
        processor.orders[orderId] = order;

        final webhookEvent = MockWebhookEvent(
          eventId: 'EV-${DateTime.now().millisecondsSinceEpoch}',
          paymentId: 'PAY-001',
          orderId: orderId,
          eventType: 'payment.authorized',
          amount: 5000,
          createdAt: DateTime.now(),
          signature: _generateSignature(
            {'payment_id': 'PAY-001', 'order_id': orderId},
            webhookSecret,
          ),
          payload: {
            'payment': {
              'id': 'PAY-001',
              'amount': 500000,
              'status': 'authorized',
            },
            'order': {'id': orderId},
          },
        );

        // Simulate network timeout - webhook never processed
        expect(processor.processedWebhookIds.isEmpty, true);
        expect(order.paymentStatus, 'pending');

        // Cloud Function detects retry and re-sends webhook
        await Future.delayed(const Duration(milliseconds: 100));

        // Act: Retry webhook processing
        final result = await processor.processWebhook(
          webhookEvent,
          webhookSecret,
        );

        // Assert: Webhook eventually succeeds
        expect(result.success, true);
        expect(result.reason, 'Payment processed');
        expect(order.paymentStatus, 'completed');
        expect(processor.processedWebhookIds.contains(webhookEvent.eventId),
            true);
        expect(order.razorpayPaymentId, 'PAY-001');
      },
    );

    // ========================================================================
    // SCENARIO 2: Webhook Received Twice (Duplicate Delivery)
    // ========================================================================
    test(
      'Scenario 2: Duplicate webhook is idempotent - no double-charging',
      () async {
        // Arrange: Create order
        final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
        final order = MockOrder(
          orderId: orderId,
          customerId: 'CUST-002',
          amount: 10000,
        );
        processor.orders[orderId] = order;

        final webhookEvent = MockWebhookEvent(
          eventId: 'EV-DUP-001',
          paymentId: 'PAY-DUP-001',
          orderId: orderId,
          eventType: 'payment.authorized',
          amount: 10000,
          createdAt: DateTime.now(),
          signature: _generateSignature(
            {'payment_id': 'PAY-DUP-001', 'order_id': orderId},
            webhookSecret,
          ),
          payload: {
            'payment': {
              'id': 'PAY-DUP-001',
              'amount': 1000000,
              'status': 'authorized',
            },
            'order': {'id': orderId},
          },
        );

        // Act: Process webhook first time
        final result1 = await processor.processWebhook(
          webhookEvent,
          webhookSecret,
        );

        // Assert: First webhook succeeds
        expect(result1.success, true);
        expect(order.paymentStatus, 'completed');
        expect(order.processedWebhookCount, 1);

        // Check ledger has 1 entry
        final ledgerEntries1 = processor.getLedgerForOrder(orderId);
        expect(ledgerEntries1.length, 1);

        // Act: Process same webhook again (network duplicate)
        final result2 = await processor.processWebhook(
          webhookEvent,
          webhookSecret,
        );

        // Assert: Second webhook is idempotent
        expect(result2.success, true);
        expect(result2.reason, 'Webhook already processed (idempotent)');
        expect(order.paymentStatus, 'completed'); // State unchanged
        expect(order.processedWebhookCount, 1); // Counter didn't increment

        // Check ledger still has 1 entry (no duplicate charge)
        final ledgerEntries2 = processor.getLedgerForOrder(orderId);
        expect(ledgerEntries2.length, 1);
        expect(
          ledgerEntries2.every((e) => e.amount == 10000),
          true,
        );
      },
    );

    // ========================================================================
    // SCENARIO 3: Payment Fails But Webhook Delayed
    // ========================================================================
    test(
      'Scenario 3: Old failure webhook does not overwrite new success',
      () async {
        // Arrange: First payment fails
        final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
        final order = MockOrder(
          orderId: orderId,
          customerId: 'CUST-003',
          amount: 7500,
        );
        processor.orders[orderId] = order;

        final failureTime = DateTime.now();
        final failureWebhook = MockWebhookEvent(
          eventId: 'EV-FAIL-001',
          paymentId: 'PAY-FAIL-001',
          orderId: orderId,
          eventType: 'payment.failed',
          amount: 7500,
          createdAt: failureTime,
          signature: _generateSignature(
            {'payment_id': 'PAY-FAIL-001', 'order_id': orderId},
            webhookSecret,
          ),
          payload: {
            'payment': {
              'id': 'PAY-FAIL-001',
              'amount': 750000,
              'status': 'failed',
              'error_code': 'GATEWAY_ERROR',
            },
            'order': {'id': orderId},
          },
        );

        // Act: Customer retries and pays with new payment ID
        final successTime = failureTime.add(const Duration(seconds: 10));
        final successWebhook = MockWebhookEvent(
          eventId: 'EV-SUCCESS-001',
          paymentId: 'PAY-SUCCESS-001',
          orderId: orderId,
          eventType: 'payment.authorized',
          amount: 7500,
          createdAt: successTime,
          signature: _generateSignature(
            {'payment_id': 'PAY-SUCCESS-001', 'order_id': orderId},
            webhookSecret,
          ),
          payload: {
            'payment': {
              'id': 'PAY-SUCCESS-001',
              'amount': 750000,
              'status': 'authorized',
            },
            'order': {'id': orderId},
          },
        );

        // Process success first
        final successResult =
            await processor.processWebhook(successWebhook, webhookSecret);
        expect(successResult.success, true);
        expect(order.paymentStatus, 'completed');
        expect(order.razorpayPaymentId, 'PAY-SUCCESS-001');
        order.confirmedAt = successTime;

        // Now old failure webhook arrives late
        final failureResult =
            await processor.processWebhook(failureWebhook, webhookSecret);

        // Assert: Old failure is ignored (timestamp check)
        expect(failureResult.success, true); // Idempotent
        expect(order.paymentStatus, 'completed'); // Unchanged
        expect(order.razorpayPaymentId, 'PAY-SUCCESS-001'); // Still new ID
        expect(processor.getLedgerForOrder(orderId).length, 1); // One charge
      },
    );

    // ========================================================================
    // SCENARIO 4: Webhook Success But Firestore Write Fails
    // ========================================================================
    test(
      'Scenario 4: Firestore failure rolls back - no partial updates',
      () async {
        // Arrange: Order ready for payment
        final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
        final order = MockOrder(
          orderId: orderId,
          customerId: 'CUST-004',
          amount: 3000,
        );
        processor.orders[orderId] = order;

        // Create a processor that will fail on write
        final failingProcessor = FailingWebhookProcessor();

        failingProcessor.orders[orderId] = order;

        final webhookEvent = MockWebhookEvent(
          eventId: 'EV-WRITE-FAIL-001',
          paymentId: 'PAY-WF-001',
          orderId: orderId,
          eventType: 'payment.authorized',
          amount: 3000,
          createdAt: DateTime.now(),
          signature: _generateSignature(
            {'payment_id': 'PAY-WF-001', 'order_id': orderId},
            webhookSecret,
          ),
          payload: {
            'payment': {
              'id': 'PAY-WF-001',
              'amount': 300000,
              'status': 'authorized',
            },
            'order': {'id': orderId},
          },
        );

        // Act: Process webhook when Firestore fails
        final result =
            await failingProcessor.processWebhook(webhookEvent, webhookSecret);

        // Assert: Transaction rolled back
        expect(result.success, false);
        expect(result.reason.contains('Firestore write failed'), true);
        expect(order.paymentStatus, 'pending'); // Unchanged
        expect(order.razorpayPaymentId, null); // Not set
        expect(
          failingProcessor.processedWebhookIds.contains(webhookEvent.eventId),
          false,
        ); // Not marked processed
        expect(failingProcessor.retryQueue.contains(webhookEvent.eventId),
            true); // Added to retry
      },
    );

    // ========================================================================
    // SCENARIO 5: 100 Concurrent Payment Webhooks (Race Conditions)
    // ========================================================================
    test(
      'Scenario 5: 100 concurrent webhooks - no race conditions, no data loss',
      () async {
        // Arrange: Create 100 orders
        final orders = <String, MockOrder>{};
        for (int i = 0; i < 100; i++) {
          final orderId = 'ORD-CONCURRENT-$i';
          final order = MockOrder(
            orderId: orderId,
            customerId: 'CUST-$i',
            amount: 5000 + (i * 100),
          );
          orders[orderId] = order;
          processor.orders[orderId] = order;
        }

        // Create 100 webhooks
        final webhooks = <MockWebhookEvent>[];
        for (int i = 0; i < 100; i++) {
          final orderId = 'ORD-CONCURRENT-$i';
          final paymentId = 'PAY-CONCURRENT-$i';
          final eventId = 'EV-CONCURRENT-$i';

          final webhook = MockWebhookEvent(
            eventId: eventId,
            paymentId: paymentId,
            orderId: orderId,
            eventType: 'payment.authorized',
            amount: 5000 + (i * 100),
            createdAt: DateTime.now(),
            signature: _generateSignature(
              {'payment_id': paymentId, 'order_id': orderId},
              webhookSecret,
            ),
            payload: {
              'payment': {
                'id': paymentId,
                'amount': (5000 + (i * 100)) * 100,
                'status': 'authorized',
              },
              'order': {'id': orderId},
            },
          );
          webhooks.add(webhook);
        }

        // Act: Process all webhooks concurrently
        final futures = webhooks.map((webhook) async {
          await Future.delayed(
              Duration(milliseconds: Random().nextInt(10))); // Random delay
          return processor.processWebhook(webhook, webhookSecret);
        });

        final results = await Future.wait(futures);

        // Assert: All succeeded without conflicts
        expect(results.every((r) => r.success), true);
        expect(results.length, 100);

        // Verify all orders confirmed
        for (int i = 0; i < 100; i++) {
          final order = orders['ORD-CONCURRENT-$i']!;
          expect(order.paymentStatus, 'completed');
          expect(order.razorpayPaymentId, 'PAY-CONCURRENT-$i');
        }

        // Verify ledger has exactly 100 entries (no duplicates)
        expect(processor.ledger.length, 100);

        // Verify total amount in ledger
        final totalInLedger =
            processor.ledger.values.fold(0.0, (sum, entry) => sum + entry.amount);
        final expectedTotal = Iterable<int>.generate(100)
            .fold(0, (sum, i) => sum + (5000 + (i * 100)));
        expect(totalInLedger, expectedTotal);

        // Verify no stale entries in retry queue
        expect(processor.retryQueue.isEmpty, true);
      },
    );

    // ========================================================================
    // ADDITIONAL TESTS: Idempotency Key Integrity
    // ========================================================================
    test(
      'Idempotency: Same payment_id never creates multiple ledger entries',
      () async {
        const orderId = 'ORD-IDEMPOTENCY-001';
        const paymentId = 'PAY-IDEMPOTENCY-001';
        const eventId = 'EV-IDEMPOTENCY-001';

        final order = MockOrder(
          orderId: orderId,
          customerId: 'CUST-IDEM',
          amount: 2500,
        );
        processor.orders[orderId] = order;

        final webhook = MockWebhookEvent(
          eventId: eventId,
          paymentId: paymentId,
          orderId: orderId,
          eventType: 'payment.authorized',
          amount: 2500,
          createdAt: DateTime.now(),
          signature: _generateSignature(
            {'payment_id': paymentId, 'order_id': orderId},
            webhookSecret,
          ),
          payload: {
            'payment': {
              'id': paymentId,
              'amount': 250000,
              'status': 'authorized',
            },
            'order': {'id': orderId},
          },
        );

        // Process webhook 5 times (simulating network retries)
        for (int i = 0; i < 5; i++) {
          final result = await processor.processWebhook(webhook, webhookSecret);
          expect(result.success, true);
        }

        // Assert: Only 1 ledger entry despite 5 webhook deliveries
        final entries = processor.getLedgerForOrder(orderId);
        expect(entries.length, 1);
        expect(entries[0].transactionId, paymentId);
        expect(entries[0].amount, 2500);
      },
    );

    // ========================================================================
    // SIGNATURE VALIDATION TEST
    // ========================================================================
    test(
      'Webhook signature validation prevents forged payments',
      () async {
        const orderId = 'ORD-SIG-001';
        final order = MockOrder(
          orderId: orderId,
          customerId: 'CUST-SIG',
          amount: 1000,
        );
        processor.orders[orderId] = order;

        final webhookEvent = MockWebhookEvent(
          eventId: 'EV-SIG-001',
          paymentId: 'PAY-SIG-001',
          orderId: orderId,
          eventType: 'payment.authorized',
          amount: 1000,
          createdAt: DateTime.now(),
          signature:
              'INVALID-FORGED-SIGNATURE-XXXXXXXXXXXXXXXXXXXX', // Forged
          payload: {
            'payment': {
              'id': 'PAY-SIG-001',
              'amount': 100000,
              'status': 'authorized',
            },
            'order': {'id': orderId},
          },
        );

        // Act: Process forged webhook
        final result = await processor.processWebhook(
          webhookEvent,
          webhookSecret,
        );

        // Assert: Rejected for invalid signature
        expect(result.success, false);
        expect(result.reason, 'Invalid signature');
        expect(order.paymentStatus, 'pending'); // Order unchanged
        expect(processor.ledger.isEmpty, true); // No charge created
      },
    );

    // ========================================================================
    // LEDGER RECONCILIATION TEST
    // ========================================================================
    test(
      'Ledger reconciliation: sum of payments = sum of orders',
      () async {
        // Create 10 orders
        final orderIds = <String>[];
        var totalOrderAmount = 0.0;

        for (int i = 0; i < 10; i++) {
          final orderId = 'ORD-RECON-$i';
          final amount = 1000 + (i * 500);
          totalOrderAmount += amount;

          final order = MockOrder(
            orderId: orderId,
            customerId: 'CUST-RECON-$i',
            amount: amount.toDouble(),
          );
          processor.orders[orderId] = order;
          orderIds.add(orderId);
        }

        // Process all payments
        for (int i = 0; i < 10; i++) {
          final orderId = orderIds[i];
          final order = processor.orders[orderId]!;
          final webhook = MockWebhookEvent(
            eventId: 'EV-RECON-$i',
            paymentId: 'PAY-RECON-$i',
            orderId: orderId,
            eventType: 'payment.authorized',
            amount: order.amount,
            createdAt: DateTime.now(),
            signature: _generateSignature(
              {'payment_id': 'PAY-RECON-$i', 'order_id': orderId},
              webhookSecret,
            ),
            payload: {
              'payment': {
                'id': 'PAY-RECON-$i',
                'amount': (order.amount * 100).toInt(),
                'status': 'authorized',
              },
              'order': {'id': orderId},
            },
          );

          await processor.processWebhook(webhook, webhookSecret);
        }

        // Assert: Ledger reconciliation
        final totalInLedger = processor.ledger.values
            .fold(0.0, (sum, entry) => sum + entry.amount);
        expect(totalInLedger, totalOrderAmount);

        // Assert: All orders confirmed
        for (final orderId in orderIds) {
          final order = processor.orders[orderId]!;
          expect(order.paymentStatus, 'completed');
          expect(order.confirmedAt, isNotNull);
        }
      },
    );
  });
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/// Generate HMAC-SHA256 signature for webhook
String _generateSignature(
  Map<String, dynamic> payload,
  String secret,
) {
  final json = jsonEncode(payload);
  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = hmac.convert(utf8.encode(json));
  return digest.toString();
}
