import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';

class GuestProfileScreen extends StatelessWidget {
  const GuestProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Guest Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 40,
                  color: Color(0xFFFF5722),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome, Guest',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Login to manage your orders, wallet, and get rewards.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Navigate to checkout where auth will be asked, or show auth sheet directly. 
                  // Since there's no auth sheet globally yet, let's just go to login for now from profile, 
                  // or show OTP screen directly. We can go to /login.
                  context.push('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cream,
                  foregroundColor: const Color(0xFFFF5722),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Login / Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Menu Items for Guest
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildGuestMenuItem(
                context,
                icon: Icons.shopping_bag_outlined,
                title: 'My Orders',
                onTap: () => _requireLogin(context),
              ),
              const SizedBox(height: 8),
              _buildGuestMenuItem(
                context,
                icon: Icons.location_on_outlined,
                title: 'Saved Addresses',
                onTap: () => _requireLogin(context),
              ),
              const SizedBox(height: 8),
              _buildGuestMenuItem(
                context,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet & Rewards',
                onTap: () => _requireLogin(context),
              ),
              const SizedBox(height: 8),
              _buildGuestMenuItem(
                context,
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () {
                  // Allow basic support chat for guests?
                  context.push('/customer/support');
                },
              ),
              const SizedBox(height: 8),
              _buildGuestMenuItem(
                context,
                icon: Icons.info_outline,
                title: 'About App',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viewing Policy...')));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuestMenuItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.grey200.withValues(alpha: 0.5)),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.grey600, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.grey900,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.grey400),
    );
  }

  void _requireLogin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please login to access this feature.'),
        duration: Duration(seconds: 2),
      ),
    );
    context.push('/login');
  }
}
