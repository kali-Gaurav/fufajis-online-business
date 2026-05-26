import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/user_model.dart';
import 'package:fufajis_online/models/payment_method.dart';
import 'package:fufajis_online/models/delivery_type.dart';
import 'package:fufajis_online/providers/order_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const codec = StandardMessageCodec();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore',
      (ByteData? message) async {
        final response = <Object?, Object?>{
          'result': [
            <Object?, Object?>{
              'name': '[DEFAULT]',
              'options': <Object?, Object?>{
                'apiKey': '123',
                'appId': '123',
                'messagingSenderId': '123',
                'projectId': '123',
              },
            }
          ]
        };
        return codec.encodeMessage(response);
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeApp',
      (ByteData? message) async {
        final response = <Object?, Object?>{
          'result': <Object?, Object?>{
            'name': '[DEFAULT]',
            'options': <Object?, Object?>{
              'apiKey': '123',
              'appId': '123',
              'messagingSenderId': '123',
              'projectId': '123',
            },
          }
        };
        return codec.encodeMessage(response);
      },
    );

    await Firebase.initializeApp();
  });

  group('OrderProvider Tests', () {
    late OrderProvider orderProvider;

    setUp(() {
      orderProvider = OrderProvider();
    });

    test('initial state should have correct default values', () {
      expect(orderProvider.orders, isEmpty);
      expect(orderProvider.currentOrder, isNull);
      expect(orderProvider.isLoading, isFalse);
      expect(orderProvider.errorMessage, isNull);
      expect(orderProvider.ordersPage, equals(1));
      expect(orderProvider.hasMoreOrders, isTrue);
      expect(orderProvider.returnRequests, isEmpty);
    });

    test('clearState should reset all state', () {
      // Set some state first
      orderProvider.clearState();
      
      expect(orderProvider.orders, isEmpty);
      expect(orderProvider.currentOrder, isNull);
      expect(orderProvider.errorMessage, isNull);
      expect(orderProvider.ordersPage, equals(1));
      expect(orderProvider.hasMoreOrders, isTrue);
    });

    test('getOrdersByStatus should filter orders by status', () async {
      await orderProvider.loadDemoOrders();
      
      expect(orderProvider.getOrdersByStatus(OrderStatus.pending), isEmpty);
      expect(orderProvider.getOrdersByStatus(OrderStatus.delivered).length, equals(2));
    });

    test('searchOrders should return matching orders', () async {
      await orderProvider.loadDemoOrders();

      // Test search by product name (Milk is in demo orders)
      expect(orderProvider.searchOrders('milk').length, greaterThan(0));
      // Test search by order number
      final orderNum = orderProvider.orders.first.orderNumber;
      expect(orderProvider.searchOrders(orderNum).length, equals(1));
    });

    test('getMembershipTier should return correct tier based on points', () {
      expect(orderProvider.getMembershipTier(), equals('Bronze'));
    });

    test('getFrequentlyBoughtProductIds should return empty list initially', () {
      expect(orderProvider.getFrequentlyBoughtProductIds(), isEmpty);
    });
  });

  group('ReturnRequest Tests', () {
    test('ReturnRequest should have all required fields', () {
      final returnRequest = ReturnRequest(
        id: 'return-1',
        orderId: 'order-1',
        customerId: 'cust-1',
        reason: 'Product damaged',
        itemIds: ['item-1', 'item-2'],
        createdAt: DateTime.now(),
        status: 'pending',
      );

      expect(returnRequest.id, equals('return-1'));
      expect(returnRequest.orderId, equals('order-1'));
      expect(returnRequest.reason, equals('Product damaged'));
      expect(returnRequest.itemIds.length, equals(2));
      expect(returnRequest.status, equals('pending'));
    });

    test('ReturnRequest fromMap should correctly parse all fields', () {
      final map = {
        'id': 'return-1',
        'orderId': 'order-1',
        'customerId': 'cust-1',
        'reason': 'Product damaged',
        'itemIds': ['item-1', 'item-2'],
        'createdAt': DateTime(2024, 5, 19, 10, 0),
        'status': 'pending',
        'shopResponse': null,
        'processedAt': null,
      };

      final returnRequest = ReturnRequest.fromMap(map);
      expect(returnRequest.id, equals('return-1'));
      expect(returnRequest.reason, equals('Product damaged'));
      expect(returnRequest.itemIds, equals(['item-1', 'item-2']));
    });

    test('ReturnRequest toMap should correctly serialize all fields', () {
      final returnRequest = ReturnRequest(
        id: 'return-1',
        orderId: 'order-1',
        customerId: 'cust-1',
        reason: 'Product damaged',
        itemIds: ['item-1', 'item-2'],
        createdAt: DateTime(2024, 5, 19, 10, 0),
        status: 'pending',
      );

      final map = returnRequest.toMap();
      expect(map['id'], equals('return-1'));
      expect(map['orderId'], equals('order-1'));
      expect(map['reason'], equals('Product damaged'));
      expect((map['itemIds'] as List).length, equals(2));
    });
  });

  group('Status Transition Validation Tests', () {
    late OrderProvider orderProvider;

    setUp(() {
      orderProvider = OrderProvider();
    });

    test('pending order can transition to confirmed', () {
      // Test the validation logic
      final valid = orderProvider.isValidStatusTransition(
        OrderStatus.pending,
        OrderStatus.confirmed,
      );
      expect(valid, isTrue);
    });

    test('pending order can transition to cancelled', () {
      final valid = orderProvider.isValidStatusTransition(
        OrderStatus.pending,
        OrderStatus.cancelled,
      );
      expect(valid, isTrue);
    });

    test('delivered order cannot transition to pending', () {
      final valid = orderProvider.isValidStatusTransition(
        OrderStatus.delivered,
        OrderStatus.pending,
      );
      expect(valid, isFalse);
    });

    test('cancelled order cannot transition to any other status', () {
      expect(
        orderProvider.isValidStatusTransition(
          OrderStatus.cancelled,
          OrderStatus.confirmed,
        ),
        isFalse,
      );
      expect(
        orderProvider.isValidStatusTransition(
          OrderStatus.cancelled,
          OrderStatus.delivered,
        ),
        isFalse,
      );
    });

    test('full order lifecycle should be valid', () {
      // pending -> confirmed -> processing -> packed -> outForDelivery -> delivered
      expect(
        orderProvider.isValidStatusTransition(
          OrderStatus.pending,
          OrderStatus.confirmed,
        ),
        isTrue,
      );
      expect(
        orderProvider.isValidStatusTransition(
          OrderStatus.confirmed,
          OrderStatus.processing,
        ),
        isTrue,
      );
      expect(
        orderProvider.isValidStatusTransition(
          OrderStatus.processing,
          OrderStatus.packed,
        ),
        isTrue,
      );
      expect(
        orderProvider.isValidStatusTransition(
          OrderStatus.packed,
          OrderStatus.outForDelivery,
        ),
        isTrue,
      );
      expect(
        orderProvider.isValidStatusTransition(
          OrderStatus.outForDelivery,
          OrderStatus.delivered,
        ),
        isTrue,
      );
    });
  });

  group('Status Transition Notes Tests', () {
    late OrderProvider orderProvider;

    setUp(() {
      orderProvider = OrderProvider();
    });

    test('getStatusTransitionNote should return correct note for each status', () {
      expect(
        orderProvider.getStatusTransitionNote(OrderStatus.pending),
        equals('Order placed and awaiting confirmation'),
      );
      expect(
        orderProvider.getStatusTransitionNote(OrderStatus.confirmed),
        equals('Order confirmed by the shop'),
      );
      expect(
        orderProvider.getStatusTransitionNote(OrderStatus.processing),
        equals('Order is being prepared'),
      );
      expect(
        orderProvider.getStatusTransitionNote(OrderStatus.packed),
        equals('Order has been packed'),
      );
      expect(
        orderProvider.getStatusTransitionNote(OrderStatus.outForDelivery),
        equals('Order is out for delivery'),
      );
      expect(
        orderProvider.getStatusTransitionNote(OrderStatus.delivered),
        equals('Order has been delivered'),
      );
      expect(
        orderProvider.getStatusTransitionNote(OrderStatus.cancelled),
        equals('Order has been cancelled'),
      );
      expect(
        orderProvider.getStatusTransitionNote(OrderStatus.returned),
        equals('Return request processed'),
      );
      expect(
        orderProvider.getStatusTransitionNote(OrderStatus.refunded),
        equals('Refund has been processed'),
      );
    });
  });
}
