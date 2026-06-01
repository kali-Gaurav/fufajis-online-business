import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
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
import '../screens/owner/packing_dashboard_screen.dart';
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
import '../screens/owner/whatsapp_sync_config_screen.dart';
import '../screens/owner/inventory_alerts_screen.dart';
import '../screens/owner/expiry_tracking_screen.dart';
import '../screens/owner/pricing_rules_screen.dart';
import '../screens/owner/pending_price_changes_screen.dart';
import '../screens/owner/rider_management_screen.dart';
import '../screens/owner/shop_settings_screen.dart';
import '../screens/owner/shop_location_picker_screen.dart';
import '../screens/owner/delivery_zones_screen.dart';
import '../screens/owner/branch_management_screen.dart';
import '../screens/owner/operating_hours_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/delivery/delivery_dashboard.dart';
import '../screens/delivery/delivery_orders_screen.dart';
import '../screens/delivery/delivery_earnings_screen.dart';
import '../screens/delivery/trip_route_sheet.dart';

import '../screens/customer/profile_creation_screen.dart';

import '../screens/employee/employee_home_screen.dart';
import '../screens/employee/scanner_screen.dart';
import '../screens/employee/inventory_receiving_screen.dart';
import '../screens/employee/order_packing_screen.dart';
import '../screens/employee/delivery_screen.dart';
import '../screens/employee/inventory_audit_screen.dart' as employee_audit;
import '../screens/employee/damage_reporting_screen.dart';
import '../screens/employee/attendance_screen.dart';
import '../screens/employee/cash_collection_screen.dart';
import '../screens/employee/returns_screen.dart';
import '../screens/employee/inventory_transfer_screen.dart';
import '../screens/employee/shelf_refill_screen.dart';
import '../screens/employee/expiry_management_screen.dart';

class AppRouter {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static final GoRouter router = GoRouter(
    refreshListenable: AuthProvider.instance,
    observers: [
      FirebaseAnalyticsObserver(analytics: _analytics),
    ],
    routes: [
      // Splash Screen
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Profile Creation (Onboarding)
      GoRoute(
        path: '/profile-creation',
        builder: (context, state) => const ProfileCreationScreen(),
      ),

      // Login Screen
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // OTP Verification
      GoRoute(
        path: '/otp/:contact',
        builder: (context, state) => OTPScreen(
          phoneNumber: Uri.decodeComponent(state.pathParameters['contact'] ?? ''),
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
            builder: (context, state) => const CheckoutScreen(),
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
            builder: (context, state) {
              final orderId = state.uri.queryParameters['orderId'];
              return PackingTerminalScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'packing-dashboard',
            builder: (context, state) => const PackingDashboardScreen(),
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
            path: 'inventory-alerts',
            builder: (context, state) => const InventoryAlertsScreen(),
          ),
          GoRoute(
            path: 'expiry-tracking',
            builder: (context, state) => const ExpiryTrackingScreen(),
          ),
          GoRoute(
            path: 'pricing-rules',
            builder: (context, state) => const PricingRulesScreen(),
          ),
          GoRoute(
            path: 'pending-price-changes',
            builder: (context, state) => const PendingPriceChangesScreen(),
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
          GoRoute(
            path: 'shop-settings',
            builder: (context, state) => const ShopSettingsScreen(),
          ),
          GoRoute(
            path: 'shop-location',
            builder: (context, state) => const ShopLocationPickerScreen(),
          ),
          GoRoute(
            path: 'delivery-zones',
            builder: (context, state) => const DeliveryZonesScreen(),
          ),
          GoRoute(
            path: 'branches',
            builder: (context, state) => const BranchManagementScreen(),
          ),
          GoRoute(
            path: 'operating-hours',
            builder: (context, state) => const OperatingHoursScreen(),
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
      
      // Employee Routes
      GoRoute(
        path: '/employee',
        builder: (context, state) => const EmployeeHomeScreen(),
        routes: [
          GoRoute(
            path: 'scanner',
            builder: (context, state) {
              final mode = state.uri.queryParameters['mode'];
              return ScannerScreen(initialMode: mode);
            },
          ),
          GoRoute(
            path: 'receiving',
            builder: (context, state) {
              final barcode = state.uri.queryParameters['barcode'];
              return InventoryReceivingScreen(barcode: barcode);
            },
          ),
          GoRoute(
            path: 'packing',
            builder: (context, state) {
              final orderId = state.uri.queryParameters['orderId'];
              return OrderPackingScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'delivery',
            builder: (context, state) {
              final parcelId = state.uri.queryParameters['parcelId'];
              return DeliveryScreen(parcelId: parcelId);
            },
          ),
          GoRoute(
            path: 'audit',
            builder: (context, state) {
              final auditId = state.uri.queryParameters['auditId'];
              return employee_audit.InventoryAuditScreen(auditId: auditId);
            },
          ),
          GoRoute(
            path: 'damage',
            builder: (context, state) {
              final barcode = state.uri.queryParameters['barcode'];
              return DamageReportingScreen(barcode: barcode);
            },
          ),
          GoRoute(
            path: 'attendance',
            builder: (context, state) {
              final qr = state.uri.queryParameters['qr'];
              return AttendanceScreen(qrCodeId: qr);
            },
          ),
          GoRoute(
            path: 'cash',
            builder: (context, state) => const CashCollectionScreen(),
          ),
          GoRoute(
            path: 'returns',
            builder: (context, state) => const ReturnsScreen(),
          ),
          GoRoute(
            path: 'transfer',
            builder: (context, state) => const InventoryTransferScreen(),
          ),
          GoRoute(
            path: 'refill',
            builder: (context, state) => const ShelfRefillScreen(),
          ),
          GoRoute(
            path: 'expiry',
            builder: (context, state) => const ExpiryManagementScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isLoggedIn = authProvider.isLoggedIn;
      final user = authProvider.currentUser;

      final isOnOnboarding = state.uri.path == '/' || 
                             state.uri.path == '/login' || 
                             state.uri.path.startsWith('/otp/') ||
                             state.uri.path == '/role-select' ||
                             state.uri.path == '/profile-creation';

      // 1. Not logged in: Allow login/otp screens
      if (!isLoggedIn) {
        if (state.uri.path == '/login' || state.uri.path.startsWith('/otp/')) return null;
        return '/login';
      }

      // 2. Logged in: Route based on active role
      if (isLoggedIn && user != null) {
        final path = state.uri.path;

        // Force profile completion for new customers
        if (user.role == UserRole.customer && 
            (user.name == null || user.name!.isEmpty) && 
            path != '/profile-creation') {
          return '/profile-creation';
        }

        // If on onboarding pages, redirect to dashboard
        if (isOnOnboarding && path != '/profile-creation') {
          switch (user.role) {
            case UserRole.shopOwner: return '/owner';
            case UserRole.deliveryAgent: return '/delivery';
            case UserRole.admin: return '/admin';
            case UserRole.employee: return '/employee';
            case UserRole.customer: return '/customer/home';
          }
        }

        // Dashboard Guard: Ensure user is in the correct section for their active role
        if (user.role == UserRole.shopOwner && !path.startsWith('/owner')) return '/owner';
        if (user.role == UserRole.customer && !path.startsWith('/customer') && path != '/profile-creation') return '/customer/home';
        if (user.role == UserRole.deliveryAgent && !path.startsWith('/delivery')) return '/delivery';
        if (user.role == UserRole.employee && !path.startsWith('/employee')) return '/employee';
        if (user.role == UserRole.admin && !path.startsWith('/admin')) return '/admin';
      }

      return null;
    },
  );
}
