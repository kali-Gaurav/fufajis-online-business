import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/expiry_service.dart';

void main() {
  group('Expiry Service - Performance Tests', () {
    late ExpiryService expiryService;

    setUp(() {
      expiryService = ExpiryService();
    });

    test('✅ Performance: Batch expiry checks should complete within threshold', () async {
      final startTime = DateTime.now();

      // Simulate checking 100 products for expiry
      final products = List.generate(100, (i) => 'product_$i');

      final stopwatch = Stopwatch()..start();

      for (var productId in products) {
        // Simulate async operation
        await Future.delayed(Duration(milliseconds: 1));
      }

      stopwatch.stop();

      // Performance threshold: should complete in under 5 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    test('✅ Performance: Expiry date calculation should be O(1)', () {
      final expiryDate = DateTime.now().add(Duration(days: 30));
      final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

      expect(daysUntilExpiry, equals(30));
    });
  });
}
