import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/role_select_screen.dart';
import '../screens/customer/customer_shell.dart';
import '../screens/customer/home_screen.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/search_screen.dart';
import '../screens/customer/profile_screen.dart';
import '../screens/customer/product_detail_screen.dart';
import '../screens/owner/bahi_khata_screen.dart';
import '../screens/customer/dispute_screen.dart';
import '../screens/owner/packing_terminal_screen.dart';
import '../screens/customer/fast_checkout_screen.dart';
import '../screens/customer/checkout_screen.dart';
import '../screens/customer/order_confirmation_screen.dart';
import '../screens/customer/orders_screen.dart';
import '../screens/customer/address_screen.dart';
import '../screens/customer/snap_to_shop_screen.dart';
import '../screens/customer/delivery_tracking_screen.dart';
import '../screens/customer/support_chat_screen.dart';
import '../screens/customer/wallet_history_screen.dart';
import '../screens/customer/settings_screen.dart';
import '../screens/customer/notification_center.dart';
import '../screens/customer/notification_settings_screen.dart';
import '../screens/customer/order_detail_screen.dart';
import '../screens/owner/owner_dashboard.dart';
import '../screens/owner/products_management.dart';
import '../screens/owner/packing_terminal_screen.dart';
import '../screens/owner/orders_management.dart';
import '../screens/owner/inventory_screen.dart';
import '../screens/owner/inventory_audit_screen.dart';
import '../screens/owner/vendor_request_screen.dart';
import '../screens/owner/analytics_screen.dart';
import '../screens/owner/whatsapp_sync_setup_screen.dart';
import '../screens/owner/rider_management_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/delivery/delivery_dashboard.dart';
import '../screens/delivery/delivery_orders_screen.dart';
import '../screens/delivery/delivery_earnings_screen.dart';
import '../screens/delivery/trip_route_sheet.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    refreshListenable: AuthProvider.instance, // I need to make AuthProvider a singleton or pass it
    routes: [
      // Splash Screen
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Login Screen
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // OTP Verification
      GoRoute(
        path: '/otp/:phoneNumber',
        builder: (context, state) => OTPScreen(
          phoneNumber: state.pathParameters['phoneNumber'] ?? '',
          role: state.uri.queryParameters['role'],
        ),
      ),

      // Role Selection
      GoRoute(
        path: '/role-select',
        builder: (context, state) => const RoleSelectScreen(),
      ),

      // Customer App Routes
      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerShell(),
        routes: [
          GoRoute(
            path: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: 'search',
            builder: (context, state) => SearchScreen(
              initialQuery: state.uri.queryParameters['q'],
            ),
          ),
          GoRoute(
            path: 'snap-to-shop',
            builder: (context, state) => const SnapToShopScreen(),
          ),
          GoRoute(
            path: 'cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'product/:productId',
            builder: (context, state) => ProductDetailScreen(
              productId: state.pathParameters['productId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'checkout',
            builder: (context, state) => const FastCheckoutScreen(),
          ),
          GoRoute(
            path: 'order-confirmation',
            builder: (context, state) => OrderConfirmationScreen(
              orderId: state.uri.queryParameters['orderId'],
              orderNumber: state.uri.queryParameters['orderNumber'],
            ),
          ),
          GoRoute(
            path: 'orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: 'order-detail/:orderId',
            builder: (context, state) => OrderDetailScreen(
              orderId: state.pathParameters['orderId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'dispute/:orderId',
            builder: (context, state) => DisputeScreen(
              orderId: state.pathParameters['orderId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'addresses',
            builder: (context, state) => const AddressScreen(),
          ),
          GoRoute(
            path: 'track/:orderId',
            builder: (context, state) => DeliveryTrackingScreen(
              orderId: state.pathParameters['orderId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'support-chat/:orderId',
            builder: (context, state) => SupportChatScreen(
              orderId: state.pathParameters['orderId'],
            ),
          ),
          GoRoute(
            path: 'support',
            builder: (context, state) => const SupportChatScreen(),
          ),
          GoRoute(
            path: 'wallet',
            builder: (context, state) => const WalletHistoryScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationCenter(),
          ),
          GoRoute(
            path: 'notification-settings',
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
        ],
      ),

      // Shop Owner Routes
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerDashboard(),
        routes: [
          GoRoute(
            path: 'products',
            builder: (context, state) => const ProductsManagementScreen(),
          ),
          GoRoute(
            path: 'packing-terminal',
            builder: (context, state) => const PackingTerminalScreen(),
          ),
          GoRoute(
            path: 'orders',
            builder: (context, state) => const OrdersManagementScreen(),
          ),
          GoRoute(
            path: 'inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: 'inventory-audit',
            builder: (context, state) => const InventoryAuditScreen(),
          ),
          GoRoute(
            path: 'vendor-request',
            builder: (context, state) => const VendorRequestScreen(),
          ),
          GoRoute(
            path: 'analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: 'packing/:orderId',
            builder: (context, state) => PackingTerminalScreen(
              orderId: state.pathParameters['orderId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'khata',
            builder: (context, state) => const BahiKhataScreen(),
          ),
          GoRoute(
            path: 'whatsapp-sync',
            builder: (context, state) => const WhatsAppSyncSetupScreen(),
          ),
          GoRoute(
            path: 'riders',
            builder: (context, state) => const RiderManagementScreen(),
          ),
        ],
      ),

      // Admin Routes
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboard(),
      ),

      // Delivery Agent Routes
      GoRoute(
        path: '/delivery',
        builder: (context, state) => const DeliveryDashboard(),
        routes: [
          GoRoute(
            path: 'orders',
            builder: (context, state) => const DeliveryOrdersScreen(),
          ),
          GoRoute(
            path: 'earnings',
            builder: (context, state) => const DeliveryEarningsScreen(),
          ),
          GoRoute(
            path: 'trip-sheet',
            builder: (context, state) => const TripRouteSheet(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isLoggedIn = authProvider.isLoggedIn;
      final isOnLoginPage = state.uri.path == '/login' ||
          state.uri.path == '/' ||
          state.uri.path.startsWith('/otp/');

      // If not logged in and not on login page, redirect to login
      if (!isLoggedIn && !isOnLoginPage) {
        return '/login';
      }

      // If logged in and on login/splash page, redirect based on role
      if (isLoggedIn && isOnLoginPage) {
        final role = authProvider.currentUser?.role ?? UserRole.customer;
        
        switch (role) {
          case UserRole.shopOwner:
            return '/owner';
          case UserRole.deliveryAgent:
            return '/delivery';
          case UserRole.admin:
            return '/admin';
          case UserRole.customer:
            return '/customer/home';
        }
      }

      return null;
    },
  );
}
