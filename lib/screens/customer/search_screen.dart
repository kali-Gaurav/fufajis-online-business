import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import 'barcode_scanner_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<ProductModel> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  List<String> _recentSearches = [];
  static const _kRecentKey = 'search_recent_v1';
  final List<String> _popularSearches = [
    'Rice',
    'Wheat Flour',
    'Sugar',
    'Milk',
    'Bread',
    'Vegetables',
    'Fruits',
    'Oil',
    'Spices',
    'Dal',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    } else {
      _focusNode.requestFocus();
    }
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_kRecentKey) ?? [];
    if (mounted) setState(() => _recentSearches = stored);
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentKey, _recentSearches);
  }

  Future<void> _clearAllRecent() async {
    setState(() => _recentSearches.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentKey);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    _searchResults = productProvider.searchProducts(query);

    if (_searchQuery.isNotEmpty && !_recentSearches.contains(_searchQuery)) {
      _recentSearches.insert(0, _searchQuery);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
      _saveRecentSearches();
    }

    setState(() => _isSearching = false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _searchQuery = '';
    });
    _focusNode.requestFocus();
  }

  void _startBarcodeScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );
    if (result != null && result.trim().isNotEmpty) {
      final query = result.trim();
      if (!mounted) return;

      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final matchedProducts = productProvider.searchProducts(query);

      if (matchedProducts.isNotEmpty) {
        // Step 7.4: Instant "Add to Cart" pop-up
        _showInstantAddDialog(matchedProducts.first);
      } else {
        // Step 7.5: Fallback to "Product Not Found" form for owners
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser?.role == UserRole.owner) {
          _showProductNotFoundForOwner(query);
        } else {
          _searchController.text = query;
          _performSearch(query);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Barcode '$query' scanned. No exact match."),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
      }
    }
  }

  void _showInstantAddDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Found!', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Price: ₹${product.price}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false).addToCart(product);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Add to Cart', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProductNotFoundForOwner(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'The product with barcode $barcode was not found in our catalog. Would you like to add it to your shop?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not Now')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to add product screen with pre-filled barcode
              context.push('/owner/products/add?barcode=$barcode');
            },
            child: const Text('Add Product'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            _buildSearchBar(),
            // Content
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildInitialContent()
                  : _isSearching
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _searchResults.isEmpty
                  ? _buildNoResults()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/customer/home'),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: true,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: const TextStyle(color: AppTheme.grey500),
                prefixIcon: const Icon(Icons.search, color: AppTheme.grey500),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close, color: AppTheme.grey500),
                      ),
                    IconButton(
                      onPressed: _startBarcodeScanner,
                      icon: const Icon(Icons.qr_code_scanner, color: AppTheme.grey500),
                      tooltip: 'Scan Barcode',
                    ),
                  ],
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.grey800
                    : AppTheme.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                TextButton(
                  onPressed: _clearAllRecent,
                  child: const Text('Clear All', style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((search) {
                return ActionChip(
                  label: Text(search),
                  onPressed: () {
                    _searchController.text = search;
                    _performSearch(search);
                  },
                  backgroundColor: AppTheme.grey100,
                  labelStyle: const TextStyle(color: AppTheme.grey700),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          // Popular Searches
          const Text(
            'Popular Searches',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSearches.map((search) {
              return ActionChip(
                label: Text(search),
                onPressed: () {
                  _searchController.text = search;
                  _performSearch(search);
                },
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                labelStyle: const TextStyle(color: AppTheme.primary),
                avatar: const Icon(Icons.trending_up, size: 16, color: AppTheme.primary),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: AppTheme.grey300),
          SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey700),
          ),
          SizedBox(height: 8),
          Text(
            'Try different keywords or browse categories',
            style: TextStyle(fontSize: 14, color: AppTheme.grey500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return FadeSlideIn(
          delay: Duration(milliseconds: index * 35),
          duration: const Duration(milliseconds: 280),
          offset: const Offset(0, 0.08),
          child: _buildSearchResultItem(product),
        );
      },
    );
  }

  Widget _buildSearchResultItem(ProductModel product) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return GestureDetector(
      onTap: () => context.go('/customer/product/${product.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported),
                    )
                  : const Icon(Icons.image, color: AppTheme.grey400),
            ),
            const SizedBox(width: 12),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.grey900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(product.unit, style: const TextStyle(fontSize: 12, color: AppTheme.grey500)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.originalPrice != null &&
                              product.originalPrice! > product.price)
                            Text(
                              '₹${product.originalPrice!.round()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.grey500,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '₹${product.price.round()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => cartProvider.addToCart(product),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
