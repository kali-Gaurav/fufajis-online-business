import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Inventory Locking During Checkout', () {
    late InventoryLockingService lockingService;

    setUp(() {
      lockingService = InventoryLockingService();
    });

    group('Reservation Creation', () {
      test('should reserve inventory for checkout', () async {
        const productId = 'prod_1';
        const quantity = 5;
        const orderId = 'order_123';

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: quantity,
          orderId: orderId,
        );

        expect(reservation, isNotNull);
        expect(reservation['status'], 'reserved');
        expect(reservation['quantity'], quantity);
        expect(reservation['expiresAt'], isNotNull);
      });

      test('should prevent overselling when inventory exhausted', () async {
        const productId = 'prod_1';
        const availableStock = 10;
        const orderQuantity1 = 8;
        const orderQuantity2 = 5; // This should fail

        // First order reserves 8
        await lockingService.reserveInventory(
          productId: productId,
          quantity: orderQuantity1,
          orderId: 'order_1',
        );

        // Second order tries to reserve 5, but only 2 available
        final secondReservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: orderQuantity2,
          orderId: 'order_2',
        );

        expect(secondReservation['status'], 'failed');
        expect(secondReservation['error'], contains('insufficient'));
      });

      test('should create unique reservation for each order', () async {
        const productId = 'prod_1';

        final res1 = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_1',
        );

        final res2 = await lockingService.reserveInventory(
          productId: productId,
          quantity: 3,
          orderId: 'order_2',
        );

        expect(res1['reservationId'], isNotNull);
        expect(res2['reservationId'], isNotNull);
        expect(res1['reservationId'], isNot(res2['reservationId']));
      });

      test('should set 10-minute expiry on reservation', () async {
        const productId = 'prod_1';
        const orderId = 'order_123';

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: orderId,
        );

        final now = DateTime.now();
        final expiresAt = DateTime.parse(reservation['expiresAt']);
        final duration = expiresAt.difference(now);

        // Should expire in approximately 10 minutes
        expect(duration.inMinutes, closeTo(10, 1));
      });

      test('should handle partial inventory reservation', () async {
        const productId = 'prod_1';
        const availableStock = 20;
        const requestQuantity = 25; // More than available

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: requestQuantity,
          orderId: 'order_123',
        );

        expect(reservation['status'], 'failed');
      });

      test('should handle zero quantity reservation', () async {
        const productId = 'prod_1';

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 0,
          orderId: 'order_123',
        );

        expect(reservation['status'], 'failed');
      });

      test('should handle negative quantity reservation', () async {
        const productId = 'prod_1';

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: -5,
          orderId: 'order_123',
        );

        expect(reservation['status'], 'failed');
      });
    });

    group('Reservation Confirmation', () {
      test('should confirm reservation and move to sold stock', () async {
        const productId = 'prod_1';
        const quantity = 5;
        const orderId = 'order_123';

        // Reserve
        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: quantity,
          orderId: orderId,
        );

        // Confirm after payment
        final confirmed = await lockingService.confirmReservation(
          reservationId: reservation['reservationId'],
          orderId: orderId,
        );

        expect(confirmed['status'], 'confirmed');
        expect(confirmed['soldQuantity'], quantity);
      });

      test('should prevent confirming non-existent reservation', () async {
        final confirmed = await lockingService.confirmReservation(
          reservationId: 'fake_reservation_id',
          orderId: 'order_123',
        );

        expect(confirmed['status'], 'failed');
        expect(confirmed['error'], contains('not found'));
      });

      test('should prevent confirming expired reservation', () async {
        const productId = 'prod_1';

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_123',
        );

        // Simulate expiry by manually updating
        await lockingService.expireReservation(reservation['reservationId']);

        final confirmed = await lockingService.confirmReservation(
          reservationId: reservation['reservationId'],
          orderId: 'order_123',
        );

        expect(confirmed['status'], 'failed');
        expect(confirmed['error'], contains('expired'));
      });

      test('should update available stock after confirmation', () async {
        const productId = 'prod_1';
        final initialStock = await lockingService.getAvailableStock(productId);

        // Reserve and confirm
        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_123',
        );

        await lockingService.confirmReservation(
          reservationId: reservation['reservationId'],
          orderId: 'order_123',
        );

        final afterStock = await lockingService.getAvailableStock(productId);

        expect(afterStock, lessThan(initialStock));
      });
    });

    group('Reservation Release', () {
      test('should release reserved inventory on payment failure', () async {
        const productId = 'prod_1';
        final initialStock = await lockingService.getAvailableStock(productId);

        // Reserve
        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_123',
        );

        // Release on failure
        final released = await lockingService.releaseReservation(
          reservationId: reservation['reservationId'],
          orderId: 'order_123',
          reason: 'payment_failed',
        );

        expect(released['status'], 'released');
        expect(released['releasedQuantity'], 5);

        // Available stock should return
        final finalStock = await lockingService.getAvailableStock(productId);
        expect(finalStock, initialStock);
      });

      test('should handle releasing non-existent reservation', () async {
        final released = await lockingService.releaseReservation(
          reservationId: 'fake_id',
          orderId: 'order_123',
          reason: 'payment_failed',
        );

        expect(released['status'], 'failed');
      });

      test('should prevent releasing confirmed reservation', () async {
        const productId = 'prod_1';

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_123',
        );

        await lockingService.confirmReservation(
          reservationId: reservation['reservationId'],
          orderId: 'order_123',
        );

        final released = await lockingService.releaseReservation(
          reservationId: reservation['reservationId'],
          orderId: 'order_123',
          reason: 'user_cancelled',
        );

        expect(released['status'], 'failed');
      });

      test('should track release reason', () async {
        const productId = 'prod_1';
        const reason = 'payment_failed';

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_123',
        );

        final released = await lockingService.releaseReservation(
          reservationId: reservation['reservationId'],
          orderId: 'order_123',
          reason: reason,
        );

        expect(released['reason'], reason);
      });
    });

    group('Automatic Expiry', () {
      test('should automatically release expired reservations', () async {
        const productId = 'prod_1';
        final initialStock = await lockingService.getAvailableStock(productId);

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_123',
        );

        // Manually expire the reservation
        await lockingService.expireReservation(reservation['reservationId']);

        // Clean up expired reservations
        await lockingService.cleanupExpiredReservations();

        // Stock should be returned
        final finalStock = await lockingService.getAvailableStock(productId);
        expect(finalStock, initialStock);
      });

      test('should not expire non-expired reservations during cleanup', () async {
        const productId = 'prod_1';

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_123',
        );

        await lockingService.cleanupExpiredReservations();

        // Reservation should still exist
        final status = await lockingService.getReservationStatus(
          reservation['reservationId'],
        );

        expect(status['status'], 'reserved');
      });

      test('should cleanup multiple expired reservations', () async {
        const productId = 'prod_1';

        final res1 = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_1',
        );

        final res2 = await lockingService.reserveInventory(
          productId: productId,
          quantity: 3,
          orderId: 'order_2',
        );

        await lockingService.expireReservation(res1['reservationId']);
        await lockingService.expireReservation(res2['reservationId']);

        final cleanedCount = await lockingService.cleanupExpiredReservations();

        expect(cleanedCount, greaterThanOrEqualTo(2));
      });
    });

    group('Stock Queries', () {
      test('should return available stock', () async {
        const productId = 'prod_1';

        final stock = await lockingService.getAvailableStock(productId);

        expect(stock, isA<int>());
        expect(stock, greaterThanOrEqualTo(0));
      });

      test('should return reserved stock', () async {
        const productId = 'prod_1';

        await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_1',
        );

        final reserved = await lockingService.getReservedStock(productId);

        expect(reserved, greaterThanOrEqualTo(5));
      });

      test('should return sold stock', () async {
        const productId = 'prod_1';

        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_123',
        );

        await lockingService.confirmReservation(
          reservationId: reservation['reservationId'],
          orderId: 'order_123',
        );

        final sold = await lockingService.getSoldStock(productId);

        expect(sold, greaterThanOrEqualTo(5));
      });

      test('should return total stock breakdown', () async {
        const productId = 'prod_1';

        final breakdown = await lockingService.getStockBreakdown(productId);

        expect(breakdown['available'], isA<int>());
        expect(breakdown['reserved'], isA<int>());
        expect(breakdown['sold'], isA<int>());
        expect(breakdown['total'], isA<int>());

        // Total should equal sum of all
        final total = breakdown['available'] + breakdown['reserved'] + breakdown['sold'];
        expect(total, breakdown['total']);
      });
    });

    group('Concurrency', () {
      test('should handle concurrent reservations correctly', () async {
        const productId = 'prod_1';

        final futures = List.generate(5, (i) {
          return lockingService.reserveInventory(
            productId: productId,
            quantity: 2,
            orderId: 'order_$i',
          );
        });

        final results = await Future.wait(futures);

        // At least some should succeed
        final successCount = results.where((r) => r['status'] == 'reserved').length;
        expect(successCount, greaterThan(0));
      });

      test('should prevent double-booking with concurrent requests', () async {
        const productId = 'prod_1';
        const availableStock = 10;

        // Try to reserve more than available in parallel
        final futures = List.generate(3, (i) {
          return lockingService.reserveInventory(
            productId: productId,
            quantity: 6, // 6 * 3 = 18 > 10
            orderId: 'order_$i',
          );
        });

        final results = await Future.wait(futures);

        // Only one should succeed
        final successCount = results.where((r) => r['status'] == 'reserved').length;
        expect(successCount, lessThanOrEqualTo(1));
      });
    });

    group('Error Handling', () {
      test('should handle database connection errors', () async {
        // Simulate connection error
        lockingService.simulateConnectionError = true;

        final reservation = await lockingService.reserveInventory(
          productId: 'prod_1',
          quantity: 5,
          orderId: 'order_123',
        );

        expect(reservation['status'], 'failed');
        expect(reservation['error'], contains('connection'));

        lockingService.simulateConnectionError = false;
      });

      test('should handle invalid product ID', () async {
        final reservation = await lockingService.reserveInventory(
          productId: '',
          quantity: 5,
          orderId: 'order_123',
        );

        expect(reservation['status'], 'failed');
      });

      test('should handle invalid order ID', () async {
        final reservation = await lockingService.reserveInventory(
          productId: 'prod_1',
          quantity: 5,
          orderId: '',
        );

        expect(reservation['status'], 'failed');
      });
    });

    group('Transaction Safety', () {
      test('should atomically reserve inventory', () async {
        const productId = 'prod_1';

        // Reservation should be atomic - either fully reserved or not at all
        final reservation = await lockingService.reserveInventory(
          productId: productId,
          quantity: 5,
          orderId: 'order_123',
        );

        if (reservation['status'] == 'reserved') {
          final stock = await lockingService.getStockBreakdown(productId);
          expect(stock['reserved'], greaterThanOrEqualTo(5));
        } else {
          final stock = await lockingService.getStockBreakdown(productId);
          expect(stock['reserved'], isNotNull);
        }
      });

      test('should rollback on partial failure', () async {
        const productId1 = 'prod_1';
        const productId2 = 'prod_2_invalid';

        final initialStock = await lockingService.getAvailableStock(productId1);

        // Multi-product reservation that will fail
        final reservation = await lockingService.reserveMultiple(
          reservations: [
            {'productId': productId1, 'quantity': 5},
            {'productId': productId2, 'quantity': 3}, // Invalid product
          ],
          orderId: 'order_123',
        );

        expect(reservation['status'], 'failed');

        // First product stock should not be affected
        final finalStock = await lockingService.getAvailableStock(productId1);
        expect(finalStock, initialStock);
      });
    });
  });
}

class InventoryLockingService {
  bool simulateConnectionError = false;

  Future<Map<String, dynamic>> reserveInventory({
    required String productId,
    required int quantity,
    required String orderId,
  }) async {
    if (simulateConnectionError) {
      return {'status': 'failed', 'error': 'connection error'};
    }
    return {};
  }

  Future<Map<String, dynamic>> confirmReservation({
    required String reservationId,
    required String orderId,
  }) async {
    return {};
  }

  Future<Map<String, dynamic>> releaseReservation({
    required String reservationId,
    required String orderId,
    required String reason,
  }) async {
    return {};
  }

  Future<void> expireReservation(String reservationId) async {}

  Future<int> cleanupExpiredReservations() async => 0;

  Future<int> getAvailableStock(String productId) async => 0;

  Future<int> getReservedStock(String productId) async => 0;

  Future<int> getSoldStock(String productId) async => 0;

  Future<Map<String, dynamic>> getStockBreakdown(String productId) async => {};

  Future<Map<String, dynamic>> getReservationStatus(String reservationId) async => {};

  Future<Map<String, dynamic>> reserveMultiple({
    required List<Map<String, dynamic>> reservations,
    required String orderId,
  }) async => {};
}
