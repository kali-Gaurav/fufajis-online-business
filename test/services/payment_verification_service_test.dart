import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/payment_verification_service.dart';

void main() {
  group('PaymentVerificationService', () {
    group('PaymentVerificationResult', () {
      test('captured status should be recognized', () {
        final result = PaymentVerificationResult(
          isVerified: true,
          status: 'captured',
          paymentId: 'pay_123',
          orderId: 'order_456',
        );

        expect(result.isCaptured, true);
        expect(result.isPending, false);
        expect(result.hasError, false);
      });

      test('paid status should be recognized as captured', () {
        final result = PaymentVerificationResult(
          isVerified: true,
          status: 'paid',
          paymentId: 'pay_123',
          orderId: 'order_456',
        );

        expect(result.isCaptured, true);
      });

      test('pending status should be recognized', () {
        final result = PaymentVerificationResult(
          isVerified: false,
          status: 'pending',
          paymentId: 'pay_123',
          orderId: 'order_456',
        );

        expect(result.isPending, true);
        expect(result.isCaptured, false);
      });

      test('error should be detected', () {
        final result = PaymentVerificationResult(
          isVerified: false,
          status: 'error',
          paymentId: 'pay_123',
          orderId: 'order_456',
          error: 'Connection timeout',
        );

        expect(result.hasError, true);
        expect(result.error, 'Connection timeout');
      });
    });
  });
}
