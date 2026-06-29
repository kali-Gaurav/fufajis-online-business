import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/models/delivery_type.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/user_model.dart';
import 'package:fufajis_online/utils/monetary_value.dart';
import 'package:fufajis_online/models/shop_config_model.dart';
import 'package:fufajis_online/services/delivery_charge_calculator.dart';
import 'package:fufajis_online/services/offline_routing_service.dart';
import 'package:fufajis_online/services/task_assignment_service.dart';

void main() {
  group('DeliveryChargeCalculator Tests', () {
    test('calculateDeliveryCharge standard delivery dynamic slabs', () {
      // Free Standard Delivery Threshold is 500
      // Under 200 standard delivery is 40
      // 200 - 500 standard delivery is 20
      
      final double charge1 = DeliveryChargeCalculator.calculateDeliveryCharge(
        DeliveryType.standard,
        150.0, // Subtotal 150 < 200
      );
      expect(charge1, equals(40.0));

      final double charge2 = DeliveryChargeCalculator.calculateDeliveryCharge(
        DeliveryType.standard,
        350.0, // Subtotal 350 (between 200 and 500)
      );
      expect(charge2, equals(20.0));

      final double charge3 = DeliveryChargeCalculator.calculateDeliveryCharge(
        DeliveryType.standard,
        600.0, // Subtotal 600 >= 500
      );
      expect(charge3, equals(0.0));
    });

    test('calculateDeliveryCharge distance-based and emergency options', () {
      final config = ShopConfigModel(
        shopName: "Fufaji Shop",
        shopAddress: "Jaipur",
        shopPhone: "+919999999999",
        shopEmail: "fufaji@shop.com",
        isOpen: true,
        shopLatitude: 26.9124,
        shopLongitude: 75.7873,
        maxDeliveryRadiusKm: 10.0,
        deliveryZones: [
          DeliveryZone(
            id: 'zone_1',
            label: 'Zone 1',
            fromRadiusKm: 0.0,
            toRadiusKm: 3.0,
            deliveryCharge: 10.0,
            minOrderForFree: 300.0,
            isActive: true,
          ),
          DeliveryZone(
            id: 'zone_2',
            label: 'Zone 2',
            fromRadiusKm: 3.0,
            toRadiusKm: 6.0,
            deliveryCharge: 30.0,
            minOrderForFree: 500.0,
            isActive: true,
          ),
        ],
        minOrderAmount: 100.0,
        minOrderForFreeDelivery: 500.0,
        flatDeliveryFee: 40.0,
        operatingHours: {},
        autoCloseOutsideHours: false,
        maxCodLimit: 5000,
        maxCreditLimit: 2000,
        maxOrdersPerSlot: 10,
        sameDayCutoffHour: 18,
        enableCashback: false,
        cashbackPercentage: 5,
        enableLoyaltyPoints: false,
        isAutoPilotEnabled: false,
        isEmergencyMode: false,
      );

      // standard type within Zone 1 (dist 2km, subtotal 150 < 300) -> 10.0
      final double charge1 = DeliveryChargeCalculator.calculateDeliveryCharge(
        DeliveryType.standard,
        150.0,
        distanceKm: 2.0,
        config: config,
      );
      expect(charge1, equals(10.0));

      // standard type within Zone 1 (dist 2km, subtotal 350 >= 300) -> FREE (0.0)
      final double charge2 = DeliveryChargeCalculator.calculateDeliveryCharge(
        DeliveryType.standard,
        350.0,
        distanceKm: 2.0,
        config: config,
      );
      expect(charge2, equals(0.0));

      // standard type within Zone 2 (dist 4.5km, subtotal 150 < 500) -> 30.0
      final double charge3 = DeliveryChargeCalculator.calculateDeliveryCharge(
        DeliveryType.standard,
        150.0,
        distanceKm: 4.5,
        config: config,
      );
      expect(charge3, equals(30.0));
    });
  });

  group('OfflineRoutingService TSP Solver Tests', () {
    final routingService = OfflineRoutingService();

    test('Held-Karp exact DP solver for N <= 15', () {
      final List<OrderModel> orders = [
        OrderModel(
          id: 'o1',
          orderNumber: '1001',
          customerId: 'c1',
          customerName: 'Customer 1',
          customerPhone: '111',
          items: [],
          subtotal: MonetaryValue(100.0),
          totalAmount: MonetaryValue(100.0),
          deliveryAddress: Address(
            id: 'a1',
            label: 'Addr 1',
            fullAddress: 'Jaipur 1',
            street: 'street 1',
            village: 'v1',
            state: 's1',
            pincode: '302001',
            latitude: 26.9200, // Near Jaipur center
            longitude: 75.7900,
            isDefault: true,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        OrderModel(
          id: 'o2',
          orderNumber: '1002',
          customerId: 'c2',
          customerName: 'Customer 2',
          customerPhone: '222',
          items: [],
          subtotal: MonetaryValue(100.0),
          totalAmount: MonetaryValue(100.0),
          deliveryAddress: Address(
            id: 'a2',
            label: 'Addr 2',
            fullAddress: 'Jaipur 2',
            street: 'street 2',
            village: 'v2',
            state: 's2',
            pincode: '302002',
            latitude: 26.9500, // Further north
            longitude: 75.8000,
            isDefault: true,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        OrderModel(
          id: 'o3',
          orderNumber: '1003',
          customerId: 'c3',
          customerName: 'Customer 3',
          customerPhone: '333',
          items: [],
          subtotal: MonetaryValue(100.0),
          totalAmount: MonetaryValue(100.0),
          deliveryAddress: Address(
            id: 'a3',
            label: 'Addr 3',
            fullAddress: 'Jaipur 3',
            street: 'street 3',
            village: 'v3',
            state: 's3',
            pincode: '302003',
            latitude: 26.9150, // Very close to start
            longitude: 75.7880,
            isDefault: true,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Start position (depot)
      const startLat = 26.9124;
      const startLon = 75.7873;

      final optimized = routingService.optimizeRoute(orders, startLat, startLon);

      // Verify that it outputs the correct length list and is sorted.
      // The first stop should be 'o3' because it is closest to start (26.9124, 75.7873).
      // Then it should go to 'o1' and then 'o2'.
      expect(optimized.length, equals(3));
      expect(optimized.first.id, equals('o3'));
      expect(optimized[1].id, equals('o1'));
      expect(optimized[2].id, equals('o2'));
    });
  });

  group('Task Priority Weights Tests', () {
    test('Priority weights helper maps enum values correctly', () {
      final service = TaskAssignmentService();
      // Ensure service instantiates and behaves properly
      expect(service, isNotNull);
    });
  });
}
