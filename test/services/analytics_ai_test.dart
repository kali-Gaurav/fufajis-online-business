import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fufajis_online/services/kpi_aggregation_service.dart';
import 'package:fufajis_online/services/forecast_service.dart';
import 'package:fufajis_online/services/fraud_detection_service.dart';
import 'package:fufajis_online/services/aws_bedrock_service.dart';
import 'package:fufajis_online/services/alert_service.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/payment_method.dart';
import 'package:fufajis_online/constants/order_status.dart';
import 'package:fufajis_online/utils/monetary_value.dart';
// ignore_for_file: must_be_immutable
import 'package:fufajis_online/models/user_model.dart';

// ─────────────── Mock Classes ───────────────

class MockSupabaseClient extends Mock implements SupabaseClient {
  final Map<String, List<Map<String, dynamic>>> queryResponses = {};
  final List<Map<String, dynamic>> upsertedRecords = [];

  @override
  SupabaseQueryBuilder from(String table) {
    return MockPostgrestQueryBuilder(table, this);
  }
}

class MockPostgrestQueryBuilder extends Mock implements SupabaseQueryBuilder {
  final String tableName;
  final MockSupabaseClient client;

  MockPostgrestQueryBuilder(this.tableName, this.client);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    final list = client.queryResponses[tableName] ?? [];
    return MockPostgrestFilterBuilder(list, client);
  }

  @override
  PostgrestFilterBuilder<PostgrestList> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = false,
  }) {
    if (values is Map<String, dynamic>) {
      client.upsertedRecords.add({'table': tableName, 'data': values});
    } else if (values is List<dynamic>) {
      for (var val in values) {
        if (val is Map<String, dynamic>) {
          client.upsertedRecords.add({'table': tableName, 'data': val});
        }
      }
    }
    return MockPostgrestFilterBuilder([], client);
  }
}

class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<PostgrestList> {
  final PostgrestList data;
  final MockSupabaseClient client;

  MockPostgrestFilterBuilder(this.data, this.client);

  @override
  PostgrestFilterBuilder<PostgrestList> gte(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<PostgrestList> lte(String column, Object value) => this;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> limit(int count, {String? referencedTable}) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) => this;

  @override
  Future<T> then<T>(FutureOr<T> Function(PostgrestList) onValue, {Function? onError}) {
    return Future.value(data).then(onValue, onError: onError);
  }
}

class MockAWSBedrockService extends Mock implements AWSBedrockService {
  String responseText = '# Executive AI Briefing\n- Demand is high\n- Stock is balanced';

  @override
  Future<String?> generateComplexReasoning(String prompt, {int maxTokens = 1000}) async {
    return responseText;
  }
}

class MockAlertService extends Mock implements AlertService {
  final List<Map<String, dynamic>> generatedSecurityAlerts = [];

  @override
  Future<void> generateSecurityAlert({
    required String securityEvent,
    required String details,
    String? userId,
  }) async {
    generatedSecurityAlerts.add({'event': securityEvent, 'details': details, 'userId': userId});
  }
}

// ─────────────── Main Test Suite ───────────────

void main() {
  group('Module 10 — Analytics & AI Engine Service Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockSupabaseClient mockSupabase;
    late MockAWSBedrockService mockBedrock;
    late MockAlertService mockAlertService;

    late KPIAggregationService kpiService;
    late ForecastService forecastService;
    late FraudDetectionService fraudService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockSupabase = MockSupabaseClient();
      mockBedrock = MockAWSBedrockService();
      mockAlertService = MockAlertService();

      // Get instances
      kpiService = KPIAggregationService();
      kpiService.client = mockSupabase;
      kpiService.firestore = fakeFirestore;

      forecastService = ForecastService();
      forecastService.client = mockSupabase;
      forecastService.firestore = fakeFirestore;
      forecastService.bedrock = mockBedrock;

      fraudService = FraudDetectionService();
      fraudService.client = mockSupabase;
      fraudService.alertService = mockAlertService;
    });

    group('KPIAggregationService Tests', () {
      test('aggregateSalesAndRevenue rolls up correctly and upserts reporting tables', () async {
        // Setup raw mock orders in Supabase
        mockSupabase.queryResponses['orders'] = [
          {
            'order_id': 'o_001',
            'shop_id': 'shop_123',
            'subtotal': 1000.0,
            'discount': 100.0,
            'delivery_fee': 40.0,
            'final_amount': 940.0,
            'order_status': 'delivered',
            'created_at': '2026-06-19T10:00:00Z',
          },
          {
            'order_id': 'o_002',
            'shop_id': 'shop_123',
            'subtotal': 500.0,
            'discount': 0.0,
            'delivery_fee': 40.0,
            'final_amount': 540.0,
            'order_status': 'cancelled',
            'created_at': '2026-06-19T11:00:00Z',
          },
        ];

        final success = await kpiService.aggregateSalesAndRevenue(
          DateTime(2026, 6, 19),
          DateTime(2026, 6, 19, 23, 59, 59),
        );

        expect(success, isTrue);

        // Verify sales_analytics rollup was upserted
        final salesUpserts = mockSupabase.upsertedRecords
            .where((r) => r['table'] == 'sales_analytics')
            .toList();
        expect(salesUpserts.length, equals(1));
        final salesRollup = salesUpserts.first['data'];
        expect(salesRollup['shop_id'], equals('shop_123'));
        expect(salesRollup['order_count'], equals(2));
        expect(salesRollup['delivered_count'], equals(1));
        expect(salesRollup['cancelled_count'], equals(1));
        expect(salesRollup['revenue'], equals(940.0));

        // Verify revenue_analytics metrics were upserted
        final revUpserts = mockSupabase.upsertedRecords
            .where((r) => r['table'] == 'revenue_analytics')
            .toList();
        expect(
          revUpserts.length,
          equals(6),
        ); // gross, net, refunds, delivery_fees, cogs, gross_profit
      });

      test('aggregateInventoryHealth aggregates product stock levels', () async {
        // Setup raw mock products
        mockSupabase.queryResponses['products'] = [
          {'id': 'p_001', 'stock': 0, 'price': 100.0}, // Out of stock
          {'id': 'p_002', 'stock': 2, 'price': 200.0}, // Low stock
          {'id': 'p_003', 'stock': 10, 'price': 50.0}, // Healthy stock
          {'id': 'p_004', 'stock': 60, 'price': 150.0}, // Dead stock potential
        ];

        final success = await kpiService.aggregateInventoryHealth();
        expect(success, isTrue);

        final invUpserts = mockSupabase.upsertedRecords
            .where((r) => r['table'] == 'inventory_analytics')
            .toList();
        expect(invUpserts.length, equals(4)); // out_of_stock, low_stock, dead_stock, turnover

        final oosRecord = invUpserts.firstWhere(
          (r) => r['data']['metric_id'].contains('out_of_stock_count'),
        );
        expect(oosRecord['data']['metric_value'], equals(1.0));

        final lowStockRecord = invUpserts.firstWhere(
          (r) => r['data']['metric_id'].contains('low_stock_count'),
        );
        expect(lowStockRecord['data']['metric_value'], equals(1.0));

        final deadStockRecord = invUpserts.firstWhere(
          (r) => r['data']['metric_id'].contains('dead_stock_value'),
        );
        // 60 * 150 * 0.4 = 3600.0
        expect(deadStockRecord['data']['metric_value'], equals(3600.0));
      });
    });

    group('ForecastService Tests', () {
      test('generateDemandForecast calculates Holt Smoothing correctly', () async {
        // Setup sales history of product unit quantities
        // 60 days series. Let's seed orders with created_at relative to now.
        final now = DateTime.now();
        final List<Map<String, dynamic>> rawOrderItems = [];

        // Seed product unit sales. Say, 2 items sold every day for the last 60 days.
        for (int i = 0; i < 60; i++) {
          final orderDateStr = now.subtract(Duration(days: i)).toIso8601String();
          rawOrderItems.add({
            'product_id': 'prod_rice',
            'quantity': 2.0,
            'orders': {'created_at': orderDateStr},
          });
        }

        mockSupabase.queryResponses['order_items'] = rawOrderItems;

        final forecasts = await forecastService.generateDemandForecast(forecastDays: 7);

        expect(forecasts.containsKey('prod_rice'), isTrue);
        // Under constant demand of 2 units/day, 7 days forecast should be close to 14.0
        expect(forecasts['prod_rice'], closeTo(14.0, 0.5));

        // Verify it upserts to ai_forecasts table in Supabase
        final forecastUpserts = mockSupabase.upsertedRecords
            .where((r) => r['table'] == 'ai_forecasts')
            .toList();
        expect(forecastUpserts.isNotEmpty, isTrue);
        expect(forecastUpserts.first['data']['prediction_type'], equals('demand'));
        expect(forecastUpserts.first['data']['predicted_value'], closeTo(14.0, 0.5));
      });

      test('generateRevenueForecast generates predictions and narrative', () async {
        // Setup daily net revenues for last 30 days
        final List<Map<String, dynamic>> rawRevenueAnalytics = [];
        final now = DateTime.now();
        for (int i = 0; i < 30; i++) {
          rawRevenueAnalytics.add({
            'metric_value': 1000.0,
            'created_at': now.subtract(Duration(days: i)).toIso8601String(),
          });
        }
        mockSupabase.queryResponses['revenue_analytics'] = rawRevenueAnalytics;

        final revenuePred = await forecastService.generateRevenueForecast(forecastDays: 7);
        expect(revenuePred, closeTo(7000.0, 50.0));

        // Verify narrative and forecasts are cached in Firestore
        final forecastDoc = await fakeFirestore.collection('forecasts').doc('latest').get();
        expect(forecastDoc.exists, isTrue);
        expect(forecastDoc.data()?['revenueForecast7Days'], closeTo(7000.0, 50.0));

        // Compile briefings via Bedrock
        final narrative = await forecastService.generateExplainableForecastBriefing(revenuePred, 7);
        expect(narrative, contains('Executive AI Briefing'));
      });
    });

    group('FraudDetectionService Tests', () {
      test(
        'analyzeOrderRisk assigns high risk score and triggers alert for geolocation mismatch',
        () async {
          final sampleOrder = OrderModel(
            id: 'order_fraud_1',
            orderNumber: 'FO-12345',
            customerId: 'user_cheater_1',
            customerName: 'Cheater Lal',
            customerPhone: '+919999999999',
            items: [],
            subtotal: MonetaryValue(1000.0),
            totalAmount: MonetaryValue(1050.0),
            paymentMethod: PaymentMethod.cod,
            status: OrderStatus.confirmed,
            paymentStatus: 'pending',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            // Location far outside branch central boundary
            liveLocation: const GeoPoint(20.0, 70.0),
            deliveryAddress: Address(id: 'addr_1', label: 'Home', latitude: 20.0, longitude: 70.0),
          );

          // Previous orders: Not first-time order
          mockSupabase.queryResponses['orders'] = [
            {'order_id': 'order_prev_1'},
          ];

          final score = await fraudService.analyzeOrderRisk(sampleOrder);
          // Far location adds 0.35
          expect(score, closeTo(0.35, 0.05));
        },
      );

      test(
        'analyzeOrderRisk flags high value first order and high value COD combination as critical',
        () async {
          final sampleOrder = OrderModel(
            id: 'order_fraud_critical',
            orderNumber: 'FO-99999',
            customerId: 'user_new_1',
            customerName: 'New Guest User',
            customerPhone: '+918888888888',
            items: [],
            subtotal: MonetaryValue(6000.0),
            totalAmount: MonetaryValue(6100.0), // Over 5000 threshold
            paymentMethod: PaymentMethod.cod, // High value COD
            status: OrderStatus.confirmed,
            paymentStatus: 'pending',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            liveLocation: const GeoPoint(26.9124, 75.7873), // Correct location
            deliveryAddress: Address(
              id: 'addr_2',
              label: 'Office',
              latitude: 26.9124,
              longitude: 75.7873,
            ),
          );

          // Previous orders: Empty (First-time order)
          mockSupabase.queryResponses['orders'] = [];

          final score = await fraudService.analyzeOrderRisk(sampleOrder);
          // First order > 5000: +0.25
          // COD > 3000: +0.20
          // Total risk score: 0.45
          expect(score, closeTo(0.45, 0.05));
        },
      );

      test('analyzeOrderRisk triggers alerts when risk exceeds critical threshold', () async {
        // Mismatched payment status (+0.40) + far outside location (+0.35) = 0.75 (> 0.7 threshold)
        final sampleOrder = OrderModel(
          id: 'order_high_fraud',
          orderNumber: 'FO-98765',
          customerId: 'user_bad_1',
          customerName: 'Mismatched User',
          customerPhone: '+917777777777',
          items: [],
          subtotal: MonetaryValue(1000.0),
          totalAmount: MonetaryValue(1050.0),
          paymentMethod: PaymentMethod.cod,
          status: OrderStatus.confirmed,
          paymentStatus: 'failed', // Failed status but active order (+0.40)
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          liveLocation: const GeoPoint(20.0, 70.0), // Far outside (+0.35)
          deliveryAddress: Address(id: 'addr_3', label: 'Work', latitude: 20.0, longitude: 70.0),
        );

        mockSupabase.queryResponses['orders'] = [
          {'order_id': 'order_prev_1'},
        ];

        final score = await fraudService.analyzeOrderRisk(sampleOrder);
        expect(score, equals(0.75));

        // Verify alert was upserted in Supabase
        final alertUpserts = mockSupabase.upsertedRecords
            .where((r) => r['table'] == 'ai_alerts')
            .toList();
        expect(alertUpserts.length, equals(1));
        expect(alertUpserts.first['data']['alert_type'], equals('fraud'));
        expect(alertUpserts.first['data']['severity'], equals('high'));

        // Verify alert was sent to AlertService
        expect(mockAlertService.generatedSecurityAlerts.length, equals(1));
        expect(mockAlertService.generatedSecurityAlerts.first['event'], equals('POTENTIAL_FRAUD'));
      });
    });
  });
}
