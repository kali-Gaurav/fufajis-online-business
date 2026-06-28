import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/rider_payout_model.dart';
import 'api_client.dart';
import '../utils/monetary_value.dart';

class PayoutResult {
  final bool success;
  final String? message;
  final String? transactionId;

  PayoutResult({required this.success, this.message, this.transactionId});
}

class RiderPayoutService {
  static final RiderPayoutService _instance = RiderPayoutService._internal();
  factory RiderPayoutService() => _instance;
  RiderPayoutService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initiates an instant payout to a rider via Razorpay Route.
  Future<PayoutResult> initiateInstantPayout({
    required String riderId,
    required String riderName,
    required double amount,
    String currency = 'INR',
  }) async {
    if (amount <= 0) {
      return PayoutResult(success: false, message: 'Invalid payout amount');
    }
    
    // 1. Payout Threshold (Step 13: ₹100 minimum)
    if (amount < 100) {
      return PayoutResult(success: false, message: 'Minimum payout amount is ₹100');
    }

    // P1-11 Idempotency Key (hourly resolution per rider to prevent double-tap payouts)
    final dateKey = DateTime.now().toIso8601String().substring(0, 13); // hourly window
    final idempotencyKey = 'payout_${riderId}_$dateKey';
    
    try {
      // Check if payout already exists for this window
      final existingDoc = await _firestore.collection('rider_payouts_idempotency').doc(idempotencyKey).get();
      if (existingDoc.exists) {
        final data = existingDoc.data()!;
        if (data['status'] == 'processed') {
          return PayoutResult(
            success: false,
            message: 'A payout has already been processed for this rider in this hour window. Idempotency enforced.',
          );
        }
      }

      // Record idempotency pending
      await _firestore.collection('rider_payouts_idempotency').doc(idempotencyKey).set({
        'riderId': riderId,
        'amount': amount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Get rider's linked account ID and bank details
      final riderDoc = await _firestore.collection('users').doc(riderId).get();
      if (!riderDoc.exists) throw Exception('Rider profile not found');

      final data = riderDoc.data()!;
      final String? accountId = data['razorpayAccountId'] as String?;
      
      // Step 14: Bank Account Validation
      if (data['bankAccountNumber'] == null || data['bankIfsc'] == null) {
        return PayoutResult(
          success: false,
          message: 'Rider bank details (Account No / IFSC) are missing or unverified.',
        );
      }

      if (accountId == null) {
        return PayoutResult(
          success: false,
          message: 'Rider has no linked Razorpay Route account ID.',
        );
      }

      // 3. Call Secure Backend
      final Map<String, dynamic>? gatewayResponse = await _callSecurePayoutFunction(
        riderAccountId: accountId,
        amount: amount,
        currency: currency,
      );

      if (gatewayResponse != null && gatewayResponse['success'] == true) {
        final String realTxnId = (gatewayResponse['transferId'] as String?) ?? 'trn_unknown';

        final payout = RiderPayoutModel(
          id: 'pay_${const Uuid().v4()}',
          riderId: riderId,
          riderName: riderName,
          amount: MonetaryValue(amount),
          currency: currency,
          status: PayoutStatus.processed,
          timestamp: DateTime.now(),
          transactionId: realTxnId,
          type: 'instant_settlement',
          branchId: 'system',
        );

        // 3. Record in Ledger (Bahi Khata)
        await _firestore
            .collection('rider_payouts')
            .doc(payout.id)
            .set(payout.toMap());

        // Mirror to AWS RDS for financial integrity
        await _syncPayoutToRDS(payout);

        // 4. Update total earnings in rider profile
        await _firestore.collection('users').doc(riderId).update({
          'totalPayouts': FieldValue.increment(amount),
          'lastPayoutDate': FieldValue.serverTimestamp(),
        });

        // Mark idempotency as processed
        await _firestore.collection('rider_payouts_idempotency').doc(idempotencyKey).update({
          'status': 'processed',
          'payoutId': payout.id,
          'processedAt': FieldValue.serverTimestamp(),
        });

        return PayoutResult(success: true, transactionId: realTxnId);
      } else {
        await _firestore.collection('rider_payouts_idempotency').doc(idempotencyKey).delete();
        return PayoutResult(
          success: false,
          message: (gatewayResponse?['error'] as String?) ?? 'Payment gateway rejected the transfer',
        );
      }
    } catch (e) {
      await _firestore.collection('rider_payouts_idempotency').doc(idempotencyKey).delete();
      debugPrint('Rider Payout Hardening Error: $e');
      return PayoutResult(success: false, message: e.toString());
    }
  }

  Future<void> _syncPayoutToRDS(RiderPayoutModel payout) async {
    // Stubbed out - pure Firestore is system of record
  }

  Future<Map<String, dynamic>?> _callSecurePayoutFunction({
    required String riderAccountId,
    required double amount,
    required String currency,
  }) async {
    try {
      final result = await ApiClient().post('/payouts/rider', {
        'riderAccountId': riderAccountId,
        'amount': amount,
        'currency': currency,
      });

      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      }
      return null;
    } catch (e) {
      debugPrint('RiderPayoutService: Payout function exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Stream<List<RiderPayoutModel>> getRiderPayoutsStream() {
    return _firestore
        .collection('rider_payouts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => RiderPayoutModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}
