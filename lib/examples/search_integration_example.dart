/// Example: Integrating ProductSearchService into POS and Scanner workflows
///
/// This file shows real-world usage patterns for the optimized search service.
/// Copy code snippets into your actual screens/services as needed.
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/search/product_search_service.dart';
import '../models/product_model.dart';
import '../screens/employee/product_search_screen_optimized.dart';

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 1: One-Time Product Indexing (Run Once at Startup)
// ═════════════════════════════════════════════════════════════════════════════

class ProductIndexingExample {
  /// Call this once when app starts or from admin dashboard
  /// Populates searchKeywords and searchTrigrams for all existing products
  static Future<void> indexAllProducts(String shopId) async {
    final searchService = ProductSearchService();

    print('Starting product indexing for shop: $shopId');

    try {
      final count = await searchService.indexProductsForSearch(
        shopId,
        batchSize: 500, // Process 500 at a time
      );
      print('Successfully indexed $count products');
    } catch (e) {
      print('Indexing failed: $e');
    }
  }

  /// Example: Call from admin dashboard
  static Widget buildIndexButton(String shopId) {
    return ElevatedButton.icon(
      onPressed: () => indexAllProducts(shopId),
      icon: const Icon(Icons.build),
      label: const Text('Index Products for Search'),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 2: Quick Barcode Search (Fastest - <20ms)
// ═════════════════════════════════════════════════════════════════════════════

class BarcodeSearchExample {
  static final _searchService = ProductSearchService();

  /// Use this when barcode is scanned by camera
  /// Returns instantly if found (O(1) indexed lookup)
  static Future<ProductModel?> findProductByBarcode(String shopId, String barcode) async {
    final product = await _searchService.searchByBarcode(shopId, barcode);

    if (product != null) {
      print('Found: ${product.name} - ₹${product.price}');
    } else {
      print('Product not found for barcode: $barcode');
    }

    return product;
  }

  /// Example: Integrate into barcode scanner callback
  static Future<void> onBarcodeScanned(String barcode, String shopId, BuildContext context) async {
    final product = await findProductByBarcode(shopId, barcode);

    if (product == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Product not found: $barcode')));
      return;
    }

    // Auto-add to POS cart
    // cart.addItem(product);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added: ${product.name}')));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 3: Manual Product Search (Keyword/Typo Tolerant)
// ═════════════════════════════════════════════════════════════════════════════

class KeywordSearchExample {
  static final _searchService = ProductSearchService();

  /// Search by name (handles typos automatically)
  /// Try exact match first, then fuzzy
  static Future<List<ProductModel>> searchByName(String shopId, String name) async {
    print('Searching for: $name');

    final results = await _searchService.searchProducts(shopId, name, limit: 20);

    print('Found ${results.length} results');
    return results;
  }

  /// Example usage
  static void exampleSearchFlow(String shopId) async {
    // User types "ryce" (typo)
    final results = await searchByName(shopId, 'ryce');

    // Service automatically:
    // 1. Tries exact keyword match for "ryce" → no results
    // 2. Generates trigrams: ["rye", "yc", "ce"]
    // 3. Searches trigram-based
    // 4. Finds "rice" products that match trigrams
    // 5. Returns sorted by relevance

    for (final product in results) {
      print('  - ${product.name}: ₹${product.price}');
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 4: Full Screen Integration (UI with Performance Metrics)
// ═════════════════════════════════════════════════════════════════════════════

class FullScreenSearchExample extends StatefulWidget {
  final String shopId;

  const FullScreenSearchExample({super.key, required this.shopId});

  @override
  State<FullScreenSearchExample> createState() => _FullScreenSearchExampleState();
}

class _FullScreenSearchExampleState extends State<FullScreenSearchExample> {
  /// Open the optimized search screen from anywhere
  void openSearchScreen() async {
    final selectedProduct = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductSearchScreen(shopId: widget.shopId)),
    );

    if (selectedProduct != null) {
      print('Selected product: ${selectedProduct.name}');
      // Add to cart, update UI, etc.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS - Product Search Example')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: openSearchScreen,
          icon: const Icon(Icons.search),
          label: const Text('Open Product Search'),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 5: Category Browse (Fast Filtered Search)
// ═════════════════════════════════════════════════════════════════════════════

class CategoryBrowseExample {
  static final _searchService = ProductSearchService();

  /// Get all products in a category
  static Future<List<ProductModel>> browseCategory(String shopId, String category) async {
    final products = await _searchService.searchByCategory(shopId, category, limit: 50);

    print('Found ${products.length} products in category: $category');
    return products;
  }

  /// Example: Low-stock products (for reorder alerts)
  static Future<List<ProductModel>> getLowStockProducts(String shopId) async {
    final products = await _searchService.searchLowStock(shopId, limit: 50);

    print('⚠️  ${products.length} products out of stock');
    return products;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 6: Advanced Filtering (Multiple Criteria)
// ═════════════════════════════════════════════════════════════════════════════

class AdvancedFilterExample {
  static final _searchService = ProductSearchService();

  /// Search with multiple filters
  static Future<List<ProductModel>> searchWithFilters(
    String shopId,
    Map<String, dynamic> filters,
  ) async {
    // Example filters:
    // - category: 'vegetables'
    // - isAvailable: true
    // - stockQuantity > 0

    final results = await _searchService.searchWithFilters(shopId, filters, limit: 100);

    print('Found ${results.length} matching products');
    return results;
  }

  /// Example: Find all vegetables that are available and in stock
  static Future<void> exampleFilterFlow(String shopId) async {
    final results = await searchWithFilters(shopId, {
      'category': 'vegetables',
      'isAvailable': true,
    });

    for (final product in results) {
      print('${product.name}: ${product.stockQuantity} in stock');
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 7: Unified Scanner with Search Integration
// ═════════════════════════════════════════════════════════════════════════════

class UnifiedScannerWithSearchExample {
  /// When employee scans a barcode in unified scanner hub,
  /// automatically determine action type and route accordingly

  static final _searchService = ProductSearchService();

  /// Parse barcode and route to correct workflow
  static Future<void> handleScannedBarcode(
    String barcode,
    String shopId,
    BuildContext context,
  ) async {
    // Step 1: Parse barcode type
    final action = ScanAction.parse(barcode);

    print('Scanned: $barcode -> Action: ${action.type}');

    // Step 2: Route based on action type
    switch (action.type) {
      case ScanActionType.productSearch:
        // Find product and add to POS cart
        final product = await _searchService.searchByBarcode(shopId, barcode);
        if (product != null) {
          // cart.addItem(product);
          print('Added to cart: ${product.name}');
        } else {
          print('Product not found');
        }
        break;

      case ScanActionType.orderPacking:
        // Route to order packing screen
        print('Routing to order packing: $barcode');
        break;

      case ScanActionType.dispatch:
        // Route to dispatch verification
        print('Routing to dispatch: $barcode');
        break;

      case ScanActionType.deliveryPOD:
        // Route to delivery POD scanner
        print('Routing to delivery POD: $barcode');
        break;

      case ScanActionType.inventoryReceiving:
        // Route to inventory receiving
        print('Routing to inventory receiving: $barcode');
        break;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 8: Performance Monitoring
// ═════════════════════════════════════════════════════════════════════════════

class PerformanceMonitoringExample {
  static final _searchService = ProductSearchService();

  /// Measure search performance
  static Future<void> benchmarkSearch(String shopId, String query) async {
    final stopwatch = Stopwatch()..start();

    final results = await _searchService.searchProducts(shopId, query);

    stopwatch.stop();

    final timeMs = stopwatch.elapsedMilliseconds;
    final performance = timeMs < 100 ? '✅ FAST' : '⚠️  SLOW';

    print('$performance: "$query" found ${results.length} in ${timeMs}ms');

    // Log to analytics
    // analytics.logEvent('search_performance', {
    //   'query': query,
    //   'results': results.length,
    //   'time_ms': timeMs,
    // });
  }

  /// Test multiple queries
  static Future<void> runBenchmarks(String shopId) async {
    final testQueries = ['rice', 'ryce', 'dal', 'dhal', 'milk', 'ghee'];

    print('Running ${testQueries.length} benchmarks...\n');

    for (final query in testQueries) {
      await benchmarkSearch(shopId, query);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 9: Error Handling & Fallbacks
// ═════════════════════════════════════════════════════════════════════════════

class ErrorHandlingExample {
  static final _searchService = ProductSearchService();

  /// Graceful error handling with fallbacks
  static Future<List<ProductModel>> safeSearch(String shopId, String query) async {
    try {
      // Try optimized search first
      final results = await _searchService.searchProducts(shopId, query);
      return results;
    } catch (e) {
      print('Search error: $e');

      // Fallback: Show message to user
      // await showDialog(
      //   context: context,
      //   builder: (context) => AlertDialog(
      //     title: const Text('Search Error'),
      //     content: Text('Could not search products: $e'),
      //     actions: [
      //       TextButton(
      //         onPressed: () => Navigator.pop(context),
      //         child: const Text('OK'),
      //       ),
      //     ],
      //   ),
      // );

      return []; // Return empty list instead of crashing
    }
  }

  /// Handle specific error types
  static Future<ProductModel?> safeBarcodeLookup(String shopId, String barcode) async {
    try {
      return await _searchService.searchByBarcode(shopId, barcode);
    } on FirebaseException catch (e) {
      print('Firebase error: ${e.message}');
      // Could be network error, permission error, etc.
      return null;
    } on Exception catch (e) {
      print('Unknown error: $e');
      return null;
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXAMPLE 10: Real-World POS Integration
// ═════════════════════════════════════════════════════════════════════════════

class RealWorldPOSExample extends StatefulWidget {
  final String shopId;

  const RealWorldPOSExample({super.key, required this.shopId});

  @override
  State<RealWorldPOSExample> createState() => _RealWorldPOSExampleState();
}

class _RealWorldPOSExampleState extends State<RealWorldPOSExample> {
  final List<ProductModel> _cart = [];

  /// When "Add Product" button is tapped
  void _addProductToCart() async {
    // Open search screen
    final ProductModel? product = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductSearchScreen(shopId: widget.shopId)),
    );

    if (product != null) {
      setState(() {
        _cart.add(product);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added: ${product.name}'), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS System')),
      body: Column(
        children: [
          // Cart display
          Expanded(
            child: ListView.builder(
              itemCount: _cart.length,
              itemBuilder: (context, index) {
                final product = _cart[index];
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('₹${product.price}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      setState(() => _cart.removeAt(index));
                    },
                  ),
                );
              },
            ),
          ),
          // Add product button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _addProductToCart,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add Product'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════

void main() {
  // Example: Run benchmarks on startup
  PerformanceMonitoringExample.runBenchmarks('shop_001');
}
