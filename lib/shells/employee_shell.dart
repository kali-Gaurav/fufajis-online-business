import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../providers/employee_provider.dart';
import '../l10n/app_localizations.dart';

/// Employee role shell with bottom navigation for warehouse/store operations.
///
/// Tabs:
/// 0. Tasks - Assigned work items, priorities, status
/// 1. Inventory - Stock management, receiving, transfers
/// 2. Delivery - Order packing, dispatch, delivery tracking
/// 3. Profile - Employee info, attendance, settings
class EmployeeShell extends StatefulWidget {
  final Widget child;
  const EmployeeShell({super.key, required this.child});

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  /// Calculate selected tab index based on current route path.
  /// Routes are grouped into 4 main categories.
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    // Tasks tab: task priority, scanner hub
    if (location.startsWith('/employee/tasks') || location.startsWith('/employee/hub')) {
      return 0;
    }

    // Inventory tab: receiving, transfer, refill, damage, expiry
    if (location.startsWith('/employee/receiving') ||
        location.startsWith('/employee/transfer') ||
        location.startsWith('/employee/refill') ||
        location.startsWith('/employee/damage') ||
        location.startsWith('/employee/expiry') ||
        location.startsWith('/employee/inventory-bulk-query') ||
        location.startsWith('/employee/audit')) {
      return 1;
    }

    // Delivery tab: packing, dispatch, pod scanner, delivery
    if (location.startsWith('/employee/packing') ||
        location.startsWith('/employee/dispatch') ||
        location.startsWith('/employee/pod') ||
        location.startsWith('/employee/delivery')) {
      return 2;
    }

    // Profile tab: attendance, cash, returns, member scanner, chat, settings
    if (location.startsWith('/employee/attendance') ||
        location.startsWith('/employee/cash') ||
        location.startsWith('/employee/returns') ||
        location.startsWith('/employee/member') ||
        location.startsWith('/employee/chat')) {
      return 3;
    }

    // Default to home (Tasks)
    return 0;
  }

  /// Get badge count for Tasks tab (pending items from provider)
  int _getPendingTaskCount() {
    try {
      final provider = Provider.of<EmployeeProvider>(context, listen: false);
      return provider.pendingTaskCount;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final String location = GoRouterState.of(context).uri.path;
    final l10n = AppLocalizations.of(context);

    // Only show bottom nav on main tabs, not on detail screens
    final isMainTab =
        location == '/employee' || location == '/employee/tasks' || location == '/employee/hub';

    return Scaffold(
      appBar: isMainTab ? null : AppBar(elevation: 1, automaticallyImplyLeading: true),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/employee/tasks');
              break;
            case 1:
              context.go('/employee/receiving');
              break;
            case 2:
              context.go('/employee/packing');
              break;
            case 3:
              context.go('/employee/attendance');
              break;
          }
        },
        destinations: [
          // Tasks Tab with badge
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _getPendingTaskCount() > 0,
              label: Text('${_getPendingTaskCount()}'),
              child: const Icon(Icons.task_alt_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _getPendingTaskCount() > 0,
              label: Text('${_getPendingTaskCount()}'),
              child: const Icon(Icons.task_alt, color: AppTheme.primary),
            ),
            label: l10n?.translate('tasks') ?? 'Tasks',
          ),
          // Inventory Tab
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2, color: AppTheme.primary),
            label: l10n?.translate('inventory') ?? 'Inventory',
          ),
          // Delivery Tab
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping, color: AppTheme.primary),
            label: l10n?.translate('delivery') ?? 'Delivery',
          ),
          // Profile Tab
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: AppTheme.primary),
            label: l10n?.translate('profile') ?? 'Profile',
          ),
        ],
      ),
    );
  }
}
