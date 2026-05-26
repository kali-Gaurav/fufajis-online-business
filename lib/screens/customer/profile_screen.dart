import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

import '../../widgets/common/role_restricted_widget.dart';

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
    final user = authProvider.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(user),
            const SizedBox(height: 16),
            // Wallet & Rewards
            _buildWalletSection(user),
            const SizedBox(height: 16),
            // Membership
            _buildMembershipSection(user),
            const SizedBox(height: 16),
            // Referral Section
            _buildReferralCard(authProvider),
            const SizedBox(height: 16),
            // Menu Items
            _buildMenuSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
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
                    child: Image.network(
                      user!.profileImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 40,
                    color: Color(0xFFFF5722),
                  ),
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
                ),
                const SizedBox(height: 4),
                Text(
                  user?.phoneNumber ?? '+91 XXXXXXXXXX',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit, color: Colors.white),
          ),
        ],
      ),
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
                    Text(
                      '₹${(user?.walletBalance ?? 0.0).round()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const Text(
                      'Wallet',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
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
                    Text(
                      '${user?.rewardPoints ?? 0}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const Text(
                      'Points',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
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
                    const Text(
                      'Cashback',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey500),
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

  Widget _buildMembershipSection(UserModel? user) {
    final points = user?.rewardPoints ?? 0;
    final tier = points >= 10000 ? 'Platinum' 
               : points >= 5000 ? 'Gold' 
               : points >= 1000 ? 'Silver' 
               : 'Bronze';

    final tierColor = tier == 'Platinum' 
        ? Colors.purple 
        : tier == 'Gold' 
            ? Colors.amber 
            : tier == 'Silver' 
                ? Colors.grey 
                : AppTheme.secondary;

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
            decoration: BoxDecoration(
              color: tierColor,
              borderRadius: BorderRadius.circular(12),
            ),
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
    final code = auth.currentUser?.phoneNumber.replaceAll('+', '') ?? 'FUFAJI50';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.people_alt, color: AppTheme.secondary),
              SizedBox(width: 12),
              Text(
                'Refer & Earn ₹50',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Share your referral code with friends and family. Both of you get 50 points on their first order!',
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.grey200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  code,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Implement Clipboard
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard!')));
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('COPY'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    final menuItems = [
      {'icon': Icons.shopping_bag_outlined, 'title': 'My Orders', 'color': AppTheme.primary},
      {'icon': Icons.calendar_month_outlined, 'title': 'My Subscriptions', 'color': AppTheme.secondary},
      {'icon': Icons.location_on_outlined, 'title': 'Saved Addresses', 'color': AppTheme.info},
      {'icon': Icons.payment_outlined, 'title': 'Payment Methods', 'color': AppTheme.success},
      {'icon': Icons.favorite_outline, 'title': 'Wishlist', 'color': AppTheme.error},
      {'icon': Icons.notifications_outlined, 'title': 'Notifications', 'color': AppTheme.warning},
      {'icon': Icons.swap_horiz_outlined, 'title': 'Switch App Role', 'color': AppTheme.secondary},
      {'icon': Icons.settings_outlined, 'title': 'Settings', 'color': AppTheme.grey600},
      {'icon': Icons.help_outline, 'title': 'Help & Support', 'color': AppTheme.primary},
      {'icon': Icons.info_outline, 'title': 'About App', 'color': AppTheme.grey600},
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
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (item['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item['icon'] as IconData,
                color: item['color'] as Color,
                size: 22,
              ),
            ),
            title: Text(
              item['title'] as String,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.grey900,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.grey400,
            ),
            onTap: () {
              if (item['title'] == 'Help & Support') {
                _openWhatsappSupport();
              } else if (item['title'] == 'Switch App Role') {
                final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                if (user?.role == UserRole.admin || user?.role == UserRole.shopOwner) {
                  context.push('/role-select');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Access Denied: Only Authorized Staff can switch roles.')),
                  );
                }
              } else if (item['title'] == 'My Orders') {
                context.push('/customer/orders');
              } else if (item['title'] == 'Saved Addresses') {
                context.push('/customer/addresses');
              } else if (item['title'] == 'Settings') {
                context.push('/customer/settings');
              } else if (item['title'] == 'Payment Methods') {
                context.push('/customer/wallet');
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _openWhatsappSupport() async {
    if (AppConfig.supportWhatsappNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'WhatsApp support number is not configured for this build.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final message = Uri.encodeComponent(
      "Hello Fufaji's Online, I need help with my order.",
    );
    final uri = Uri.parse(
      'https://wa.me/${AppConfig.supportWhatsappNumber}?text=$message',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open WhatsApp.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
