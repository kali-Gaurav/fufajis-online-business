// ============================================================================
//  Fufaji's Online — Customer Home Screen
//  Benchmark: Swiggy.  Model: SINGLE SHOP (every product belongs to Fufaji's).
//
//  Because there is only ONE shop, this screen is designed as Fufaji's own
//  storefront — not a marketplace of vendors. The layout borrows Swiggy's best
//  patterns and re-purposes them for a single-store experience:
//
//    • Immersive collapsing header with location + delivery promise
//    • A single "Store Hero" card (the Swiggy restaurant-header equivalent)
//    • Offer / coupon carousel driven by the shop's own config
//    • Quick-action service tiles (Buy Again, Express, Snap, Voice, Wallet)
//    • "What do you need today?" categories
//    • Lightning deals with live countdown
//    • Buy-Again + personalised product rails
//    • A "Why shop at Fufaji's" trust strip + store info footer
//
//  IMPORTANT: CustomerShell owns the Scaffold. This widget returns scroll
//  content only. All provider calls + routes used here are verified to exist.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/shop_config_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../models/product_model.dart';
import '../../models/reorder_template_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import '../../services/shop_service.dart';
import '../../services/remote_config_service.dart';
import '../../services/reorder_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/smart_kitchen_service.dart';
import '../../widgets/quick_reorder_card.dart';
import '../../widgets/smart_reorder_card.dart';
import '../../widgets/voice_search_dialog.dart';
import '../../widgets/countdown_timer.dart';
import '../../widgets/update_announcement_banner.dart';
import '../../product_card.dart';
import 'smart_kitchen_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/trust/fj_trust_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ShopService _shopService = ShopService();

  static const List<String> _searchHints = [
    'Search "atta"',
    'Search "cooking oil"',
    'Search "Maggi"',
    'Search "milk"',
    'Search "sugar"',
    'Search "biscuits"',
  ];

  static const List<String> _searchHintsHi = [
    'खोजें "आटा"',
    'खोजें "तेल"',
    'खोजें "मैगी"',
    'खोजें "दूध"',
    'खोजें "चीनी"',
    'खोजें "बिस्कुट"',
  ];

  int _hintIndex = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _hintIndex = (_hintIndex + 1) % _searchHints.length);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getCurrentSearchHint(bool isHindi) {
    final hints = isHindi ? _searchHintsHi : _searchHints;
    return hints[_hintIndex % hints.length];
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = Provider.of<AuthProvider>(context).currentUser;
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final isElderly = accessibility.isElderlyMode;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    return StreamBuilder<bool>(
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
            if (mounted) setState(() {});
          },
          color: AppTheme.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Pinned search + location ────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                floating: true,
                delegate: _SearchPinnedDelegate(
                  hint: _getCurrentSearchHint(isHindi),
                  onSearchTap: () => context.push('/customer/search'),
                  onVoiceTap: _openVoiceSearch,
                  isShopOpen: isShopOpen,
                  district: user?.district,
                  village: user?.village,
                  isElderly: isElderly,
                ),
              ),

              const SliverToBoxAdapter(child: UpdateAnnouncementBanner()),

              if (!isShopOpen)
                SliverToBoxAdapter(child: _ShopClosedBanner()),

              // const SliverToBoxAdapter(child: VillageChaupalFeed()),

              if (isElderly) ...[
                // ── Elderly / simple mode ─────────────────────────────
                SliverToBoxAdapter(child: _buildSmartKitchenReminder(user?.uid)),
                SliverToBoxAdapter(
                    child: _buildLargeVoiceOrderButton(accessibility)),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(child: _buildSavedPresetsSection(user?.uid)),
                SliverToBoxAdapter(
                    child: _buildCategoriesSection(productProvider, isElderly)),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                    child: _buildQuickReorderSection(orderProvider, productProvider)),
              ] else ...[
                // ── Standard, full-featured mode ──────────────────────
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // 1. Greeting + single-shop hero
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: const Duration(milliseconds: 50),
                    child: Column(
                      children: [
                        _buildGreeting(user?.name, isShopOpen),
                        _buildStoreHero(isShopOpen),
                      ],
                    ),
                  ),
                ),

                // 1.5 TRUST LAYER — NEW P0 FIX
                const SliverToBoxAdapter(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: Duration(milliseconds: 100),
                    child: FufajiTrustBanner(),
                  ),
                ),

                // 2. Offer / coupon carousel
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: const Duration(milliseconds: 120),
                    child: _buildOfferCarousel(),
                  ),
                ),

                // 3. Quick-action service tiles
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: const Duration(milliseconds: 190),
                    child: _buildQuickActions(orderProvider),
                  ),
                ),

                // 4. Categories
                const SliverToBoxAdapter(child: SizedBox(height: 4)),
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: const Duration(milliseconds: 260),
                    child: _buildCategoriesSection(productProvider, false),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // 5. Festival spotlight + lightning deals
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: const Duration(milliseconds: 330),
                    child: _buildDealZone(productProvider),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // 6. Buy again + saved lists
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: const Duration(milliseconds: 400),
                    child: Column(
                      children: [
                        const SmartReorderCard(),
                        _buildSmartPurchasingSection(orderProvider, productProvider, user?.uid),
                      ],
                    ),
                  ),
                ),

                // 7. Discovery rails
                SliverToBoxAdapter(
                  child: FadeSlideIn(
                    duration: AppTheme.durationMedium,
                    delay: const Duration(milliseconds: 470),
                    child: Column(
                      children: [
                        _buildBestSellers(productProvider),
                        _buildTrending(productProvider),
                        _buildLocalPicks(productProvider, user?.district, user?.village),
                        _buildFufajisPick(productProvider),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                    child: _buildRecentlyViewed(productProvider)),

                // 8. Smart tools
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(child: _buildSmartTools()),

                // 9. Trust strip + store info footer
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildWhyFufajis()),
                SliverToBoxAdapter(child: _buildStoreInfoFooter(isShopOpen)),
                SliverToBoxAdapter(child: _buildSignature()),
              ],

              // Clears FABs + StickyCheckoutBar
              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  GREETING
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildGreeting(String? name, bool isShopOpen) {
    final first = (name != null && name.trim().isNotEmpty)
        ? name.trim().split(' ').first
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first != null ? '${_greeting()}, $first 👋' : '${_greeting()} 👋',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.grey900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isShopOpen
                      ? 'What can Fufaji pack for you today?'
                      : 'Shop is resting — browse & we will be back soon',
                  style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  STORE HERO  (the single-shop "restaurant header" analog)
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildStoreHero(bool isShopOpen) {
    final shop = Provider.of<ShopConfigProvider>(context).shopConfig;
    final shopName = shop?.shopName ?? "Fufaji's Online";
    final freeAbove = shop?.minOrderForFreeDelivery ?? 199;
    final cashbackOn = shop?.enableCashback ?? false;
    final cashbackPct = shop?.cashbackPercentage ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppTheme.heroGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('🛒', style: TextStyle(fontSize: 26)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Your trusted local store',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _statusPill(isShopOpen),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _heroStat(Icons.star_rounded, '4.8', 'Rating'),
                      _heroDivider(),
                      _heroStat(Icons.bolt_rounded, '10–30', 'Min delivery'),
                      _heroDivider(),
                      _heroStat(Icons.payments_rounded, 'COD', 'Available'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _heroChip('🚚 Free delivery over ₹${freeAbove.round()}'),
                      if (cashbackOn && cashbackPct > 0)
                        _heroChip('💰 ${cashbackPct.round()}% cashback'),
                      _heroChip('🥬 Fresh & local'),
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

  Widget _statusPill(bool open) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: open ? AppTheme.success : AppTheme.error,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            open ? 'Open' : 'Closed',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: open ? AppTheme.secondaryDark : AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(
        width: 1,
        height: 28,
        color: Colors.white.withValues(alpha: 0.25),
      );

  Widget _heroChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  OFFER CAROUSEL
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildOfferCarousel() {
    final shop = Provider.of<ShopConfigProvider>(context, listen: false).shopConfig;
    final freeAbove = (shop?.minOrderForFreeDelivery ?? 199).round();
    final cashbackPct = (shop?.cashbackPercentage ?? 0).round();
    final cashbackOn = shop?.enableCashback ?? false;

    final offers = <_Offer>[
      _Offer(
        title: 'FREE Delivery',
        subtitle: 'On orders above ₹$freeAbove',
        code: 'AUTO',
        icon: Icons.local_shipping_rounded,
        colors: const [AppTheme.deliveryAccent, Color(0xFF43A047)],
      ),
      if (cashbackOn && cashbackPct > 0)
        _Offer(
          title: '$cashbackPct% Cashback',
          subtitle: 'In your Fufaji wallet',
          code: 'WALLET',
          icon: Icons.account_balance_wallet_rounded,
          colors: const [AppTheme.employeeAccent, Color(0xFF8E24AA)],
        ),
      const _Offer(
        title: 'First Order ₹50 OFF',
        subtitle: 'New here? Welcome to Fufaji’s',
        code: 'FUFAJI50',
        icon: Icons.card_giftcard_rounded,
        colors: [AppTheme.primaryDark, Color(0xFFFF8F00)],
      ),
      const _Offer(
        title: 'Speak & Shop',
        subtitle: 'Order by voice in seconds',
        code: 'VOICE',
        icon: Icons.mic_rounded,
        colors: [AppTheme.ownerAccent, Color(0xFF1E88E5)],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 96,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: offers.length,
          itemBuilder: (context, i) => _offerCard(offers[i]),
        ),
      ),
    );
  }

  Widget _offerCard(_Offer o) {
    return GestureDetector(
      onTap: () {
        if (o.code == 'VOICE') {
          _openVoiceSearch();
        } else if (o.code == 'WALLET') {
          context.push('/customer/wallet');
        } else {
          context.push('/customer/search');
        }
      },
      child: Container(
        width: 250,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: o.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(o.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    o.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  QUICK ACTIONS
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildQuickActions(OrderProvider orderProvider) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.mic_rounded,
        label: 'Voice Order',
        color: AppTheme.info,
        onTap: () => context.push('/customer/voice-order'),
      ),
      _QuickAction(
        icon: Icons.history_rounded,
        label: 'Buy Again',
        color: AppTheme.primary,
        onTap: () => context.push('/customer/orders'),
      ),
      _QuickAction(
        icon: Icons.kitchen_rounded,
        label: 'Smart Kitchen',
        color: const Color(0xFF2E7D32),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SmartKitchenScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Wallet',
        color: const Color(0xFFFF6F00),
        onTap: () => context.push('/customer/wallet'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadows,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: actions.map(_quickActionItem).toList(),
        ),
      ),
    );
  }

  Widget _quickActionItem(_QuickAction a) {
    return Expanded(
      child: GestureDetector(
        onTap: a.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(a.icon, color: a.color, size: 23),
            ),
            const SizedBox(height: 6),
            Text(
              a.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CATEGORIES
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildCategoriesSection(ProductProvider productProvider, bool isElderly) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    return FutureBuilder<List<String>>(
      future: user != null
          ? Future.value(RecommendationService.getFavoriteCategories(
              orderProvider.orders, productProvider.products))
          : Future.value(<String>[]),
      builder: (context, favSnapshot) {
        final favCategories = favSnapshot.data ?? [];
        final categories = List<CategoryModel>.from(productProvider.categories);

        if (favCategories.isNotEmpty) {
          categories.sort((a, b) {
            final ai = favCategories.indexOf(a.name.toLowerCase());
            final bi = favCategories.indexOf(b.name.toLowerCase());
            if (ai != -1 && bi != -1) return ai.compareTo(bi);
            if (ai != -1) return -1;
            if (bi != -1) return 1;
            return 0;
          });
        }

        if (categories.isEmpty) return const SizedBox.shrink();

        if (isElderly) {
          final display = categories.take(6).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  AppLocalizations.of(context)!.translate('shopByCategory'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.5,
                ),
                itemCount: display.length,
                itemBuilder: (context, index) {
                  final cat = display[index];
                  final selected =
                      productProvider.selectedCategory == cat.name.toLowerCase();
                  return GestureDetector(
                    onTap: () => productProvider.setSelectedCategory(
                        selected ? '' : cat.name.toLowerCase()),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary.withValues(alpha: 0.15)
                            : _catColor(cat.color).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? AppTheme.primary : AppTheme.grey300,
                          width: selected ? 3 : 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat.icon, style: const TextStyle(fontSize: 38)),
                          const SizedBox(height: 6),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: selected ? AppTheme.primary : AppTheme.grey900,
                            ),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)!.translate('whatDoYouNeed'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  if (productProvider.selectedCategory.isNotEmpty)
                    GestureDetector(
                      onTap: () => productProvider.setSelectedCategory(''),
                      child: Text(AppLocalizations.of(context)!.translate('clear'),
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 196,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) =>
                    _categoryChip(categories[index], productProvider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _categoryChip(CategoryModel cat, ProductProvider provider) {
    final selected = provider.selectedCategory == cat.id;
    final color = _catColor(cat.color);
    return GestureDetector(
      onTap: () => provider
          .setSelectedCategory(selected ? '' : cat.id),
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : color.withValues(alpha: 0.12),
                border: Border.all(
                  color: selected ? AppTheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(cat.icon, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cat.localizedName(AppLocalizations.of(context)!.localeName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.primary : AppTheme.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _catColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DEAL ZONE
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildDealZone(ProductProvider productProvider) {
    return Column(
      children: [
        _buildFestivalBanner(),
        if (productProvider.dealsProducts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildLightningDeals(productProvider),
        ],
      ],
    );
  }

  Widget _buildFestivalBanner() {
    final mode = RemoteConfigService().festivalMode;
    String title = 'Today’s Special Sale';
    String subtitle = 'Fresh deals, every day';
    List<Color> colors = [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)];
    IconData icon = Icons.celebration_rounded;

    if (mode == 'diwali') {
      title = 'Diwali Dhamaka';
      subtitle = 'Light up your home with deals';
      colors = [const Color(0xFFFF9800), const Color(0xFFFFC107)];
      icon = Icons.lightbulb_rounded;
    } else if (mode == 'holi') {
      title = 'Holi Hungama';
      subtitle = 'Colours of joy & savings';
      colors = [const Color(0xFFE91E63), const Color(0xFF2196F3)];
      icon = Icons.palette_rounded;
    } else if (mode == 'none') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => context.push('/customer/festival-bundles/${Uri.encodeComponent(title)}'),
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: Opacity(
                  opacity: 0.18,
                  child: Icon(icon, size: 150, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Shop Now →',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLightningDeals(ProductProvider productProvider) {
    DateTime endTime;
    final first = productProvider.dealsProducts.first;
    if (first.lightningDealEndTime != null) {
      endTime = first.lightningDealEndTime!;
    } else {
      final now = DateTime.now();
      endTime = DateTime(now.year, now.month, now.day, now.hour + 1, 0, 0);
    }

    return _productRail(
      title: '⚡ Lightning Deals',
      subtitleWidget: Row(
        children: [
          const Text('Hurry! Ends in ',
              style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
          CountdownTimer(
            endTime: endTime,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.error),
          ),
        ],
      ),
      products: productProvider.dealsProducts,
      categoryFilter: productProvider.selectedCategory,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SMART PURCHASING  (buy again + saved lists + kitchen)
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildSmartPurchasingSection(
      OrderProvider orderProvider, ProductProvider productProvider, String? userId) {
    final recentIds = orderProvider.getFrequentlyBoughtProductIds();
    if (recentIds.isEmpty && userId == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.03),
        border:
            const Border.symmetric(horizontal: BorderSide(color: AppTheme.grey200)),
      ),
      child: Column(
        children: [
          _buildQuickReorderSection(orderProvider, productProvider),
          if (userId != null) _buildSavedPresetsSection(userId),
          if (userId != null) _buildSmartKitchenReminder(userId),
        ],
      ),
    );
  }

  Widget _buildQuickReorderSection(
      OrderProvider orderProvider, ProductProvider productProvider) {
    final ap = Provider.of<AccessibilityProvider>(context, listen: false);
    final recentIds = orderProvider.getFrequentlyBoughtProductIds();
    if (recentIds.isEmpty) return const SizedBox.shrink();
    final products = recentIds
        .map((id) => productProvider.getProductById(id))
        .whereType<ProductModel>()
        .toList();
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(ap.label(en: 'Buy Again', hi: 'दोबारा खरीदें'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: products.length,
            itemBuilder: (context, index) =>
                QuickReorderCard(product: products[index]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ap.label(en: '📋 My Grocery Lists', hi: '📋 मेरी लिस्ट'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  TextButton(
                    onPressed: () => context.push('/customer/orders'),
                    child: Text(ap.label(en: 'Manage', hi: 'देखें')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: templates.length,
                itemBuilder: (context, index) =>
                    _presetCard(templates[index]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _presetCard(ReorderTemplate template) {
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
        boxShadow: AppTheme.cardShadows,
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
                      template.isAutoGenerated
                          ? Icons.auto_awesome
                          : Icons.bookmark,
                      size: 18,
                      color: template.isAutoGenerated
                          ? Colors.purple
                          : AppTheme.success,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        template.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.grey900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${template.itemCount} items • ₹${template.estimatedTotal.round()}',
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.replay, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(ap.label(en: 'Reorder', hi: 'ऑर्डर करें'),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary)),
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
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
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
          backgroundColor:
              result.hasUnavailableItems ? AppTheme.warning : AppTheme.success,
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
            backgroundColor: AppTheme.error),
      );
    }
  }

  Widget _buildSmartKitchenReminder(String? userId) {
    if (userId == null) return const SizedBox.shrink();
    return FutureBuilder<List<StaplePrediction>>(
      future: SmartKitchenService().predictReplenishmentNeeds(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final low = snapshot.data!.where((s) => s.isRunningLow).toList();
        if (low.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SmartKitchenScreen())),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.warning),
              ),
              child: Row(
                children: [
                  const Icon(Icons.kitchen_rounded, color: AppTheme.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Smart Kitchen Alert!',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          'Running low on ${low.length} staples like ${low.first.productName}.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.warning),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PRODUCT RAILS
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildBestSellers(ProductProvider p) => _productRail(
        title: '🏆 Bestsellers at Fufaji’s',
        subtitle: 'What the neighbourhood loves',
        products: p.featuredProducts,
        categoryFilter: p.selectedCategory,
      );

  Widget _buildTrending(ProductProvider p) => _productRail(
        title: '🔥 Trending Now',
        subtitle: 'Flying off the shelves',
        products: p.trendingProducts,
        categoryFilter: p.selectedCategory,
      );

  Widget _buildLocalPicks(ProductProvider p, String? district, String? village) {
    final local = p.getLocalProducts(district: district, village: village);
    if (local.isEmpty) return const SizedBox.shrink();
    return _productRail(
      title: '🏡 Fufaji’s Local Picks',
      subtitle: 'Specialties from ${village ?? district ?? 'your area'}',
      products: local,
      categoryFilter: p.selectedCategory,
    );
  }

  Widget _buildFufajisPick(ProductProvider p) {
    final picks = p.featuredProducts.take(8).toList();
    if (picks.isEmpty) return const SizedBox.shrink();
    return _productRail(
      title: '⭐ Fufaji’s Pick',
      subtitle: 'Hand-checked for quality',
      products: picks,
      categoryFilter: p.selectedCategory,
    );
  }

  Widget _buildRecentlyViewed(ProductProvider p) {
    if (p.recentlyViewed.isEmpty) return const SizedBox.shrink();
    return _productRail(
      title: '👀 Recently Viewed',
      subtitle: 'Pick up where you left off',
      products: p.recentlyViewed,
      categoryFilter: p.selectedCategory,
    );
  }

  Widget _productRail({
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    required List<ProductModel> products,
    String? categoryFilter,
  }) {
    final filtered = (categoryFilter != null && categoryFilter.isNotEmpty)
        ? products
            .where((p) =>
                p.categoryId.toLowerCase() == categoryFilter.toLowerCase())
            .toList()
        : products;

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      if (subtitleWidget != null)
                        subtitleWidget
                      else if (subtitle != null)
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.grey600)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/customer/search'),
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 262,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filtered.length,
              itemBuilder: (context, index) => Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                child: ProductCard(product: filtered[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SMART TOOLS
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildSmartTools() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🛠️ Smart Tools',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _smartToolCard(
                  icon: Icons.mic_rounded,
                  label: 'Voice Search',
                  onTap: _openVoiceSearch,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _smartToolCard(
                  icon: Icons.kitchen_rounded,
                  label: 'Smart Kitchen',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SmartKitchenScreen())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _smartToolCard(
                  icon: Icons.support_agent_rounded,
                  label: 'Help & Support',
                  onTap: () => context.push('/customer/support'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _smartToolCard(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              auth.logout();
                            },
                            child: const Text('Sign Out', style: TextStyle(color: AppTheme.error)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smartToolCard({
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
            Icon(icon, color: AppTheme.primary, size: 26),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey800)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  WHY FUFAJI'S
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildWhyFufajis() {
    final items = <List<dynamic>>[
      [Icons.eco_rounded, 'Fresh\n& Local', const Color(0xFF2E7D32)],
      [Icons.bolt_rounded, 'Fast\nDelivery', const Color(0xFFFF6F00)],
      [Icons.verified_user_rounded, 'Trusted\nQuality', const Color(0xFF1565C0)],
      [Icons.favorite_rounded, 'Caring\nSupport', const Color(0xFFC2185B)],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadows,
        ),
        child: Column(
          children: [
            const Text('Why shop at Fufaji’s?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((it) {
                return Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (it[2] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(it[0] as IconData,
                          color: it[2] as Color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(it[1] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.grey800)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  STORE INFO FOOTER
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildStoreInfoFooter(bool isShopOpen) {
    final shop = Provider.of<ShopConfigProvider>(context, listen: false).shopConfig;
    final name = shop?.shopName ?? "Fufaji's Online Store";
    final address = shop?.shopAddress ?? 'Jaipur, Rajasthan, India';
    final phone = shop?.shopPhone ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.grey50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 20, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isShopOpen ? AppTheme.success : AppTheme.error)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(isShopOpen ? 'Open now' : 'Closed',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isShopOpen
                              ? AppTheme.secondaryDark
                              : AppTheme.error)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _footerRow(Icons.location_on_rounded, address),
            const SizedBox(height: 6),
            _footerRow(Icons.access_time_rounded, 'Daily • 8:00 AM – 9:00 PM'),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => _call(phone),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.grey300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.call_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Call', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => _openWhatsapp(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _footerRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.grey500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.grey700)),
        ),
      ],
    );
  }

  Widget _buildSignature() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Center(
        child: Text(
          'Made for our neighbourhood.\nFrom Fufaji’s, with ❤️',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.grey400,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ELDERLY: big voice button
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildLargeVoiceOrderButton(AccessibilityProvider ap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push('/customer/voice-order'),
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
                    child: const Icon(Icons.mic, size: 48, color: Colors.white),
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
                              color: Colors.white),
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
                              fontWeight: FontWeight.bold),
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

  // ════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _openVoiceSearch() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const VoiceSearchDialog(),
    );
    if (result != null && result.isNotEmpty && mounted) {
      context.push('/customer/search?q=$result');
    }
  }

  Future<void> _call(String phone) async {
    final url = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsapp() async {
    final phone = RemoteConfigService()
        .supportPhone
        .replaceAll('+', '')
        .replaceAll(' ', '');
    final url =
        Uri.parse('https://wa.me/$phone?text=Hello Fufaji, I need help.');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SHOP CLOSED BANNER
// ════════════════════════════════════════════════════════════════════════════
class _ShopClosedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppTheme.error.withValues(alpha: 0.95),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.door_front_door_outlined, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Shop is closed right now — browse freely, order when we reopen.',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PINNED SEARCH + LOCATION
// ════════════════════════════════════════════════════════════════════════════
class _SearchPinnedDelegate extends SliverPersistentHeaderDelegate {
  final String hint;
  final VoidCallback onSearchTap;
  final VoidCallback onVoiceTap;
  final bool isShopOpen;
  final String? district;
  final String? village;
  final bool isElderly;

  const _SearchPinnedDelegate({
    required this.hint,
    required this.onSearchTap,
    required this.onVoiceTap,
    required this.isShopOpen,
    this.district,
    this.village,
    required this.isElderly,
  });

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 110;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final locationOpacity = (1 - shrinkOffset / 46).clamp(0.0, 1.0);
    final showLocation = shrinkOffset < 46;

    return Container(
      height: (maxExtent - shrinkOffset).clamp(minExtent, maxExtent),
      color: AppTheme.cream,
      child: Column(
        children: [
          if (showLocation)
            Opacity(
              opacity: locationOpacity,
              child: _LocationRow(district: district, village: village),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: GestureDetector(
              onTap: onSearchTap,
              child: GlassmorphicContainer(
                height: 44,
                borderRadius: 12,
                tint: AppTheme.primaryLight.withValues(alpha: 0.15),
                borderColor: AppTheme.primary.withValues(alpha: 0.25),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hint,
                        style: const TextStyle(fontSize: 14, color: AppTheme.grey700),
                      ),
                    ),
                    GestureDetector(
                      onTap: onVoiceTap,
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.mic_rounded, color: AppTheme.primary, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchPinnedDelegate old) =>
      old.isShopOpen != isShopOpen ||
      old.district != district ||
      old.village != village ||
      old.hint != hint ||
      old.isElderly != isElderly;
}

class _LocationRow extends StatelessWidget {
  final String? district;
  final String? village;

  const _LocationRow({this.district, this.village});

  @override
  Widget build(BuildContext context) {
    final location = (village != null && village!.isNotEmpty)
        ? '$village, ${district ?? ''}'
        : (district ?? 'Jaipur');

    return GestureDetector(
      onTap: () => context.push('/customer/addresses'),
      child: Container(
        color: AppTheme.cream,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded,
                size: 16, color: AppTheme.primary),
            const SizedBox(width: 4),
            const Text('Deliver to ',
                style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
            Flexible(
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.grey900),
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                size: 16, color: AppTheme.grey500),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 12, color: AppTheme.info),
                  SizedBox(width: 2),
                  Text('10 min',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.info)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SMALL MODELS
// ════════════════════════════════════════════════════════════════════════════
class _Offer {
  final String title;
  final String subtitle;
  final String code;
  final IconData icon;
  final List<Color> colors;
  const _Offer({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.icon,
    required this.colors,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
