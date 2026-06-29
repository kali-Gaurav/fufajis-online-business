import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/utils/monetary_value.dart';

void main() {
  group('MonetaryValue Tests', () {
    test('Construction from various types', () {
      expect(MonetaryValue(99.99).toDouble(), 99.99);
      expect(MonetaryValue(100).toDouble(), 100.0);
      expect(MonetaryValue('99.99').toDouble(), 99.99);
    });

    test('No rounding errors on multiplication', () {
      // This is the classic case that breaks with double
      final result = MonetaryValue(99.99) * 3;
      expect(result.toDouble(), 299.97);
      
      // Verify it's not the broken 299.96999999999997
      expect(result.toFormattedString(), '299.97');
    });

    test('Arithmetic operations', () {
      final a = 100.inr;
      final b = 50.inr;
      
      expect((a + b).toDouble(), 150.0);
      expect((a - b).toDouble(), 50.0);
      expect((a * 2).toDouble(), 200.0);
      expect((a / 2).toDouble(), 50.0);
    });

    test('Comparisons', () {
      final a = 100.inr;
      final b = 50.inr;
      
      expect(a > b, true);
      expect(a < b, false);
      expect(a >= b, true);
      expect(a <= b, false);
      expect(a == MonetaryValue(100), true);
    });

    test('Display formatting', () {
      expect(99.99.inr.toDisplayString(), '₹99.99');
      expect(100.inr.toFormattedString(), '100.00');
    });

    test('Wallet scenario - no lost money', () {
      // Scenario: wallet of ₹1000.00, spent ₹333.33
      final wallet = 1000.00.inr;
      final spent = 333.33.inr;
      final remaining = wallet - spent;
      
      expect(remaining.toDouble(), 666.67);
      expect(remaining.toFormattedString(), '666.67');
    });

    test('Order calculation - cart totals', () {
      // Item 1: ₹99.99 x 3
      final item1 = 99.99.inr * 3;
      expect(item1.toDouble(), 299.97);
      
      // Item 2: ₹50.00 x 2
      final item2 = 50.00.inr * 2;
      expect(item2.toDouble(), 100.0);
      
      // Total: ₹399.97
      final total = item1 + item2;
      expect(total.toDouble(), 399.97);
      expect(total.toFormattedString(), '399.97');
    });

    test('Discount calculation', () {
      // Original: ₹100.00, Discount 10%
      final original = 100.00.inr;
      final discountRate = 10.inr / 100;
      final discount = original * 10 / 100;
      
      expect(discount.toDouble(), 10.0);
      expect((original - discount).toDouble(), 90.0);
    });

    test('Tax addition', () {
      // Subtotal: ₹100.00, Tax 5%
      final subtotal = 100.00.inr;
      final tax = subtotal * 5 / 100;
      final total = subtotal + tax;
      
      expect(tax.toDouble(), 5.0);
      expect(total.toDouble(), 105.0);
    });

    test('Utility functions', () {
      final values = [
        10.inr,
        20.inr,
        30.inr,
      ];
      
      expect(MonetaryUtils.sum(values).toDouble(), 60.0);
      expect(MonetaryUtils.average(values).toDouble(), 20.0);
    });

    test('Zero division protection', () {
      expect(
        () => MonetaryValue(100) / 0,
        throwsArgumentError,
      );
    });

    test('Invalid type protection', () {
      expect(
        () => MonetaryValue(null),
        throwsArgumentError,
      );
    });
  });
}
