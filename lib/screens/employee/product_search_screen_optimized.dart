import 'package:flutter/material.dart';
import '../../services/search/product_search_service.dart';
import '../../models/product_model.dart';
import '../../services/logging_service.dart';
import '../../utils/app_theme.dart';

/// Optimized product search screen for POS barcode scanning and product lookup
///
/// Features:
/// - Instant barcode lookup (O(1) - single digit milliseconds)
/// - Fuzzy keyword search with trigrams (< 100ms for 5000+ items)
/// - Real-time performance metrics display
/// - Hindi/English support
/// - Automatic result selection for single match
///
/// Integration:
/// Push this screen with a return value to get the selected product:
/// ```dart
/// final product = await Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => ProductSearchScreen(shopId: 'shop_001'),
///   ),
/// );
/// ```
class ProductSearchScreen extends StatefulWidget {
  final String shopId;
  final bool autoSelectSingle;

  const ProductSearchScreen({required this.shopId, this.autoSelectSingle = true, super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  late ProductSearchService _searchService;
  late TextEditingController _searchController;
  List<ProductModel> _searchResults = [];
  bool _isSearching = false;
  String _lastQuery = '';
  int _lastSearchTimeMs = 0;

  @override
  void initState() {
    super.initState();
    _searchService = ProductSearchService();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Perform search with timing metrics
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _lastQuery = '';
      });
      return;
    }

    setState(() => _isSearching = true);
    final startTime = DateTime.now();

    try {
      // Try barcode first (fastest - single digit milliseconds)
      final barcodeResult = await _searchService.searchByBarcode(widget.shopId, query);

      if (barcodeResult != null) {
        _lastSearchTimeMs = DateTime.now().difference(startTime).inMilliseconds;

        if (widget.autoSelectSingle && mounted) {
          // Auto-return single barcode match
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            Navigator.pop(context, barcodeResult);
          }
        } else if (mounted) {
          setState(() {
            _searchResults = [barcodeResult];
            _lastQuery = query;
            _isSearching = false;
          });
        }

        LoggingService().info('ProductSearch: Barcode "$query" found in ${_lastSearchTimeMs}ms');
        return;
      }

      // Fall back to keyword search
      final results = await _searchService.searchProducts(widget.shopId, query);

      _lastSearchTimeMs = DateTime.now().difference(startTime).inMilliseconds;

      if (!mounted) return;

      // Auto-select if single result
      if (results.length == 1 && widget.autoSelectSingle) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.pop(context, results.first);
        }
        return;
      }

      setState(() {
        _searchResults = results;
        _lastQuery = query;
        _isSearching = false;
      });

      LoggingService().info(
        'ProductSearch: Keyword search "$query": ${results.length} results in ${_lastSearchTimeMs}ms',
      );
    } catch (e) {
      LoggingService().error('ProductSearch: Search error: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Products', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search input
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Enter product name or barcode',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _isSearching
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : _searchResults.isNotEmpty
                        ? InkWell(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                            child: const Icon(Icons.close, color: Colors.grey),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  onChanged: (value) => _performSearch(value),
                  textInputAction: TextInputAction.search,
                ),
                if (_lastSearchTimeMs > 0 && _searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Found ${_searchResults.length} in ${_lastSearchTimeMs}ms',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
          // Results count and performance info
          if (_searchResults.isNotEmpty && !_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchResults.length == 1
                        ? '1 product found'
                        : '${_searchResults.length} products found',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _lastSearchTimeMs < 100
                          ? AppTheme.success.withValues(alpha: 0.2)
                          : AppTheme.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_lastSearchTimeMs}ms',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _lastSearchTimeMs < 100 ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Results list
          Expanded(
            child: _isSearching
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text('Searching...', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _lastQuery.isEmpty ? 'Start typing to search' : 'No products found',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        if (_lastQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try searching by name or barcode',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      final stockStatus = product.stockQuantity <= 0 ? 'Out of stock' : 'In stock';
                      final stockColor = product.stockQuantity <= 0
                          ? AppTheme.error
                          : AppTheme.success;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 1,
                        child: ListTile(
                          leading: product.imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    product.imageUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => _buildPlaceholder(),
                                  ),
                                )
                              : _buildPlaceholder(),
                          title: Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${product.price.toDisplayString()} | ${product.unit}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    product.stockQuantity > 0 ? Icons.check_circle : Icons.cancel,
                                    size: 14,
                                    color: stockColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    stockStatus,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: stockColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (product.stockQuantity > 0) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${product.stockQuantity})',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                              if (product.rating > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 12, color: AppTheme.warning),
                                    const SizedBox(width: 2),
                                    Text(
                                      product.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          onTap: () => Navigator.pop(context, product),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.shopping_bag, color: Colors.grey[600], size: 24),
    );
  }
}
