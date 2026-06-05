import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/low_stock_alert_model.dart';
import '../services/product_service.dart';
import '../services/inventory_alert_service.dart';
import '../services/expiry_checker_service.dart';
import 'dart:async';
import '../utils/db_seeder.dart';

class ProductProvider with ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  ProductService get _productService => ProductService();
  InventoryAlertService get _inventoryAlertService => InventoryAlertService();
  ExpiryCheckerService get _expiryCheckerService => ExpiryCheckerService();

  List<ProductModel> _products = [];
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _trendingProducts = [];
  List<ProductModel> _dealsProducts = [];
  final List<ProductModel> _recentlyViewed = [];
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

  ProductProvider(this._prefs, {bool enableRemoteData = true}) {
    _loadWishlist();
    if (enableRemoteData && _isFirebaseReady) {
      _initFirestoreListener();
      _runDailyExpiryChecks();
    }
  }

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  Future<void> _runDailyExpiryChecks() async {
    if (_shopId == null) return;
    try {
      await _expiryCheckerService.checkAndApplyDiscounts(_shopId!);
      await _expiryCheckerService.removeExpiredProducts(_shopId!);
      await _expiryCheckerService.applyNearExpiryDiscount(
        daysBeforeExpiry: 3,
        discountPercent: 20.0,
      );
    } catch (e) {
      debugPrint('Error running daily expiry checks: $e');
    }
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
      _runDailyExpiryChecks();
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

  /// Sorts products based on criterion (Step 10.4)
  void sortProducts(String criterion) {
    switch (criterion) {
      case 'price_low_high':
        _products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high_low':
        _products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'newest':
        _products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'popularity':
        _products.sort(
          (a, b) => (b.isTrending ? 1 : 0).compareTo(a.isTrending ? 1 : 0),
        );
        break;
    }
    notifyListeners();
  }

  ProductModel? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  ProductModel? getProductByBarcode(String barcode) {
    try {
      return _products.firstWhere((p) => p.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  List<ProductModel> getProductsWithExpiry() {
    return _products.where((p) => p.expiryDate != null).toList();
  }

  Future<void> _updateInventoryHealth() async {
    if (_shopId == null) return;
    _inventoryHealth = await _inventoryAlertService.getInventoryHealthScore(
      _shopId!,
    );
    notifyListeners();
  }

  void _listenToLowStock() {
    try {
      _productService.getLowStockAlertsStream().listen(
        (alerts) {
          _lowStockAlerts = alerts;
          notifyListeners();
        },
        onError: (Object e) {
          debugPrint('Error listening to low stock alerts: $e');
        },
      );
    } catch (e) {
      debugPrint('Low stock listener unavailable: $e');
    }
  }

  Future<void> checkAllProductsLowStock() async {
    _isLoading = true;
    notifyListeners();
    try {
      final alertService = InventoryAlertService();

      for (var product in _products) {
        if (product.stockQuantity < product.minimumStock) {
          await _productService.createLowStockAlert(product);
        } else {
          final velocityData = await alertService
              .calculateSalesVelocityWithTrend(product.id);
          final daysUntilStockout = await alertService.predictDaysUntilStockout(
            product.id,
            product.stockQuantity,
            precalculatedVelocity: velocityData,
          );
          if (daysUntilStockout <= 7) {
            await _productService.createLowStockAlert(product);
          }
        }
      }
      await _updateInventoryHealth();
    } catch (e) {
      debugPrint('Error checking low stock: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DocumentSnapshot? _lastProductDoc;
  bool _hasMoreProducts = true;
  bool get hasMoreProducts => _hasMoreProducts;

  Future<void> fetchProductsPaged({
    int limit = 20,
    bool isRefresh = false,
  }) async {
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
      Query query = _db
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(limit);
      if (_lastProductDoc != null) {
        query = query.startAfterDocument(_lastProductDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastProductDoc = snapshot.docs.last;
        final newProducts = snapshot.docs
            .map(
              (doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();
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

  Future<void> seedDatabase() async {
    // In a professional build, this would be restricted to Admin
    await _productService.batchAddProducts(_getMockProducts());
    try {
      await DatabaseSeeder.seedPurchaseOrdersAndLocations(
        shopId: _shopId ?? 'shop_001',
        branchId: 'branch_001',
      );
    } catch (e) {
      debugPrint('Error seeding mock POs and locations: $e');
    }
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
        imageUrl:
            'https://images.unsplash.com/photo-1518977676601-b53f02ac6d31?w=400',
        stockQuantity: 100,
        district: 'Jaipur',
        barcode: '8901234567001',
        tags: const ['potato', 'potatoes', 'aloo', 'आलू', 'à¤†à¤²à¥‚'],
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
        imageUrl:
            'https://images.unsplash.com/photo-1563636619-e910ef2a844b?w=400',
        stockQuantity: 50,
        district: 'Jaipur',
        barcode: '8901234567004',
        tags: const ['milk', 'doodh', 'दूध', 'à¤¦à¥‚à¤§'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ProductModel(
        id: 'prod_003',
        name: 'Fresh Tomatoes',
        description: 'Juicy local tomatoes for daily cooking.',
        price: 35.0,
        originalPrice: 45.0,
        unit: '1 kg',
        category: 'vegetables',
        shopId: 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl:
            'https://images.unsplash.com/photo-1546470427-e26264be0b0d?w=400',
        stockQuantity: 80,
        district: 'Jaipur',
        barcode: '8901234567002',
        tags: const [
          'tomato',
          'tomatoes',
          'tamatar',
          'टमाटर',
          'à¤Ÿà¤®à¤¾à¤Ÿà¤°',
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ProductModel(
        id: 'prod_004',
        name: 'Red Onions',
        description: 'Fresh red onions for curries and salads.',
        price: 42.0,
        originalPrice: 50.0,
        unit: '1 kg',
        category: 'vegetables',
        shopId: 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl:
            'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=400',
        stockQuantity: 90,
        district: 'Jaipur',
        barcode: '8901234567003',
        tags: const ['onion', 'onions', 'pyaz'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables':
        return '🥦';
      case 'fruits':
        return '🍎';
      case 'dairy':
        return '🥛';
      case 'groceries':
        return '🛒';
      case 'bakery':
        return '🍞';
      case 'beverages':
        return '🥤';
      case 'household':
        return '🧹';
      default:
        return '📦';
    }
  }

  String _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables':
        return '#4CAF50';
      case 'fruits':
        return '#F44336';
      case 'dairy':
        return '#2196F3';
      case 'groceries':
        return '#FF9800';
      case 'bakery':
        return '#795548';
      default:
        return '#FF5722';
    }
  }

  // Search products with fuzzy matching
  List<ProductModel> searchProducts(String query) {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty) return [];

    if (RegExp(r'^\d{8,}$').hasMatch(normalizedQuery)) {
      return _products
          .where((p) => p.barcode.trim() == normalizedQuery)
          .toList();
    }

    final expandedTokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .expand(_expandSearchToken)
        .where((token) => token.length > 1 && token != 'aur')
        .toSet();

    return _products.where((p) {
      final searchableText = [
        p.name,
        p.category,
        p.barcode,
        ...p.tags,
      ].map(_normalizeSearchQuery).join(' ');

      if (searchableText.contains(normalizedQuery)) return true;
      return expandedTokens.any(searchableText.contains);
    }).toList();
  }

  String _normalizeSearchQuery(String value) {
    return value
        .toLowerCase()
        .replaceAll('।', ' ')
        .replaceAll(RegExp(r'[^\w\sà-῿]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Iterable<String> _expandSearchToken(String token) {
    const aliases = {
      'aloo': ['aloo', 'potato', 'potatoes'],
      'आलू': ['आलू', 'potato', 'potatoes', 'aloo'],
      'à¤†à¤²à¥‚': ['à¤†à¤²à¥‚', 'potato', 'potatoes', 'aloo'],
      'tamatar': ['tamatar', 'tomato', 'tomatoes'],
      'टमाटर': ['टमाटर', 'tomato', 'tomatoes', 'tamatar'],
      'à¤Ÿà¤®à¤¾à¤Ÿà¤°': ['à¤Ÿà¤®à¤¾à¤Ÿà¤°', 'tomato', 'tomatoes', 'tamatar'],
      'doodh': ['doodh', 'milk'],
      'दूध': ['दूध', 'milk', 'doodh'],
      'à¤¦à¥‚à¤§': ['à¤¦à¥‚à¤§', 'milk', 'doodh'],
    };
    return aliases[token] ?? [token];
  }

  List<ProductModel> getProductsByCategory(String category) {
    if (category.toLowerCase() == 'all') return _products;
    return _products
        .where((p) => p.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  Future<void> _applyLightningDeals() async {
    // Logic to apply lightning deals from cache or Firestore
  }

  Future<void> addProduct(ProductModel product) async {
    await _productService.addProduct(product);
  }

  Future<void> updateProduct(ProductModel product) async {
    await _productService.updateProduct(product.id, product.toMap());
  }

  Future<void> deleteProduct(String productId) async {
    await _productService.deleteProduct(productId);
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
    return _products
        .where((p) => p.district == (district ?? 'Jaipur'))
        .toList();
  }

  List<ProductModel> getNearbyProducts({double? lat, double? lng}) {
    // Simplified: Returns products from same district
    return getLocalProducts(district: 'Jaipur');
  }

  Future<void> refreshLightningDeals() async {
    await _applyLightningDeals();
  }
}
