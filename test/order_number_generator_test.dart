import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/utils/order_number_generator.dart';

void main() {
  group('OrderNumberGenerator Tests', () {
    test('generate should return string with correct format', () {
      final orderNumber = OrderNumberGenerator.generate();
      expect(orderNumber, matches(RegExp(r'^HLM-\d{8}-\d{4}$')));
    });

    test('generate should include correct date part', () {
      final customDate = DateTime(2024, 5, 19);
      final orderNumber = OrderNumberGenerator.generate(date: customDate);
      expect(orderNumber, equals('HLM-20240519-????'));
    });

    test('generate should include random 4-digit number', () {
      final orderNumber = OrderNumberGenerator.generate();
      final parts = orderNumber.split('-');
      final randomPart = int.parse(parts[2]);
      expect(randomPart, greaterThanOrEqualTo(1000));
      expect(randomPart, lessThanOrEqualTo(9999));
    });

    test('generate should produce unique numbers', () {
      final numbers = <String>{};
      for (int i = 0; i < 100; i++) {
        numbers.add(OrderNumberGenerator.generate());
      }
      // With 9000 possible combinations, 100 should be unique
      expect(numbers.length, equals(100));
    });

    test('validate should return true for valid order numbers', () {
      expect(
        OrderNumberGenerator.validate('HLM-20240519-1234'),
        isTrue,
      );
      expect(
        OrderNumberGenerator.validate('HLM-20231225-9999'),
        isTrue,
      );
    });

    test('validate should return false for invalid order numbers', () {
      expect(OrderNumberGenerator.validate('INVALID'), isFalse);
      expect(OrderNumberGenerator.validate('HLM-20240519'), isFalse);
      expect(OrderNumberGenerator.validate('HLM-20240519-123'), isFalse);
      expect(OrderNumberGenerator.validate('HLM-20240519-12345'), isFalse);
      expect(OrderNumberGenerator.validate('ABC-20240519-1234'), isFalse);
    });

    test('extractDate should return correct DateTime for valid order number', () {
      final date = OrderNumberGenerator.extractDate('HLM-20240519-1234');
      expect(date, isNotNull);
      expect(date!.year, equals(2024));
      expect(date.month, equals(5));
      expect(date.day, equals(19));
    });

    test('extractDate should return null for invalid order number', () {
      expect(OrderNumberGenerator.extractDate('INVALID'), isNull);
    });

    test('isFromToday should return true for today\'s orders', () {
      final todayOrderNumber = OrderNumberGenerator.generate();
      expect(OrderNumberGenerator.isFromToday(todayOrderNumber), isTrue);
    });

    test('isFromToday should return false for older orders', () {
      const oldOrderNumber = 'HLM-20200101-1234';
      expect(OrderNumberGenerator.isFromToday(oldOrderNumber), isFalse);
    });

    test('generate with custom date should produce correct format', () {
      final date = DateTime(2024, 12, 25);
      final orderNumber = OrderNumberGenerator.generate(date: date);
      expect(orderNumber, matches(RegExp(r'^HLM-20241225-\d{4}$')));
    });

    test('generate should handle leap year dates', () {
      final leapYearDate = DateTime(2024, 2, 29);
      final orderNumber = OrderNumberGenerator.generate(date: leapYearDate);
      expect(orderNumber, matches(RegExp(r'^HLM-20240229-\d{4}$')));
    });

    test('generate should handle first day of month', () {
      final firstDayDate = DateTime(2024, 1, 1);
      final orderNumber = OrderNumberGenerator.generate(date: firstDayDate);
      expect(orderNumber, matches(RegExp(r'^HLM-20240101-\d{4}$')));
    });

    test('generate should handle last day of year', () {
      final lastDayDate = DateTime(2024, 12, 31);
      final orderNumber = OrderNumberGenerator.generate(date: lastDayDate);
      expect(orderNumber, matches(RegExp(r'^HLM-20241231-\d{4}$')));
    });
  });
}
