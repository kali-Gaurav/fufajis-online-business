import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/subscription_model.dart';
import '../../models/product_model.dart';
import '../../models/product_review_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/qna_section.dart';
import '../../widgets/group_buy_widget.dart';
import '../../widgets/farm_map_widget.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  bool _isLoading = true;
  ProductModel? _product;
  ProductUnitOption? _selectedUnitOption;
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<List<ProductReviewModel>>? _reviewsSubscription;
  List<ProductReviewModel> _reviews = [];
  bool _isSubmittingReview = false;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  void _loadProduct() {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final prod = productProvider.getProductById(widget.productId);
    if (prod != null) {
      _product = prod;
      productProvider.addToRecentlyViewed(prod.id);
      if (prod.unitOptions.isNotEmpty) {
        _selectedUnitOption = prod.unitOptions.first;
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
    _listenToReviews();
  }

  void _listenToReviews() {
    _reviewsSubscription?.cancel();
    _reviewsSubscription = _firestoreService.getProductReviewsStream(widget.productId).listen(
      (reviews) {
        if (mounted) setState(() => _reviews = reviews);
      },
      onError: (_) {
        if (mounted) setState(() => _reviews = []);
      },
    );
  }

  @override
  void dispose() {
    _reviewsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_product == null) return _buildNotFound();

    final productProvider = Provider.of<ProductProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final variantKey = _selectedUnitOption?.name;
    final cartQuantity = cartProvider.getQuantityForVariant(widget.productId, variantKey);
    final isInCart = cartQuantity > 0;
    final isFavorite = productProvider.isInWishlist(widget.productId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.grey900),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.grey900),
            onPressed: () {
              final shareText = 'Check out ${_product!.name} on Fufaji\'s Online!\n'
                  'Price: ₹${(_product!.isLightningDealActive ? _product!.lightningDealPrice : _product!.price)?.round()}\n'
                  'Link: https://fufajis.online/product/${widget.productId}';
              SharePlus.share(shareText);
            },
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : AppTheme.grey900,
            ),
            onPressed: () => productProvider.toggleWishlist(widget.productId),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: _buildProductContent(cartProvider, isInCart, cartQuantity),
      bottomNavigationBar: _buildBottomBar(cartProvider, isInCart, cartQuantity),
    );
  }

  Widget _buildNotFound() {
    return Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2, size: 80, color: AppTheme.grey400),
            const SizedBox(height: 16),
            const Text('Product not found', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => context.go('/'), child: const Text('Go to Home')),
          ],
        ),
      ),
    );
  }

  Widget _buildProductContent(CartProvider cartProvider, bool isInCart, int quantity) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailLightningBanner(product: _product!),
          _buildProductImages(),
          const SizedBox(height: 16),
          _buildProductInfo(),
          const SizedBox(height: 16),
          if (_product!.unitOptions.isNotEmpty) ...[
            _buildUnitOptionsSelector(),
            const SizedBox(height: 16),
          ],
          _buildQuantitySelector(),
          const SizedBox(height: 16),
          GroupBuyWidget(product: _product!),
          const SizedBox(height: 16),
          FarmMapWidget(product: _product!),
          const SizedBox(height: 16),
          _buildDeliveryInfo(),
          const SizedBox(height: 16),
          _buildSpecifications(),
          const SizedBox(height: 16),
          _buildReviewsSection(),
          const SizedBox(height: 16),
          QnaSection(productId: widget.productId),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildProductImages() {
    final images = _product!.images.isNotEmpty ? _product!.images : [_product!.imageUrl];
    return Container(
      height: 300,
      color: Colors.white,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          final imgUrl = images[index].toString();
          return imgUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imgUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported, size: 80),
                )
              : const Icon(Icons.image, size: 80);
        },
      ),
    );
  }

  Widget _buildProductInfo() {
    final double displayPrice = _selectedUnitOption != null ? _selectedUnitOption!.price : (_product!.isLightningDealActive ? (_product!.lightningDealPrice ?? 0.0) : _product!.price);
    final double? originalPrice = _selectedUnitOption != null ? _selectedUnitOption!.originalPrice : _product!.originalPrice;
    final String unit = _selectedUnitOption != null ? _selectedUnitOption!.name : _product!.unit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_product!.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_product!.shopName, style: const TextStyle(color: AppTheme.grey600)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${displayPrice.round()}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              if (originalPrice != null && originalPrice > displayPrice) ...[
                const SizedBox(width: 12),
                Text('₹${originalPrice.round()}', style: const TextStyle(fontSize: 18, color: Colors.grey, decoration: TextDecoration.lineThrough)),
              ],
            ],
          ),
          Text('Price per $unit', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildUnitOptionsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Select Option', style: TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _product!.unitOptions.length,
            itemBuilder: (context, index) {
              final opt = _product!.unitOptions[index];
              final isSel = _selectedUnitOption?.id == opt.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedUnitOption = opt),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.primary.withValues(alpha: 0.1) : Colors.white,
                    border: Border.all(color: isSel ? AppTheme.primary : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(opt.name, style: TextStyle(color: isSel ? AppTheme.primary : Colors.black, fontWeight: isSel ? FontWeight.bold : FontWeight.normal))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null, icon: const Icon(Icons.remove_circle_outline)),
          Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(onPressed: () => setState(() => _quantity++), icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfo() => const ListTile(leading: Icon(Icons.local_shipping, color: AppTheme.primary), title: Text('Express Delivery Available'), subtitle: Text('Delivered within 2-4 hours'));

  Widget _buildSpecifications() {
    if (_product!.specifications.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Specifications', style: TextStyle(fontWeight: FontWeight.bold))),
        ..._product!.specifications.entries.map((e) => ListTile(title: Text(e.key), trailing: Text(e.value.toString()))),
      ],
    );
  }

  Widget _buildReviewsSection() => ListTile(title: const Text('Customer Reviews'), trailing: Text('${_reviews.length} Reviews'), onTap: () {});

  Widget _buildBottomBar(CartProvider cart, bool isInCart, int qty) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                cart.addToCart(_product!, quantity: _quantity, selectedUnit: _selectedUnitOption);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Cart')));
              },
              child: const Text('ADD TO CART'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                cart.addToCart(_product!, quantity: _quantity, selectedUnit: _selectedUnitOption);
                context.push('/customer/checkout');
              },
              child: const Text('BUY NOW'),
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewComposer() {
    // Logic for review composer
  }
}

class DetailLightningBanner extends StatefulWidget {
  final ProductModel product;
  const DetailLightningBanner({super.key, required this.product});

  @override
  State<DetailLightningBanner> createState() => _DetailLightningBannerState();
}

class _DetailLightningBannerState extends State<DetailLightningBanner> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) => mounted ? setState(() {}) : null);
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.product.isLightningDealActive) return const SizedBox.shrink();
    return Container(
      color: Colors.red.shade900,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(children: [Icon(Icons.flash_on, color: Colors.yellow), SizedBox(width: 8), Text('LIGHTNING DEAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
    );
  }
}
