import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fufajis_online/models/payment_method.dart';
import 'package:fufajis_online/services/payment_method_validator.dart';

void main() {
  group('PaymentMethod Enum Tests', () {
    test('PaymentMethod should have all required values', () {
      expect(PaymentMethod.cod, equals(PaymentMethod.cod));
      expect(PaymentMethod.upi, equals(PaymentMethod.upi));
      expect(PaymentMethod.card, equals(PaymentMethod.card));
      expect(PaymentMethod.netBanking, equals(PaymentMethod.netBanking));
      expect(PaymentMethod.wallet, equals(PaymentMethod.wallet));
      expect(PaymentMethod.razorpay, equals(PaymentMethod.razorpay));
      expect(PaymentMethod.emi, equals(PaymentMethod.emi));
      expect(PaymentMethod.payLater, equals(PaymentMethod.payLater));
    });

    test('PaymentMethod values count should be 8', () {
      expect(PaymentMethod.values.length, equals(8));
    });
  });

  group('PaymentMethodOption Tests', () {
    test('allOptions should return all payment methods', () {
      final options = PaymentMethodOption.allOptions;
      expect(options.length, equals(8));
      expect(options.map((o) => o.method).toSet().length, equals(8));
    });

    test('fromMethod should return correct option for each method', () {
      for (final method in PaymentMethod.values) {
        final option = PaymentMethodOption.fromMethod(method);
        expect(option.method, equals(method));
        expect(option.name, isNotEmpty);
        expect(option.description, isNotEmpty);
      }
    });

    test('getDisplayName should return non-empty string', () {
      for (final method in PaymentMethod.values) {
        final name = PaymentMethodOption.getDisplayName(method);
        expect(name, isNotEmpty);
      }
    });

    test('getIcon should return valid IconData', () {
      for (final method in PaymentMethod.values) {
        final icon = PaymentMethodOption.getIcon(method);
        expect(icon, isNotNull);
      }
    });

    test('getColor should return valid Color', () {
      for (final method in PaymentMethod.values) {
        final color = PaymentMethodOption.getColor(method);
        expect(color, isNotNull);
      }
    });

    test('isOnlinePayment should correctly identify online methods', () {
      expect(PaymentMethodOption.isOnlinePayment(PaymentMethod.upi), isTrue);
      expect(PaymentMethodOption.isOnlinePayment(PaymentMethod.card), isTrue);
      expect(PaymentMethodOption.isOnlinePayment(PaymentMethod.netBanking), isTrue);
      expect(PaymentMethodOption.isOnlinePayment(PaymentMethod.razorpay), isTrue);
      expect(PaymentMethodOption.isOnlinePayment(PaymentMethod.emi), isTrue);
      expect(PaymentMethodOption.isOnlinePayment(PaymentMethod.payLater), isTrue);
      expect(PaymentMethodOption.isOnlinePayment(PaymentMethod.cod), isFalse);
      expect(PaymentMethodOption.isOnlinePayment(PaymentMethod.wallet), isFalse);
    });

    test('supportsInstantRefund should correctly identify eligible methods', () {
      expect(PaymentMethodOption.supportsInstantRefund(PaymentMethod.upi), isTrue);
      expect(PaymentMethodOption.supportsInstantRefund(PaymentMethod.card), isTrue);
      expect(PaymentMethodOption.supportsInstantRefund(PaymentMethod.wallet), isTrue);
      expect(PaymentMethodOption.supportsInstantRefund(PaymentMethod.razorpay), isTrue);
      expect(PaymentMethodOption.supportsInstantRefund(PaymentMethod.cod), isFalse);
      expect(PaymentMethodOption.supportsInstantRefund(PaymentMethod.netBanking), isFalse);
    });

    test('withWalletBalance should update subLabel', () {
      final walletOption = PaymentMethodOption.fromMethod(PaymentMethod.wallet);
      final updatedOption = walletOption.withWalletBalance(500);
      expect(updatedOption.subLabel, equals('Available: ₹500'));
    });
  });

  group('PaymentMethodValidator Tests', () {
    test('validatePaymentMethod should return true for valid COD', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(PaymentMethod.cod, 1500),
        isTrue,
      );
    });

    test('validatePaymentMethod should return false for COD below minimum', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(PaymentMethod.cod, 500),
        isFalse,
      );
    });

    test('validatePaymentMethod should return false for COD above maximum', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(PaymentMethod.cod, 15000),
        isFalse,
      );
    });

    test('validatePaymentMethod should return true for valid wallet', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(
          PaymentMethod.wallet,
          1000,
          walletBalance: 500,
        ),
        isTrue,
      );
    });

    test('validatePaymentMethod should return false for wallet with zero balance', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(
          PaymentMethod.wallet,
          1000,
          walletBalance: 0,
        ),
        isFalse,
      );
    });

    test('validatePaymentMethod should return true for valid Pay Later', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(
          PaymentMethod.payLater,
          5000,
          isPayLaterEligible: true,
        ),
        isTrue,
      );
    });

    test('validatePaymentMethod should return false for Pay Later when not eligible', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(
          PaymentMethod.payLater,
          5000,
          isPayLaterEligible: false,
        ),
        isFalse,
      );
    });

    test('validatePaymentMethod should return true for valid EMI', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(PaymentMethod.emi, 5000),
        isTrue,
      );
    });

    test('validatePaymentMethod should return false for EMI below minimum', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(PaymentMethod.emi, 2000),
        isFalse,
      );
    });

    test('validatePaymentMethod should return true for online payments', () {
      expect(
        PaymentMethodValidator.validatePaymentMethod(PaymentMethod.upi, 1000),
        isTrue,
      );
      expect(
        PaymentMethodValidator.validatePaymentMethod(PaymentMethod.card, 1000),
        isTrue,
      );
      expect(
        PaymentMethodValidator.validatePaymentMethod(PaymentMethod.netBanking, 1000),
        isTrue,
      );
    });

    test('getAvailablePaymentMethods should return all methods with availability', () {
      final methods = PaymentMethodValidator.getAvailablePaymentMethods(
        2000,
        walletBalance: 500,
        isPayLaterEligible: true,
      );
      expect(methods.length, equals(8));
    });

    test('getUnavailabilityReason should return reason for unavailable COD', () {
      final reason = PaymentMethodValidator.getUnavailabilityReason(
        PaymentMethod.cod,
        500,
      );
      expect(reason, contains('Minimum order amount'));
    });

    test('calculateMaxWalletAmount should limit to 50% of order', () {
      expect(
        PaymentMethodValidator.calculateMaxWalletAmount(1000, 1000),
        equals(500),
      );
    });

    test('calculateMaxWalletAmount should not exceed wallet balance', () {
      expect(
        PaymentMethodValidator.calculateMaxWalletAmount(1000, 200),
        equals(200),
      );
    });

    test('walletCanCoverOrder should correctly identify coverage', () {
      expect(
        PaymentMethodValidator.walletCanCoverOrder(500, 1000),
        isTrue,
      );
      expect(
        PaymentMethodValidator.walletCanCoverOrder(1000, 500),
        isFalse,
      );
    });

    test('getRecommendedMethods should include COD when valid', () {
      final recommendations = PaymentMethodValidator.getRecommendedMethods(1500);
      expect(recommendations, contains(PaymentMethod.cod));
    });

    test('getRecommendedMethods should include wallet when sufficient balance', () {
      final recommendations = PaymentMethodValidator.getRecommendedMethods(
        1000,
        walletBalance: 500,
      );
      expect(recommendations, contains(PaymentMethod.wallet));
    });

    test('formatPaymentMethod should return display name', () {
      expect(
        PaymentMethodValidator.formatPaymentMethod(PaymentMethod.cod),
        equals('Cash on Delivery'),
      );
      expect(
        PaymentMethodValidator.formatPaymentMethod(PaymentMethod.upi),
        equals('UPI'),
      );
    });
  });

  group('PaymentMethodOption Serialization Tests', () {
    test('toMap and fromMap should be symmetric', () {
      final original = PaymentMethodOption.cod;
      final map = original.toMap();
      final restored = PaymentMethodOption.fromMap(map);
      expect(restored.method, equals(original.method));
      expect(restored.name, equals(original.name));
      expect(restored.description, equals(original.description));
    });
  });
}
