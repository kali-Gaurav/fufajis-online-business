import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/low_stock_alert_model.dart';
import '../services/product_service.dart';
import '../services/inventory_alert_service.dart';
import '../services/expiry_checker_service.dart';
import '../services/inventory_sync_service.dart';
import 'dart:async';
import '../utils/db_seeder.dart';
import '../services/storage_service.dart';
import '../utils/monetary_value.dart';

class ProductProvider with ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  ProductService get _productService => ProductService();
  InventoryAlertService get _inventoryAlertService => InventoryAlertService();
  ExpiryCheckerService get _expiryCheckerService => ExpiryCheckerService();
  final InventorySyncService _inventorySyncService = InventorySyncService();

  List<ProductModel> _products = [];
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _trendingProducts = [];
  List<ProductModel> _dealsProducts = [];
  final List<ProductModel> _recentlyViewed = [];
  List<String> _wishlistIds = [];
  List<CategoryModel> _categories = [];
  List<LowStockAlert> _lowStockAlerts = [];
  final SharedPreferences _prefs;

  // Stream subscriptions for real-time sync
  StreamSubscription<List<ProductModel>>? _allProductsSubscription;
  StreamSubscription<ProductModel?>? _singleProductSubscription;
  StreamSubscription<List<ProductModel>>? _categoryProductsSubscription;
  StreamSubscription<List<ProductModel>>? _lowStockProductsSubscription;

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
    _setupInventorySyncCallbacks();
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
        _products.sort((a, b) => (b.isTrending ? 1 : 0).compareTo(a.isTrending ? 1 : 0));
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
    _inventoryHealth = await _inventoryAlertService.getInventoryHealthScore(_shopId!);
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
          final velocityData = await alertService.calculateSalesVelocityWithTrend(product.id);
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

  Future<void> fetchProductsPaged({int limit = 20, bool isRefresh = false}) async {
    if (_isLoading) return;
    if (!isRefresh && !_hasMoreProducts) return;

    _isLoading = true;
    if (isRefresh) {
      _products = [];
      _lastProductDoc = null;
      _hasMoreProducts = true;
    }
    Future.microtask(() {
      if (hasListeners) notifyListeners();
    });

    try {
      Query query = _db.collection('products').orderBy('createdAt', descending: true).limit(limit);
      if (_lastProductDoc != null) {
        query = query.startAfterDocument(_lastProductDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastProductDoc = snapshot.docs.last;
        final newProducts = snapshot.docs
            .map((doc) => ProductModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        _products.addAll(newProducts);
        _hasMoreProducts = newProducts.length == limit;

        // Cache products to Hive for offline mode
        try {
          await StorageService().put('cached_products', _products.map((p) => p.toMap()).toList());
        } catch (storageErr) {
          debugPrint('Error caching products to Hive: $storageErr');
        }
      } else {
        _hasMoreProducts = false;
      }

      _updateCategoriesFromProducts();
      _updateSpecialSections();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching paged products: $e. Attempting local Hive cache load.');
      try {
        final cachedData = StorageService().get('cached_products');
        if (cachedData != null && cachedData is List) {
          final cachedList = cachedData
              .map((item) => ProductModel.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList();
          if (cachedList.isNotEmpty) {
            _products = cachedList;
            _hasMoreProducts = false;
            _updateCategoriesFromProducts();
            _updateSpecialSections();
          }
        }
      } catch (cacheErr) {
        debugPrint('Failed to load products from Hive cache: $cacheErr');
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateCategoriesFromProducts() {
    // Phase 1 Audit Upgrade: Decouple Logic ID from Localized Display
    final Map<String, CategoryModel> uniqueCats = {};

    // Add "All" static category
    uniqueCats['all'] = CategoryModel(
      id: 'all',
      name: 'All',
      nameHindi: 'सब',
      icon: '🏠',
      color: '#FF5722',
    );

    // Populate from Enum Master List (Ensures consistent metadata)
    for (final cat in ProductCategory.values) {
      uniqueCats[cat.name] = CategoryModel.fromEnum(cat);
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
        price: MonetaryValue(40.0),
        originalPrice: MonetaryValue(50.0),
        unit: '1 kg',
        categoryId: 'vegetables',
        shopId: 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl: 'https://images.unsplash.com/photo-1518977676601-b53f02ac6d31?w=400',
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
        price: MonetaryValue(64.0),
        originalPrice: MonetaryValue(68.0),
        unit: '1 L',
        categoryId: 'dairy',
        shopId: 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl: 'https://images.unsplash.com/photo-1563636619-e910ef2a844b?w=400',
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
        price: MonetaryValue(35.0),
        originalPrice: MonetaryValue(45.0),
        unit: '1 kg',
        categoryId: 'vegetables',
        shopId: 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl: 'https://images.unsplash.com/photo-1546470427-e26264be0b0d?w=400',
        stockQuantity: 80,
        district: 'Jaipur',
        barcode: '8901234567002',
        tags: const ['tomato', 'tomatoes', 'tamatar', 'टमाटर', 'à¤Ÿà¤®à¤¾à¤Ÿà¤°'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ProductModel(
        id: 'prod_004',
        name: 'Red Onions',
        description: 'Fresh red onions for curries and salads.',
        price: MonetaryValue(42.0),
        originalPrice: MonetaryValue(50.0),
        unit: '1 kg',
        categoryId: 'vegetables',
        shopId: 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl: 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=400',
        stockQuantity: 90,
        district: 'Jaipur',
        barcode: '8901234567003',
        tags: const ['onion', 'onions', 'pyaz'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  // Search products with fuzzy matching
  List<ProductModel> searchProducts(String query) {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty) return [];

    if (RegExp(r'^\d{8,}$').hasMatch(normalizedQuery)) {
      return _products.where((p) => p.barcode.trim() == normalizedQuery).toList();
    }

    final expandedTokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .expand(_expandSearchToken)
        .where((token) => token.length > 1 && token != 'aur')
        .toSet();

    return _products.where((p) {
      final searchableText = [
        p.name,
        p.categoryId,
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

  List<ProductModel> getProductsByCategory(String catId) {
    if (catId.toLowerCase() == 'all') return _products;
    return _products.where((p) => p.categoryId.toLowerCase() == catId.toLowerCase()).toList();
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

  Stream<List<Map<String, dynamic>>> getPendingPriceChangesStream() {
    return _productService.getPendingPriceChangesStream();
  }

  Stream<List<Map<String, dynamic>>> getPriceChangesHistoryStream() {
    return _productService.getPriceChangesHistoryStream();
  }

  Future<void> approvePriceChange(String changeId) async {
    await _productService.approvePriceChange(changeId);
    notifyListeners();
  }

  Future<void> approveAllPriceChanges(List<String> changeIds) async {
    await _productService.approveAllPriceChanges(changeIds);
    notifyListeners();
  }

  Future<void> rejectPriceChange(String changeId, String reason) async {
    await _productService.rejectPriceChange(changeId, reason);
    notifyListeners();
  }

  Future<void> proposePriceChange({
    required String productId,
    required String productName,
    required double oldPrice,
    required double newPrice,
    required String reason,
    required String requestedBy,
  }) async {
    await _productService.proposePriceChange(
      productId: productId,
      productName: productName,
      oldPrice: oldPrice,
      newPrice: newPrice,
      reason: reason,
      requestedBy: requestedBy,
    );
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
    await fetchProductsPaged(isRefresh: true);
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

  /// Setup callbacks for real-time inventory sync
  void _setupInventorySyncCallbacks() {
    _inventorySyncService.onProductStockUpdate = (product) {
      _handleProductStockUpdate(product);
    };

    _inventorySyncService.onProductsUpdate = (products) {
      _handleProductsUpdate(products);
    };

    _inventorySyncService.onProductRemoved = (productId) {
      _handleProductRemoved(productId);
    };
  }

  /// Handle single product stock update from Firestore
  void _handleProductStockUpdate(ProductModel updatedProduct) {
    try {
      final existingIndex = _products.indexWhere((p) => p.id == updatedProduct.id);
      if (existingIndex >= 0) {
        _products[existingIndex] = updatedProduct;

        // Update special sections if product is in them
        if (_featuredProducts.any((p) => p.id == updatedProduct.id)) {
          final featIndex = _featuredProducts.indexWhere((p) => p.id == updatedProduct.id);
          if (featIndex >= 0) _featuredProducts[featIndex] = updatedProduct;
        }
        if (_trendingProducts.any((p) => p.id == updatedProduct.id)) {
          final trendIndex = _trendingProducts.indexWhere((p) => p.id == updatedProduct.id);
          if (trendIndex >= 0) _trendingProducts[trendIndex] = updatedProduct;
        }
        if (_dealsProducts.any((p) => p.id == updatedProduct.id)) {
          final dealsIndex = _dealsProducts.indexWhere((p) => p.id == updatedProduct.id);
          if (dealsIndex >= 0) _dealsProducts[dealsIndex] = updatedProduct;
        }
        if (_recentlyViewed.any((p) => p.id == updatedProduct.id)) {
          final recIndex = _recentlyViewed.indexWhere((p) => p.id == updatedProduct.id);
          if (recIndex >= 0) _recentlyViewed[recIndex] = updatedProduct;
        }

        notifyListeners();
        debugPrint('Product stock updated: ${updatedProduct.id}');
      }
    } catch (e) {
      debugPrint('Error handling product stock update: $e');
    }
  }

  /// Handle bulk products update from Firestore
  void _handleProductsUpdate(List<ProductModel> updatedProducts) {
    try {
      for (final updatedProduct in updatedProducts) {
        final existingIndex = _products.indexWhere((p) => p.id == updatedProduct.id);
        if (existingIndex >= 0) {
          _products[existingIndex] = updatedProduct;
        } else {
          _products.add(updatedProduct);
        }
      }
      _updateSpecialSections();
      notifyListeners();
      debugPrint('Bulk products updated: ${updatedProducts.length} items');
    } catch (e) {
      debugPrint('Error handling bulk products update: $e');
    }
  }

  /// Handle product removal from Firestore
  void _handleProductRemoved(String productId) {
    try {
      _products.removeWhere((p) => p.id == productId);
      _featuredProducts.removeWhere((p) => p.id == productId);
      _trendingProducts.removeWhere((p) => p.id == productId);
      _dealsProducts.removeWhere((p) => p.id == productId);
      _recentlyViewed.removeWhere((p) => p.id == productId);
      _updateSpecialSections();
      notifyListeners();
      debugPrint('Product removed: $productId');
    } catch (e) {
      debugPrint('Error handling product removal: $e');
    }
  }

  /// Subscribe to real-time updates for all products in a shop
  Future<void> subscribeToAllProducts({required String shopId}) async {
    try {
      // Cancel existing subscription
      await _allProductsSubscription?.cancel();

      _allProductsSubscription = _inventorySyncService
          .watchAllProducts(shopId: shopId)
          .listen(
            (products) {
              _handleProductsUpdate(products);
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Error in all products subscription: $error');
              debugPrintStack(stackTrace: stackTrace);
            },
            cancelOnError: false,
          );

      debugPrint('Subscribed to all products for shop: $shopId');
    } catch (e) {
      debugPrint('Error subscribing to all products: $e');
    }
  }

  /// Subscribe to real-time updates for a single product
  Future<void> subscribeToProduct({required String productId}) async {
    try {
      // Cancel existing subscription
      await _singleProductSubscription?.cancel();

      _singleProductSubscription = _inventorySyncService
          .watchProductById(productId)
          .listen(
            (product) {
              if (product != null) {
                _handleProductStockUpdate(product);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Error in single product subscription: $error');
              debugPrintStack(stackTrace: stackTrace);
            },
            cancelOnError: false,
          );

      debugPrint('Subscribed to product: $productId');
    } catch (e) {
      debugPrint('Error subscribing to single product: $e');
    }
  }

  /// Subscribe to real-time updates for products in a category
  Future<void> subscribeToCategory({required String shopId, required String category}) async {
    try {
      // Cancel existing subscription
      await _categoryProductsSubscription?.cancel();

      _categoryProductsSubscription = _inventorySyncService
          .watchProductsByCategory(shopId: shopId, category: category)
          .listen(
            (products) {
              _handleProductsUpdate(products);
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Error in category subscription: $error');
              debugPrintStack(stackTrace: stackTrace);
            },
            cancelOnError: false,
          );

      debugPrint('Subscribed to category: $category for shop: $shopId');
    } catch (e) {
      debugPrint('Error subscribing to category: $e');
    }
  }

  /// Subscribe to real-time updates for low stock products
  Future<void> subscribeToLowStockProducts({required String shopId}) async {
    try {
      // Cancel existing subscription
      await _lowStockProductsSubscription?.cancel();

      _lowStockProductsSubscription = _inventorySyncService
          .watchLowStockProducts(shopId: shopId)
          .listen(
            (products) {
              // Update the low stock alerts list
              try {
                _lowStockAlerts = products
                    .map(
                      (p) => LowStockAlert(
                        id: '${p.id}_alert',
                        productId: p.id,
                        productName: p.name,
                        currentStock: p.stockQuantity,
                        minimumStock: p.minimumStock,
                        createdAt: DateTime.now(),
                      ),
                    )
                    .toList();
                notifyListeners();
                debugPrint('Low stock products updated: ${products.length} items');
              } catch (e) {
                debugPrint('Error processing low stock products: $e');
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Error in low stock subscription: $error');
              debugPrintStack(stackTrace: stackTrace);
            },
            cancelOnError: false,
          );

      debugPrint('Subscribed to low stock products for shop: $shopId');
    } catch (e) {
      debugPrint('Error subscribing to low stock products: $e');
    }
  }

  /// Unsubscribe from all real-time sync subscriptions
  Future<void> unsubscribeFromAllUpdates() async {
    try {
      await _allProductsSubscription?.cancel();
      _allProductsSubscription = null;

      await _singleProductSubscription?.cancel();
      _singleProductSubscription = null;

      await _categoryProductsSubscription?.cancel();
      _categoryProductsSubscription = null;

      await _lowStockProductsSubscription?.cancel();
      _lowStockProductsSubscription = null;

      debugPrint('Unsubscribed from all real-time updates');
    } catch (e) {
      debugPrint('Error unsubscribing from updates: $e');
    }
  }

  /// Get the number of active listeners
  int getActiveListenerCount() {
    return _inventorySyncService.getActiveListenerCount();
  }

  /// Dispose resources
  @override
  void dispose() {
    // Cancel all subscriptions
    _allProductsSubscription?.cancel();
    _singleProductSubscription?.cancel();
    _categoryProductsSubscription?.cancel();
    _lowStockProductsSubscription?.cancel();

    // Stop all Firestore listeners
    _inventorySyncService.stopAllListeners();

    super.dispose();
  }
}
