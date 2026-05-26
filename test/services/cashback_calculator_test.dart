import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/cashback_calculator.dart';

void main() {
  group('CashbackCalculator', () {
    late CashbackCalculator calculator;

    setUp(() {
      calculator = CashbackCalculator();
    });

    group('calculateCashback', () {
      test('should calculate 1% cashback on order amount', () {
        // 1% of ₹100 = ₹1
        expect(calculator.calculateCashback(100.0), 1.0);
        // 1% of ₹500 = ₹5
        expect(calculator.calculateCashback(500.0), 5.0);
        // 1% of ₹1000 = ₹10
        expect(calculator.calculateCashback(1000.0), 10.0);
      });

      test('should apply multiplier to cashback', () {
        // 1% of ₹100 with 1.5x multiplier = ₹1.5
        expect(calculator.calculateCashback(100.0, multiplier: 1.5), 1.5);
        // 1% of ₹500 with 2.0x multiplier = ₹10
        expect(calculator.calculateCashback(500.0, multiplier: 2.0), 10.0);
      });

      test('should handle zero amount', () {
        expect(calculator.calculateCashback(0.0), 0.0);
      });

      test('should handle large amounts', () {
        // 1% of ₹10000 = ₹100
        expect(calculator.calculateCashback(10000.0), 100.0);
      });

      test('should handle decimal amounts', () {
        // 1% of ₹99.99 = ₹0.9999
        final cashback = calculator.calculateCashback(99.99);
        expect(cashback, closeTo(0.9999, 0.0001));
      });
    });

    group('Cashback constants', () {
      test('should have correct base cashback percentage', () {
        expect(CashbackCalculator.baseCashbackPercentage, 0.01);
      });
    });

    group('Cashback calculations by tier', () {
      test('should calculate Bronze tier cashback (1%)', () {
        // Bronze: 1% cashback
        final cashback = calculator.calculateCashback(100.0, multiplier: 1.0);
        expect(cashback, 1.0);
      });

      test('should calculate Silver tier cashback (1.5%)', () {
        // Silver: 1.5% cashback
        final cashback = calculator.calculateCashback(100.0, multiplier: 1.5);
        expect(cashback, 1.5);
      });

      test('should calculate Gold tier cashback (2%)', () {
        // Gold: 2% cashback
        final cashback = calculator.calculateCashback(100.0, multiplier: 2.0);
        expect(cashback, 2.0);
      });

      test('should calculate Platinum tier cashback (3%)', () {
        // Platinum: 3% cashback
        final cashback = calculator.calculateCashback(100.0, multiplier: 3.0);
        expect(cashback, 3.0);
      });
    });

    group('Cashback for different order amounts', () {
      test('should calculate cashback for small order', () {
        // ₹100 order = ₹1 cashback
        expect(calculator.calculateCashback(100.0), 1.0);
      });

      test('should calculate cashback for medium order', () {
        // ₹500 order = ₹5 cashback
        expect(calculator.calculateCashback(500.0), 5.0);
      });

      test('should calculate cashback for large order', () {
        // ₹5000 order = ₹50 cashback
        expect(calculator.calculateCashback(5000.0), 50.0);
      });

      test('should calculate cashback for very large order', () {
        // ₹50000 order = ₹500 cashback
        expect(calculator.calculateCashback(50000.0), 500.0);
      });
    });

    group('Cashback with tier multipliers', () {
      test('should calculate total cashback for Bronze tier order', () {
        // ₹500 order, Bronze tier (1x multiplier)
        final cashback = calculator.calculateCashback(500.0, multiplier: 1.0);
        expect(cashback, 5.0);
      });

      test('should calculate total cashback for Silver tier order', () {
        // ₹500 order, Silver tier (1.5x multiplier)
        final cashback = calculator.calculateCashback(500.0, multiplier: 1.5);
        expect(cashback, 7.5);
      });

      test('should calculate total cashback for Gold tier order', () {
        // ₹500 order, Gold tier (2x multiplier)
        final cashback = calculator.calculateCashback(500.0, multiplier: 2.0);
        expect(cashback, 10.0);
      });

      test('should calculate total cashback for Platinum tier order', () {
        // ₹500 order, Platinum tier (3x multiplier)
        final cashback = calculator.calculateCashback(500.0, multiplier: 3.0);
        expect(cashback, 15.0);
      });
    });
  });
}
