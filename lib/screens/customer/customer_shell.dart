import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import '../../widgets/sticky_checkout_bar.dart';
import '../../widgets/ai_shopping_assistant.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const SearchScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    "Fufaji's Online",
    'Search',
    'Cart',
    'Profile',
  ];

  final List<IconData> _icons = [
    Icons.home_outlined,
    Icons.search,
    Icons.shopping_cart_outlined,
    Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        orderProvider.listenToOrders(authProvider.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          // Location Selector
          TextButton.icon(
            onPressed: () => context.push('/customer/addresses'),
            icon: const Icon(Icons.location_on_outlined, size: 20),
            label: const Text(
              'Jaipur',
              style: TextStyle(fontSize: 14),
            ),
          ),
          // Role Switcher for Demo
          IconButton(
            onPressed: () => context.push('/role-select'),
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Role',
          ),
          // Notifications
          IconButton(
            onPressed: () => context.push('/customer/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          _pages[_currentIndex],
          if (_currentIndex != 2)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: StickyCheckoutBar(),
            ),
          const AIShoppingAssistant(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              context.go('/customer/home');
              break;
            case 1:
              context.go('/customer/search');
              break;
            case 2:
              context.go('/customer/cart');
              break;
            case 3:
              context.go('/customer/profile');
              break;
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(_icons[0]),
            selectedIcon: Icon(_icons[0], color: AppTheme.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(_icons[1]),
            selectedIcon: Icon(_icons[1], color: AppTheme.primary),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Stack(
              children: [
                Icon(_icons[2]),
                if (cartProvider.totalItems > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cartProvider.totalItems}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            selectedIcon: Stack(
              children: [
                Icon(_icons[2], color: AppTheme.primary),
                if (cartProvider.totalItems > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cartProvider.totalItems}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(_icons[3]),
            selectedIcon: Icon(_icons[3], color: AppTheme.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
