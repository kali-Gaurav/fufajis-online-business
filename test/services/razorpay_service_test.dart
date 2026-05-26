import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/models/payment_result.dart';
import 'package:fufajis_online/services/razorpay_service.dart';

void main() {
  group('PaymentResult', () {
    test('success result should have correct properties', () {
      final result = PaymentResult.success(
        paymentId: 'pay_123',
        orderId: 'order_456',
        signature: 'sig_789',
      );

      expect(result.status, PaymentStatus.success);
      expect(result.paymentId, 'pay_123');
      expect(result.orderId, 'order_456');
      expect(result.signature, 'sig_789');
      expect(result.isSuccess, true);
      expect(result.isFailed, false);
      expect(result.isCancelled, false);
    });

    test('failed result should have correct properties', () {
      final result = PaymentResult.failed(
        errorCode: 'NETWORK_ERROR',
        errorMessage: 'Payment failed due to network error',
        orderId: 'order_456',
      );

      expect(result.status, PaymentStatus.failed);
      expect(result.errorCode, 'NETWORK_ERROR');
      expect(result.errorMessage, 'Payment failed due to network error');
      expect(result.isSuccess, false);
      expect(result.isFailed, true);
    });

    test('cancelled result should have correct properties', () {
      final result = PaymentResult.cancelled(orderId: 'order_456');

      expect(result.status, PaymentStatus.cancelled);
      expect(result.isCancelled, true);
      expect(result.paymentId, isNull);
    });

    test('external wallet result should have correct properties', () {
      final result = PaymentResult.externalWallet(
        walletName: 'PhonePe',
        orderId: 'order_456',
      );

      expect(result.status, PaymentStatus.externalWallet);
      expect(result.walletName, 'PhonePe');
      expect(result.isExternalWallet, true);
    });

    test('toMap should serialize correctly', () {
      final result = PaymentResult.success(
        paymentId: 'pay_123',
        orderId: 'order_456',
        signature: 'sig_789',
      );

      final map = result.toMap();
      expect(map['status'], 'PaymentStatus.success');
      expect(map['paymentId'], 'pay_123');
      expect(map['orderId'], 'order_456');
      expect(map['signature'], 'sig_789');
    });

    test('fromMap should deserialize correctly', () {
      final map = {
        'status': 'PaymentStatus.success',
        'paymentId': 'pay_123',
        'orderId': 'order_456',
        'signature': 'sig_789',
        'timestamp': '2024-01-15T10:30:00.000Z',
      };

      final result = PaymentResult.fromMap(map);
      expect(result.status, PaymentStatus.success);
      expect(result.paymentId, 'pay_123');
      expect(result.orderId, 'order_456');
    });

    test('toString should be readable', () {
      final result = PaymentResult.success(
        paymentId: 'pay_123',
        orderId: 'order_456',
      );

      expect(result.toString(), contains('PaymentStatus.success'));
      expect(result.toString(), contains('pay_123'));
    });
  });

  group('PaymentStatus', () {
    test('all statuses should be defined', () {
      expect(PaymentStatus.values, [
        PaymentStatus.success,
        PaymentStatus.failed,
        PaymentStatus.cancelled,
        PaymentStatus.externalWallet,
        PaymentStatus.unknown,
      ]);
    });
  });
}
