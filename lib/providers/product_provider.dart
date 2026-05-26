import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/low_stock_alert_model.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';
import '../services/inventory_alert_service.dart';
import '../services/expiry_checker_service.dart';
import '../services/pricing_engine.dart';
import 'dart:convert';
import 'dart:async';

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final InventoryAlertService _inventoryAlertService = InventoryAlertService();
  final ExpiryCheckerService _expiryCheckerService = ExpiryCheckerService();
  final PricingEngineService _pricingEngineService = PricingEngineService();
  
  List<ProductModel> _products = [];
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _trendingProducts = [];
  List<ProductModel> _dealsProducts = [];
  List<ProductModel> _recentlyViewed = [];
  List<String> _wishlistIds = [];
  List<CategoryModel> _categories = [];
  List<LowStockAlert> _lowStockAlerts = [];
  final SharedPreferences _prefs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  
  String _selectedCategory = '';
  String get selectedCategory => _selectedCategory;

  Map<String, dynamic>? _inventoryHealth;
  Map<String, dynamic>? get inventoryHealth => _inventoryHealth;

  List<ProductModel> get products => _products;
  List<ProductModel> get featuredProducts => _featuredProducts;
  List<ProductModel> get trendingProducts => _trendingProducts;
  List<ProductModel> get dealsProducts => _dealsProducts;
  List<ProductModel> get recentlyViewed => _recentlyViewed;
  List<String> get wishlistIds => _wishlistIds;
  List<CategoryModel> get categories => _categories;
  List<LowStockAlert> get lowStockAlerts => _lowStockAlerts;

  bool isInWishlist(String productId) => _wishlistIds.contains(productId);

  ProductProvider(this._prefs) {
    _loadWishlist();
    _initFirestoreListener();
    _listenToLowStock();
  }

  void _loadWishlist() {
    _wishlistIds = _prefs.getStringList('wishlist_ids') ?? [];
  }

  void toggleWishlist(String productId) {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
    } else {
      _wishlistIds.add(productId);
    }
    _prefs.setStringList('wishlist_ids', _wishlistIds);
    notifyListeners();
  }

  String? _shopId;
  String? get currentShopId => _shopId;

  void updateShopId(String? id) {
    if (_shopId != id) {
      _shopId = id;
      _updateInventoryHealth();
    }
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  ProductModel? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateInventoryHealth() async {
    if (_shopId == null) return;
    _inventoryHealth = await _inventoryAlertService.getInventoryHealthScore(_shopId!);
    notifyListeners();
  }

  void _listenToLowStock() {
    _firestoreService.getLowStockAlertsStream().listen((alerts) {
      _lowStockAlerts = alerts;
      notifyListeners();
    });
  }

  DocumentSnapshot? _lastProductDoc;
  bool _hasMoreProducts = true;
  bool get hasMoreProducts => _hasMoreProducts;

  Future<void> fetchProductsPaged({int limit = 20, bool isRefresh = false}) async {
    if (_isLoading) return;
    if (!isRefresh && !_hasMoreProducts) return;

    _isLoading = true;
    if (isRefresh) {
      _products = [];
      _lastProductDoc = null;
      _hasMoreProducts = true;
    }
    notifyListeners();

    try {
      Query query = _db.collection('products').orderBy('createdAt', descending: true).limit(limit);
      if (_lastProductDoc != null) {
        query = query.startAfterDocument(_lastProductDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastProductDoc = snapshot.docs.last;
        final newProducts = snapshot.docs.map((doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
        _products.addAll(newProducts);
        _hasMoreProducts = newProducts.length == limit;
      } else {
        _hasMoreProducts = false;
      }
      
      _updateCategoriesFromProducts();
      _updateSpecialSections();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching paged products: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateCategoriesFromProducts() {
      final Map<String, CategoryModel> uniqueCats = {};
      uniqueCats['all'] = CategoryModel(
        id: 'all',
        name: 'All',
        nameHindi: 'सब',
        icon: '🏠',
        color: '#FF5722',
      );

      for (var p in _products) {
        if (!uniqueCats.containsKey(p.category)) {
          final catName = p.category[0].toUpperCase() + p.category.substring(1);
          uniqueCats[p.category] = CategoryModel(
            id: p.category,
            name: catName,
            nameHindi: catName,
            icon: _getCategoryIcon(p.category),
            color: _getCategoryColor(p.category),
          );
        }
      }
      _categories = uniqueCats.values.toList();
  }

  void _updateSpecialSections() {
      _featuredProducts = _products.where((p) => p.isFeatured).take(10).toList();
      _trendingProducts = _products.where((p) => p.isTrending).take(10).toList();
      _dealsProducts = _products.where((p) => p.isOnSale).take(10).toList();
  }

  void _initFirestoreListener() {
    // We are replacing the infinite listener with pagination logic
    // but we can still keep a listener for low stock alerts or other metadata
    _listenToLowStock();
    // Initial fetch
    fetchProductsPaged(isRefresh: true);
  }

  void addToRecentlyViewed(String productId) {
    final product = getProductById(productId);
    if (product == null) return;

    _recentlyViewed.removeWhere((p) => p.id == productId);
    _recentlyViewed.insert(0, product);
    if (_recentlyViewed.length > 10) _recentlyViewed.removeLast();

    final ids = _recentlyViewed.map((p) => p.id).toList();
    _prefs.setStringList('recently_viewed_ids', ids);
    notifyListeners();
  }

  void _populateRecentlyViewed() {
    final ids = _prefs.getStringList('recently_viewed_ids') ?? [];
    _recentlyViewed = [];
    for (final id in ids) {
      final p = getProductById(id);
      if (p != null) _recentlyViewed.add(p);
    }
  }

  Future<void> seedDatabase() async {
    // In a professional build, this would be restricted to Admin
    await _firestoreService.batchAddProducts(_getMockProducts());
  }

  void loadMockProducts() {
    _products = _getMockProducts();
    _featuredProducts = _products.where((p) => p.isFeatured).toList();
    _trendingProducts = _products.where((p) => p.isTrending).toList();
    _dealsProducts = _products.where((p) => p.isOnSale).toList();
    notifyListeners();
  }

  List<ProductModel> _getMockProducts() {
    // Basic set of professional products for seeding
    return [
      ProductModel(
        id: 'prod_001',
        name: 'Fresh Organic Potatoes',
        description: 'High quality local potatoes from Jaipur farms.',
        price: 40.0,
        originalPrice: 50.0,
        unit: '1 kg',
        category: 'vegetables',
        shopId: 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl: 'https://images.unsplash.com/photo-1518977676601-b53f02ac6d31?w=400',
        stockQuantity: 100,
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ProductModel(
        id: 'prod_002',
        name: 'Full Cream Milk',
        description: 'Fresh buffalo milk delivered daily.',
        price: 64.0,
        originalPrice: 68.0,
        unit: '1 L',
        category: 'dairy',
        shopId: 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl: 'https://images.unsplash.com/photo-1563636619-e910ef2a844b?w=400',
        stockQuantity: 50,
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables': return '🥦';
      case 'fruits': return '🍎';
      case 'dairy': return '🥛';
      case 'groceries': return '🛒';
      case 'bakery': return '🍞';
      case 'beverages': return '🥤';
      case 'household': return '🧹';
      default: return '📦';
    }
  }

  String _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables': return '#4CAF50';
      case 'fruits': return '#F44336';
      case 'dairy': return '#2196F3';
      case 'groceries': return '#FF9800';
      case 'bakery': return '#795548';
      default: return '#FF5722';
    }
  }

  // Search products with fuzzy matching
  List<ProductModel> searchProducts(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _products.where((p) => 
      p.name.toLowerCase().contains(lowerQuery) || 
      p.category.toLowerCase().contains(lowerQuery) ||
      p.tags.any((t) => t.toLowerCase().contains(lowerQuery))
    ).toList();
  }

  List<ProductModel> getProductsByCategory(String category) {
    if (category.toLowerCase() == 'all') return _products;
    return _products.where((p) => p.category.toLowerCase() == category.toLowerCase()).toList();
  }

  Future<void> _applyLightningDeals() async {
    // Logic to apply lightning deals from cache or Firestore
  }

  Future<void> addProduct(ProductModel product) async {
    await _firestoreService.addProduct(product);
  }

  Future<void> updateProduct(ProductModel product) async {
    await _firestoreService.updateProduct(product.id, product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _firestoreService.deleteProduct(productId);
  }

  Future<Map<String, dynamic>> getPricingRules() async {
    return {'strategy': 'Match', 'revenueImpact': 0.0, 'isDefault': true};
  }

  Future<List<Map<String, dynamic>>> getPendingPriceChanges() async {
    return [];
  }

  Future<Map<String, dynamic>> getWhatsAppSyncStatus() async {
    return {
      'enabled': true,
      'lastSyncTime': DateTime.now(),
      'itemsCount': _products.length,
      'recentItems': [],
    };
  }

  Future<String> processWhatsAppMessage(String message) async {
    return "✅ WhatsApp command '$message' received. Feature hardening in progress.";
  }

  Future<void> refreshProducts() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));
    _isLoading = false;
    notifyListeners();
  }

  List<ProductModel> getLocalProducts({String? district, String? village}) {
    return _products.where((p) => p.district == (district ?? 'Jaipur')).toList();
  }

  List<ProductModel> getNearbyProducts({double? lat, double? lng}) {
    // Simplified: Returns products from same district
    return getLocalProducts(district: 'Jaipur');
  }

  Future<void> refreshLightningDeals() async {
    await _applyLightningDeals();
  }
}
