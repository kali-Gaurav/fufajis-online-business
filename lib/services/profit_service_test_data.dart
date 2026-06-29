/// Test data generation and validation for Profit Service
///
/// This file provides utilities for testing the profit calculation system
/// with sample orders and expected results
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Test case data for profit calculation validation
class ProfitTestCase {
  final String name;
  final double expectedGrossRevenue;
  final double expectedCogs;
  final double expectedRefunds;
  final double expectedCommissions;
  final double expectedNetProfit;
  final double expectedProfitMargin;
  final List<Map<String, dynamic>> testOrders;

  const ProfitTestCase({
    required this.name,
    required this.expectedGrossRevenue,
    required this.expectedCogs,
    required this.expectedRefunds,
    required this.expectedCommissions,
    required this.expectedNetProfit,
    required this.expectedProfitMargin,
    required this.testOrders,
  });
}

/// Sample test case from requirements:
/// - Order Revenue: 100
/// - COGS: 30 (30% cost)
/// - Refund: 10
/// - Commission: 10 (10% of revenue)
/// - Expected Net Profit: 50 (50% margin)
final ProfitTestCase basicTestCase = ProfitTestCase(
  name: 'Basic Test Case',
  expectedGrossRevenue: 100.0,
  expectedCogs: 30.0,
  expectedRefunds: 10.0,
  expectedCommissions: 10.0, // 10% of 100
  expectedNetProfit: 50.0, // 100 - 30 - 10 - 10
  expectedProfitMargin: 50.0, // (50 / 100) * 100
  testOrders: [
    {
      'id': 'order_001',
      'orderNumber': 'ORD-001',
      'customerId': 'cust_001',
      'customerName': 'Test Customer',
      'customerPhone': '9999999999',
      'items': [
        {
          'id': 'item_001',
          'productId': 'prod_001',
          'productName': 'Test Product',
          'productImage': '',
          'unit': 'kg',
          'quantity': 1,
          'price': 100.0,
          'totalPrice': 100.0,
        }
      ],
      'subtotal': 100.0,
      'deliveryCharge': 0.0,
      'discount': 0.0,
      'tax': 0.0,
      'totalAmount': 100.0,
      'walletAmountUsed': 0.0,
      'cashbackEarned': 0.0,
      'rewardPointsUsed': 0,
      'rewardPointsEarned': 0,
      'status': 'OrderStatus.delivered',
      'paymentMethod': 'PaymentMethod.cod',
      'deliveryType': 'DeliveryType.standard',
      'deliveryAddress': {
        'id': 'addr_001',
        'label': 'Home',
        'fullAddress': '123 Main St',
        'village': 'Test Village',
        'landmark': 'Near Market',
        'pincode': '100001',
        'latitude': 28.6139,
        'longitude': 77.2090,
      },
      'shopId': 'shop_001',
      'shopName': 'Test Shop',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'tipAmount': 0.0,
      'packagingFee': 0.0,
      'isGift': false,
    }
  ],
);

/// Complex test case with multiple items and varying costs
final ProfitTestCase complexMultiItemCase = ProfitTestCase(
  name: 'Multi-Item Complex Case',
  expectedGrossRevenue: 500.0,
  expectedCogs: 150.0, // Mixed cost percentages
  expectedRefunds: 50.0, // One order partially refunded
  expectedCommissions: 50.0, // 10% of 500
  expectedNetProfit: 250.0, // 500 - 150 - 50 - 50
  expectedProfitMargin: 50.0, // (250 / 500) * 100
  testOrders: [
    {
      'id': 'order_001',
      'orderNumber': 'ORD-001',
      'customerId': 'cust_001',
      'customerName': 'Customer 1',
      'customerPhone': '9999999999',
      'items': [
        {
          'id': 'item_001',
          'productId': 'prod_001',
          'productName': 'Tomatoes',
          'productImage': '',
          'unit': 'kg',
          'quantity': 2,
          'price': 50.0,
          'totalPrice': 100.0,
        },
        {
          'id': 'item_002',
          'productId': 'prod_002',
          'productName': 'Onions',
          'productImage': '',
          'unit': 'kg',
          'quantity': 3,
          'price': 30.0,
          'totalPrice': 90.0,
        }
      ],
      'subtotal': 190.0,
      'deliveryCharge': 0.0,
      'discount': 0.0,
      'tax': 0.0,
      'totalAmount': 190.0,
      'walletAmountUsed': 0.0,
      'cashbackEarned': 0.0,
      'rewardPointsUsed': 0,
      'rewardPointsEarned': 0,
      'status': 'OrderStatus.delivered',
      'paymentMethod': 'PaymentMethod.cod',
      'deliveryType': 'DeliveryType.standard',
      'deliveryAddress': {
        'id': 'addr_001',
        'label': 'Home',
        'fullAddress': '123 Main St',
        'village': 'Test Village',
        'landmark': 'Near Market',
        'pincode': '100001',
        'latitude': 28.6139,
        'longitude': 77.2090,
      },
      'shopId': 'shop_001',
      'shopName': 'Test Shop',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'tipAmount': 0.0,
      'packagingFee': 0.0,
      'isGift': false,
    },
    {
      'id': 'order_002',
      'orderNumber': 'ORD-002',
      'customerId': 'cust_002',
      'customerName': 'Customer 2',
      'customerPhone': '9999999998',
      'items': [
        {
          'id': 'item_003',
          'productId': 'prod_003',
          'productName': 'Potatoes',
          'productImage': '',
          'unit': 'kg',
          'quantity': 5,
          'price': 40.0,
          'totalPrice': 200.0,
        }
      ],
      'subtotal': 200.0,
      'deliveryCharge': 0.0,
      'discount': 0.0,
      'tax': 0.0,
      'totalAmount': 200.0,
      'walletAmountUsed': 0.0,
      'cashbackEarned': 0.0,
      'rewardPointsUsed': 0,
      'rewardPointsEarned': 0,
      'status': 'OrderStatus.refunded',
      'paymentMethod': 'PaymentMethod.cod',
      'deliveryType': 'DeliveryType.standard',
      'deliveryAddress': {
        'id': 'addr_002',
        'label': 'Office',
        'fullAddress': '456 Office St',
        'village': 'Test Village',
        'landmark': 'Near Office',
        'pincode': '100002',
        'latitude': 28.6200,
        'longitude': 77.2200,
      },
      'shopId': 'shop_001',
      'shopName': 'Test Shop',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'tipAmount': 0.0,
      'packagingFee': 0.0,
      'isGift': false,
    },
    {
      'id': 'order_003',
      'orderNumber': 'ORD-003',
      'customerId': 'cust_003',
      'customerName': 'Customer 3',
      'customerPhone': '9999999997',
      'items': [
        {
          'id': 'item_004',
          'productId': 'prod_004',
          'productName': 'Carrots',
          'productImage': '',
          'unit': 'kg',
          'quantity': 1,
          'price': 110.0,
          'totalPrice': 110.0,
        }
      ],
      'subtotal': 110.0,
      'deliveryCharge': 0.0,
      'discount': 0.0,
      'tax': 0.0,
      'totalAmount': 110.0,
      'walletAmountUsed': 0.0,
      'cashbackEarned': 0.0,
      'rewardPointsUsed': 0,
      'rewardPointsEarned': 0,
      'status': 'OrderStatus.delivered',
      'paymentMethod': 'PaymentMethod.cod',
      'deliveryType': 'DeliveryType.standard',
      'deliveryAddress': {
        'id': 'addr_003',
        'label': 'Home',
        'fullAddress': '789 Home St',
        'village': 'Test Village',
        'landmark': 'Near Home',
        'pincode': '100003',
        'latitude': 28.6300,
        'longitude': 77.2300,
      },
      'shopId': 'shop_001',
      'shopName': 'Test Shop',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'tipAmount': 0.0,
      'packagingFee': 0.0,
      'isGift': false,
    },
  ],
);

/// Edge case: Zero revenue scenario
const ProfitTestCase zeroRevenueCase = ProfitTestCase(
  name: 'Zero Revenue Case',
  expectedGrossRevenue: 0.0,
  expectedCogs: 0.0,
  expectedRefunds: 0.0,
  expectedCommissions: 0.0,
  expectedNetProfit: 0.0,
  expectedProfitMargin: 0.0,
  testOrders: [],
);

/// Edge case: Negative profit scenario
final ProfitTestCase negativeProfitCase = ProfitTestCase(
  name: 'Negative Profit Case (Loss)',
  expectedGrossRevenue: 100.0,
  expectedCogs: 80.0, // High COGS (80% cost)
  expectedRefunds: 0.0,
  expectedCommissions: 10.0, // 10% of 100
  expectedNetProfit: 10.0, // 100 - 80 - 10
  expectedProfitMargin: 10.0, // (10 / 100) * 100
  testOrders: [
    {
      'id': 'order_001',
      'orderNumber': 'ORD-001',
      'customerId': 'cust_001',
      'customerName': 'Test Customer',
      'customerPhone': '9999999999',
      'items': [
        {
          'id': 'item_001',
          'productId': 'prod_001',
          'productName': 'Expensive Import',
          'productImage': '',
          'unit': 'unit',
          'quantity': 1,
          'price': 100.0,
          'totalPrice': 100.0,
        }
      ],
      'subtotal': 100.0,
      'deliveryCharge': 0.0,
      'discount': 0.0,
      'tax': 0.0,
      'totalAmount': 100.0,
      'walletAmountUsed': 0.0,
      'cashbackEarned': 0.0,
      'rewardPointsUsed': 0,
      'rewardPointsEarned': 0,
      'status': 'OrderStatus.delivered',
      'paymentMethod': 'PaymentMethod.cod',
      'deliveryType': 'DeliveryType.standard',
      'deliveryAddress': {
        'id': 'addr_001',
        'label': 'Home',
        'fullAddress': '123 Main St',
        'village': 'Test Village',
        'landmark': 'Near Market',
        'pincode': '100001',
        'latitude': 28.6139,
        'longitude': 77.2090,
      },
      'shopId': 'shop_001',
      'shopName': 'Test Shop',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'tipAmount': 0.0,
      'packagingFee': 0.0,
      'isGift': false,
    }
  ],
);

/// High margin scenario (cheap products, high selling price)
const ProfitTestCase highMarginCase = ProfitTestCase(
  name: 'High Profit Margin Case',
  expectedGrossRevenue: 1000.0,
  expectedCogs: 100.0, // Only 10% cost
  expectedRefunds: 0.0,
  expectedCommissions: 100.0, // 10% of 1000
  expectedNetProfit: 800.0, // 1000 - 100 - 100
  expectedProfitMargin: 80.0, // (800 / 1000) * 100
  testOrders: [], // Add sample orders as needed
);
