import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/remote_config_service.dart';
import '../../widgets/quick_reorder_card.dart';
import '../../widgets/voice_search_dialog.dart';
import '../../widgets/one_click_voice_order.dart';
import '../../widgets/countdown_timer.dart';
import '../../product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = Provider.of<AuthProvider>(context).currentUser;

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'whatsapp',
            onPressed: _openWhatsappSupport,
            backgroundColor: const Color(0xFF25D366),
            child: const Icon(Icons.chat, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'voice_order',
            onPressed: () => showOneClickOrder(context),
            label: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('3-STEP QUICK ORDER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('FASTEST WAY TO SHOP', style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(width: 4),
                    const Icon(Icons.info_outline, size: 8, color: Colors.white70),
                  ],
                ),
              ],
            ),
            icon: const Icon(Icons.mic, size: 28),
            backgroundColor: AppTheme.primaryColor,
          ),
        ],
      ),
      body: StreamBuilder<bool>(
        stream: _firestoreService.getShopStatusStream(),
        initialData: true,
        builder: (context, snapshot) {
          final isShopOpen = snapshot.data ?? true;
          
          return RefreshIndicator(
            onRefresh: () async {
              await productProvider.refreshProducts();
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isShopOpen) _buildShopClosedBanner(),
                  _buildLocationBanner(user?.district, user?.village),
                  const SizedBox(height: 8),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildFestivalBanner(),
                  const SizedBox(height: 16),
                  _buildRecentlyViewedSection(productProvider),
                  _buildLocalSpecialtiesSection(productProvider, user?.district, user?.village),
                  const SizedBox(height: 16),
                  _buildQuickReorderSection(orderProvider, productProvider),
                  _buildCategoriesSection(productProvider),
                  const SizedBox(height: 16),
                  _lightningDealsSection(productProvider: productProvider),
                  const SizedBox(height: 16),
                  _buildFlashDealsSection(productProvider),
                  const SizedBox(height: 16),
                  _buildTrendingSection(productProvider),
                  const SizedBox(height: 16),
                  _buildNearbySection(productProvider),
                  const SizedBox(height: 16),
                  _buildBestSellersSection(productProvider),
                  const SizedBox(height: 80), // Space for FABs
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShopClosedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.9)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.door_front_door_outlined, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'SHOP CLOSED: We are not accepting orders right now.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBanner(String? district, String? village) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1)),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivering to', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
                Text(
                  '${village ?? 'Local Area'}, ${district ?? 'Nearby'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/customer/addresses'),
            child: const Text('Change', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/customer/search'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppTheme.grey500),
                    SizedBox(width: 12),
                    Text('Search products...', style: TextStyle(fontSize: 16, color: AppTheme.grey500)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              onPressed: () async {
                final result = await showDialog<String>(
                  context: context,
                  builder: (context) => const VoiceSearchDialog(),
                );
                if (result != null && result.isNotEmpty && mounted) {
                  context.push('/customer/search?q=$result');
                }
              },
              icon: const Icon(Icons.mic, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFestivalBanner() {
    final remoteConfig = RemoteConfigService();
    final mode = remoteConfig.festivalMode;

    String title = 'Special Sale';
    String subtitle = 'Up to 50% Off';
    List<Color> colors = [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)];
    IconData icon = Icons.celebration;

    if (mode == 'diwali') {
      title = 'Diwali Dhamaka';
      subtitle = 'Light up your home with deals';
      colors = [const Color(0xFFFF9800), const Color(0xFFFFEB3B)];
      icon = Icons.lightbulb_outline;
    } else if (mode == 'holi') {
      title = 'Holi Hungama';
      subtitle = 'Colors of Joy & Savings';
      colors = [const Color(0xFFE91E63), const Color(0xFF2196F3)];
      icon = Icons.palette_outlined;
    } else if (mode == 'none') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push('/customer/search?q=sale'),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.white)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Shop Now',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: -20,
                bottom: -20,
                child: Opacity(
                  opacity: 0.2,
                  child: Icon(icon, size: 160, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyViewedSection(ProductProvider productProvider) {
    if (productProvider.recentlyViewed.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        _buildProductSection(
          title: 'Recently Viewed',
          subtitle: 'Pick up where you left off',
          products: productProvider.recentlyViewed,
          onSeeAll: () {},
          categoryFilter: productProvider.selectedCategory,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLocalSpecialtiesSection(ProductProvider productProvider, String? district, String? village) {
    final localProducts = productProvider.getLocalProducts(district: district, village: village);
    if (localProducts.isEmpty) return const SizedBox.shrink();
    return _buildProductSection(
      title: '🏡 Fufaji\'s Local Picks',
      subtitle: 'Specialties from ${village ?? district ?? 'your area'}',
      products: localProducts,
      onSeeAll: () {},
      categoryFilter: productProvider.selectedCategory,
    );
  }

  Widget _buildQuickReorderSection(OrderProvider orderProvider, ProductProvider productProvider) {
    final recentIds = orderProvider.getFrequentlyBoughtProductIds();
    if (recentIds.isEmpty) return const SizedBox.shrink();
    final products = recentIds.map((id) => productProvider.getProductById(id)).whereType<ProductModel>().toList();
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Buy Again', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: products.length,
            itemBuilder: (context, index) => QuickReorderCard(product: products[index]),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoriesSection(ProductProvider productProvider) {
    final categories = productProvider.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {}, child: const Text('See All')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _buildCategoryItem(cat.name, cat.icon, cat.color, productProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(String name, String icon, String color, ProductProvider provider) {
    final isSelected = provider.selectedCategory == name.toLowerCase();
    return GestureDetector(
      onTap: () => provider.setSelectedCategory(isSelected ? '' : name.toLowerCase()),
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : Color(int.parse(color.replaceFirst('#', '0xFF'))).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? Border.all(color: AppTheme.primary, width: 2) : null,
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 32))),
            ),
            const SizedBox(height: 4),
            Text(
              name, 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.grey900,
              ), 
              textAlign: TextAlign.center, 
              overflow: TextOverflow.ellipsis
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashDealsSection(ProductProvider productProvider) {
    DateTime? endTime;
    if (productProvider.dealsProducts.isNotEmpty && productProvider.dealsProducts.first.lightningDealEndTime != null) {
      endTime = productProvider.dealsProducts.first.lightningDealEndTime;
    } else {
      // Default to end of hour if not set
      final now = DateTime.now();
      endTime = DateTime(now.year, now.month, now.day, now.hour + 1, 0, 0);
    }

    return _buildProductSection(
      title: '⚡ Flash Deals', 
      subtitleWidget: Row(
        children: [
          const Text('Ends in ', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
          CountdownTimer(endTime: endTime!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error)),
        ],
      ),
      products: productProvider.dealsProducts, 
      onSeeAll: () {}, 
      categoryFilter: productProvider.selectedCategory
    );
  }
  
  Widget _lightningDealsSection({required ProductProvider productProvider}) {
    DateTime? endTime;
    if (productProvider.dealsProducts.isNotEmpty && productProvider.dealsProducts.first.lightningDealEndTime != null) {
      endTime = productProvider.dealsProducts.first.lightningDealEndTime;
    } else {
      final now = DateTime.now();
      endTime = DateTime(now.year, now.month, now.day, now.hour + 1, 0, 0);
    }

    return _buildProductSection(
      title: '⚡ Lightning Deals', 
      subtitleWidget: Row(
        children: [
          const Text('Hurry! Prices reset in ', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
          CountdownTimer(endTime: endTime!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
        ],
      ),
      products: productProvider.dealsProducts, 
      onSeeAll: () {}, 
      categoryFilter: productProvider.selectedCategory
    );
  }

  Widget _buildTrendingSection(ProductProvider productProvider) => _buildProductSection(title: '🔥 Trending Now', subtitle: 'Most popular', products: productProvider.trendingProducts, onSeeAll: () {}, categoryFilter: productProvider.selectedCategory);
  Widget _buildNearbySection(ProductProvider productProvider) => _buildProductSection(title: '📍 Nearby Popular', subtitle: 'From shops near you', products: productProvider.getNearbyProducts(), onSeeAll: () {}, categoryFilter: productProvider.selectedCategory);
  Widget _buildBestSellersSection(ProductProvider productProvider) => _buildProductSection(title: '🏆 Best Sellers', subtitle: 'Top products this week', products: productProvider.featuredProducts, onSeeAll: () {}, categoryFilter: productProvider.selectedCategory);

  Widget _buildProductSection({
    required String title, 
    String? subtitle, 
    Widget? subtitleWidget,
    required List<dynamic> products, 
    required VoidCallback onSeeAll, 
    String? categoryFilter
  }) {
    // Apply category filter if active
    final filteredProducts = categoryFilter != null && categoryFilter.isNotEmpty
        ? products.where((p) => p.category.toLowerCase() == categoryFilter.toLowerCase()).toList()
        : products;

    if (filteredProducts.isEmpty && categoryFilter != null && categoryFilter.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (subtitleWidget != null)
                    subtitleWidget
                  else if (subtitle != null)
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
                ],
              ),
              TextButton(onPressed: onSeeAll, child: const Text('See All')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: products.isEmpty ? const Center(child: Text('No products available')) : ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: ProductCard(product: product),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openWhatsappSupport() async {
    final remoteConfig = RemoteConfigService();
    final phone = remoteConfig.supportPhone.replaceAll('+', '').replaceAll(' ', '');
    final url = Uri.parse('https://wa.me/$phone?text=Hello Fufaji, I need help.');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
