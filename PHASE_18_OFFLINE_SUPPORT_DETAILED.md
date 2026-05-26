# Phase 18: Offline Support - Implementation Checklist

## Overview
Complete offline functionality for cart, orders, and product browsing.

## Current Status
- ✅ OfflineManager: Partially implemented
- ✅ OfflineSyncService: Implemented
- ✅ OfflineRoutingService: Implemented
- ⏳ Offline cart operations: Needs completion
- ⏳ Offline order placement: Needs completion
- ⏳ NetworkMonitor: Needs implementation
- ⏳ UI offline indicators: Needs implementation

## Task 18.1: Complete OfflineManager Implementation
**Status:** Partially Complete
**File:** `lib/services/offline_manager.dart`

### Implementation Steps:
1. [ ] Implement offline product caching
2. [ ] Cache product images locally
3. [ ] Implement cache invalidation strategy
4. [ ] Add cache size management
5. [ ] Monitor cache storage usage

### Code Template:
```dart
class OfflineManager {
  static final OfflineManager _instance = OfflineManager._internal();
  
  factory OfflineManager() {
    return _instance;
  }
  
  OfflineManager._internal();
  
  final Hive _hive = Hive;
  late Box<ProductModel> _productBox;
  late Box<Map> _imageBox;
  
  static const String _productBoxName = 'offline_products';
  static const String _imageBoxName = 'offline_images';
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100 MB

  Future<void> initialize() async {
    try {
      _productBox = await _hive.openBox<ProductModel>(_productBoxName);
      _imageBox = await _hive.openBox<Map>(_imageBoxName);
      await _cleanupOldCache();
    } catch (e) {
      debugPrint('Error initializing offline manager: $e');
    }
  }

  // Cache product
  Future<void> cacheProduct(ProductModel product) async {
    try {
      await _productBox.put(product.id, product);
    } catch (e) {
      debugPrint('Error caching product: $e');
    }
  }

  // Cache multiple products
  Future<void> cacheProducts(List<ProductModel> products) async {
    try {
      final Map<String, ProductModel> productsMap = {
        for (var product in products) product.id: product,
      };
      await _productBox.putAll(productsMap);
    } catch (e) {
      debugPrint('Error caching products: $e');
    }
  }

  // Get cached product
  ProductModel? getCachedProduct(String productId) {
    try {
      return _productBox.get(productId);
    } catch (e) {
      debugPrint('Error getting cached product: $e');
      return null;
    }
  }

  // Get all cached products
  List<ProductModel> getAllCachedProducts() {
    try {
      return _productBox.values.toList();
    } catch (e) {
      debugPrint('Error getting all cached products: $e');
      return [];
    }
  }

  // Cache image
  Future<void> cacheImage(String imageUrl, Uint8List imageData) async {
    try {
      await _imageBox.put(imageUrl, {
        'data': imageData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await _checkCacheSize();
    } catch (e) {
      debugPrint('Error caching image: $e');
    }
  }

  // Get cached image
  Uint8List? getCachedImage(String imageUrl) {
    try {
      final cached = _imageBox.get(imageUrl);
      if (cached != null) {
        return cached['data'] as Uint8List;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached image: $e');
      return null;
    }
  }

  // Check cache size and cleanup if needed
  Future<void> _checkCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheSize = await _calculateDirectorySize(cacheDir);
      
      if (cacheSize > _maxCacheSize) {
        await _cleanupOldCache();
      }
    } catch (e) {
      debugPrint('Error checking cache size: $e');
    }
  }

  // Calculate directory size
  Future<int> _calculateDirectorySize(Directory directory) async {
    int size = 0;
    try {
      final files = directory.listSync(recursive: true);
      for (var file in files) {
        if (file is File) {
          size += file.lengthSync();
        }
      }
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
    }
    return size;
  }

  // Cleanup old cache
  Future<void> _cleanupOldCache() async {
    try {
      // Remove oldest images
      final entries = _imageBox.toMap().entries.toList();
      entries.sort((a, b) {
        final timeA = a.value['timestamp'] as int;
        final timeB = b.value['timestamp'] as int;
        return timeA.compareTo(timeB);
      });
      
      // Remove oldest 20% of images
      final removeCount = (entries.length * 0.2).toInt();
      for (int i = 0; i < removeCount; i++) {
        await _imageBox.delete(entries[i].key);
      }
    } catch (e) {
      debugPrint('Error cleaning up cache: $e');
    }
  }

  // Clear all cache
  Future<void> clearCache() async {
    try {
      await _productBox.clear();
      await _imageBox.clear();
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cachedProducts': _productBox.length,
      'cachedImages': _imageBox.length,
      'lastUpdated': DateTime.now(),
    };
  }
}
```

## Task 18.2: Implement Offline Cart Operations
**Status:** Not Started
**File:** `lib/providers/cart_provider.dart` (update)

### Implementation Steps:
1. [ ] Update cart provider for offline support
2. [ ] Implement local storage persistence
3. [ ] Add offline cart operations
4. [ ] Implement cart sync logic
5. [ ] Test offline cart operations
6. [ ] Test cart sync when online

### Code to Add:
```dart
// Add to CartProvider
class CartProvider with ChangeNotifier {
  final Box<CartItem> _cartBox = Hive.box<CartItem>('cart');
  bool _isOnline = true;

  // Add item to cart (works offline)
  Future<void> addToCart(CartItem item) async {
    try {
      final existingItem = _cartBox.get(item.productId);
      if (existingItem != null) {
        existingItem.quantity += item.quantity;
        await _cartBox.put(item.productId, existingItem);
      } else {
        await _cartBox.put(item.productId, item);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  // Remove item from cart (works offline)
  Future<void> removeFromCart(String productId) async {
    try {
      await _cartBox.delete(productId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from cart: $e');
    }
  }

  // Update quantity (works offline)
  Future<void> updateQuantity(String productId, int quantity) async {
    try {
      final item = _cartBox.get(productId);
      if (item != null) {
        item.quantity = quantity;
        await _cartBox.put(productId, item);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating quantity: $e');
    }
  }

  // Get cart items
  List<CartItem> getCartItems() {
    return _cartBox.values.toList();
  }

  // Sync cart when online
  Future<void> syncCart() async {
    if (!_isOnline) return;
    
    try {
      final items = getCartItems();
      // Sync with server
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc('items')
          .set({
            'items': items.map((e) => e.toMap()).toList(),
            'lastSynced': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error syncing cart: $e');
    }
  }

  // Clear cart
  Future<void> clearCart() async {
    try {
      await _cartBox.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cart: $e');
    }
  }
}
```

## Task 18.3: Implement Offline Order Placement
**Status:** Not Started
**File:** `lib/providers/order_provider.dart` (update)

### Implementation Steps:
1. [ ] Update order provider for offline support
2. [ ] Implement order queueing
3. [ ] Implement order sync logic
4. [ ] Add conflict resolution
5. [ ] Show queued orders in history
6. [ ] Test offline order placement

### Code Template:
```dart
// Add to OrderProvider
class OrderProvider with ChangeNotifier {
  final Box<OrderModel> _queuedOrdersBox = Hive.box<OrderModel>('queued_orders');
  bool _isOnline = true;

  // Place order (queues if offline)
  Future<String> placeOrder(OrderModel order) async {
    try {
      if (_isOnline) {
        // Place order online
        final docRef = await FirebaseFirestore.instance
            .collection('orders')
            .add(order.toMap());
        return docRef.id;
      } else {
        // Queue order for later
        final orderId = 'queued_${DateTime.now().millisecondsSinceEpoch}';
        order.id = orderId;
        order.status = 'queued';
        await _queuedOrdersBox.put(orderId, order);
        notifyListeners();
        return orderId;
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      rethrow;
    }
  }

  // Get queued orders
  List<OrderModel> getQueuedOrders() {
    return _queuedOrdersBox.values.toList();
  }

  // Sync queued orders when online
  Future<void> syncQueuedOrders() async {
    if (!_isOnline) return;

    try {
      final queuedOrders = getQueuedOrders();
      
      for (var order in queuedOrders) {
        try {
          // Remove queued prefix from ID
          final newOrder = order.copyWith(
            status: 'placed',
            createdAt: DateTime.now(),
          );
          
          final docRef = await FirebaseFirestore.instance
              .collection('orders')
              .add(newOrder.toMap());
          
          // Remove from queue
          await _queuedOrdersBox.delete(order.id);
          
          debugPrint('Synced queued order: ${order.id}');
        } catch (e) {
          debugPrint('Error syncing order ${order.id}: $e');
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing queued orders: $e');
    }
  }

  // Clear queued orders
  Future<void> clearQueuedOrders() async {
    try {
      await _queuedOrdersBox.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing queued orders: $e');
    }
  }
}
```

## Task 18.4: Implement NetworkMonitor
**Status:** Not Started
**File:** `lib/services/network_monitor.dart`

### Code Template:
```dart
class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  
  factory NetworkMonitor() {
    return _instance;
  }
  
  NetworkMonitor._internal();
  
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = 
      StreamController<bool>.broadcast();
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      
      // Listen for connectivity changes
      _connectivity.onConnectivityChanged.listen((result) {
        _updateConnectionStatus(result);
      });
    } catch (e) {
      debugPrint('Error initializing network monitor: $e');
    }
  }

  void _updateConnectionStatus(dynamic result) {
    bool isOnline = false;
    
    if (result is List) {
      isOnline = result.any((r) => r != ConnectivityResult.none);
    } else {
      isOnline = result != ConnectivityResult.none;
    }
    
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _connectionStatusController.add(_isOnline);
      debugPrint('Network status changed: $_isOnline');
      
      if (_isOnline) {
        _onOnline();
      } else {
        _onOffline();
      }
    }
  }

  void _onOnline() {
    debugPrint('Device is online');
    // Trigger sync operations
  }

  void _onOffline() {
    debugPrint('Device is offline');
    // Disable online-only features
  }

  void dispose() {
    _connectionStatusController.close();
  }
}
```

## Task 18.5: Add UI Offline Indicators
**Status:** Not Started
**File:** `lib/widgets/offline_indicator.dart`

### Code Template:
```dart
class OfflineIndicator extends StatelessWidget {
  final NetworkMonitor _networkMonitor = NetworkMonitor();

  OfflineIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _networkMonitor.connectionStatus,
      initialData: _networkMonitor.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        
        if (isOnline) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.orange[700],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'You are offline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Add to main app
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(
        children: [
          OfflineIndicator(),
          Expanded(child: YourMainWidget()),
        ],
      ),
    );
  }
}
```

## Offline Provider
**File:** `lib/providers/offline_provider.dart`

### Code Template:
```dart
class OfflineProvider with ChangeNotifier {
  final NetworkMonitor _networkMonitor = NetworkMonitor();
  final OfflineManager _offlineManager = OfflineManager();
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  
  int _queuedOrdersCount = 0;
  int get queuedOrdersCount => _queuedOrdersCount;

  Future<void> initialize() async {
    await _networkMonitor.initialize();
    await _offlineManager.initialize();
    
    _networkMonitor.connectionStatus.listen((isOnline) {
      _isOnline = isOnline;
      if (isOnline) {
        _syncOfflineData();
      }
      notifyListeners();
    });
  }

  Future<void> _syncOfflineData() async {
    try {
      // Sync cart
      // Sync queued orders
      // Sync other offline data
      debugPrint('Offline data synced');
    } catch (e) {
      debugPrint('Error syncing offline data: $e');
    }
  }

  void dispose() {
    _networkMonitor.dispose();
  }
}
```

## Testing Checklist

### Unit Tests
- [ ] Offline manager caching
- [ ] Cache size management
- [ ] Cart operations offline
- [ ] Order queueing
- [ ] Network status detection

### Widget Tests
- [ ] Offline indicator displays
- [ ] Cart screen works offline
- [ ] Order screen shows queued orders

### Integration Tests
- [ ] Products can be browsed offline
- [ ] Cart operations work offline
- [ ] Orders can be placed offline
- [ ] Offline data syncs when online
- [ ] Sync conflicts are resolved

### Manual Testing
- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Test offline browsing
- [ ] Test offline cart
- [ ] Test offline order placement
- [ ] Test sync when online
- [ ] Test with various network conditions

## Success Criteria

- [ ] Products can be browsed offline
- [ ] Cart operations work offline
- [ ] Orders can be placed offline
- [ ] Offline data syncs when online
- [ ] Offline indicator shows correctly
- [ ] Sync conflicts are resolved
- [ ] Cache is managed correctly
- [ ] Network changes are detected
- [ ] All tests pass
- [ ] No critical bugs

## Estimated Time: 30-40 hours

### Breakdown:
- Offline manager: 6-8 hours
- Offline cart: 6-8 hours
- Offline orders: 6-8 hours
- Network monitor: 4-6 hours
- UI indicators: 4-6 hours
- Testing: 6-8 hours

## Next Phase
After completing Phase 18, move to Phase 19: Accessibility & Localization

