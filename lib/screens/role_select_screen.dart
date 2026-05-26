import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  bool _isLoading = false;

  void _selectRole(String roleStr) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      UserRole role;
      
      switch (roleStr) {
        case 'shopOwner':
          role = UserRole.shopOwner;
          break;
        case 'deliveryAgent':
          role = UserRole.deliveryAgent;
          break;
        case 'customer':
        default:
          role = UserRole.customer;
          break;
      }

      await authProvider.updateRole(role);

      if (mounted) {
        // Redirection handled by central AppRouter via refreshListenable
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 50,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                'Select Your Role',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how you want to use the app',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.grey600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Customer Card
              _buildRoleCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Customer',
                description: 'Shop from local stores and get delivery at home',
                color: AppTheme.primary,
                onTap: () => _selectRole('customer'),
              ),
              const SizedBox(height: 16),
              // Shop Owner Card
              _buildRoleCard(
                icon: Icons.storefront,
                title: 'Shop Owner',
                description: 'Manage your shop, products, and orders',
                color: AppTheme.secondary,
                onTap: () => _selectRole('shopOwner'),
              ),
              const SizedBox(height: 16),
              // Delivery Agent Card
              _buildRoleCard(
                icon: Icons.delivery_dining,
                title: 'Delivery Partner',
                description: 'Deliver orders and earn money',
                color: AppTheme.info,
                onTap: () => _selectRole('deliveryAgent'),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.grey400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
