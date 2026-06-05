import 'dart:async';
import 'package:flutter/material.dart';
import '../models/shop_config_model.dart';
import '../models/shop_branch_model.dart';
import '../services/shop_config_service.dart';

class ShopConfigProvider with ChangeNotifier {
  final ShopConfigService _service = ShopConfigService();

  ShopConfigModel? _shopConfig;
  List<ShopBranchModel> _branches = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription<ShopConfigModel>? _configSubscription;
  StreamSubscription<List<ShopBranchModel>>? _branchesSubscription;

  // Getters
  ShopConfigModel? get shopConfig => _shopConfig;
  List<ShopBranchModel> get branches => _branches;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ShopConfigProvider() {
    init();
  }

  // Initialize and start listening to stream
  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Seed/Load initial config
      _shopConfig = await _service.getShopConfig();
      _branches = await _service.getBranches();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load shop settings: $e';
      _isLoading = false;
      notifyListeners();
    }

    // Cancel old subscriptions if any
    _configSubscription?.cancel();
    _branchesSubscription?.cancel();

    // Start real-time listeners
    _configSubscription = _service.getShopConfigStream().listen(
      (config) {
        _shopConfig = config;
        notifyListeners();
      },
      onError: (err) {
        _error = 'Shop configuration stream error: $err';
        notifyListeners();
      },
    );

    _branchesSubscription = _service.getBranchesStream().listen(
      (branchList) {
        _branches = branchList;
        notifyListeners();
      },
      onError: (err) {
        _error = 'Branches stream error: $err';
        notifyListeners();
      },
    );
  }

  // Update shop status (open/close)
  Future<void> toggleShopStatus() async {
    if (_shopConfig == null) return;
    try {
      final updated = _shopConfig!.copyWith(isOpen: !_shopConfig!.isOpen);
      await _service.updateShopConfig(updated);
    } catch (e) {
      _error = 'Failed to toggle shop status: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setShopOpen(bool isOpen) async {
    if (_shopConfig == null) return;
    try {
      final updated = _shopConfig!.copyWith(isOpen: isOpen);
      await _service.updateShopConfig(updated);
    } catch (e) {
      _error = 'Failed to update shop status: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Update shop location coordinates & address
  Future<void> updateShopLocation(
    double lat,
    double lng,
    String address,
  ) async {
    if (_shopConfig == null) return;
    try {
      final updated = _shopConfig!.copyWith(
        shopLatitude: lat,
        shopLongitude: lng,
        shopAddress: address,
      );
      await _service.updateShopConfig(updated);
    } catch (e) {
      _error = 'Failed to update shop location: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Save the entire shop config
  Future<void> updateShopConfig(ShopConfigModel config) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _service.updateShopConfig(config);
      _shopConfig = config;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update shop configuration: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Toggle Emergency Operations Mode
  Future<void> toggleEmergencyMode() async {
    if (_shopConfig == null) return;
    try {
      final updated = _shopConfig!.copyWith(
        isEmergencyMode: !_shopConfig!.isEmergencyMode,
      );
      await _service.updateShopConfig(updated);
    } catch (e) {
      _error = 'Failed to toggle emergency mode: $e';
      notifyListeners();
      rethrow;
    }
  }

  // --- Delivery Zones CRUD ---
  Future<void> addDeliveryZone(DeliveryZone zone) async {
    if (_shopConfig == null) return;
    try {
      final List<DeliveryZone> updatedZones = List.from(
        _shopConfig!.deliveryZones,
      );
      updatedZones.add(zone);

      // Calculate max delivery radius from the zones
      double maxRadius = _shopConfig!.maxDeliveryRadiusKm;
      for (var z in updatedZones) {
        if (z.isActive && z.toRadiusKm > maxRadius) {
          maxRadius = z.toRadiusKm;
        }
      }

      final updated = _shopConfig!.copyWith(
        deliveryZones: updatedZones,
        maxDeliveryRadiusKm: maxRadius,
      );
      await _service.updateShopConfig(updated);
    } catch (e) {
      _error = 'Failed to add delivery zone: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateDeliveryZone(DeliveryZone zone) async {
    if (_shopConfig == null) return;
    try {
      final List<DeliveryZone> updatedZones = _shopConfig!.deliveryZones.map((
        z,
      ) {
        return z.id == zone.id ? zone : z;
      }).toList();

      double maxRadius = 0.0;
      for (var z in updatedZones) {
        if (z.isActive && z.toRadiusKm > maxRadius) {
          maxRadius = z.toRadiusKm;
        }
      }

      final updated = _shopConfig!.copyWith(
        deliveryZones: updatedZones,
        maxDeliveryRadiusKm: maxRadius > 0.0
            ? maxRadius
            : _shopConfig!.maxDeliveryRadiusKm,
      );
      await _service.updateShopConfig(updated);
    } catch (e) {
      _error = 'Failed to update delivery zone: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeDeliveryZone(String zoneId) async {
    if (_shopConfig == null) return;
    try {
      final List<DeliveryZone> updatedZones = _shopConfig!.deliveryZones
          .where((z) => z.id != zoneId)
          .toList();

      double maxRadius = 0.0;
      for (var z in updatedZones) {
        if (z.isActive && z.toRadiusKm > maxRadius) {
          maxRadius = z.toRadiusKm;
        }
      }

      final updated = _shopConfig!.copyWith(
        deliveryZones: updatedZones,
        maxDeliveryRadiusKm: maxRadius > 0.0 ? maxRadius : 8.0,
      );
      await _service.updateShopConfig(updated);
    } catch (e) {
      _error = 'Failed to remove delivery zone: $e';
      notifyListeners();
      rethrow;
    }
  }

  // --- Branch CRUD ---
  Future<void> addBranch(ShopBranchModel branch) async {
    try {
      await _service.addBranch(branch);
      // Wait for stream to update local state or fetch manually
    } catch (e) {
      _error = 'Failed to add branch: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateBranch(ShopBranchModel branch) async {
    try {
      await _service.updateBranch(branch);
    } catch (e) {
      _error = 'Failed to update branch: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeBranch(String branchId) async {
    try {
      await _service.deleteBranch(branchId);
    } catch (e) {
      _error = 'Failed to delete branch: $e';
      notifyListeners();
      rethrow;
    }
  }

  // --- Operating Hours CRUD ---
  Future<void> updateOperatingHours(String day, OperatingHours hours) async {
    if (_shopConfig == null) return;
    try {
      final Map<String, OperatingHours> updatedHours = Map.from(
        _shopConfig!.operatingHours,
      );
      updatedHours[day] = hours;
      final updated = _shopConfig!.copyWith(operatingHours: updatedHours);
      await _service.updateShopConfig(updated);
    } catch (e) {
      _error = 'Failed to update operating hours for $day: $e';
      notifyListeners();
      rethrow;
    }
  }

  // --- Convenience / Helper methods ---
  double calculateDeliveryCharge(
    double distanceKm,
    double orderAmount, {
    ShopBranchModel? branch,
  }) {
    if (_shopConfig == null) return 40.0;
    return _service.calculateDeliveryChargeForDistance(
      distanceKm: distanceKm,
      orderAmount: orderAmount,
      config: _shopConfig!,
      branch: branch,
    );
  }

  bool isAddressDeliverable(double lat, double lng) {
    if (_shopConfig == null) return false;
    return _service.isWithinDeliveryArea(lat, lng, _shopConfig!, _branches);
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _branchesSubscription?.cancel();
    super.dispose();
  }
}
