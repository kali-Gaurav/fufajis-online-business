import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';

class RoleSwitcherBottomSheet extends StatelessWidget {
  const RoleSwitcherBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Switch Role',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.grey900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...user.roles.map((role) {
            final isSelected = user.role == role;
            return Card(
              elevation: isSelected ? 2 : 0,
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppTheme.primary : AppTheme.grey200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getRoleIcon(role),
                    color: isSelected ? Colors.white : AppTheme.grey600,
                  ),
                ),
                title: Text(
                  _getRoleName(role),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppTheme.primary : AppTheme.grey900,
                  ),
                ),
                subtitle: Text(
                  _getRoleDescription(role),
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.primary)
                    : null,
                onTap: isSelected
                    ? null
                    : () {
                        authProvider.switchRole(role);
                        Navigator.pop(context);
                      },
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return Icons.shopping_bag_outlined;
      case UserRole.owner:
        return Icons.storefront;
      case UserRole.rider:
        return Icons.delivery_dining;
      case UserRole.superAdmin:
        return Icons.admin_panel_settings;
      case UserRole.employee:
        return Icons.badge_outlined;
      case UserRole.dispatcher:
      case UserRole.shopOwner:
        return Icons.hub_outlined;
      case UserRole.branchManager:
        return Icons.business_center_outlined;
      case UserRole.supplier:
        return Icons.local_shipping_outlined;
      case UserRole.franchiseOwner:
        return Icons.store_outlined;
      case UserRole.deliveryAgent:
        return Icons.directions_bike_outlined;
      case UserRole.admin:
        return Icons.shield_outlined;
    }
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.owner:
        return 'Shop Owner';
      case UserRole.rider:
        return 'Delivery Partner';
      case UserRole.superAdmin:
        return 'Administrator';
      case UserRole.employee:
        return 'Employee';
      case UserRole.dispatcher:
      case UserRole.shopOwner:
        return 'Dispatcher';
      case UserRole.branchManager:
        return 'Branch Manager';
      case UserRole.supplier:
        return 'Supplier';
      case UserRole.franchiseOwner:
        return 'Franchise Owner';
      case UserRole.deliveryAgent:
        return 'Delivery Agent';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Shop from local stores';
      case UserRole.owner:
        return 'Manage your business';
      case UserRole.rider:
        return 'Earn by delivering orders';
      case UserRole.superAdmin:
        return 'System oversight';
      case UserRole.employee:
        return 'Store operations';
      case UserRole.dispatcher:
      case UserRole.shopOwner:
        return 'Dispatch operations';
      case UserRole.branchManager:
        return 'Branch oversight';
      case UserRole.supplier:
        return 'Supply chain management';
      case UserRole.franchiseOwner:
        return 'Manage franchise business';
      case UserRole.deliveryAgent:
        return 'Deliver orders on the road';
      case UserRole.admin:
        return 'System administration';
    }
  }
}
