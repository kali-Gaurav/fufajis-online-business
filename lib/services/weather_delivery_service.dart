import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'weather_service.dart';

/// Component 10 — Weather Surcharge Exclusion & Delay Alerts
///
/// Fufaji Policy (LOCKED, owner-approved):
///   ✅ Show "Heavy Rain Alert" banner when bad weather detected
///   ✅ Show revised estimated delivery time
///   ❌ NEVER add hidden weather surcharge to order total
///   ❌ NEVER increase delivery fee due to weather
///
/// This service is the single authority for weather-based delivery adjustments.
/// It reads weather data, computes delay estimates, and writes delay alerts to
/// Firestore so rider and customer notifications can be triggered.
class WeatherDeliveryService {
  static final WeatherDeliveryService _instance = WeatherDeliveryService._internal();
  factory WeatherDeliveryService() => _instance;
  WeatherDeliveryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Delay addition in minutes per weather condition
  // These are display-only — they never affect pricing.
  static const Map<String, int> _delayMinutes = {
    'Thunderstorm': 45,
    'Tornado': 60,
    'Squall': 40,
    'Rain': 20,
    'Drizzle': 10,
    'Fog': 15,
    'Mist': 10,
    'Haze': 5,
    'Dust': 10,
    'Sand': 10,
    'Smoke': 5,
    'Clear': 0,
    'Clouds': 0,
  };

  // ─────────────── DELIVERY ESTIMATE ───────────────

  /// Returns an adjusted delivery estimate considering weather.
  /// IMPORTANT: Price is NEVER modified — only ETA is adjusted.
  Future<WeatherDeliveryEstimate> getDeliveryEstimate({
    double latitude = 26.9124,
    double longitude = 75.7873,
    int baseDeliveryMinutes = 30,
  }) async {
    WeatherAlert weather;
    try {
      weather = await WeatherService.getCurrentWeather(latitude: latitude, longitude: longitude);
    } catch (e) {
      debugPrint('[WeatherDelivery] Weather fetch failed: $e');
      return WeatherDeliveryEstimate.normal(baseDeliveryMinutes);
    }

    final additionalMinutes = _delayMinutes[weather.condition] ?? 0;
    final adjustedMinutes = baseDeliveryMinutes + additionalMinutes;

    final estimate = WeatherDeliveryEstimate(
      baseMinutes: baseDeliveryMinutes,
      additionalMinutes: additionalMinutes,
      totalMinutes: adjustedMinutes,
      condition: weather.condition,
      description: weather.description,
      hasDelay: additionalMinutes > 0,
      // Policy: display alert message but NEVER add surcharge
      alertMessage: _buildAlertMessage(weather.condition, additionalMinutes),
      // Explicitly confirm no price change
      priceSurcharge: 0.0,
    );

    debugPrint(
      '[WeatherDelivery] Estimated delivery: ${estimate.totalMinutes} min (base=$baseDeliveryMinutes, delay=$additionalMinutes, condition=${weather.condition})',
    );
    return estimate;
  }

  String _buildAlertMessage(String condition, int additionalMinutes) {
    if (additionalMinutes <= 0) return '';

    switch (condition) {
      case 'Thunderstorm':
      case 'Tornado':
      case 'Squall':
        return '⛈️ Heavy Rain Alert — Severe weather may delay delivery by ~$additionalMinutes minutes. '
            'Your delivery fee remains unchanged.';
      case 'Rain':
        return '🌧️ Heavy Rain Alert — Rainy weather may add ~$additionalMinutes minutes to your delivery. '
            'No extra charges applied.';
      case 'Drizzle':
        return '🌦️ Light rain in your area. Estimated +$additionalMinutes minutes delay. No extra charges.';
      case 'Fog':
      case 'Mist':
        return '🌫️ Low visibility conditions. Rider safety measures may add ~$additionalMinutes minutes.';
      case 'Haze':
      case 'Dust':
      case 'Sand':
        return '🌪️ Dusty conditions detected. Delivery may be delayed by ~$additionalMinutes minutes.';
      default:
        return 'Delivery may be slightly delayed due to weather conditions.';
    }
  }

  // ─────────────── FIRESTORE DELAY ALERTS ───────────────

  /// Writes a weather delay alert for an order (for rider & customer notifications).
  Future<void> writeDelayAlert({
    required String orderId,
    required WeatherDeliveryEstimate estimate,
  }) async {
    if (!estimate.hasDelay) return;

    await _firestore.collection('orders').doc(orderId).collection('delay_alerts').add({
      'type': 'weather_delay',
      'condition': estimate.condition,
      'additionalMinutes': estimate.additionalMinutes,
      'estimatedTotalMinutes': estimate.totalMinutes,
      'alertMessage': estimate.alertMessage,
      'priceSurcharge': 0.0, // Always zero — policy enforcement
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update order ETA in the main order document
    await _firestore.collection('orders').doc(orderId).update({
      'estimatedDeliveryMinutes': estimate.totalMinutes,
      'weatherDelayMinutes': estimate.additionalMinutes,
      'weatherCondition': estimate.condition,
      'weatherAlertMessage': estimate.alertMessage,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '[WeatherDelivery] Delay alert written for order $orderId (+${estimate.additionalMinutes}min)',
    );
  }

  /// Removes weather delay alerts when conditions clear.
  Future<void> clearDelayAlert(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'weatherDelayMinutes': 0,
      'weatherCondition': 'Clear',
      'weatherAlertMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────── PROACTIVE CHECK FOR ACTIVE ORDERS ───────────────

  /// Checks all active orders and writes delay alerts if weather warrants it.
  /// Call this periodically (e.g., every 15 min) from a background service.
  Future<void> processActiveOrderDelays(String shopId) async {
    final estimate = await getDeliveryEstimate();
    if (!estimate.hasDelay) return;

    final snap = await _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['confirmed', 'preparing', 'out_for_delivery'])
        .get();

    for (final doc in snap.docs) {
      await writeDelayAlert(orderId: doc.id, estimate: estimate);
    }

    debugPrint('[WeatherDelivery] Processed ${snap.docs.length} active orders with delay alert.');
  }
}

// ─────────────── VALUE OBJECTS ───────────────

class WeatherDeliveryEstimate {
  final int baseMinutes;
  final int additionalMinutes;
  final int totalMinutes;
  final String condition;
  final String description;
  final bool hasDelay;
  final String alertMessage;
  final double priceSurcharge; // Always 0 — enforced by policy

  const WeatherDeliveryEstimate({
    required this.baseMinutes,
    required this.additionalMinutes,
    required this.totalMinutes,
    required this.condition,
    required this.description,
    required this.hasDelay,
    required this.alertMessage,
    required this.priceSurcharge,
  });

  factory WeatherDeliveryEstimate.normal(int baseMinutes) => WeatherDeliveryEstimate(
    baseMinutes: baseMinutes,
    additionalMinutes: 0,
    totalMinutes: baseMinutes,
    condition: 'Clear',
    description: 'clear sky',
    hasDelay: false,
    alertMessage: '',
    priceSurcharge: 0.0,
  );
}
