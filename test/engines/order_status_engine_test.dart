import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/order_status_engine.dart';
import 'package:fufajis_online/constants/order_status.dart';

void main() {
  late OrderStatusEngine engine;

  setUp(() {
    engine = OrderStatusEngine();
  });

  group('OrderStatusEngine Workflow Validation', () {
    test('Valid workflow transitions should succeed', () {
      // Valid path: pending -> confirmed -> processing -> packed -> outForDelivery -> delivered
      expect(
        () => engine.validateTransition(OrderStatus.pending, OrderStatus.confirmed, 'admin'),
        returnsNormally,
      );
      expect(
        () => engine.validateTransition(OrderStatus.confirmed, OrderStatus.processing, 'admin'),
        returnsNormally,
      );
      expect(
        () => engine.validateTransition(OrderStatus.processing, OrderStatus.packed, 'admin'),
        returnsNormally,
      );
      expect(
        () => engine.validateTransition(OrderStatus.packed, OrderStatus.outForDelivery, 'admin'),
        returnsNormally,
      );
      expect(
        () => engine.validateTransition(OrderStatus.outForDelivery, OrderStatus.delivered, 'admin'),
        returnsNormally,
      );
    });

    test('Invalid workflow transitions should throw InvalidStatusTransitionException', () {
      expect(
        () => engine.validateTransition(OrderStatus.pending, OrderStatus.delivered, 'admin'),
        throwsA(isA<InvalidStatusTransitionException>()),
      );

      expect(
        () => engine.validateTransition(OrderStatus.delivered, OrderStatus.processing, 'admin'),
        throwsA(isA<InvalidStatusTransitionException>()),
      );
    });

    test('Customer role should be blocked from unauthorized transitions', () {
      expect(
        () => engine.validateTransition(OrderStatus.pending, OrderStatus.confirmed, 'customer'),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
    });

    test('Customer role is allowed to transition to cancelled', () {
      expect(
        () => engine.validateTransition(OrderStatus.pending, OrderStatus.cancelled, 'customer'),
        returnsNormally,
      );
    });

    test('Delivery Partner is only allowed specific transitions', () {
      // Allowed: outForDelivery, delivered
      expect(
        () => engine.validateTransition(
          OrderStatus.packed,
          OrderStatus.outForDelivery,
          'delivery_partner',
        ),
        returnsNormally,
      );

      expect(
        () => engine.validateTransition(
          OrderStatus.outForDelivery,
          OrderStatus.delivered,
          'delivery_partner',
        ),
        returnsNormally,
      );

      // Blocked: Cancelled
      expect(
        () => engine.validateTransition(
          OrderStatus.processing,
          OrderStatus.cancelled,
          'delivery_partner',
        ),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
    });
  });
}
