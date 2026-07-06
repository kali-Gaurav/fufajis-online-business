import 'package:flutter/foundation.dart';
import '../models/inventory_model.dart';
import '../repositories/inventory_repository.dart';
import '../models/cart_item.dart';

class InventoryProvider with ChangeNotifier {
  final InventoryRepository _repository = InventoryRepository();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _error;
  String? get error => _error;
  
  Map<String, InventoryModel> _inventoryCache = {};
  
  Future<InventoryModel?> fetchInventory(String productId, {String branchId = 'default'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final inventory = await _repository.getInventory(productId, branchId: branchId);
      if (inventory != null) {
        _inventoryCache['${productId}_$branchId'] = inventory;
      }
      return inventory;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> reserveStock(List<CartItem> items, {String branchId = 'default'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _repository.reserveInventory(items, branchId: branchId);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> commitStock(List<CartItem> items, {String branchId = 'default'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _repository.commitInventory(items, branchId: branchId);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
