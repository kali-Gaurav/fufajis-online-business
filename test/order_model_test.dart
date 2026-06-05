import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/user_model.dart';
import 'package:fufajis_online/models/payment_method.dart';

void main() {
  group('OrderStatus Enum Tests', () {
    test('OrderStatus should have all required values', () {
      expect(OrderStatus.pending, equals(OrderStatus.pending));
      expect(OrderStatus.confirmed, equals(OrderStatus.confirmed));
      expect(OrderStatus.processing, equals(OrderStatus.processing));
      expect(OrderStatus.packed, equals(OrderStatus.packed));
      expect(OrderStatus.outForDelivery, equals(OrderStatus.outForDelivery));
      expect(OrderStatus.delivered, equals(OrderStatus.delivered));
      expect(OrderStatus.cancelled, equals(OrderStatus.cancelled));
      expect(OrderStatus.returned, equals(OrderStatus.returned));
      expect(OrderStatus.refunded, equals(OrderStatus.refunded));
    });

    test('OrderStatus values count should be 9', () {
      expect(OrderStatus.values.length, equals(9));
    });
  });

  group('OrderStatus Extension Tests', () {
    test('displayName should return correct string for each status', () {
      expect(OrderStatus.pending.displayName, equals('Pending'));
      expect(OrderStatus.confirmed.displayName, equals('Confirmed'));
      expect(OrderStatus.processing.displayName, equals('Processing'));
      expect(OrderStatus.packed.displayName, equals('Packed'));
      expect(OrderStatus.outForDelivery.displayName, equals('Out for Delivery'));
      expect(OrderStatus.delivered.displayName, equals('Delivered'));
      expect(OrderStatus.cancelled.displayName, equals('Cancelled'));
      expect(OrderStatus.returned.displayName, equals('Returned'));
      expect(OrderStatus.refunded.displayName, equals('Refunded'));
    });

    test('description should return non-empty string for each status', () {
      for (final status in OrderStatus.values) {
        expect(status.description, isNotEmpty);
      }
    });

    test('color should return valid Color for each status', () {
      for (final status in OrderStatus.values) {
        expect(status.color, isNotNull);
      }
    });

    test('icon should return valid IconData for each status', () {
      for (final status in OrderStatus.values) {
        expect(status.icon, isNotNull);
      }
    });

    test('isActive should be true for pending, confirmed, processing, packed, outForDelivery', () {
      expect(OrderStatus.pending.isActive, isTrue);
      expect(OrderStatus.confirmed.isActive, isTrue);
      expect(OrderStatus.processing.isActive, isTrue);
      expect(OrderStatus.packed.isActive, isTrue);
      expect(OrderStatus.outForDelivery.isActive, isTrue);
      expect(OrderStatus.delivered.isActive, isFalse);
      expect(OrderStatus.cancelled.isActive, isFalse);
    });

    test('isTerminal should be true for delivered, cancelled, returned, refunded', () {
      expect(OrderStatus.delivered.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);
      expect(OrderStatus.returned.isTerminal, isTrue);
      expect(OrderStatus.refunded.isTerminal, isTrue);
      expect(OrderStatus.pending.isTerminal, isFalse);
    });

    test('canCancel should be true for active states except outForDelivery', () {
      expect(OrderStatus.pending.canCancel, isTrue);
      expect(OrderStatus.confirmed.canCancel, isTrue);
      expect(OrderStatus.processing.canCancel, isTrue);
      expect(OrderStatus.packed.canCancel, isTrue);
      expect(OrderStatus.outForDelivery.canCancel, isFalse);
      expect(OrderStatus.delivered.canCancel, isFalse);
    });

    test('canReturn should be true only for delivered', () {
      expect(OrderStatus.delivered.canReturn, isTrue);
      expect(OrderStatus.pending.canReturn, isFalse);
      expect(OrderStatus.cancelled.canReturn, isFalse);
    });
  });

  group('StatusHistoryEntry Tests', () {
    test('fromMap should correctly parse StatusHistoryEntry', () {
      final map = {
        'status': 'OrderStatus.pending',
        'timestamp': DateTime(2024, 5, 19, 10, 30),
        'note': 'Order placed',
      };
      final entry = StatusHistoryEntry.fromMap(map);
      expect(entry.status, equals(OrderStatus.pending));
      expect(entry.note, equals('Order placed'));
    });

    test('toMap should correctly serialize StatusHistoryEntry', () {
      final entry = StatusHistoryEntry(
        status: OrderStatus.confirmed,
        timestamp: DateTime(2024, 5, 19, 11, 0),
        note: 'Order confirmed by shop',
      );
      final map = entry.toMap();
      expect(map['status'], equals('OrderStatus.confirmed'));
      expect(map['note'], equals('Order confirmed by shop'));
    });

    test('copyWith should create modified copy', () {
      final original = StatusHistoryEntry(
        status: OrderStatus.pending,
        timestamp: DateTime.now(),
      );
      final modified = original.copyWith(
        status: OrderStatus.confirmed,
        note: 'Confirmed',
      );
      expect(modified.status, equals(OrderStatus.confirmed));
      expect(modified.note, equals('Confirmed'));
      expect(original.status, equals(OrderStatus.pending));
    });
  });

  group('OrderItem Tests', () {
    test('OrderItem should have all required fields', () {
      final item = OrderItem(
        id: 'item-1',
        productId: 'prod-1',
        productName: 'Organic Rice',
        productImage: 'https://example.com/rice.jpg',
        unit: 'kg',
        quantity: 2,
        price: 50.0,
        totalPrice: 100.0,
        shopId: 'shop-1',
        shopName: 'Organic Store',
      );
      expect(item.id, equals('item-1'));
      expect(item.productName, equals('Organic Rice'));
      expect(item.quantity, equals(2));
      expect(item.price, equals(50.0));
      expect(item.totalPrice, equals(100.0));
    });

    test('OrderItem fromMap should correctly parse all fields', () {
      final map = {
        'id': 'item-1',
        'productId': 'prod-1',
        'productName': 'Organic Rice',
        'productImage': 'https://example.com/rice.jpg',
        'unit': 'kg',
        'quantity': 2,
        'price': 50.0,
        'originalPrice': 60.0,
        'discountPercentage': 16.67,
        'totalPrice': 100.0,
        'shopId': 'shop-1',
        'shopName': 'Organic Store',
        'selectedVariant': 'Premium',
        'selectedSize': '5kg',
        'selectedColor': null,
      };
      final item = OrderItem.fromMap(map);
      expect(item.id, equals('item-1'));
      expect(item.originalPrice, equals(60.0));
      expect(item.discountPercentage, equals(16.67));
      expect(item.selectedVariant, equals('Premium'));
    });

    test('OrderItem toMap should correctly serialize all fields', () {
      final item = OrderItem(
        id: 'item-1',
        productId: 'prod-1',
        productName: 'Organic Rice',
        productImage: 'https://example.com/rice.jpg',
        unit: 'kg',
        quantity: 2,
        price: 50.0,
        originalPrice: 60.0,
        discountPercentage: 16.67,
        totalPrice: 100.0,
        shopId: 'shop-1',
        shopName: 'Organic Store',
        selectedVariant: 'Premium',
        selectedSize: '5kg',
        selectedColor: 'White',
      );
      final map = item.toMap();
      expect(map['id'], equals('item-1'));
      expect(map['productName'], equals('Organic Rice'));
      expect(map['originalPrice'], equals(60.0));
      expect(map['selectedColor'], equals('White'));
    });

    test('OrderItem copyWith should create modified copy', () {
      final original = OrderItem(
        id: 'item-1',
        productId: 'prod-1',
        productName: 'Organic Rice',
        productImage: 'https://example.com/rice.jpg',
        unit: 'kg',
        quantity: 2,
        price: 50.0,
        totalPrice: 100.0,
      );
      final modified = original.copyWith(quantity: 3, price: 45.0);
      expect(modified.quantity, equals(3));
      expect(modified.price, equals(45.0));
      expect(original.quantity, equals(2));
    });
  });

  group('OrderModel Tests', () {
    late Address testAddress;
    late List<OrderItem> testItems;

    setUp(() {
      testAddress = Address(
        id: 'addr-1',
        label: 'Home',
        fullAddress: '123 Main Street',
        village: 'Test Village',
        landmark: 'Near Park',
        pincode: '123456',
        latitude: 12.9716,
        longitude: 77.5946,
      );

      testItems = [
        OrderItem(
          id: 'item-1',
          productId: 'prod-1',
          productName: 'Organic Rice',
          productImage: 'https://example.com/rice.jpg',
          unit: 'kg',
          quantity: 2,
          price: 50.0,
          totalPrice: 100.0,
        ),
        OrderItem(
          id: 'item-2',
          productId: 'prod-2',
          productName: 'Wheat Flour',
          productImage: 'https://example.com/flour.jpg',
          unit: 'kg',
          quantity: 1,
          price: 30.0,
          totalPrice: 30.0,
        ),
      ];
    });

    test('OrderModel should have all required fields', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: 'HLM-20240519-1234',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '+919876543210',
        customerEmail: 'john@example.com',
        items: testItems,
        subtotal: 130.0,
        deliveryCharge: 0.0,
        discount: 10.0,
        tax: 12.0,
        totalAmount: 132.0,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(order.id, equals('order-1'));
      expect(order.orderNumber, equals('HLM-20240519-1234'));
      expect(order.customerName, equals('John Doe'));
      expect(order.items.length, equals(2));
      expect(order.subtotal, equals(130.0));
      expect(order.totalAmount, equals(132.0));
    });

    test('OrderModel fromMap should correctly parse all fields', () {
      final map = {
        'id': 'order-1',
        'orderNumber': 'HLM-20240519-1234',
        'customerId': 'cust-1',
        'customerName': 'John Doe',
        'customerPhone': '+919876543210',
        'customerEmail': 'john@example.com',
        'items': [
          {
            'id': 'item-1',
            'productId': 'prod-1',
            'productName': 'Organic Rice',
            'productImage': 'https://example.com/rice.jpg',
            'unit': 'kg',
            'quantity': 2,
            'price': 50.0,
            'totalPrice': 100.0,
          },
        ],
        'subtotal': 130.0,
        'deliveryCharge': 0.0,
        'discount': 10.0,
        'tax': 12.0,
        'totalAmount': 132.0,
        'walletAmountUsed': 50.0,
        'cashbackEarned': 1.32,
        'rewardPointsUsed': 100,
        'rewardPointsEarned': 132,
        'paymentMethod': 'PaymentMethod.upi',
        'paymentId': 'pay_123',
        'paymentStatus': 'success',
        'status': 'OrderStatus.confirmed',
        'deliveryType': 'DeliveryType.standard',
        'deliveryAddress': testAddress.toMap(),
        'deliveryInstructions': 'Leave at door',
        'otp': '123456',
        'otpVerified': false,
        'createdAt': DateTime(2024, 5, 19, 10, 0),
        'updatedAt': DateTime(2024, 5, 19, 10, 30),
        'statusHistory': [
          {
            'status': 'OrderStatus.pending',
            'timestamp': DateTime(2024, 5, 19, 10, 0),
          },
          {
            'status': 'OrderStatus.confirmed',
            'timestamp': DateTime(2024, 5, 19, 10, 30),
          },
        ],
      };

      final order = OrderModel.fromMap(map);
      expect(order.id, equals('order-1'));
      expect(order.orderNumber, equals('HLM-20240519-1234'));
      expect(order.status, equals(OrderStatus.confirmed));
      expect(order.paymentMethod, equals(PaymentMethod.upi));
      expect(order.items.length, equals(1));
      expect(order.statusHistory.length, equals(2));
    });

    test('OrderModel toMap should correctly serialize all fields', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: 'HLM-20240519-1234',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '+919876543210',
        items: testItems,
        subtotal: 130.0,
        totalAmount: 132.0,
        deliveryAddress: testAddress,
        createdAt: DateTime(2024, 5, 19, 10, 0),
        updatedAt: DateTime(2024, 5, 19, 10, 30),
        statusHistory: [
          StatusHistoryEntry(
            status: OrderStatus.pending,
            timestamp: DateTime(2024, 5, 19, 10, 0),
          ),
        ],
      );

      final map = order.toMap();
      expect(map['id'], equals('order-1'));
      expect(map['orderNumber'], equals('HLM-20240519-1234'));
      expect(map['status'], equals('OrderStatus.pending'));
      expect((map['items'] as List).length, equals(2));
      expect((map['statusHistory'] as List).length, equals(1));
    });

    test('OrderModel copyWith should create modified copy', () {
      final original = OrderModel(
        id: 'order-1',
        orderNumber: 'HLM-20240519-1234',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '+919876543210',
        items: testItems,
        subtotal: 130.0,
        totalAmount: 132.0,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final modified = original.copyWith(
        status: OrderStatus.confirmed,
        paymentId: 'pay_123',
      );

      expect(modified.status, equals(OrderStatus.confirmed));
      expect(modified.paymentId, equals('pay_123'));
      expect(original.status, equals(OrderStatus.pending));
    });

    test('updateStatus should add entry to statusHistory', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: 'HLM-20240519-1234',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '+919876543210',
        items: testItems,
        subtotal: 130.0,
        totalAmount: 132.0,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = order.updateStatus(
        OrderStatus.confirmed,
        note: 'Order confirmed by shop',
      );

      expect(updated.status, equals(OrderStatus.confirmed));
      expect(updated.statusHistory.length, equals(1));
      expect(updated.statusHistory.first.status, equals(OrderStatus.confirmed));
      expect(updated.statusHistory.first.note, equals('Order confirmed by shop'));
    });

    test('totalItemCount should return sum of all item quantities', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: 'HLM-20240519-1234',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '+919876543210',
        items: testItems,
        subtotal: 130.0,
        totalAmount: 132.0,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(order.totalItemCount, equals(3));
    });

    test('totalSavings should calculate correctly', () {
      final itemsWithDiscount = [
        OrderItem(
          id: 'item-1',
          productId: 'prod-1',
          productName: 'Organic Rice',
          productImage: 'https://example.com/rice.jpg',
          unit: 'kg',
          quantity: 2,
          price: 50.0,
          originalPrice: 60.0,
          discountPercentage: 16.67,
          totalPrice: 100.0,
        ),
      ];

      final order = OrderModel(
        id: 'order-1',
        orderNumber: 'HLM-20240519-1234',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '+919876543210',
        items: itemsWithDiscount,
        subtotal: 100.0,
        totalAmount: 100.0,
        deliveryAddress: testAddress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(order.totalSavings, equals(20.0));
    });

    test('canCancel should reflect status correctly', () {
      final pendingOrder = OrderModel(
        id: 'order-1',
        orderNumber: 'HLM-20240519-1234',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '+919876543210',
        items: testItems,
        subtotal: 130.0,
        totalAmount: 132.0,
        deliveryAddress: testAddress,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final outForDeliveryOrder = pendingOrder.copyWith(
        status: OrderStatus.outForDelivery,
      );

      expect(pendingOrder.canCancel, isTrue);
      expect(outForDeliveryOrder.canCancel, isFalse);
    });

    test('canReturn should be true only for delivered orders', () {
      final pendingOrder = OrderModel(
        id: 'order-1',
        orderNumber: 'HLM-20240519-1234',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '+919876543210',
        items: testItems,
        subtotal: 130.0,
        totalAmount: 132.0,
        deliveryAddress: testAddress,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final deliveredOrder = pendingOrder.copyWith(
        status: OrderStatus.delivered,
      );

      expect(pendingOrder.canReturn, isFalse);
      expect(deliveredOrder.canReturn, isTrue);
    });

    test('statusDisplayInfo should return correct display info', () {
      final order = OrderModel(
        id: 'order-1',
        orderNumber: 'HLM-20240519-1234',
        customerId: 'cust-1',
        customerName: 'John Doe',
        customerPhone: '+919876543210',
        items: testItems,
        subtotal: 130.0,
        totalAmount: 132.0,
        deliveryAddress: testAddress,
        status: OrderStatus.delivered,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final info = order.statusDisplayInfo;
      expect(info.status, equals(OrderStatus.delivered));
      expect(info.displayName, equals('Delivered'));
      expect(info.color, equals(Colors.green));
    });
  });
}
