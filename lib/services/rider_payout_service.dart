import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/rider_payout_model.dart';

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

    try {
      // 1. Get rider's linked account ID
      final riderDoc = await _firestore.collection('users').doc(riderId).get();
      if (!riderDoc.exists) throw Exception('Rider profile not found');
      
      final String? accountId = riderDoc.data()?['razorpayAccountId'];
      if (accountId == null) {
        return PayoutResult(success: false, message: 'Rider has no linked Razorpay account');
      }

      // 2. Call Secure Backend (Simulation)
      // In production, this hits a Firebase Cloud Function that uses Razorpay Node.js SDK
      final String mockTxnId = 'trn_${DateTime.now().millisecondsSinceEpoch}';
      final bool gatewaySuccess = await _callSecurePayoutFunction(
        riderAccountId: accountId,
        amount: amount,
        currency: currency,
      );

      if (gatewaySuccess) {
        final payout = RiderPayoutModel(
          id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
          riderId: riderId,
          riderName: riderName,
          amount: amount,
          currency: currency,
          status: PayoutStatus.processed,
          timestamp: DateTime.now(),
          transactionId: mockTxnId,
          type: 'instant_settlement',
        );

        // 3. Record in Ledger (Bahi Khata)
        await _firestore.collection('rider_payouts').doc(payout.id).set(payout.toMap());
        
        // 4. Update total earnings in rider profile
        await _firestore.collection('users').doc(riderId).update({
          'totalPayouts': FieldValue.increment(amount),
          'lastPayoutDate': FieldValue.serverTimestamp(),
        });

        return PayoutResult(success: true, transactionId: mockTxnId);
      } else {
        return PayoutResult(success: false, message: 'Payment gateway rejected the transfer');
      }
    } catch (e) {
      debugPrint('Rider Payout Hardening Error: $e');
      return PayoutResult(success: false, message: e.toString());
    }
  }

  Future<bool> _callSecurePayoutFunction({
    required String riderAccountId,
    required double amount,
    required String currency,
  }) async {
    try {
      final FirebaseFunctions functions = FirebaseFunctions.instance;
      final HttpsCallable callable = functions.httpsCallable('initiateRiderPayout');
      
      final HttpsCallableResult result = await callable.call({
        'riderAccountId': riderAccountId,
        'amount': amount,
        'currency': currency,
      });

      if (result.data != null && result.data['success'] == true) {
        debugPrint('RiderPayoutService: Payout function succeeded with transfer ID: ${result.data['transferId']}');
        return true;
      }
      debugPrint('RiderPayoutService: Payout function failed: ${result.data}');
      return false;
    } catch (e) {
      debugPrint('RiderPayoutService: Payout function exception: $e');
      return false;
    }
  }

  Stream<List<RiderPayoutModel>> getRiderPayoutsStream() {
    return _firestore
        .collection('rider_payouts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => RiderPayoutModel.fromMap(doc.data())).toList());
  }
}
