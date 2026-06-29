# Inventory Sync - Quick Reference

## Files Created/Modified

### New Files
1. **`lib/services/inventory_sync_service.dart`** (500+ lines)
   - Core service for real-time inventory synchronization
   - Manages Firestore listeners and streams
   - Implements debouncing and local caching

2. **`test/services/inventory_sync_service_test.dart`** (400+ lines)
   - 25+ comprehensive test cases
   - Integration and performance tests
   - Mock setup with FakeFirebaseFirestore

### Modified Files
1. **`lib/providers/product_provider.dart`** (Already imported and integrated)
   - Uses InventorySyncService for real-time updates
   - Subscriptions and cleanup already implemented

## Quick Start

### 1. Basic Setup (Already in ProductProvider)

```dart
final InventorySyncService _inventorySyncService = InventorySyncService();

void _setupInventorySyncCallbacks() {
  _inventorySyncService.onProductStockUpdate = _handleProductStockUpdate;
  _inventorySyncService.onProductsUpdate = _handleProductsUpdate;
  _inventorySyncService.onProductRemoved = _handleProductRemoved;
}
```

### 2. Subscribe to Updates

```dart
// All products in a shop
await provider.subscribeToAllProducts(shopId: 'shop_001');

// Single product
await provider.subscribeToProduct(productId: 'prod_001');

// Category products
await provider.subscribeToCategory(shopId: 'shop_001', category: 'vegetables');

// Low stock items
await provider.subscribeToLowStockProducts(shopId: 'shop_001');
```

### 3. Use in UI

```dart
Consumer<ProductProvider>(
  builder: (context, provider, _) {
    return Text('Stock: ${provider.getProductById("prod_001")?.stockQuantity}');
  },
)
```

## API Methods

### Watching Streams

```dart
// Get stream of all products
Stream<List<ProductModel>> watchAllProducts({required String shopId})

// Get stream of single product
Stream<ProductModel?> watchProductById(String productId)

// Get stream of category products
Stream<List<ProductModel>> watchProductsByCategory({
  required String shopId,
  required String category,
})

// Get stream of low stock products
Stream<List<ProductModel>> watchLowStockProducts({required String shopId})

// Get stream of available products
Stream<List<ProductModel>> watchAvailableProducts({required String shopId})

// Get stream of branch products
Stream<List<ProductModel>> watchProductsByBranch({
  required String shopId,
  required String branchId,
})
```

### Caching

```dart
// Get cached product
ProductModel? cached = syncService.getLocalCache('prod_001');

// Check if cached
bool exists = syncService.isInCache('prod_001');

// Get all cached
Map<String, ProductModel> all = syncService.getAllLocalCache();

// Cache size
int size = syncService.getCacheSize();

// Clear cache
syncService.clearLocalCache();
```

### Analytics

```dart
// Get inventory statistics
Map stats = await syncService.getInventoryStats(shopId: 'shop_001');

// Watch metrics stream
Stream<Map> metrics = syncService.watchInventoryMetrics(shopId: 'shop_001');

// Batch update
Map result = await syncService.batchUpdateInventory(
  productIdToQuantity: {'prod_001': 100},
  shopId: 'shop_001',
);
```

### Diagnostics

```dart
// Check Firestore connection
bool connected = await syncService.isFirestoreConnected();

// Get permission errors
String? error = await syncService.getPermissionErrors();

// Handle network errors
String type = syncService.handleNetworkError(exception);

// Active listener count
int count = syncService.getActiveListenerCount();

// Active listener IDs
List<String> ids = syncService.getActiveListenerIds();
```

### Lifecycle

```dart
// Stop all listeners (call in dispose())
await syncService.stopAllListeners();

// Cancel specific listener
await syncService.cancelListener('listener_id');
```

## Configuration

### Debounce Duration
```dart
// Default: 500ms
static const Duration _debounceDuration = Duration(milliseconds: 500);

// Change in inventory_sync_service.dart if needed
```

### Firestore Indexes Required

```firestore
# Collection: products
# Composite index for watchProductsByCategory
- shopId (Asc)
- categoryId (Asc)
- updatedAt (Desc)

# Composite index for watchProductsByBranch (if using)
- shopId (Asc)
- branchStock.<branchId> (Desc)
```

## Common Patterns

### Pattern 1: Auto-Subscribe on Screen Load

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<ProductProvider>().subscribeToAllProducts(
      shopId: 'shop_001',
    );
  });
}
```

### Pattern 2: Conditional Subscription

```dart
if (widget.productId != null) {
  provider.subscribeToProduct(productId: widget.productId!);
} else {
  provider.subscribeToCategory(
    shopId: provider.currentShopId!,
    category: 'vegetables',
  );
}
```

### Pattern 3: Offline Fallback

```dart
final product = provider.getProductById('prod_001');
if (product != null) {
  // Use cached/synced product
  return Text('Stock: ${product.stockQuantity}');
} else {
  // Try to load from Firestore or show error
  return Text('Product not available');
}
```

### Pattern 4: Unsubscribe on Navigate

```dart
@override
void dispose() {
  // Cancel subscription when leaving screen
  context.read<ProductProvider>()._allProductsSubscription?.cancel();
  super.dispose();
}
```

### Pattern 5: Listen for Low Stock Alerts

```dart
Consumer<ProductProvider>(
  builder: (context, provider, _) {
    provider.subscribeToLowStockProducts(shopId: 'shop_001');
    
    return provider.lowStockAlerts.isEmpty
      ? Text('All items in stock')
      : ListView.builder(
          itemCount: provider.lowStockAlerts.length,
          itemBuilder: (context, idx) {
            final alert = provider.lowStockAlerts[idx];
            return Text('${alert.productName}: ${alert.currentStock}');
          },
        );
  },
)
```

## Testing

### Run All Tests
```bash
flutter test test/services/inventory_sync_service_test.dart
```

### Run Specific Test Group
```bash
flutter test test/services/inventory_sync_service_test.dart -k "Integration"
```

### Run Performance Tests
```bash
flutter test test/services/inventory_sync_service_test.dart -k "Performance"
```

## Troubleshooting

### Problem: Stock not updating
**Solution:**
1. Verify `subscribeToAllProducts()` is called
2. Check Firestore security rules allow read
3. Check network connectivity

### Problem: High memory usage
**Solution:**
1. Ensure `stopAllListeners()` called in `dispose()`
2. Use `watchProductById()` instead of `watchAllProducts()` for single products
3. Call `clearLocalCache()` if cache grows unbounded

### Problem: Updates delayed
**Solution:**
1. Check if debouncing is expected (500ms is default)
2. Verify Firestore indexes exist
3. Check network latency

### Problem: Listener not working
**Solution:**
1. Check `onError` callback in subscription
2. Verify service not disposed
3. Check `activeListenerCount` with `getActiveListenerCount()`

## Performance Tips

1. **Use specific watches** instead of watchAll:
   ```dart
   // Good - specific
   watchProductById('prod_001')
   
   // Avoid - fetches all
   watchAllProducts()
   ```

2. **Reuse subscriptions**:
   ```dart
   // Cache subscription in provider
   _allProductsSubscription ??= syncService.watchAllProducts(...).listen(...)
   ```

3. **Filter at source**:
   ```dart
   // Good - Firestore filters
   watchProductsByCategory(category: 'vegetables')
   
   // Avoid - filter in app
   watchAllProducts().map(filter)
   ```

4. **Batch updates**:
   ```dart
   // Good - single batch
   batchUpdateInventory({
     'prod_001': 100,
     'prod_002': 50,
   })
   
   // Avoid - individual updates
   updateProduct('prod_001', 100)
   updateProduct('prod_002', 50)
   ```

5. **Monitor listeners**:
   ```dart
   print('Active listeners: ${syncService.getActiveListenerCount()}');
   print('Listener IDs: ${syncService.getActiveListenerIds()}');
   ```

## Security Considerations

1. **Authentication required** - All Firestore reads require auth
2. **Permission checks** - Firestore rules validate shopId
3. **Data isolation** - Each shop only sees their products
4. **Batch limits** - Max 500 operations per batch

## Migration from Old System

If replacing an older inventory system:

1. **Keep old methods** for backward compatibility
2. **Parallel run** both systems during transition
3. **Migrate views** one screen at a time
4. **Monitor performance** before full cutover
5. **Archive old data** after successful migration

## Support & Debugging

### Enable Debug Logs
```dart
// In main.dart or relevant service init
LoggingService().setDebugMode(true);
```

### Check Active Listeners
```dart
debugPrint('Active: ${syncService.getActiveListenerCount()}');
debugPrint('IDs: ${syncService.getActiveListenerIds()}');
```

### Verify Connectivity
```dart
bool connected = await syncService.isFirestoreConnected();
String? error = await syncService.getPermissionErrors();
```

### Monitor Cache
```dart
int size = syncService.getCacheSize();
Map<String, ProductModel> cached = syncService.getAllLocalCache();
```

## Additional Resources

- **Full Guide:** See `INVENTORY_SYNC_GUIDE.md`
- **Code:** `lib/services/inventory_sync_service.dart`
- **Tests:** `test/services/inventory_sync_service_test.dart`
- **Integration:** `lib/providers/product_provider.dart`
