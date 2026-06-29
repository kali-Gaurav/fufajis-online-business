# Inventory Sync Quick Start Guide

## Installation (2 minutes)

### Step 1: Add Dependencies
Already included in pubspec.yaml:
- `cloud_firestore: ^6.5.0` (Firestore)
- `provider: ^6.1.2` (State management)

### Step 2: Files Added
- `lib/services/inventory_sync_service.dart` - Core sync engine
- `lib/providers/product_provider.dart` - Enhanced with sync support
- `test/services/inventory_sync_service_test.dart` - Test suite

## Implementation (5 minutes)

### Use Case 1: Customer Product List (Auto Real-Time Sync)

```dart
class ProductListScreen extends StatefulWidget {
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  @override
  void initState() {
    super.initState();
    // Subscribe to real-time updates
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.subscribeToAllProducts(shopId: 'shop_001');
  }

  @override
  void dispose() {
    // Cleanup
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.unsubscribeFromAllUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final products = productProvider.products;
        
        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              // Stock updates in real-time, UI rebuilds automatically
            );
          },
        );
      },
    );
  }
}
```

### Use Case 2: Category Products with Real-Time Stock

```dart
class CategoryScreen extends StatefulWidget {
  final String category;
  const CategoryScreen({required this.category});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  @override
  void initState() {
    super.initState();
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.subscribeToCategory(
      shopId: 'shop_001',
      category: widget.category,
    );
  }

  @override
  void dispose() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.unsubscribeFromAllUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final products = productProvider.getProductsByCategory(widget.category);
        
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductTile(product: product); // Stock syncs in real-time
          },
        );
      },
    );
  }
}
```

### Use Case 3: Product Detail with Live Stock

```dart
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.subscribeToProduct(productId: widget.productId);
  }

  @override
  void dispose() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider._inventorySyncService.stopListeningToProduct(widget.productId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final product = productProvider.getProductById(widget.productId);
        
        if (product == null) return const Center(child: Text('Product not found'));
        
        return Column(
          children: [
            Image.network(product.imageUrl),
            Text(product.name),
            Text('Stock: ${product.stockQuantity}'), // Updates in real-time
            ElevatedButton(
              onPressed: product.stockQuantity > 0 ? () => addToCart() : null,
              child: const Text('Add to Cart'),
            ),
          ],
        );
      },
    );
  }

  void addToCart() {
    // Add to cart logic
  }
}
```

### Use Case 4: Inventory Alerts (Low Stock Monitor)

```dart
class InventoryAlertsScreen extends StatefulWidget {
  @override
  State<InventoryAlertsScreen> createState() => _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends State<InventoryAlertsScreen> {
  @override
  void initState() {
    super.initState();
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    
    // Subscribe to low stock products
    productProvider.subscribeToLowStockProducts(shopId: 'shop_001');
    
    // Setup alert callback
    productProvider._inventorySyncService.onProductStockUpdate = (product) {
      if (product.stockQuantity == 0) {
        _showOutOfStockNotification(product);
      } else if (product.stockQuantity < product.minimumStock) {
        _showLowStockNotification(product);
      }
    };
  }

  @override
  void dispose() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.unsubscribeFromAllUpdates();
    super.dispose();
  }

  void _showLowStockNotification(ProductModel product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} is low on stock!')),
    );
  }

  void _showOutOfStockNotification(ProductModel product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} is out of stock!'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final lowStockProducts = productProvider.lowStockAlerts;
        
        if (lowStockProducts.isEmpty) {
          return const Center(child: Text('All products well-stocked'));
        }
        
        return ListView.builder(
          itemCount: lowStockProducts.length,
          itemBuilder: (context, index) {
            final alert = lowStockProducts[index];
            return AlertTile(alert: alert); // Updates as stock changes
          },
        );
      },
    );
  }
}
```

## Testing (2 minutes)

### Run Tests
```bash
flutter test test/services/inventory_sync_service_test.dart
```

### Manual Testing
1. Open app on Device A
2. Open Firestore console (Device B)
3. Update a product's `stockQuantity`
4. Watch it update instantly on Device A

## Common Issues & Solutions

### Problem: Updates not showing in UI
**Solution**: Ensure you're using `Consumer<ProductProvider>` or `Provider.of` with `listen: true`

### Problem: Memory leaks
**Solution**: Always call `unsubscribeFromAllUpdates()` in dispose()

### Problem: Too many listeners
**Solution**: Check `productProvider.getActiveListenerCount()` - should be 0 when not on screen

### Problem: Firestore costs high
**Solution**: 
- Only subscribe to needed categories
- Use pagination (`pageSize` parameter)
- Reduce debounce interval if too many updates

## Firestore Rules

Add to `firestore.rules`:
```firestore
match /products/{productId} {
  allow read: if request.auth != null;
}
```

## What Syncs in Real-Time

✅ `stockQuantity` - Primary stock  
✅ `branchStock` - Multi-branch stock  
✅ `isAvailable` - Availability status  
✅ `lastRestocked` - Last restock timestamp  
✅ Price changes  
✅ Product metadata  
✅ Product deletion  

## API at a Glance

```dart
// Subscribe
await productProvider.subscribeToAllProducts(shopId: 'shop_001');
await productProvider.subscribeToProduct(productId: 'prod_001');
await productProvider.subscribeToCategory(shopId: 'shop_001', category: 'vegetables');
await productProvider.subscribeToLowStockProducts(shopId: 'shop_001');

// Unsubscribe
await productProvider.unsubscribeFromAllUpdates();

// Monitor
int activeCount = productProvider.getActiveListenerCount();

// Callbacks
productProvider._inventorySyncService.onProductStockUpdate = (product) { };
productProvider._inventorySyncService.onProductRemoved = (productId) { };
```

## Next Steps

1. ✅ Integrate in one screen (e.g., ProductListScreen)
2. ✅ Test with Firestore updates
3. ✅ Add to more screens
4. ✅ Monitor performance with Firebase console
5. ✅ Adjust debounce/page size as needed

## Performance Tips

- **Page Size**: Use 30-50 for most screens
- **Debounce**: 500ms is optimal, adjust only if necessary
- **Cleanup**: Always dispose to prevent leaks
- **Cache First**: Load cached products immediately, sync in background

## Support & Documentation

- Full docs: `INVENTORY_SYNC_DOCUMENTATION.md`
- Tests: `test/services/inventory_sync_service_test.dart`
- Service: `lib/services/inventory_sync_service.dart`
- Provider: `lib/providers/product_provider.dart`

## Success Indicators

✅ Products update without manual refresh  
✅ Stock changes visible instantly  
✅ No memory leaks when navigating  
✅ Works offline (uses cache)  
✅ Handles network errors gracefully  

You're all set! Start with Use Case 1 above.
