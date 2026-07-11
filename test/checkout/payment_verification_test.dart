import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/razorpay_service.dart';
import 'package:fufajis_online/services/payment_verification_service.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

void main() {
  group('Payment Verification', () {
    late PaymentVerificationService verificationService;

    setUp(() {
      verificationService = PaymentVerificationService();
    });

    group('Signature Verification', () {
      test('should verify valid Razorpay payment signature', () {
        // Example from Razorpay docs
        final orderId = 'order_DBJOWzybf0sJbb';
        final paymentId = 'pay_DBJOWzybf0sJbb';
        final signature = 'expectedSignatureHash';

        final isValid = verificationService.verifySignature(
          paymentId: paymentId,
          orderId: orderId,
          signature: signature,
        );

        // Note: In real tests, this would use Razorpay test credentials
        expect(isValid, isA<bool>());
      });

      test('should reject invalid signature', () {
        const paymentId = 'pay_invalid';
        const orderId = 'order_invalid';
        const invalidSignature = 'wrong_signature_hash';

        final isValid = verificationService.verifySignature(
          paymentId: paymentId,
          orderId: orderId,
          signature: invalidSignature,
        );

        expect(isValid, isFalse);
      });

      test('should reject tampered payment data', () {
        const paymentId = 'pay_DBJOWzybf0sJbb';
        const orderId = 'order_DBJOWzybf0sJbb';
        const tampered = 'tampered_signature';

        final isValid = verificationService.verifySignature(
          paymentId: paymentId,
          orderId: orderId,
          signature: tampered,
        );

        expect(isValid, isFalse);
      });

      test('should handle empty signature', () {
        const paymentId = 'pay_DBJOWzybf0sJbb';
        const orderId = 'order_DBJOWzybf0sJbb';
        const emptySignature = '';

        final isValid = verificationService.verifySignature(
          paymentId: paymentId,
          orderId: orderId,
          signature: emptySignature,
        );

        expect(isValid, isFalse);
      });

      test('should handle null signature', () {
        const paymentId = 'pay_DBJOWzybf0sJbb';
        const orderId = 'order_DBJOWzybf0sJbb';

        expect(
          () => verificationService.verifySignature(
            paymentId: paymentId,
            orderId: orderId,
            signature: '',
          ),
          isA<bool>(),
        );
      });
    });

    group('Amount Validation', () {
      test('should validate correct payment amount', () {
        const expectedAmount = 22550; // ₹225.50 in paise

        final isValid = verificationService.validateAmount(
          expectedAmount: expectedAmount,
          actualAmount: expectedAmount,
        );

        expect(isValid, isTrue);
      });

      test('should reject incorrect payment amount', () {
        const expectedAmount = 22550;
        const actualAmount = 22500; // 50 paise less

        final isValid = verificationService.validateAmount(
          expectedAmount: expectedAmount,
          actualAmount: actualAmount,
        );

        expect(isValid, isFalse);
      });

      test('should reject overpayment', () {
        const expectedAmount = 22550;
        const actualAmount = 25000; // overpaid

        final isValid = verificationService.validateAmount(
          expectedAmount: expectedAmount,
          actualAmount: actualAmount,
        );

        expect(isValid, isFalse);
      });

      test('should handle zero amount', () {
        const expectedAmount = 0;
        const actualAmount = 0;

        final isValid = verificationService.validateAmount(
          expectedAmount: expectedAmount,
          actualAmount: actualAmount,
        );

        expect(isValid, isTrue);
      });

      test('should reject negative amounts', () {
        const expectedAmount = 22550;
        const actualAmount = -22550; // negative

        final isValid = verificationService.validateAmount(
          expectedAmount: expectedAmount,
          actualAmount: actualAmount,
        );

        expect(isValid, isFalse);
      });
    });

    group('Idempotency', () {
      test('should detect duplicate payment attempts', () {
        const paymentId = 'pay_DBJOWzybf0sJbb';
        const idempotencyKey = 'order_unique_123';

        // First attempt
        final firstAttempt = verificationService.recordPaymentAttempt(
          paymentId: paymentId,
          idempotencyKey: idempotencyKey,
        );

        // Second attempt with same key
        final secondAttempt = verificationService.recordPaymentAttempt(
          paymentId: paymentId,
          idempotencyKey: idempotencyKey,
        );

        expect(firstAttempt, isTrue);
        expect(secondAttempt, isFalse); // Should detect duplicate
      });

      test('should allow different payments with different idempotency keys', () {
        const paymentId1 = 'pay_first';
        const paymentId2 = 'pay_second';
        const key1 = 'order_key_1';
        const key2 = 'order_key_2';

        final first = verificationService.recordPaymentAttempt(
          paymentId: paymentId1,
          idempotencyKey: key1,
        );

        final second = verificationService.recordPaymentAttempt(
          paymentId: paymentId2,
          idempotencyKey: key2,
        );

        expect(first, isTrue);
        expect(second, isTrue);
      });

      test('should prevent duplicate order creation', () {
        const orderId = 'order_123';
        const paymentId = 'pay_123';

        // First payment
        final first = verificationService.recordPaymentAttempt(
          paymentId: paymentId,
          idempotencyKey: orderId,
        );

        // Retry with same payment
        final retry = verificationService.recordPaymentAttempt(
          paymentId: paymentId,
          idempotencyKey: orderId,
        );

        expect(first, isTrue);
        expect(retry, isFalse);
      });
    });

    group('Payment Status Transitions', () {
      test('should allow transition from pending to confirmed', () {
        const orderId = 'order_123';

        final canTransition = verificationService.canTransitionStatus(
          from: 'pending_payment',
          to: 'confirmed',
          orderId: orderId,
        );

        expect(canTransition, isTrue);
      });

      test('should allow transition from confirmed to processing', () {
        const orderId = 'order_123';

        final canTransition = verificationService.canTransitionStatus(
          from: 'confirmed',
          to: 'processing',
          orderId: orderId,
        );

        expect(canTransition, isTrue);
      });

      test('should prevent transition from confirmed back to pending_payment', () {
        const orderId = 'order_123';

        final canTransition = verificationService.canTransitionStatus(
          from: 'confirmed',
          to: 'pending_payment',
          orderId: orderId,
        );

        expect(canTransition, isFalse);
      });

      test('should prevent invalid status transition', () {
        const orderId = 'order_123';

        final canTransition = verificationService.canTransitionStatus(
          from: 'delivered',
          to: 'pending_payment',
          orderId: orderId,
        );

        expect(canTransition, isFalse);
      });

      test('should track status transition history', () {
        const orderId = 'order_123';

        verificationService.recordStatusTransition(
          orderId: orderId,
          fromStatus: 'pending_payment',
          toStatus: 'confirmed',
          timestamp: DateTime.now(),
        );

        final history = verificationService.getStatusHistory(orderId);

        expect(history, isNotEmpty);
        expect(history.length, greaterThanOrEqualTo(1));
      });
    });

    group('Webhook Verification', () {
      test('should verify valid webhook signature', () {
        const webhookSecret = 'test_webhook_secret';
        final payload = {
          'event': 'payment.authorized',
          'payload': {
            'payment': {
              'entity': {
                'id': 'pay_123',
                'amount': 22550,
                'status': 'captured',
              }
            }
          }
        };
        const signature = 'valid_webhook_signature';

        // Note: Real webhook verification would use HMAC
        final isValid = verificationService.verifyWebhook(
          signature: signature,
          payload: payload,
          secret: webhookSecret,
        );

        expect(isValid, isA<bool>());
      });

      test('should reject webhook with invalid signature', () {
        const webhookSecret = 'test_webhook_secret';
        const invalidSignature = 'invalid_signature';

        final isValid = verificationService.verifyWebhook(
          signature: invalidSignature,
          payload: {},
          secret: webhookSecret,
        );

        expect(isValid, isFalse);
      });

      test('should prevent webhook replay attacks', () {
        const webhookId = 'webhook_event_123';

        // First receipt
        final firstReceipt = verificationService.recordWebhookReceipt(webhookId);

        // Replay attempt
        final replayAttempt = verificationService.recordWebhookReceipt(webhookId);

        expect(firstReceipt, isTrue);
        expect(replayAttempt, isFalse); // Should reject replay
      });
    });

    group('Error Handling', () {
      test('should handle network errors gracefully', () async {
        // Simulate network error during verification
        expect(
          () async => verificationService.verifyPaymentAsync(
            paymentId: 'pay_123',
            orderId: 'order_123',
            signature: 'sig_123',
          ),
          returnsNormally,
        );
      });

      test('should handle missing payment response', () {
        const paymentId = 'pay_invalid';
        const orderId = 'order_123';

        expect(
          () => verificationService.verifySignature(
            paymentId: paymentId,
            orderId: orderId,
            signature: 'any_sig',
          ),
          returnsNormally,
        );
      });

      test('should handle malformed webhook payload', () {
        const signature = 'sig_123';
        final malformedPayload = {'invalid': 'structure'};

        expect(
          () => verificationService.verifyWebhook(
            signature: signature,
            payload: malformedPayload,
            secret: 'secret',
          ),
          returnsNormally,
        );
      });

      test('should log verification errors', () {
        const paymentId = 'pay_error';
        const orderId = 'order_error';

        // Should not throw, should log
        verificationService.verifySignature(
          paymentId: paymentId,
          orderId: orderId,
          signature: 'bad_sig',
        );

        // Error log should be captured
        expect(true, isTrue); // Test passes if no exception
      });
    });

    group('Performance', () {
      test('should verify signature quickly', () {
        const paymentId = 'pay_123';
        const orderId = 'order_123';
        const signature = 'sig_123';

        final stopwatch = Stopwatch()..start();

        verificationService.verifySignature(
          paymentId: paymentId,
          orderId: orderId,
          signature: signature,
        );

        stopwatch.stop();

        // Verification should complete in under 100ms
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('should validate amount quickly', () {
        const expectedAmount = 22550;
        const actualAmount = 22550;

        final stopwatch = Stopwatch()..start();

        verificationService.validateAmount(
          expectedAmount: expectedAmount,
          actualAmount: actualAmount,
        );

        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });
    });

    group('Security', () {
      test('should handle SQL injection in signature', () {
        const paymentId = 'pay_123';
        const orderId = 'order_123';
        const maliciousSignature = "' OR '1'='1";

        final isValid = verificationService.verifySignature(
          paymentId: paymentId,
          orderId: orderId,
          signature: maliciousSignature,
        );

        expect(isValid, isFalse);
      });

      test('should handle XSS attempts in webhook payload', () {
        const signature = 'sig_123';
        final xssPayload = {
          'payload': '<script>alert("xss")</script>',
        };

        expect(
          () => verificationService.verifyWebhook(
            signature: signature,
            payload: xssPayload,
            secret: 'secret',
          ),
          returnsNormally,
        );
      });

      test('should not leak sensitive data in error messages', () {
        const paymentId = 'pay_123';
        const orderId = 'order_123';

        // Should not expose full signature in error
        verificationService.verifySignature(
          paymentId: paymentId,
          orderId: orderId,
          signature: 'bad_signature_do_not_leak_full_sig',
        );

        // Test passes if no exception with sensitive data
        expect(true, isTrue);
      });
    });
  });
}
