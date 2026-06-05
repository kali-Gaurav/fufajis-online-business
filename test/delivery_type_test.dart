import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/models/delivery_type.dart';
import 'package:fufajis_online/services/delivery_charge_calculator.dart';

void main() {
  group('DeliveryType Tests', () {
    test('DeliveryType enum has all expected values', () {
      expect(DeliveryType.standard, equals(DeliveryType.standard));
      expect(DeliveryType.express, equals(DeliveryType.express));
      expect(DeliveryType.sameDay, equals(DeliveryType.sameDay));
      expect(DeliveryType.villageDelivery, equals(DeliveryType.villageDelivery));
    });

    test('DeliveryTypeOption.allOptions returns all options', () {
      final options = DeliveryTypeOption.allOptions;
      expect(options.length, equals(DeliveryType.values.length));
      expect(options.map((e) => e.type).toSet(), equals(DeliveryType.values.toSet()));
    });

    test('DeliveryTypeOption.fromType returns correct option', () {
      expect(DeliveryTypeOption.fromType(DeliveryType.standard).type, equals(DeliveryType.standard));
      expect(DeliveryTypeOption.fromType(DeliveryType.express).type, equals(DeliveryType.express));
      expect(DeliveryTypeOption.fromType(DeliveryType.sameDay).type, equals(DeliveryType.sameDay));
      expect(DeliveryTypeOption.fromType(DeliveryType.villageDelivery).type, equals(DeliveryType.villageDelivery));
    });

    test('Standard delivery option has correct values', () {
      const standard = DeliveryTypeOption.standard;
      expect(standard.name, equals('Standard Delivery'));
      expect(standard.price, equals(0));
      expect(standard.estimatedDays, equals(2));
      expect(standard.estimatedTime, equals('2-3 days'));
    });

    test('Express delivery option has correct values', () {
      const express = DeliveryTypeOption.express;
      expect(express.name, equals('Express Delivery'));
      expect(express.price, equals(50));
      expect(express.estimatedDays, equals(1));
      expect(express.estimatedTime, equals('Next day'));
    });

    test('Same day delivery option has correct values', () {
      const sameDay = DeliveryTypeOption.sameDay;
      expect(sameDay.name, equals('Same Day Delivery'));
      expect(sameDay.price, equals(100));
      expect(sameDay.estimatedDays, equals(0));
      expect(sameDay.estimatedTime, equals('Within 8 hours'));
    });

    test('Village delivery option has correct values', () {
      const village = DeliveryTypeOption.villageDelivery;
      expect(village.name, equals('Village Delivery'));
      expect(village.price, equals(30));
      expect(village.estimatedDays, equals(4));
      expect(village.estimatedTime, equals('3-5 days'));
    });

    test('priceString returns FREE for zero price', () {
      expect(DeliveryTypeOption.standard.priceString, equals('FREE'));
    });

    test('priceString returns formatted price for non-zero price', () {
      expect(DeliveryTypeOption.express.priceString, equals('₹50'));
      expect(DeliveryTypeOption.sameDay.priceString, equals('₹100'));
      expect(DeliveryTypeOption.villageDelivery.priceString, equals('₹30'));
    });
  });

  group('DeliveryChargeCalculator Tests', () {
    test('Standard delivery is FREE for orders above ₹500', () {
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.standard, 500), equals(0));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.standard, 600), equals(0));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.standard, 1000), equals(0));
    });

    test('Standard delivery is ₹20 for orders between ₹200-500', () {
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.standard, 200), equals(20));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.standard, 300), equals(20));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.standard, 499), equals(20));
    });

    test('Standard delivery is ₹40 for orders below ₹200', () {
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.standard, 100), equals(40));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.standard, 199), equals(40));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.standard, 50), equals(40));
    });

    test('Express delivery always costs ₹50', () {
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.express, 100), equals(50));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.express, 500), equals(50));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.express, 1000), equals(50));
    });

    test('Same day delivery always costs ₹100', () {
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.sameDay, 100), equals(100));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.sameDay, 500), equals(100));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.sameDay, 1000), equals(100));
    });

    test('Village delivery always costs ₹30', () {
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.villageDelivery, 100), equals(30));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.villageDelivery, 500), equals(30));
      expect(DeliveryChargeCalculator.calculateDeliveryCharge(DeliveryType.villageDelivery, 1000), equals(30));
    });

    test('getEstimatedDeliveryDate returns correct date for standard delivery', () {
      final now = DateTime.now();
      final result = DeliveryChargeCalculator.getEstimatedDeliveryDate(DeliveryType.standard);
      expect(result.difference(now).inDays, equals(2));
    });

    test('getEstimatedDeliveryDate returns correct date for express delivery', () {
      final now = DateTime.now();
      final result = DeliveryChargeCalculator.getEstimatedDeliveryDate(DeliveryType.express);
      expect(result.difference(now).inDays, equals(1));
    });

    test('getEstimatedDeliveryDate returns today for same day delivery', () {
      final now = DateTime.now();
      final result = DeliveryChargeCalculator.getEstimatedDeliveryDate(DeliveryType.sameDay);
      expect(result.difference(now).inDays, equals(0));
    });

    test('getFormattedDeliveryDate returns correct format for standard delivery', () {
      final result = DeliveryChargeCalculator.getFormattedDeliveryDate(DeliveryType.standard);
      expect(result, equals('2-3 days'));
    });

    test('getFormattedDeliveryDate returns correct format for express delivery', () {
      final result = DeliveryChargeCalculator.getFormattedDeliveryDate(DeliveryType.express);
      expect(result, equals('Next day'));
    });

    test('getFormattedDeliveryDate returns correct format for same day delivery', () {
      final result = DeliveryChargeCalculator.getFormattedDeliveryDate(DeliveryType.sameDay);
      expect(result, equals('Within 8 hours'));
    });

    test('getFormattedDeliveryDate returns correct format for village delivery', () {
      final result = DeliveryChargeCalculator.getFormattedDeliveryDate(DeliveryType.villageDelivery);
      expect(result, equals('3-5 days'));
    });

    test('isStandardDeliveryFree returns true for orders above threshold', () {
      expect(DeliveryChargeCalculator.isStandardDeliveryFree(500), isTrue);
      expect(DeliveryChargeCalculator.isStandardDeliveryFree(600), isTrue);
      expect(DeliveryChargeCalculator.isStandardDeliveryFree(1000), isTrue);
    });

    test('isStandardDeliveryFree returns false for orders at or below threshold', () {
      expect(DeliveryChargeCalculator.isStandardDeliveryFree(499), isFalse);
      expect(DeliveryChargeCalculator.isStandardDeliveryFree(200), isFalse);
      expect(DeliveryChargeCalculator.isStandardDeliveryFree(100), isFalse);
    });

    test('getAmountNeededForFreeDelivery returns 0 for orders above threshold', () {
      expect(DeliveryChargeCalculator.getAmountNeededForFreeDelivery(500), equals(0));
      expect(DeliveryChargeCalculator.getAmountNeededForFreeDelivery(600), equals(0));
    });

    test('getAmountNeededForFreeDelivery returns correct amount for orders below threshold', () {
      expect(DeliveryChargeCalculator.getAmountNeededForFreeDelivery(499), equals(1));
      expect(DeliveryChargeCalculator.getAmountNeededForFreeDelivery(400), equals(100));
      expect(DeliveryChargeCalculator.getAmountNeededForFreeDelivery(200), equals(300));
      expect(DeliveryChargeCalculator.getAmountNeededForFreeDelivery(100), equals(400));
    });

    test('calculateTotal returns correct total with delivery charge', () {
      expect(
        DeliveryChargeCalculator.calculateTotal(
          subtotal: 100,
          deliveryType: DeliveryType.standard,
        ),
        equals(140),
      );
      expect(
        DeliveryChargeCalculator.calculateTotal(
          subtotal: 300,
          deliveryType: DeliveryType.standard,
        ),
        equals(320),
      );
      expect(
        DeliveryChargeCalculator.calculateTotal(
          subtotal: 600,
          deliveryType: DeliveryType.standard,
        ),
        equals(600),
      );
    });

    test('calculateTotal applies discount and wallet amount correctly', () {
      expect(
        DeliveryChargeCalculator.calculateTotal(
          subtotal: 300,
          deliveryType: DeliveryType.express,
          discount: 30,
        ),
        equals(320),
      );
      expect(
        DeliveryChargeCalculator.calculateTotal(
          subtotal: 300,
          deliveryType: DeliveryType.express,
          discount: 30,
          walletAmount: 50,
        ),
        equals(270),
      );
    });

    test('getDeliveryDetails returns complete information', () {
      final details = DeliveryChargeCalculator.getDeliveryDetails(DeliveryType.express, 300);
      expect(details['charge'], equals(50));
      expect(details['formattedCharge'], equals('₹50'));
      expect(details['estimatedDate'], equals('Next day'));
      expect(details['name'], equals('Express Delivery'));
      expect(details['isFree'], isFalse);
    });

    test('getDeliveryDetails returns FREE for standard delivery above threshold', () {
      final details = DeliveryChargeCalculator.getDeliveryDetails(DeliveryType.standard, 600);
      expect(details['charge'], equals(0));
      expect(details['formattedCharge'], equals('FREE'));
      expect(details['isFree'], isTrue);
    });
  });
}
