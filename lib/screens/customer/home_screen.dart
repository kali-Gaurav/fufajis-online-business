import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';
import '../../services/shop_service.dart';
import '../../services/remote_config_service.dart';
import '../../widgets/quick_reorder_card.dart';
import '../../widgets/voice_search_dialog.dart';
import '../../widgets/one_click_voice_order.dart';
import '../../widgets/countdown_timer.dart';
import '../../product_card.dart';
import '../../services/reorder_service.dart';
import '../../models/reorder_template_model.dart';
import '../../providers/accessibility_provider.dart';
import 'smart_kitchen_screen.dart';
import '../../services/smart_kitchen_service.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/update_announcement_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ShopService _shopService = ShopService();

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = Provider.of<AuthProvider>(context).currentUser;
    final accessibilityProvider = Provider.of<AccessibilityProvider>(context);
    final isElderly = accessibilityProvider.isElderlyMode;

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
          _buildReorderEssentialsWidget(orderProvider, productProvider),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'voice_order',
            onPressed: () => showOneClickOrder(context),
            label: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  accessibilityProvider.label(en: '3-STEP QUICK ORDER', hi: 'बोलकर ऑर्डर करें'), 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      accessibilityProvider.label(en: 'FASTEST WAY TO SHOP', hi: 'सबसे आसान तरीका'), 
                      style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.8))
                    ),
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
        stream: _shopService.getShopStatusStream(),
        initialData: true,
        builder: (context, snapshot) {
          final isShopOpen = snapshot.data ?? true;
          
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                productProvider.refreshProducts(),
                Future.delayed(const Duration(milliseconds: 300)),
              ]);
              if (mounted) setState(() {}); // Refresh banners and deals
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: isElderly
                    ? [
                        const UpdateAnnouncementBanner(),
                        if (!isShopOpen) _buildShopClosedBanner(),
                        _buildLocationBanner(user?.district, user?.village),
                        const SizedBox(height: 16),
                        _buildSmartKitchenReminder(user?.uid),
                        _buildLargeVoiceOrderButton(accessibilityProvider),
                        const SizedBox(height: 16),
                        _buildSearchBar(),
                        const SizedBox(height: 24),
                        _buildSavedPresetsSection(user?.uid),
                        _buildCategoriesSection(productProvider),
                        const SizedBox(height: 24),
                        _buildQuickReorderSection(orderProvider, productProvider),
                        const SizedBox(height: 80),
                      ]
                    : [
                        const UpdateAnnouncementBanner(),
                        if (!isShopOpen) _buildShopClosedBanner(),
                        _buildLocationBanner(user?.district, user?.village),
                        const SizedBox(height: 8),
                        _buildSmartKitchenReminder(user?.uid),
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        _buildFestivalBanner(),
                        const SizedBox(height: 16),
                        _buildRecentlyViewedSection(productProvider),
                        _buildLocalSpecialtiesSection(productProvider, user?.district, user?.village),
                        const SizedBox(height: 16),
                        _buildQuickReorderSection(orderProvider, productProvider),
                        _buildSavedPresetsSection(user?.uid),
                        _buildCategoriesSection(productProvider),
                        const SizedBox(height: 16),
                        _lightningDealsSection(productProvider: productProvider),
                        const SizedBox(height: 16),
                        _buildFlashDealsSection(productProvider),
                        const SizedBox(height: 16),
                        _buildCustomerSmartTools(),
                        const SizedBox(height: 16),
                        _buildFufajisPick(productProvider),
                        const SizedBox(height: 16),
                        _buildLiveDealsCounter(productProvider),
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

  Widget _buildLargeVoiceOrderButton(AccessibilityProvider ap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => showOneClickOrder(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ap.label(en: 'Speak to Order', hi: 'बोलकर ऑर्डर करें'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ap.label(
                            en: 'Tap here and say what you want to buy',
                            hi: 'यहाँ दबाएं और बोलें जो भी सामान चाहिए',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShopClosedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.9)),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
    final ap = Provider.of<AccessibilityProvider>(context, listen: false);
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
                Text(ap.label(en: 'Delivering to', hi: 'यहाँ डिलीवरी होगी'), style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
                Text(
                  '${village ?? 'Local Area'}, ${district ?? 'Nearby'}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/customer/addresses'),
            child: Text(ap.label(en: 'Change', hi: 'बदलें'), style: const TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartKitchenReminder(String? userId) {
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<List<StaplePrediction>>(
      future: SmartKitchenService().predictReplenishmentNeeds(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        final lowStaples = snapshot.data!.where((s) => s.isRunningLow).toList();
        if (lowStaples.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SmartKitchenScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.kitchen, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart Kitchen Alert!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'You are running low on ${lowStaples.length} staples like ${lowStaples.first.productName}.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.amber),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    final ap = Provider.of<AccessibilityProvider>(context, listen: false);
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
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppTheme.grey500),
                    const SizedBox(width: 12),
                    Text(
                      ap.label(en: 'Search products...', hi: 'सामान खोजें...'), 
                      style: const TextStyle(fontSize: 16, color: AppTheme.grey500)
                    ),
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
    final ap = Provider.of<AccessibilityProvider>(context, listen: false);
    final recentIds = orderProvider.getFrequentlyBoughtProductIds();
    if (recentIds.isEmpty) return const SizedBox.shrink();
    final products = recentIds.map((id) => productProvider.getProductById(id)).whereType<ProductModel>().toList();
    if (products.isEmpty) return const SizedBox.shrink();
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            ap.label(en: 'Buy Again', hi: 'दोबारा खरीदें'), 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
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

  /// Saved Grocery Presets section — shows user's reorder templates
  Widget _buildSavedPresetsSection(String? userId) {
    if (userId == null) return const SizedBox.shrink();
    final ap = Provider.of<AccessibilityProvider>(context, listen: false);
 
    return FutureBuilder<List<ReorderTemplate>>(
      future: ReorderService().getTemplates(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
 
        final templates = snapshot.data!;
 
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
                      Text(
                        ap.label(en: '📋 My Grocery Presets', hi: '📋 मेरी लिस्ट'), 
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      Text(
                        ap.label(en: 'One-tap to reorder', hi: 'एक बार में पूरा ऑर्डर करें'), 
                        style: const TextStyle(fontSize: 12, color: AppTheme.grey600)
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.push('/customer/orders'),
                    child: Text(ap.label(en: 'Manage', hi: 'देखें')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  return _buildPresetCard(templates[index]);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildPresetCard(ReorderTemplate template) {
    final ap = Provider.of<AccessibilityProvider>(context, listen: false);
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: template.isAutoGenerated
              ? [const Color(0xFFF3E5F5), const Color(0xFFE1BEE7)]
              : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleTemplateReorder(template),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      template.isAutoGenerated ? Icons.auto_awesome : Icons.bookmark,
                      size: 18,
                      color: template.isAutoGenerated ? Colors.purple : AppTheme.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        template.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.grey900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ap.label(
                    en: '${template.itemCount} items • ₹${template.estimatedTotal.round()}',
                    hi: '${template.itemCount} सामान • ₹${template.estimatedTotal.round()}'
                  ),
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.replay, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        ap.label(en: 'Reorder', hi: 'ऑर्डर करें'), 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTemplateReorder(ReorderTemplate template) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await ReorderService().populateCartFromTemplate(
      template: template,
      cartProvider: cartProvider,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.summaryMessage),
          backgroundColor: result.hasUnavailableItems ? Colors.orange : AppTheme.success,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'VIEW CART',
            textColor: Colors.white,
            onPressed: () => context.push('/customer/cart'),
          ),
        ),
      );
      context.push('/customer/cart');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.summaryMessage),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildCategoriesSection(ProductProvider productProvider) {
    final ap = Provider.of<AccessibilityProvider>(context, listen: false);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final isElderly = ap.isElderlyMode;
    
    return FutureBuilder<List<String>>(
      future: user != null ? Future.value(RecommendationService.getFavoriteCategories(orderProvider.orders, productProvider.products)) : Future.value(<String>[]),
      builder: (context, favSnapshot) {
        final favCategories = favSnapshot.data ?? [];
        final categories = List<CategoryModel>.from(productProvider.categories);

        // Sort categories to bubble up user's favorites
        if (favCategories.isNotEmpty) {
          categories.sort((a, b) {
            final aIndex = favCategories.indexOf(a.name.toLowerCase());
            final bIndex = favCategories.indexOf(b.name.toLowerCase());
            if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
            if (aIndex != -1) return -1;
            if (bIndex != -1) return 1;
            return 0;
          });
        }

        final displayCategories = isElderly ? categories.take(6).toList() : categories;

        if (isElderly) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  ap.label(en: 'Shop by Category', hi: 'सामान की श्रेणी'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.4,
                ),
                itemCount: displayCategories.length,
                itemBuilder: (context, index) {
                  final cat = displayCategories[index];
                  final isSelected = productProvider.selectedCategory == cat.name.toLowerCase();
                  return GestureDetector(
                    onTap: () => productProvider.setSelectedCategory(isSelected ? '' : cat.name.toLowerCase()),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppTheme.primary.withValues(alpha: 0.15)
                            : Color(int.parse(cat.color.replaceFirst('#', '0xFF'))).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.grey300,
                          width: isSelected ? 3 : 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat.icon, style: const TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          Text(
                            cat.name, 
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.primary : AppTheme.grey900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        }

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
      },
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

  Widget _buildReorderEssentialsWidget(OrderProvider orderProvider, ProductProvider productProvider) {
    final essentials = orderProvider.getWeeklyEssentials();
    if (essentials.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.primary,
        child: InkWell(
          onTap: () {
            // Bulk add essentials to cart
            final products = essentials
                .map((id) => productProvider.getProductById(id))
                .whereType<ProductModel>()
                .toList();
            for (var p in products) {
              Provider.of<CartProvider>(context, listen: false).addToCart(p);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${products.length} essentials added to cart!'), backgroundColor: AppTheme.success),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.replay_circle_filled, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'REORDER ESSENTIALS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildCustomerSmartTools() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🛠️ Smart Tools',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmartToolCard(
                  icon: Icons.camera_alt_outlined,
                  label: 'Snap to Shop',
                  onTap: () => context.push('/customer/snap-to-shop'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmartToolCard(
                  icon: Icons.kitchen_outlined,
                  label: 'Smart Kitchen',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SmartKitchenScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmartToolCard(
                  icon: Icons.group_outlined,
                  label: 'Group Buy',
                  onTap: () => context.push('/customer/group-buying'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartToolCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.grey200),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFufajisPick(ProductProvider productProvider) {
    final picks = productProvider.featuredProducts.take(6).toList();
    if (picks.isEmpty) return const SizedBox.shrink();
    return _buildProductSection(
      title: "⭐ Fufaji's Pick",
      subtitle: 'Handpicked best quality items',
      products: picks,
      onSeeAll: () => context.push('/customer/search?q=featured'),
      categoryFilter: productProvider.selectedCategory,
    );
  }

  Widget _buildLiveDealsCounter(ProductProvider productProvider) {
    final dealsCount = productProvider.dealsProducts.length;
    if (dealsCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push('/customer/search?q=deals'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A11CB).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dealsCount Live Deals Active!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Grab them before they\'re gone',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
