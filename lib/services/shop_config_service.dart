import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/shop_config_model.dart';
import '../models/shop_branch_model.dart';

class ShopConfigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final ShopConfigService _instance = ShopConfigService._internal();
  factory ShopConfigService() => _instance;
  ShopConfigService._internal();

  // Cache to store the latest config in-memory
  ShopConfigModel? _cachedConfig;
  ShopConfigModel? get cachedConfig => _cachedConfig;

  List<ShopBranchModel> _cachedBranches = [];
  List<ShopBranchModel> get cachedBranches => _cachedBranches;

  // Seeding default configuration
  ShopConfigModel _getDefaultConfig() {
    final Map<String, OperatingHours> hours = {};
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    for (var day in days) {
      hours[day] = OperatingHours(
        isOpen: true,
        openTime: '09:00',
        closeTime: '21:00',
      );
    }

    final zones = [
      DeliveryZone(
        id: 'zone_1',
        label: 'Zone 1 - Free (0-3 km)',
        fromRadiusKm: 0.0,
        toRadiusKm: 3.0,
        deliveryCharge: 0.0,
        minOrderForFree: 300.0,
        isActive: true,
      ),
      DeliveryZone(
        id: 'zone_2',
        label: 'Zone 2 - Near (3-5 km)',
        fromRadiusKm: 3.0,
        toRadiusKm: 5.0,
        deliveryCharge: 20.0,
        minOrderForFree: 500.0,
        isActive: true,
      ),
      DeliveryZone(
        id: 'zone_3',
        label: 'Zone 3 - Mid (5-8 km)',
        fromRadiusKm: 5.0,
        toRadiusKm: 8.0,
        deliveryCharge: 40.0,
        minOrderForFree: 800.0,
        isActive: true,
      ),
    ];

    return ShopConfigModel(
      shopName: "Fufaji Online Store",
      shopAddress: "Jaipur, Rajasthan, India",
      shopPhone: "+91 9876543210",
      shopEmail: "owner@fufajionline.com",
      shopLogoUrl: null,
      isOpen: true,
      shopLatitude: 26.9124,
      shopLongitude: 75.7873,
      maxDeliveryRadiusKm: 8.0,
      deliveryZones: zones,
      minOrderAmount: 100.0,
      minOrderForFreeDelivery: 500.0,
      flatDeliveryFee: 40.0,
      operatingHours: hours,
      autoCloseOutsideHours: false,
      maxCodLimit: 5000.0,
      maxCreditLimit: 2000.0,
      maxOrdersPerSlot: 10,
      sameDayCutoffHour: 18,
      enableCashback: false,
      cashbackPercentage: 5.0,
      enableLoyaltyPoints: false,
      isAutoPilotEnabled: false,
    );
  }

  // Get Shop Configuration, seeds it if not present
  Future<ShopConfigModel> getShopConfig() async {
    try {
      final doc = await _db.collection('settings').doc('shop_config').get();
      if (doc.exists && doc.data() != null) {
        final config = ShopConfigModel.fromMap(doc.data()!);
        _cachedConfig = config;
        return config;
      } else {
        final defaultConfig = _getDefaultConfig();
        await updateShopConfig(defaultConfig);
        _cachedConfig = defaultConfig;
        return defaultConfig;
      }
    } catch (e) {
      debugPrint('Error getting shop config: $e');
      return _cachedConfig ?? _getDefaultConfig();
    }
  }

  // Update Shop Configuration
  Future<void> updateShopConfig(ShopConfigModel config) async {
    try {
      final batch = _db.batch();

      // Update shop config doc
      final configRef = _db.collection('settings').doc('shop_config');
      batch.set(configRef, config.toMap());

      // Sync to legacy settings/shop_status doc for backward compatibility
      final statusRef = _db.collection('settings').doc('shop_status');
      batch.set(statusRef, {
        'isOpen': config.isOpen,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      _cachedConfig = config;
    } catch (e) {
      debugPrint('Error updating shop config: $e');
      rethrow;
    }
  }

  // Stream of Shop Config updates
  Stream<ShopConfigModel> getShopConfigStream() {
    return _db.collection('settings').doc('shop_config').snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data() != null) {
        final config = ShopConfigModel.fromMap(snapshot.data()!);
        _cachedConfig = config;
        return config;
      }
      final defaultConfig = _getDefaultConfig();
      _cachedConfig = defaultConfig;
      return defaultConfig;
    });
  }

  // Distance calculator using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    const c = cos;
    final a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // Check if an address coordinates is within the delivery zone of shop/branch
  bool isWithinDeliveryArea(
    double lat,
    double lng,
    ShopConfigModel config,
    List<ShopBranchModel> branches,
  ) {
    // If multi-branch is active and we have branches, check if it fits in any branch
    if (branches.isNotEmpty) {
      for (var branch in branches) {
        if (!branch.isActive) continue;
        final dist = calculateDistance(
          branch.latitude,
          branch.longitude,
          lat,
          lng,
        );
        if (dist <= branch.deliveryRadiusKm) {
          return true;
        }
      }
      return false;
    }

    // Otherwise, check main shop
    final distance = calculateDistance(
      config.shopLatitude,
      config.shopLongitude,
      lat,
      lng,
    );
    return distance <= config.maxDeliveryRadiusKm;
  }

  // Find nearest branch for delivery
  ShopBranchModel? getNearestBranch(
    double lat,
    double lng,
    List<ShopBranchModel> branches,
  ) {
    if (branches.isEmpty) return null;

    ShopBranchModel? nearest;
    double minDistance = double.infinity;

    for (var branch in branches) {
      if (!branch.isActive) continue;
      final dist = calculateDistance(
        branch.latitude,
        branch.longitude,
        lat,
        lng,
      );
      if (dist <= branch.deliveryRadiusKm && dist < minDistance) {
        minDistance = dist;
        nearest = branch;
      }
    }
    return nearest;
  }

  // Calculate delivery charge based on distance and order amount
  double calculateDeliveryChargeForDistance({
    required double distanceKm,
    required double orderAmount,
    required ShopConfigModel config,
    ShopBranchModel? branch,
  }) {
    final zones = branch != null ? branch.deliveryZones : config.deliveryZones;
    final activeZones = zones.where((z) => z.isActive).toList();

    // Sort zones by distance range (fromRadiusKm)
    activeZones.sort((a, b) => a.fromRadiusKm.compareTo(b.fromRadiusKm));

    for (var zone in activeZones) {
      if (distanceKm >= zone.fromRadiusKm && distanceKm <= zone.toRadiusKm) {
        final freeThreshold = config.isEmergencyMode
            ? zone.minOrderForFree * 1.5
            : zone.minOrderForFree;
        if (orderAmount >= freeThreshold) {
          return 0.0;
        }
        final charge = config.isEmergencyMode
            ? zone.deliveryCharge * 2.0
            : zone.deliveryCharge;
        return charge;
      }
    }

    // Fallback if no matching zone found but it was somehow inside radius
    final fallbackFreeThreshold = config.isEmergencyMode
        ? config.minOrderForFreeDelivery * 1.5
        : config.minOrderForFreeDelivery;
    if (orderAmount >= fallbackFreeThreshold) {
      return 0.0;
    }
    final fallbackCharge = config.isEmergencyMode
        ? config.flatDeliveryFee * 2.0
        : config.flatDeliveryFee;
    return fallbackCharge;
  }

  // --- Branch Management ---
  Future<List<ShopBranchModel>> getBranches() async {
    try {
      final snapshot = await _db
          .collection('settings')
          .doc('shop_config')
          .collection('branches')
          .get();
      final branchesList = snapshot.docs
          .map((doc) => ShopBranchModel.fromMap(doc.data()))
          .toList();
      _cachedBranches = branchesList;
      return branchesList;
    } catch (e) {
      debugPrint('Error getting branches: $e');
      return [];
    }
  }

  Stream<List<ShopBranchModel>> getBranchesStream() {
    return _db
        .collection('settings')
        .doc('shop_config')
        .collection('branches')
        .snapshots()
        .map((snapshot) {
          final branchesList = snapshot.docs
              .map((doc) => ShopBranchModel.fromMap(doc.data()))
              .toList();
          _cachedBranches = branchesList;
          return branchesList;
        });
  }

  Future<void> addBranch(ShopBranchModel branch) async {
    try {
      await _db
          .collection('settings')
          .doc('shop_config')
          .collection('branches')
          .doc(branch.id)
          .set(branch.toMap());
    } catch (e) {
      debugPrint('Error adding branch: $e');
      rethrow;
    }
  }

  Future<void> updateBranch(ShopBranchModel branch) async {
    try {
      await _db
          .collection('settings')
          .doc('shop_config')
          .collection('branches')
          .doc(branch.id)
          .update(branch.toMap());
    } catch (e) {
      debugPrint('Error updating branch: $e');
      rethrow;
    }
  }

  Future<void> deleteBranch(String branchId) async {
    try {
      await _db
          .collection('settings')
          .doc('shop_config')
          .collection('branches')
          .doc(branchId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting branch: $e');
      rethrow;
    }
  }
}
