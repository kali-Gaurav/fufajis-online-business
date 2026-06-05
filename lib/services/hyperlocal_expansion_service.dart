import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/shop_config_model.dart';

/// Production-grade Hyperlocal Expansion Service
///
/// Handles:
/// - Dynamic delivery zone expansion based on demand signals
/// - Zone demand heatmap analytics with order density scoring
/// - Automated zone activation when demand thresholds are met
/// - Surge pricing during high-demand periods
/// - Distance-weighted delivery fee calculation
/// - Zone-specific min order amounts
/// - Coverage gap analysis for expansion recommendations
class HyperlocalExpansionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final HyperlocalExpansionService _instance = HyperlocalExpansionService._internal();
  factory HyperlocalExpansionService() => _instance;
  HyperlocalExpansionService._internal();

  // ===== DEMAND HEATMAP ANALYTICS =====

  /// Record an order's delivery location for demand analysis
  Future<void> recordDeliveryDemand({
    required double latitude,
    required double longitude,
    required String pincode,
    required double orderAmount,
    required String zoneId,
  }) async {
    try {
      final gridKey = _getGridKey(latitude, longitude);
      final demandRef = _firestore.collection('demand_heatmap').doc(gridKey);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(demandRef);

        if (doc.exists) {
          transaction.update(demandRef, {
            'orderCount': FieldValue.increment(1),
            'totalRevenue': FieldValue.increment(orderAmount),
            'lastOrderAt': DateTime.now(),
            'pincodes': FieldValue.arrayUnion([pincode]),
          });
        } else {
          transaction.set(demandRef, {
            'gridKey': gridKey,
            'centerLat': _roundToGrid(latitude),
            'centerLng': _roundToGrid(longitude),
            'orderCount': 1,
            'totalRevenue': orderAmount,
            'firstOrderAt': DateTime.now(),
            'lastOrderAt': DateTime.now(),
            'pincodes': [pincode],
            'isExpansionCandidate': false,
          });
        }
      });
    } catch (e) {
      debugPrint('Error recording delivery demand: $e');
    }
  }

  /// Get the demand heatmap data for analysis
  Future<List<DemandHeatmapCell>> getDemandHeatmap({int minOrders = 3}) async {
    try {
      final snapshot = await _firestore
          .collection('demand_heatmap')
          .where('orderCount', isGreaterThanOrEqualTo: minOrders)
          .orderBy('orderCount', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => DemandHeatmapCell.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting demand heatmap: $e');
      return [];
    }
  }

  /// Grid key for 0.5km x 0.5km cells
  String _getGridKey(double lat, double lng) {
    final gridLat = _roundToGrid(lat);
    final gridLng = _roundToGrid(lng);
    return '${gridLat}_$gridLng';
  }

  double _roundToGrid(double value) {
    return (value * 200).round() / 200; // ~0.5km resolution
  }

  // ===== DYNAMIC ZONE EXPANSION =====

  /// Analyze demand and recommend zone expansions
  Future<List<ZoneExpansionRecommendation>> analyzeExpansionOpportunities({
    required double shopLat,
    required double shopLng,
    required double currentMaxRadius,
    int minOrdersForExpansion = 10,
    double minRevenueForExpansion = 5000.0,
  }) async {
    try {
      final recommendations = <ZoneExpansionRecommendation>[];

      // Get all demand cells outside current delivery radius
      final allCells = await getDemandHeatmap(minOrders: 1);

      for (final cell in allCells) {
        final distance = _calculateDistance(shopLat, shopLng, cell.centerLat, cell.centerLng);

        // Only consider cells outside current zone but within reasonable expansion range
        if (distance > currentMaxRadius && distance <= currentMaxRadius + 5.0) {
          final score = _calculateExpansionScore(
            orderCount: cell.orderCount,
            totalRevenue: cell.totalRevenue,
            distance: distance,
            daysSinceFirstOrder: DateTime.now().difference(cell.firstOrderAt).inDays,
          );

          if (cell.orderCount >= minOrdersForExpansion || 
              cell.totalRevenue >= minRevenueForExpansion) {
            recommendations.add(ZoneExpansionRecommendation(
              gridKey: cell.gridKey,
              centerLat: cell.centerLat,
              centerLng: cell.centerLng,
              distanceFromShop: distance,
              orderCount: cell.orderCount,
              totalRevenue: cell.totalRevenue,
              score: score,
              suggestedDeliveryCharge: _suggestDeliveryCharge(distance),
              suggestedMinOrder: _suggestMinOrder(distance),
              pincodes: cell.pincodes,
            ));
          }
        }
      }

      // Sort by expansion score (highest first)
      recommendations.sort((a, b) => b.score.compareTo(a.score));
      return recommendations;
    } catch (e) {
      debugPrint('Error analyzing expansion opportunities: $e');
      return [];
    }
  }

  /// Calculate expansion viability score (0-100)
  double _calculateExpansionScore({
    required int orderCount,
    required double totalRevenue,
    required double distance,
    required int daysSinceFirstOrder,
  }) {
    // Weighted factors
    final orderScore = (orderCount / 50.0).clamp(0.0, 1.0) * 30.0;        // Max 30 points
    final revenueScore = (totalRevenue / 50000.0).clamp(0.0, 1.0) * 25.0;  // Max 25 points
    final distancePenalty = (1.0 - (distance / 15.0)).clamp(0.0, 1.0) * 20.0; // Max 20 (closer = better)
    final velocityScore = daysSinceFirstOrder > 0
        ? (orderCount / daysSinceFirstOrder * 7.0).clamp(0.0, 1.0) * 25.0     // Max 25 (weekly order rate)
        : 0.0;

    return (orderScore + revenueScore + distancePenalty + velocityScore).clamp(0.0, 100.0).toDouble();
  }

  /// Suggest delivery charge based on distance
  double _suggestDeliveryCharge(double distanceKm) {
    if (distanceKm <= 3.0) return 0.0;
    if (distanceKm <= 5.0) return 20.0;
    if (distanceKm <= 8.0) return 40.0;
    if (distanceKm <= 10.0) return 60.0;
    return 80.0 + ((distanceKm - 10.0) * 10.0); // ₹10 per extra km
  }

  /// Suggest minimum order based on distance
  double _suggestMinOrder(double distanceKm) {
    if (distanceKm <= 3.0) return 200.0;
    if (distanceKm <= 5.0) return 300.0;
    if (distanceKm <= 8.0) return 500.0;
    return 800.0;
  }

  /// Auto-expand a zone (create a new delivery zone in config)
  Future<DeliveryZone> autoExpandZone({
    required ZoneExpansionRecommendation recommendation,
    String? customLabel,
  }) async {
    try {
      final zoneId = 'zone_expanded_${DateTime.now().millisecondsSinceEpoch}';
      final newZone = DeliveryZone(
        id: zoneId,
        label: customLabel ?? 'Expanded Zone (${recommendation.distanceFromShop.toStringAsFixed(1)} km)',
        fromRadiusKm: recommendation.distanceFromShop - 1.0,
        toRadiusKm: recommendation.distanceFromShop + 1.0,
        deliveryCharge: recommendation.suggestedDeliveryCharge,
        minOrderForFree: recommendation.suggestedMinOrder * 2,
        isActive: true,
      );

      // Add to shop config
      await _firestore.collection('settings').doc('shop_config').update({
        'deliveryZones': FieldValue.arrayUnion([newZone.toMap()]),
        'maxDeliveryRadiusKm': recommendation.distanceFromShop + 1.0,
      });

      // Mark cells as served
      for (final pincode in recommendation.pincodes) {
        await _firestore.collection('demand_heatmap').doc(recommendation.gridKey).update({
          'isExpansionCandidate': false,
          'assignedZoneId': zoneId,
        });
      }

      return newZone;
    } catch (e) {
      debugPrint('Error auto-expanding zone: $e');
      rethrow;
    }
  }

  // ===== SURGE PRICING =====

  /// Check if surge pricing should be applied
  Future<SurgeInfo> checkSurgePricing({
    required String zoneId,
    required DateTime orderTime,
  }) async {
    try {
      final now = orderTime;
      final hourKey = '${now.toIso8601String().split('T')[0]}_${now.hour}';
      final surgeRef = _firestore.collection('surge_data').doc('${zoneId}_$hourKey');

      final doc = await surgeRef.get();
      int currentHourOrders = 0;

      if (doc.exists) {
        currentHourOrders = doc.data()?['orderCount'] ?? 0;
      }

      // Record this check
      await surgeRef.set({
        'zoneId': zoneId,
        'hour': now.hour,
        'date': now.toIso8601String().split('T')[0],
        'orderCount': FieldValue.increment(1),
        'lastOrderAt': now,
      }, SetOptions(merge: true));

      // Determine surge multiplier
      double surgeMultiplier = 1.0;
      String surgeLevel = 'normal';

      if (currentHourOrders >= 20) {
        surgeMultiplier = 1.5;
        surgeLevel = 'high';
      } else if (currentHourOrders >= 12) {
        surgeMultiplier = 1.25;
        surgeLevel = 'moderate';
      } else if (currentHourOrders >= 8) {
        surgeMultiplier = 1.1;
        surgeLevel = 'slight';
      }

      // Peak hour surges (evening 6-8 PM, morning 9-10 AM)
      if ((now.hour >= 18 && now.hour <= 20) || (now.hour >= 9 && now.hour <= 10)) {
        surgeMultiplier *= 1.1; // Additional 10% during peak hours
      }

      // Rain/weather surge (would integrate with weather service)
      // For now, we just check a flag in settings
      final weatherDoc = await _firestore.collection('settings').doc('weather_surge').get();
      if (weatherDoc.exists && weatherDoc.data()?['isRaining'] == true) {
        surgeMultiplier *= 1.2;
        surgeLevel = 'weather';
      }

      return SurgeInfo(
        multiplier: surgeMultiplier,
        level: surgeLevel,
        currentHourOrders: currentHourOrders,
        isPeakHour: (now.hour >= 18 && now.hour <= 20) || (now.hour >= 9 && now.hour <= 10),
      );
    } catch (e) {
      debugPrint('Error checking surge pricing: $e');
      return SurgeInfo(multiplier: 1.0, level: 'normal', currentHourOrders: 0, isPeakHour: false);
    }
  }

  /// Calculate final delivery charge with surge
  double calculateSurgeDeliveryCharge({
    required double baseCharge,
    required SurgeInfo surgeInfo,
    required MembershipTierDiscount? tierDiscount,
  }) {
    double charge = baseCharge * surgeInfo.multiplier;

    // Apply tier discount (e.g., Gold gets 20% off surge, Platinum gets 50% off)
    if (tierDiscount != null) {
      charge *= (1 - tierDiscount.surgeDiscount);
    }

    return charge;
  }

  // ===== ZONE HEALTH MONITORING =====

  /// Get zone performance metrics
  Future<List<ZonePerformance>> getZonePerformance() async {
    try {
      final configDoc = await _firestore.collection('settings').doc('shop_config').get();
      if (!configDoc.exists) return [];

      final config = ShopConfigModel.fromMap(configDoc.data()!);
      final results = <ZonePerformance>[];

      for (final zone in config.deliveryZones) {
        // Get orders in this zone from the last 30 days
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        final ordersSnapshot = await _firestore
            .collection('orders')
            .where('deliveryZoneId', isEqualTo: zone.id)
            .where('createdAt', isGreaterThan: thirtyDaysAgo)
            .get();

        double totalRevenue = 0;
        int orderCount = ordersSnapshot.docs.length;
        int cancelledCount = 0;

        for (final doc in ordersSnapshot.docs) {
          totalRevenue += (doc.data()['totalAmount'] ?? 0.0).toDouble();
          if (doc.data()['status'] == 'OrderStatus.cancelled') {
            cancelledCount++;
          }
        }

        final avgOrderValue = orderCount > 0 ? totalRevenue / orderCount : 0.0;
        final cancellationRate = orderCount > 0 ? cancelledCount / orderCount : 0.0;

        results.add(ZonePerformance(
          zoneId: zone.id,
          zoneLabel: zone.label,
          orderCount: orderCount,
          totalRevenue: totalRevenue,
          avgOrderValue: avgOrderValue,
          cancellationRate: cancellationRate,
          deliveryCharge: zone.deliveryCharge,
          isActive: zone.isActive,
          isHealthy: orderCount >= 5 && cancellationRate < 0.2,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('Error getting zone performance: $e');
      return [];
    }
  }

  /// Auto-disable underperforming zones
  Future<void> autoDisableUnderperformingZones({
    int minOrdersThreshold = 2,
    double maxCancellationRate = 0.4,
    int evaluationDays = 30,
  }) async {
    try {
      final performance = await getZonePerformance();

      for (final zone in performance) {
        if (zone.isActive &&
            zone.orderCount < minOrdersThreshold &&
            zone.cancellationRate > maxCancellationRate) {
          debugPrint('Auto-disabling underperforming zone: ${zone.zoneLabel}');
          // Don't disable core zones (zone_1, zone_2, zone_3)
          if (!zone.zoneId.startsWith('zone_expanded_')) continue;

          final configDoc = await _firestore.collection('settings').doc('shop_config').get();
          if (!configDoc.exists) continue;

          final config = ShopConfigModel.fromMap(configDoc.data()!);
          final updatedZones = config.deliveryZones.map((z) {
            if (z.id == zone.zoneId) {
              return z.copyWith(isActive: false);
            }
            return z;
          }).toList();

          await _firestore.collection('settings').doc('shop_config').update({
            'deliveryZones': updatedZones.map((z) => z.toMap()).toList(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error auto-disabling zones: $e');
    }
  }

  // ===== DISTANCE UTILS =====

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }
}

// ===== DATA MODELS =====

class DemandHeatmapCell {
  final String gridKey;
  final double centerLat;
  final double centerLng;
  final int orderCount;
  final double totalRevenue;
  final DateTime firstOrderAt;
  final DateTime lastOrderAt;
  final List<String> pincodes;
  final bool isExpansionCandidate;

  DemandHeatmapCell({
    required this.gridKey,
    required this.centerLat,
    required this.centerLng,
    required this.orderCount,
    required this.totalRevenue,
    required this.firstOrderAt,
    required this.lastOrderAt,
    required this.pincodes,
    this.isExpansionCandidate = false,
  });

  factory DemandHeatmapCell.fromMap(Map<String, dynamic> map) {
    return DemandHeatmapCell(
      gridKey: map['gridKey'] ?? '',
      centerLat: (map['centerLat'] ?? 0.0).toDouble(),
      centerLng: (map['centerLng'] ?? 0.0).toDouble(),
      orderCount: map['orderCount'] ?? 0,
      totalRevenue: (map['totalRevenue'] ?? 0.0).toDouble(),
      firstOrderAt: map['firstOrderAt']?.toDate() ?? DateTime.now(),
      lastOrderAt: map['lastOrderAt']?.toDate() ?? DateTime.now(),
      pincodes: List<String>.from(map['pincodes'] ?? []),
      isExpansionCandidate: map['isExpansionCandidate'] ?? false,
    );
  }
}

class ZoneExpansionRecommendation {
  final String gridKey;
  final double centerLat;
  final double centerLng;
  final double distanceFromShop;
  final int orderCount;
  final double totalRevenue;
  final double score;
  final double suggestedDeliveryCharge;
  final double suggestedMinOrder;
  final List<String> pincodes;

  ZoneExpansionRecommendation({
    required this.gridKey,
    required this.centerLat,
    required this.centerLng,
    required this.distanceFromShop,
    required this.orderCount,
    required this.totalRevenue,
    required this.score,
    required this.suggestedDeliveryCharge,
    required this.suggestedMinOrder,
    required this.pincodes,
  });
}

class SurgeInfo {
  final double multiplier;
  final String level;
  final int currentHourOrders;
  final bool isPeakHour;

  SurgeInfo({
    required this.multiplier,
    required this.level,
    required this.currentHourOrders,
    required this.isPeakHour,
  });

  bool get hasSurge => multiplier > 1.0;
  String get displayLabel {
    if (multiplier >= 1.5) return '🔴 High Demand';
    if (multiplier >= 1.25) return '🟡 Moderate Demand';
    if (multiplier >= 1.1) return '🟢 Slight Surge';
    return '';
  }
}

class ZonePerformance {
  final String zoneId;
  final String zoneLabel;
  final int orderCount;
  final double totalRevenue;
  final double avgOrderValue;
  final double cancellationRate;
  final double deliveryCharge;
  final bool isActive;
  final bool isHealthy;

  ZonePerformance({
    required this.zoneId,
    required this.zoneLabel,
    required this.orderCount,
    required this.totalRevenue,
    required this.avgOrderValue,
    required this.cancellationRate,
    required this.deliveryCharge,
    required this.isActive,
    required this.isHealthy,
  });
}

class MembershipTierDiscount {
  final String tierName;
  final double surgeDiscount; // 0.0 to 1.0

  MembershipTierDiscount({required this.tierName, required this.surgeDiscount});

  static MembershipTierDiscount fromTierName(String tier) {
    switch (tier) {
      case 'Platinum':
        return MembershipTierDiscount(tierName: 'Platinum', surgeDiscount: 0.5);
      case 'Gold':
        return MembershipTierDiscount(tierName: 'Gold', surgeDiscount: 0.2);
      case 'Silver':
        return MembershipTierDiscount(tierName: 'Silver', surgeDiscount: 0.1);
      default:
        return MembershipTierDiscount(tierName: 'Bronze', surgeDiscount: 0.0);
    }
  }
}
