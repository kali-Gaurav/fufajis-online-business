import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/user_model.dart';
import 'package:fufajis_online/utils/monetary_value.dart';
import 'package:fufajis_online/constants/order_status.dart';

void main() {
  group('OrderService - Inventory & Status Transitions', () {
    group('Order Auto-Transitions', () {
      test('Should auto-transition order from pending to confirmed', () {
        // Arrange
        final order = OrderModel(
          id: 'order1',
          orderNumber: 'ORD-001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '+919876543210',
          items: const [],
          subtotal: MonetaryValue(500.0),
          totalAmount: MonetaryValue(500.0),
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            street: 'Test Street',
            city: 'Test City',
            latitude: 0.0,
            longitude: 0.0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final transitionedOrder = order.updateStatus(
          OrderStatus.confirmed,
          note: 'Test transition',
          actorRole: 'system',
        );

        // Assert
        expect(transitionedOrder.status, equals(OrderStatus.confirmed));
        expect(transitionedOrder.statusHistory.length, greaterThan(0));
        expect(transitionedOrder.statusHistory.last.status, equals(OrderStatus.confirmed));
      });

      test('Should validate status transitions correctly', () {
        // Test valid transitions
        expect(OrderStatus.pending.toString() == 'OrderStatus.pending', true);

        final order = OrderModel(
          id: 'order1',
          orderNumber: 'ORD-001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '+919876543210',
          items: const [],
          subtotal: MonetaryValue(500.0),
          totalAmount: MonetaryValue(500.0),
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            street: 'Test Street',
            city: 'Test City',
            latitude: 0.0,
            longitude: 0.0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // pending → confirmed: valid
        expect(order.isValidTransition(OrderStatus.confirmed), true);

        // pending → delivered: invalid (must go through intermediate states)
        expect(order.isValidTransition(OrderStatus.delivered), false);

        // pending → cancelled: valid
        expect(order.isValidTransition(OrderStatus.cancelled), true);
      });

      test('Confirmed orders can transition to processing', () {
        // Arrange
        final order = OrderModel(
          id: 'order1',
          orderNumber: 'ORD-001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '+919876543210',
          items: const [],
          subtotal: MonetaryValue(500.0),
          totalAmount: MonetaryValue(500.0),
          status: OrderStatus.confirmed,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            street: 'Test Street',
            city: 'Test City',
            latitude: 0.0,
            longitude: 0.0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final canTransition = order.isValidTransition(OrderStatus.processing);

        // Assert
        expect(canTransition, true);
      });

      test('Terminal statuses prevent further transitions', () {
        // Arrange - delivered order
        final deliveredOrder = OrderModel(
          id: 'order1',
          orderNumber: 'ORD-001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '+919876543210',
          items: const [],
          subtotal: MonetaryValue(500.0),
          totalAmount: MonetaryValue(500.0),
          status: OrderStatus.delivered,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            street: 'Test Street',
            city: 'Test City',
            latitude: 0.0,
            longitude: 0.0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act & Assert
        expect(deliveredOrder.isValidTransition(OrderStatus.cancelled), false);
        expect(deliveredOrder.isValidTransition(OrderStatus.returned), false);
      });
    });

    group('Order Lifecycle Validation', () {
      test(
        'Complete order lifecycle: pending → confirmed → processing → packed → outForDelivery → delivered',
        () {
          // Arrange
          var order = OrderModel(
            id: 'order1',
            orderNumber: 'ORD-001',
            customerId: 'cust1',
            customerName: 'John Doe',
            customerPhone: '+919876543210',
            items: const [],
            subtotal: MonetaryValue(500.0),
            totalAmount: MonetaryValue(500.0),
            deliveryAddress: Address(
              id: 'addr1',
              label: 'Home',
              street: 'Test Street',
              city: 'Test City',
              latitude: 0.0,
              longitude: 0.0,
            ),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Act - complete lifecycle
          order = order.updateStatus(OrderStatus.confirmed, note: 'Confirmed');
          expect(order.status, equals(OrderStatus.confirmed));

          order = order.updateStatus(OrderStatus.processing, note: 'Processing');
          expect(order.status, equals(OrderStatus.processing));

          order = order.updateStatus(OrderStatus.packed, note: 'Packed');
          expect(order.status, equals(OrderStatus.packed));

          order = order.updateStatus(OrderStatus.outForDelivery, note: 'Out for delivery');
          expect(order.status, equals(OrderStatus.outForDelivery));

          order = order.updateStatus(OrderStatus.delivered, note: 'Delivered');
          expect(order.status, equals(OrderStatus.delivered));

          // Assert
          expect(order.statusHistory.length, equals(5));
          expect(
            order.statusHistory.map((StatusHistoryEntry e) => e.status).toList(),
            equals([
              OrderStatus.confirmed,
              OrderStatus.processing,
              OrderStatus.packed,
              OrderStatus.outForDelivery,
              OrderStatus.delivered,
            ]),
          );
        },
      );

      test('Order can be cancelled at any active state', () {
        // Arrange
        var order = OrderModel(
          id: 'order1',
          orderNumber: 'ORD-001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '+919876543210',
          items: const [],
          subtotal: MonetaryValue(500.0),
          totalAmount: MonetaryValue(500.0),
          status: OrderStatus.processing,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            street: 'Test Street',
            city: 'Test City',
            latitude: 0.0,
            longitude: 0.0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final canCancel = order.isValidTransition(OrderStatus.cancelled);

        // Assert
        expect(canCancel, true);
      });

      test('Order cannot be cancelled after delivery', () {
        // Arrange
        var order = OrderModel(
          id: 'order1',
          orderNumber: 'ORD-001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '+919876543210',
          items: const [],
          subtotal: MonetaryValue(500.0),
          totalAmount: MonetaryValue(500.0),
          status: OrderStatus.delivered,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            street: 'Test Street',
            city: 'Test City',
            latitude: 0.0,
            longitude: 0.0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final canCancel = order.isValidTransition(OrderStatus.cancelled);

        // Assert
        expect(canCancel, false);
      });
    });
  });
}
