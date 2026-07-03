import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/models/delivery_type.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/payment_method.dart';
import 'package:fufajis_online/models/user_model.dart' as user_model;
import 'package:fufajis_online/repositories/order_repository.dart';
import 'package:fufajis_online/constants/order_status.dart';
import 'package:fufajis_online/utils/monetary_value.dart';
import 'package:fufajis_online/services/order_status_engine.dart';

void main() {
  group('OrderRepository', () {
    late OrderRepository repository;

    setUp(() {
      repository = OrderRepository();
    });

    test('OrderRepository singleton returns same instance', () {
      final repo1 = OrderRepository();
      final repo2 = OrderRepository();
      expect(identical(repo1, repo2), true);
    });
  });

  group('OrderStatusEngine - State Machine Validation', () {
    late OrderStatusEngine engine;

    setUp(() {
      engine = OrderStatusEngine();
    });

    test('validates pending -> confirmed transition', () {
      expect(engine.isValidTransition(OrderStatus.pending, OrderStatus.confirmed), true);
    });

    test('validates pending -> cancelled transition', () {
      expect(engine.isValidTransition(OrderStatus.pending, OrderStatus.cancelled), true);
    });

    test('rejects pending -> delivered transition (invalid)', () {
      expect(engine.isValidTransition(OrderStatus.pending, OrderStatus.delivered), false);
    });

    test('validates linear progression: pending->confirmed->processing->packed', () {
      expect(engine.isValidTransition(OrderStatus.pending, OrderStatus.confirmed), true);
      expect(engine.isValidTransition(OrderStatus.confirmed, OrderStatus.processing), true);
      expect(engine.isValidTransition(OrderStatus.processing, OrderStatus.packed), true);
    });

    test('rejects backward transitions (e.g., packed -> processing)', () {
      expect(engine.isValidTransition(OrderStatus.packed, OrderStatus.processing), false);
    });

    test('allows same status transition (idempotent)', () {
      expect(engine.isValidTransition(OrderStatus.confirmed, OrderStatus.confirmed), true);
    });

    test('validates delivered -> returned transition', () {
      expect(engine.isValidTransition(OrderStatus.delivered, OrderStatus.returned), true);
    });

    test('validates returned -> refunded transition', () {
      expect(engine.isValidTransition(OrderStatus.returned, OrderStatus.refunded), true);
    });

    test('validates cancelled -> refunded transition', () {
      expect(engine.isValidTransition(OrderStatus.cancelled, OrderStatus.refunded), true);
    });

    test('rejects transition from refunded (terminal state)', () {
      expect(engine.isValidTransition(OrderStatus.refunded, OrderStatus.cancelled), false);
    });

    test('throws exception on invalid transition', () {
      expect(
        () => engine.validateTransition(OrderStatus.pending, OrderStatus.delivered, 'customer'),
        throwsA(isA<InvalidStatusTransitionException>()),
      );
    });

    test('getValidNextStates returns correct options', () {
      final nextStates = engine.getValidNextStates(OrderStatus.pending);
      expect(nextStates.contains(OrderStatus.confirmed), true);
      expect(nextStates.contains(OrderStatus.cancelled), true);
      expect(nextStates.length, 2);
    });

    test('getValidNextStates returns empty for terminal state', () {
      final nextStates = engine.getValidNextStates(OrderStatus.refunded);
      expect(nextStates.isEmpty, true);
    });

    test('canCancel returns true for active states', () {
      // Create a dummy order for testing
      OrderModel createOrder(OrderStatus status) => OrderModel(
        id: '1',
        orderNumber: '1',
        customerId: '1',
        customerName: '1',
        customerPhone: '1',
        items: [],
        subtotal: MonetaryValue(0),
        tax: MonetaryValue(0),
        discount: MonetaryValue(0),
        deliveryCharge: MonetaryValue(0),
        totalAmount: MonetaryValue(0),
        walletAmountUsed: MonetaryValue(0),
        cashbackEarned: MonetaryValue(0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        status: status,
        deliveryType: DeliveryType.standard,
        deliveryAddress: user_model.Address(id: '1', label: 'Home', latitude: 0, longitude: 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(engine.canCancel(createOrder(OrderStatus.pending)), true);
      expect(engine.canCancel(createOrder(OrderStatus.confirmed)), true);
      expect(engine.canCancel(createOrder(OrderStatus.processing)), true);
      expect(engine.canCancel(createOrder(OrderStatus.packed)), true);
    });

    test('canCancel returns false for terminal states', () {
      OrderModel createOrder(OrderStatus status) => OrderModel(
        id: '1',
        orderNumber: '1',
        customerId: '1',
        customerName: '1',
        customerPhone: '1',
        items: [],
        subtotal: MonetaryValue(0),
        tax: MonetaryValue(0),
        discount: MonetaryValue(0),
        deliveryCharge: MonetaryValue(0),
        totalAmount: MonetaryValue(0),
        walletAmountUsed: MonetaryValue(0),
        cashbackEarned: MonetaryValue(0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        status: status,
        deliveryType: DeliveryType.standard,
        deliveryAddress: user_model.Address(id: '1', label: 'Home', latitude: 0, longitude: 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(engine.canCancel(createOrder(OrderStatus.delivered)), false);
      expect(engine.canCancel(createOrder(OrderStatus.cancelled)), false);
      expect(engine.canCancel(createOrder(OrderStatus.returned)), false);
      expect(engine.canCancel(createOrder(OrderStatus.refunded)), false);
    });

    test('canReturn returns true only for delivered', () {
      OrderModel createOrder(OrderStatus status) => OrderModel(
        id: '1',
        orderNumber: '1',
        customerId: '1',
        customerName: '1',
        customerPhone: '1',
        items: [],
        subtotal: MonetaryValue(0),
        tax: MonetaryValue(0),
        discount: MonetaryValue(0),
        deliveryCharge: MonetaryValue(0),
        totalAmount: MonetaryValue(0),
        walletAmountUsed: MonetaryValue(0),
        cashbackEarned: MonetaryValue(0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        status: status,
        deliveryType: DeliveryType.standard,
        deliveryAddress: user_model.Address(id: '1', label: 'Home', latitude: 0, longitude: 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(engine.canReturn(createOrder(OrderStatus.delivered)), true);
      expect(engine.canReturn(createOrder(OrderStatus.pending)), false);
      expect(engine.canReturn(createOrder(OrderStatus.cancelled)), false);
    });

    test('canRefund validates refund eligibility', () {
      expect(engine.canRefund(OrderStatus.cancelled), true);
      expect(engine.canRefund(OrderStatus.returned), true);
      expect(engine.canRefund(OrderStatus.pending), false);
      expect(engine.canRefund(OrderStatus.delivered), false);
    });
  });

  group('OrderStatusExtension - Display Properties', () {
    test('OrderStatus.pending has correct display name', () {
      expect(OrderStatus.pending.displayName, 'Pending');
    });

    test('OrderStatus.delivered has correct display name', () {
      expect(OrderStatus.delivered.displayName, 'Delivered');
    });

    test('all statuses have non-empty descriptions', () {
      for (final status in OrderStatus.values) {
        expect(status.description.isNotEmpty, true);
      }
    });

    test('progressPercentage reflects order completion', () {
      expect(OrderStatus.pending.progressPercentage, lessThan(100));
      expect(OrderStatus.delivered.progressPercentage, 100);
      expect(OrderStatus.cancelled.progressPercentage, 0);
    });

    test('isActive property correct for each status', () {
      expect(OrderStatus.pending.isActive, true);
      expect(OrderStatus.processing.isActive, true);
      expect(OrderStatus.delivered.isActive, false);
      expect(OrderStatus.cancelled.isActive, false);
    });

    test('isTerminal property correct for each status', () {
      expect(OrderStatus.pending.isTerminal, false);
      expect(OrderStatus.processing.isTerminal, false);
      expect(OrderStatus.delivered.isTerminal, true);
      expect(OrderStatus.cancelled.isTerminal, true);
      expect(OrderStatus.refunded.isTerminal, true);
    });

    test('canCancel property works correctly', () {
      expect(OrderStatus.pending.canCancel, true);
      expect(OrderStatus.outForDelivery.canCancel, false);
      expect(OrderStatus.delivered.canCancel, false);
    });

    test('canReturn property works correctly', () {
      expect(OrderStatus.delivered.canReturn, true);
      expect(OrderStatus.pending.canReturn, false);
      expect(OrderStatus.confirmed.canReturn, false);
    });
  });

  group('OrderModel - Status Transitions', () {
    late user_model.Address testAddress;

    setUp(() {
      testAddress = user_model.Address(
        id: '1',
        label: 'Home',
        fullAddress: '123 Main St',
        latitude: 0,
        longitude: 0,
      );
    });

    test('OrderModel.updateStatus creates valid transition', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: '1001',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '9999999999',
        items: [],
        subtotal: MonetaryValue(100.0),
        tax: MonetaryValue(0.0),
        discount: MonetaryValue(0.0),
        deliveryCharge: MonetaryValue(0.0),
        totalAmount: MonetaryValue(100.0),
        walletAmountUsed: MonetaryValue(0.0),
        cashbackEarned: MonetaryValue(0.0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryType: DeliveryType.standard,
        status: OrderStatus.pending,
      );

      final updatedOrder = order.updateStatus(
        OrderStatus.confirmed,
        note: 'Payment received',
        actorId: 'emp-1',
        actorRole: 'owner',
        actorName: 'Owner Name',
      );

      expect(updatedOrder.status, OrderStatus.confirmed);
      expect(updatedOrder.statusHistory.length, 1);
      expect(updatedOrder.statusHistory.first.status, OrderStatus.confirmed);
      expect(updatedOrder.statusHistory.first.note, 'Payment received');
    });

    test('OrderModel.updateStatus throws on invalid transition', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: '1001',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '9999999999',
        items: [],
        subtotal: MonetaryValue(100.0),
        tax: MonetaryValue(0.0),
        discount: MonetaryValue(0.0),
        deliveryCharge: MonetaryValue(0.0),
        totalAmount: MonetaryValue(100.0),
        walletAmountUsed: MonetaryValue(0.0),
        cashbackEarned: MonetaryValue(0.0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        status: OrderStatus.delivered,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryType: DeliveryType.standard,
      );

      expect(() => order.updateStatus(OrderStatus.pending), throwsA(isA<StateError>()));
    });

    test('OrderModel.isValidTransition works correctly', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: '1001',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '9999999999',
        items: [],
        subtotal: MonetaryValue(100.0),
        tax: MonetaryValue(0.0),
        discount: MonetaryValue(0.0),
        deliveryCharge: MonetaryValue(0.0),
        totalAmount: MonetaryValue(100.0),
        walletAmountUsed: MonetaryValue(0.0),
        cashbackEarned: MonetaryValue(0.0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        status: OrderStatus.pending,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryType: DeliveryType.standard,
      );

      expect(order.isValidTransition(OrderStatus.confirmed), true);
      expect(order.isValidTransition(OrderStatus.cancelled), true);
      expect(order.isValidTransition(OrderStatus.delivered), false);
    });

    test('OrderModel.statusHistory accumulates transitions', () {
      var order = OrderModel(
        id: 'order-1',
        orderNumber: '1001',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '9999999999',
        items: [],
        subtotal: MonetaryValue(100.0),
        tax: MonetaryValue(0.0),
        discount: MonetaryValue(0.0),
        deliveryCharge: MonetaryValue(0.0),
        totalAmount: MonetaryValue(100.0),
        walletAmountUsed: MonetaryValue(0.0),
        cashbackEarned: MonetaryValue(0.0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryType: DeliveryType.standard,
        status: OrderStatus.pending,
      );

      order = order.updateStatus(OrderStatus.confirmed, note: 'Step 1');
      order = order.updateStatus(OrderStatus.processing, note: 'Step 2');
      order = order.updateStatus(OrderStatus.packed, note: 'Step 3');

      expect(order.statusHistory.length, 3);
      expect(order.statusHistory[0].status, OrderStatus.confirmed);
      expect(order.statusHistory[1].status, OrderStatus.processing);
      expect(order.statusHistory[2].status, OrderStatus.packed);
    });
  });

  group('OrderModel - Serialization', () {
    late user_model.Address testAddress;

    setUp(() {
      testAddress = user_model.Address(
        id: '1',
        label: 'Home',
        fullAddress: '123 Main St',
        latitude: 0,
        longitude: 0,
      );
    });

    test('OrderModel.toMap and fromMap are consistent', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: '1001',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '9999999999',
        items: [],
        subtotal: MonetaryValue(100.0),
        tax: MonetaryValue(0.0),
        discount: MonetaryValue(0.0),
        deliveryCharge: MonetaryValue(0.0),
        totalAmount: MonetaryValue(100.0),
        walletAmountUsed: MonetaryValue(0.0),
        cashbackEarned: MonetaryValue(0.0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryType: DeliveryType.standard,
        status: OrderStatus.pending,
      );

      final map = order.toMap();
      final reconstructed = OrderModel.fromMap(map);

      expect(reconstructed.id, order.id);
      expect(reconstructed.orderNumber, order.orderNumber);
      expect(reconstructed.customerId, order.customerId);
      expect(reconstructed.totalAmount, order.totalAmount);
    });

    test('OrderModel.copyWith preserves all fields', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: '1001',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '9999999999',
        items: [],
        subtotal: MonetaryValue(100.0),
        tax: MonetaryValue(0.0),
        discount: MonetaryValue(0.0),
        deliveryCharge: MonetaryValue(0.0),
        totalAmount: MonetaryValue(100.0),
        walletAmountUsed: MonetaryValue(0.0),
        cashbackEarned: MonetaryValue(0.0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryType: DeliveryType.standard,
        status: OrderStatus.pending,
      );

      final updated = order.copyWith(status: OrderStatus.confirmed, paymentStatus: 'paid');

      expect(updated.id, order.id);
      expect(updated.orderNumber, order.orderNumber);
      expect(updated.status, OrderStatus.confirmed);
      expect(updated.paymentStatus, 'paid');
    });
  });

  group('OrderModel - Computed Properties', () {
    late user_model.Address testAddress;

    setUp(() {
      testAddress = user_model.Address(
        id: '1',
        label: 'Home',
        fullAddress: '123 Main St',
        latitude: 0,
        longitude: 0,
      );
    });

    test('totalItemCount calculates correctly', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: '1001',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '9999999999',
        items: [
          OrderItem(
            id: 'item-1',
            productId: 'prod-1',
            productName: 'Product 1',
            productImage: '',
            unit: 'pcs',
            quantity: 2,
            price: MonetaryValue(50.0),
            totalPrice: MonetaryValue(100.0),
          ),
          OrderItem(
            id: 'item-2',
            productId: 'prod-2',
            productName: 'Product 2',
            productImage: '',
            unit: 'pcs',
            quantity: 3,
            price: MonetaryValue(30.0),
            totalPrice: MonetaryValue(90.0),
          ),
        ],
        subtotal: MonetaryValue(190.0),
        tax: MonetaryValue(0.0),
        discount: MonetaryValue(0.0),
        deliveryCharge: MonetaryValue(0.0),
        totalAmount: MonetaryValue(190.0),
        walletAmountUsed: MonetaryValue(0.0),
        cashbackEarned: MonetaryValue(0.0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryType: DeliveryType.standard,
        status: OrderStatus.pending,
      );

      expect(order.totalItemCount, 5);
    });

    test('canCancel and canReturn properties work', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: '1001',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '9999999999',
        items: [],
        subtotal: MonetaryValue(100.0),
        tax: MonetaryValue(0.0),
        discount: MonetaryValue(0.0),
        deliveryCharge: MonetaryValue(0.0),
        totalAmount: MonetaryValue(100.0),
        walletAmountUsed: MonetaryValue(0.0),
        cashbackEarned: MonetaryValue(0.0),
        rewardPointsUsed: 0,
        rewardPointsEarned: 0,
        paymentMethod: PaymentMethod.cod,
        selectedPaymentMethod: PaymentMethod.cod,
        status: OrderStatus.pending,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryType: DeliveryType.standard,
      );

      expect(order.canCancel, true);
      expect(order.canReturn, false);

      final deliveredOrder = order.copyWith(status: OrderStatus.delivered);
      expect(deliveredOrder.canCancel, false);
      expect(deliveredOrder.canReturn, true);
    });
  });
}
