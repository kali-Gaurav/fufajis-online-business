import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../constants/app_typography.dart';
import '../../constants/app_spacing.dart';

import '../../models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../services/customer_state.dart';
import 'guest_profile_screen.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/missing_animations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final user = authProvider.currentUser;

    if (authProvider.customerState == CustomerState.guest ||
        authProvider.customerState == CustomerState.guestWithCart) {
      return const Scaffold(body: GuestProfileScreen());
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header — FadeSlideIn for premium entrance
            FadeSlideIn(
              duration: const Duration(milliseconds: 500),
              child: _buildProfileHeader(user),
            ),
            const SizedBox(height: 16),
            // Buy Again Section
            SpringCard(
              delay: const Duration(milliseconds: 80),
              child: _buildBuyAgainSection(orderProvider, productProvider),
            ),
            const SizedBox(height: 16),
            // Wallet & Rewards
            SpringCard(delay: const Duration(milliseconds: 140), child: _buildWalletSection(user)),
            const SizedBox(height: 16),
            // Membership
            SpringCard(
              delay: const Duration(milliseconds: 200),
              child: _buildMembershipSection(user),
            ),
            const SizedBox(height: 16),
            // Referral Section
            SpringCard(
              delay: const Duration(milliseconds: 260),
              child: _buildReferralCard(authProvider),
            ),
            const SizedBox(height: 16),
            // Menu Items
            SpringCard(delay: const Duration(milliseconds: 320), child: _buildMenuSection()),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Row(
        children: [
          // Profile Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: user?.profileImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.network(user!.profileImage!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.person, size: 40, color: Color(0xFFFF5722)),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Guest User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.phoneNumber ?? '+91 XXXXXXXXXX',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?.role.toString().split('.').last ?? 'Customer',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Edit Button
          GestureDetector(
            onTap: () => context.push('/profile-creation'),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyAgainSection(OrderProvider orderProvider, ProductProvider productProvider) {
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Buy Again',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () => context.push('/customer/product/${product.id}'),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWalletSection(UserModel? user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Wallet
          Expanded(
            child: InkWell(
              onTap: () => context.push('/customer/wallet'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: AppTheme.primary),
                    const SizedBox(height: 4),
                    MorphNumber(
                      value: (user?.walletBalance ?? 0.0).round(),
                      prefix: '₹',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const Text('Wallet', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 40, color: AppTheme.grey200),
          // Reward Points
          Expanded(
            child: InkWell(
              onTap: () => context.push('/customer/wallet'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    const Icon(Icons.stars, color: AppTheme.warning),
                    const SizedBox(height: 4),
                    MorphNumber(
                      value: user?.rewardPoints ?? 0,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const Text('Points', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 40, color: AppTheme.grey200),
          // Cashback
          Expanded(
            child: InkWell(
              onTap: () => context.push('/customer/wallet'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.success),
                    const SizedBox(height: 4),
                    Text(
                      '₹${((user?.walletBalance ?? 0.0) * 0.15).round()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const Text('Cashback', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipSection(UserModel? user) {
    final points = user?.rewardPoints ?? 0;
    final tier = points >= 10000
        ? 'Platinum'
        : points >= 5000
        ? 'Gold'
        : points >= 1000
        ? 'Silver'
        : 'Bronze';

    final tierColor = tier == 'Platinum'
        ? Colors.purple
        : tier == 'Gold'
        ? AppTheme.warning
        : tier == 'Silver'
        ? Colors.grey
        : AppTheme.info;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tierColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: tierColor, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.workspace_premium, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$tier Member',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Earn more points for higher tier',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard(AuthProvider auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = auth.currentUser?.referralCode;
    final hasCode = code != null && code.isNotEmpty;
    final display = hasCode ? code : 'Tap to view';

    return GestureDetector(
      onTap: () => context.push('/customer/refer'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.info.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.people_alt, color: AppTheme.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Refer & Earn ₹50',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Share your referral code with friends and family. You both get ₹50 in your wallet on their first order!',
              style: TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.grey800 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppTheme.grey700 : AppTheme.grey200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    display,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : AppTheme.grey900,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (hasCode) {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('Code copied to clipboard!')));
                      } else {
                        context.push('/customer/refer');
                      }
                    },
                    icon: Icon(hasCode ? Icons.copy : Icons.arrow_forward, size: 16),
                    label: Text(hasCode ? 'COPY' : 'OPEN'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    final menuItems = [
      {'icon': Icons.shopping_bag_outlined, 'title': 'My Orders', 'color': AppTheme.primary},
      {'icon': Icons.calendar_month_outlined, 'title': 'My Subscriptions', 'color': AppTheme.info},
      {'icon': Icons.location_on_outlined, 'title': 'Saved Addresses', 'color': AppTheme.info},
      {'icon': Icons.payment_outlined, 'title': 'Payment Methods', 'color': AppTheme.success},
      {'icon': Icons.favorite_outline, 'title': 'Wishlist', 'color': AppTheme.error},
      {'icon': Icons.card_giftcard_outlined, 'title': 'Rewards', 'color': AppTheme.info},
      {'icon': Icons.workspace_premium_outlined, 'title': 'Membership', 'color': AppTheme.warning},
      {'icon': Icons.group_outlined, 'title': 'Family Management', 'color': AppTheme.info},
      {'icon': Icons.kitchen_outlined, 'title': 'Smart Kitchen', 'color': AppTheme.success},
      {'icon': Icons.notifications_outlined, 'title': 'Notifications', 'color': AppTheme.warning},
      {'icon': Icons.swap_horiz_outlined, 'title': 'Switch App Role', 'color': AppTheme.info},
      {
        'icon': Icons.contact_phone_outlined,
        'title': 'Identity & Contacts',
        'color': AppTheme.primary,
      },
      {'icon': Icons.settings_outlined, 'title': 'Settings', 'color': AppTheme.grey600},
      {'icon': Icons.help_outline, 'title': 'Help & Support', 'color': AppTheme.primary},
      {'icon': Icons.info_outline, 'title': 'About App', 'color': AppTheme.grey600},
      {'icon': Icons.logout_rounded, 'title': 'Logout', 'color': AppTheme.error},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: menuItems.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: AppTheme.grey200.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
              ),
              title: Text(
                item['title'] as String,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.grey900,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.grey400),
              onTap: () {
                if (item['title'] == 'Help & Support') {
                  _openWhatsappSupport();
                } else if (item['title'] == 'Logout') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Provider.of<AuthProvider>(context, listen: false).logout();
                          },
                          child: const Text('Logout', style: TextStyle(color: AppTheme.error)),
                        ),
                      ],
                    ),
                  );
                } else if (item['title'] == 'Switch App Role') {
                  final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                  if (user?.role == UserRole.superAdmin || user?.role == UserRole.owner) {
                    context.push('/role-select');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Access Denied: Only Authorized Staff can switch roles.'),
                      ),
                    );
                  }
                } else if (item['title'] == 'My Orders') {
                  context.push('/customer/orders');
                } else if (item['title'] == 'Saved Addresses') {
                  context.push('/customer/addresses');
                } else if (item['title'] == 'Identity & Contacts') {
                  context.push('/customer/identity');
                } else if (item['title'] == 'Settings') {
                  context.push('/customer/settings');
                } else if (item['title'] == 'Payment Methods') {
                  context.push('/customer/wallet');
                } else if (item['title'] == 'Wishlist') {
                  context.push('/customer/wishlist');
                } else if (item['title'] == 'My Subscriptions') {
                  context.push('/customer/subscriptions');
                } else if (item['title'] == 'Notifications') {
                  context.push('/customer/notifications');
                } else if (item['title'] == 'Rewards') {
                  context.push('/customer/loyalty');
                } else if (item['title'] == 'Membership') {
                  context.push('/customer/membership');
                } else if (item['title'] == 'Family Management') {
                  context.push('/customer/family');
                } else if (item['title'] == 'Smart Kitchen') {
                  context.push('/customer/smart-kitchen');
                }
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openWhatsappSupport() async {
    if (AppConfig.supportWhatsappNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp support number is not configured for this build.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final message = Uri.encodeComponent("Hello Fufaji's Online, I need help with my order.");
    final uri = Uri.parse('https://wa.me/${AppConfig.supportWhatsappNumber}?text=$message');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open WhatsApp.'), backgroundColor: AppTheme.error),
      );
    }
  }
}
