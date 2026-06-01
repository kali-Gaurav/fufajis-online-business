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
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
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
          }).toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return Icons.shopping_bag_outlined;
      case UserRole.shopOwner:
        return Icons.storefront;
      case UserRole.deliveryAgent:
        return Icons.delivery_dining;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.employee:
        return Icons.badge_outlined;
    }
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.shopOwner:
        return 'Shop Owner';
      case UserRole.deliveryAgent:
        return 'Delivery Partner';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.employee:
        return 'Employee';
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Shop from local stores';
      case UserRole.shopOwner:
        return 'Manage your business';
      case UserRole.deliveryAgent:
        return 'Earn by delivering orders';
      case UserRole.admin:
        return 'System oversight';
      case UserRole.employee:
        return 'Store operations';
    }
  }
}
