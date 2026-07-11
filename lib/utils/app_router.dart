import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'page_transitions.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/auth/email_login_screen.dart';
import '../screens/auth/owner_login_screen.dart';
import '../screens/auth/staff_login_screen.dart';
import '../screens/auth/staff_registration_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/role_select_screen.dart';
import '../screens/customer/customer_shell.dart';
import '../screens/customer/home_screen.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/search_screen.dart';
import '../screens/customer/profile_screen.dart';
import '../screens/customer/account_picker_screen.dart';
import '../screens/customer/my_devices_screen.dart';
import '../screens/customer/product_detail_screen.dart';
import '../screens/owner/bahi_khata_screen.dart';
import '../screens/customer/dispute_screen.dart';
import '../screens/owner/packing_terminal_screen.dart';
import '../screens/owner/packing_dashboard_screen.dart';
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
import '../screens/owner/advanced_performance_dashboard_screen.dart';
import '../screens/owner/products_management.dart';
import '../screens/owner/orders_management.dart';
import '../screens/owner/inventory_screen.dart';
import '../screens/owner/inventory_audit_screen.dart';
import '../screens/owner/vendor_request_screen.dart';
import '../screens/owner/analytics_screen.dart';
import '../screens/owner/bi_analytics_hub_screen.dart';
import '../screens/owner/financial_dashboard_screen.dart';
import '../screens/owner/business_dashboard_screen.dart';
import '../screens/owner/franchise_dashboard_screen.dart';
import '../screens/owner/postgres_analytics_screen.dart';
import '../screens/owner/owner_ai_dashboard.dart';
import '../screens/owner/executive_decision_center.dart';
import '../screens/owner/whatsapp_sync_setup_screen.dart';
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
import '../screens/owner/mission_control/team_room_screen.dart';
import '../screens/owner/approval_dashboard_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/delivery/delivery_dashboard.dart';
import '../screens/delivery/delivery_orders_screen.dart';
import '../screens/delivery/delivery_earnings_screen.dart';
import '../screens/delivery/trip_route_sheet.dart';
import '../screens/owner/cash_register_screen.dart';
import '../screens/owner/bill_scanner_screen.dart';
import '../screens/owner/employee_management_screen.dart';
import '../screens/delivery/smart_route_screen.dart';

import '../screens/customer/profile_creation_screen.dart';
import '../screens/security_pin_screen.dart';
import '../screens/auth/verification_wall_screen.dart';
import '../screens/auth/phone_login_screen.dart';
import '../screens/auth/phone_verify_screen.dart';
import '../providers/guest_provider.dart';

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
import '../screens/employee/unified_scanner_hub.dart';
import '../screens/employee/dispatch_scanner_screen.dart';
import '../screens/scanner/return_damage_hub_screen.dart';
import '../screens/employee/delivery_pod_scanner_screen.dart';
import '../screens/employee/customer_membership_scanner_screen.dart';
import '../screens/owner/scan_activity_screen.dart';
import '../screens/owner/owner_chat_center_screen.dart';
import '../screens/owner/owner_chat_detail_screen.dart';
import '../screens/owner/bulk_inventory_query_screen.dart';
import '../screens/owner/inventory_approval_queue_screen.dart';
import '../screens/owner/customer_segmentation_screen.dart';
import '../screens/owner/delivery_sla_dashboard_screen.dart';
import '../screens/owner/failed_delivery_escalation_screen.dart';
import '../screens/delivery/delivery_reschedule_screen.dart';
import '../screens/rider/rider_route_history_screen.dart';
import '../screens/customer/wallet_screen.dart';
import '../screens/customer/wallet_payment_dashboard_screen.dart';
import '../screens/customer/membership_screen.dart';
import '../screens/rider/rider_map_screen.dart';
import '../screens/admin/dead_letter_dashboard_screen.dart';
import '../screens/owner/rider_pulse_heatmap_screen.dart';
// FIX (Module 10, P0-10.4): these three finance screens were fully built
// (real Razorpay/RazorpayX integration) but had zero router entries —
// no owner could ever reach them.
import '../screens/owner/refund_processing_screen.dart';
import '../screens/owner/settlements_management.dart';
import '../screens/owner/settlement_reporting_screen.dart';
import '../screens/customer/wishlist_screen.dart';
import '../screens/customer/loyalty_screen.dart';
import '../screens/customer/referral_rewards_dashboard_screen.dart';
import '../screens/customer/family_management_screen.dart';
import '../screens/customer/smart_kitchen_screen.dart';
import '../screens/customer/subscription_screen.dart';
import '../screens/customer/subscription_management_screen.dart';
import '../screens/customer/identity_contacts_screen.dart';
import '../screens/customer/refer_earn_screen.dart';
import '../screens/customer/personalized_recommendations_screen.dart';
import '../screens/customer/add_review_screen.dart';
import '../screens/customer/enhanced_delivery_tracking_screen.dart';
import '../screens/customer/product_card_enhancements_screen.dart';
import '../screens/owner/owner_dashboard_redesigned.dart';
import '../screens/owner/inventory_visual_improvements_screen.dart';
import '../screens/employee/employee_task_board_screen.dart';
import '../screens/vendor/vendor_signup_screen.dart';
import '../screens/vendor/vendor_dashboard_screen.dart';
import '../screens/vendor/vendor_products_management_screen.dart';
import '../screens/vendor/vendor_orders_screen.dart';
import '../screens/vendor/vendor_payout_screen.dart';
import '../screens/vendor/vendor_commission_autopayout_screen.dart';
import '../screens/vendor/vendor_commission_dashboard_screen.dart';
import '../screens/vendor/vendor_dispute_resolution_screen.dart';
import '../screens/admin/admin_vendor_approval_screen.dart';
import '../screens/customer/subscription_checkout_screen.dart';
import '../screens/customer/subscription_detail_screen.dart';
import '../screens/customer/subscription_retention_screen.dart';
import '../screens/customer/subscriptions/subscription_setup_screen.dart';
import '../services/subscription_service.dart';
import '../screens/owner/owner_subscription_dashboard.dart';
import '../screens/inventory/supplier_management_screen.dart';

/// Combines multiple [Listenable]s into one so GoRouter re-evaluates
/// its redirect when either AuthProvider OR GuestProvider changes state.
class _MultiListenable extends ChangeNotifier {
  _MultiListenable(this._listenables) {
    for (final l in _listenables) {
      l.addListener(notifyListeners);
    }
  }
  final List<Listenable> _listenables;

  @override
  void dispose() {
    for (final l in _listenables) {
      l.removeListener(notifyListeners);
    }
    super.dispose();
  }
}

class AppRouter {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static final GoRouter router = GoRouter(
    refreshListenable: _MultiListenable([
      AuthProvider.instance,
      GuestProvider(), // singleton — same instance as MultiProvider
    ]),
    observers: [FirebaseAnalyticsObserver(analytics: _analytics)],
    routes: [
      // Splash Screen — no transition (first frame)
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            FufajiNoTransition(key: state.pageKey, child: const SplashScreen()),
      ),

      // Profile Creation — fade+scale (onboarding feel)
      GoRoute(
        path: '/profile-creation',
        pageBuilder: (context, state) =>
            FufajiFadeScaleTransition(key: state.pageKey, child: const ProfileCreationScreen()),
      ),

      // Login Screen — fade+scale
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            FufajiFadeScaleTransition(key: state.pageKey, child: const LoginScreen()),
      ),

      // Verification Wall — slide up (it's an interruption)
      GoRoute(
        path: '/auth/verify-wall',
        pageBuilder: (context, state) => FufajiSlideUpTransition(
          key: state.pageKey,
          child: VerificationWallScreen(
            returnPath: state.uri.queryParameters['returnPath'] ?? '/customer/home',
            reason: state.uri.queryParameters['reason'],
          ),
        ),
      ),

      // Phone Auth — shared axis horizontal (wizard step)
      GoRoute(
        path: '/auth/phone-login',
        pageBuilder: (context, state) =>
            FufajiSharedAxisH(key: state.pageKey, child: const PhoneLoginScreen()),
      ),
      // Email Auth
      GoRoute(
        path: '/auth/email-login',
        pageBuilder: (context, state) =>
            FufajiSharedAxisH(key: state.pageKey, child: const EmailLoginScreen()),
      ),
      GoRoute(
        path: '/auth/phone-verify',
        pageBuilder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          final role = state.uri.queryParameters['role'];
          return FufajiSharedAxisH(
            key: state.pageKey,
            child: PhoneVerifyScreen(phoneNumber: phone, role: role),
          );
        },
      ),

      // New Authentication Routes
      GoRoute(
        path: '/auth/owner-login',
        pageBuilder: (context, state) =>
            FufajiSharedAxisH(key: state.pageKey, child: const OwnerLoginScreen()),
      ),
      GoRoute(
        path: '/auth/staff-login',
        pageBuilder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'employee';
          return FufajiSharedAxisH(
            key: state.pageKey,
            child: StaffLoginScreen(role: role),
          );
        },
      ),
      GoRoute(
        path: '/auth/staff-register',
        pageBuilder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'employee';
          return FufajiSharedAxisH(
            key: state.pageKey,
            child: StaffRegistrationScreen(role: role),
          );
        },
      ),

      // Security PIN — slide up (gate/guard feel)
      GoRoute(
        path: '/security-pin',
        pageBuilder: (context, state) =>
            FufajiSlideUpTransition(key: state.pageKey, child: const SecurityPinScreen()),
      ),

      // Account Picker — fade+scale
      GoRoute(
        path: '/account-picker',
        pageBuilder: (context, state) =>
            FufajiFadeScaleTransition(key: state.pageKey, child: const AccountPickerScreen()),
      ),

      // OTP Verification — shared axis (wizard step forward)
      GoRoute(
        path: '/otp/:contact',
        pageBuilder: (context, state) => FufajiSharedAxisH(
          key: state.pageKey,
          child: OTPScreen(
            phoneNumber: Uri.decodeComponent(state.pathParameters['contact'] ?? ''),
            role: state.uri.queryParameters['role'],
          ),
        ),
      ),

      // Role Selection — fade+scale (decision screen)
      GoRoute(
        path: '/role-select',
        pageBuilder: (context, state) =>
            FufajiFadeScaleTransition(key: state.pageKey, child: const RoleSelectScreen()),
      ),

      // Customer App Routes
      ShellRoute(
        builder: (context, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(path: '/customer/home', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/customer/search',
            builder: (context, state) => SearchScreen(initialQuery: state.uri.queryParameters['q']),
          ),
          GoRoute(
            path: '/customer/snap-to-shop',
            builder: (context, state) => const SnapToShopScreen(),
          ),
          GoRoute(path: '/customer/cart', builder: (context, state) => const CartScreen()),
          GoRoute(path: '/customer/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/customer/devices', builder: (context, state) => const MyDevicesScreen()),
          GoRoute(
            path: '/customer/product/:productId',
            pageBuilder: (context, state) => FufajiZoomTransition(
              key: state.pageKey,
              child: ProductDetailScreen(productId: state.pathParameters['productId'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/customer/checkout',
            pageBuilder: (context, state) =>
                FufajiSlideUpTransition(key: state.pageKey, child: const CheckoutScreen()),
          ),
          GoRoute(
            path: '/customer/order-confirmation',
            pageBuilder: (context, state) => FufajiZoomTransition(
              key: state.pageKey,
              child: OrderConfirmationScreen(
                orderId: state.uri.queryParameters['orderId'],
                orderNumber: state.uri.queryParameters['orderNumber'],
              ),
            ),
          ),
          GoRoute(
            path: '/customer/orders',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const OrdersScreen()),
          ),
          GoRoute(
            path: '/customer/order-detail/:orderId',
            pageBuilder: (context, state) => FufajiPageTransition(
              key: state.pageKey,
              child: OrderDetailScreen(orderId: state.pathParameters['orderId'] ?? ''),
            ),
          ),
          GoRoute(
            path: 'operating-hours',
            pageBuilder: (context, state) => FufajiFadeScaleTransition(
              key: state.pageKey,
              child: const OperatingHoursScreen(),
            ),
          ),
          GoRoute(
            path: 'approval-dashboard',
            pageBuilder: (context, state) => FufajiFadeScaleTransition(
              key: state.pageKey,
              child: const ApprovalDashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/customer/dispute/:orderId',
            pageBuilder: (context, state) => FufajiSlideUpTransition(
              key: state.pageKey,
              child: DisputeScreen(orderId: state.pathParameters['orderId'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/customer/addresses',
            pageBuilder: (context, state) =>
                FufajiSlideUpTransition(key: state.pageKey, child: const AddressScreen()),
          ),
          GoRoute(
            path: '/customer/track/:orderId',
            builder: (context, state) =>
                DeliveryTrackingScreen(orderId: state.pathParameters['orderId'] ?? ''),
          ),
          GoRoute(
            path: '/customer/support-chat/:orderId',
            builder: (context, state) =>
                SupportChatScreen(orderId: state.pathParameters['orderId']),
          ),
          GoRoute(
            path: '/customer/support',
            builder: (context, state) => const SupportChatScreen(),
          ),
          GoRoute(
            path: '/customer/wallet',
            builder: (context, state) => const WalletHistoryScreen(),
          ),
          GoRoute(path: '/customer/my-wallet', builder: (context, state) => const WalletScreen()),
          GoRoute(
            path: '/customer/wallet-payments',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const WalletPaymentDashboardScreen()),
          ),
          GoRoute(
            path: '/customer/membership',
            builder: (context, state) => const MembershipScreen(),
          ),
          GoRoute(path: '/customer/settings', builder: (context, state) => const SettingsScreen()),
          GoRoute(
            path: '/customer/notifications',
            builder: (context, state) => const NotificationCenter(),
          ),
          GoRoute(
            path: '/customer/notification-settings',
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
          // ── Missing customer routes wired up ──────────────────────────────
          GoRoute(
            path: '/customer/wishlist',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const WishlistScreen()),
          ),
          GoRoute(
            path: '/customer/loyalty',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const LoyaltyScreen()),
          ),
          GoRoute(
            path: '/customer/referral-rewards',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const ReferralRewardsDashboardScreen()),
          ),
          GoRoute(
            path: '/customer/family',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const FamilyManagementScreen()),
          ),
          GoRoute(
            path: '/customer/smart-kitchen',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const SmartKitchenScreen()),
          ),
          GoRoute(
            path: '/customer/subscriptions',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const SubscriptionScreen()),
          ),
          GoRoute(
            path: '/customer/subscription-setup',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const SubscriptionSetupScreen()),
          ),
          GoRoute(
            path: '/customer/subscription-detail/:subscriptionId',
            pageBuilder: (context, state) =>
                FufajiPageTransition(
                  key: state.pageKey,
                  child: SubscriptionDetailScreen(
                    subscriptionId: state.pathParameters['subscriptionId'] ?? '',
                  ),
                ),
          ),
          GoRoute(
            path: '/customer/subscription-checkout',
            pageBuilder: (context, state) {
              final items = state.extra as List<SubscriptionItem>? ?? [];
              return FufajiPageTransition(
                key: state.pageKey,
                child: SubscriptionCheckoutScreen(items: items),
              );
            },
          ),
          GoRoute(
            path: '/customer/subscription-retention',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const SubscriptionRetentionScreen()),
          ),
          GoRoute(
            path: '/customer/subscription-management',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const SubscriptionManagementScreen()),
          ),
          GoRoute(
            path: '/customer/identity',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const IdentityContactsScreen()),
          ),
          GoRoute(
            path: '/customer/refer',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const ReferEarnScreen()),
          ),
          GoRoute(
            path: '/customer/recommendations',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const PersonalizedRecommendationsScreen()),
          ),
          GoRoute(
            path: '/customer/add-review/:productId',
            pageBuilder: (context, state) => FufajiSlideUpTransition(
              key: state.pageKey,
              child: AddReviewScreen(
                productId: state.pathParameters['productId'] ?? '',
                productName: state.uri.queryParameters['name'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/customer/product-details/:productId',
            pageBuilder: (context, state) =>
                FufajiPageTransition(
                  key: state.pageKey,
                  child: ProductCardEnhancementsScreen(
                    productId: state.pathParameters['productId'] ?? '',
                  ),
                ),
          ),
          GoRoute(
            path: '/customer/track-delivery/:orderId',
            pageBuilder: (context, state) =>
                FufajiPageTransition(
                  key: state.pageKey,
                  child: EnhancedDeliveryTrackingScreen(
                    orderId: state.pathParameters['orderId'] ?? '',
                  ),
                ),
          ),
        ],
      ),

      // Shop Owner Routes
      ShellRoute(
        builder: (context, state, child) => OwnerDashboard(child: child),
        routes: [
          GoRoute(
            path: '/owner',
            builder: (context, state) =>
                const ProductsManagementScreen(), // Default dashboard content
          ),
          GoRoute(
            path: '/owner/products',
            builder: (context, state) => const ProductsManagementScreen(),
          ),
          GoRoute(
            path: '/owner/performance',
            pageBuilder: (context, state) =>
                FufajiPageTransition(key: state.pageKey, child: const AdvancedPerformanceDashboardScreen()),
          ),
          GoRoute(
            path: '/owner/packing-terminal',
            builder: (context, state) {
              final orderId = state.uri.queryParameters['orderId'];
              return PackingTerminalScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: '/owner/packing-dashboard',
            builder: (context, state) => const PackingDashboardScreen(),
          ),
          GoRoute(
            path: '/owner/orders',
            builder: (context, state) => const OrdersManagementScreen(),
          ),
          GoRoute(path: '/owner/inventory', builder: (context, state) => const InventoryScreen()),
          GoRoute(
            path: '/owner/inventory-alerts',
            builder: (context, state) => const InventoryAlertsScreen(),
          ),
          GoRoute(
            path: '/owner/expiry-tracking',
            builder: (context, state) => const ExpiryTrackingScreen(),
          ),
          GoRoute(
            path: '/owner/pricing-rules',
            builder: (context, state) => const PricingRulesScreen(),
          ),
          GoRoute(
            path: '/owner/pending-price-changes',
            builder: (context, state) => const PendingPriceChangesScreen(),
          ),
          GoRoute(
            path: '/owner/inventory-audit',
            builder: (context, state) => const InventoryAuditScreen(),
          ),
          GoRoute(
            path: '/inventory/suppliers',
            builder: (context, state) => const SupplierManagementScreen(),
          ),
          GoRoute(
            path: '/owner/vendor-request',
            builder: (context, state) => const VendorRequestScreen(),
          ),
          GoRoute(
            path: '/owner/analytics',
            builder: (context, state) => const BiAnalyticsHubScreen(),
          ),
          GoRoute(
            path: '/owner/analytics/postcode',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/owner/analytics/postgres',
            builder: (context, state) => const PostgresAnalyticsScreen(),
          ),
          GoRoute(
            path: '/owner/bi/financial',
            builder: (context, state) => const FinancialDashboardScreen(),
          ),
          GoRoute(
            path: '/owner/bi/business',
            builder: (context, state) => const BusinessDashboardScreen(),
          ),
          GoRoute(
            path: '/owner/bi/franchise',
            builder: (context, state) => const FranchiseDashboardScreen(),
          ),
          GoRoute(
            path: '/owner/bi/ai-dashboard',
            builder: (context, state) => const OwnerAiDashboard(),
          ),
          GoRoute(
            path: '/owner/bi/decision-center',
            builder: (context, state) => const ExecutiveDecisionCenter(),
          ),
          GoRoute(
            path: '/owner/packing/:orderId',
            builder: (context, state) =>
                PackingTerminalScreen(orderId: state.pathParameters['orderId'] ?? ''),
          ),
          GoRoute(path: '/owner/khata', builder: (context, state) => const BahiKhataScreen()),
          // FIX (Module 10, P0-10.4): finance screens now reachable.
          GoRoute(
            path: '/owner/refunds',
            builder: (context, state) => const RefundProcessingScreen(),
          ),
          GoRoute(
            path: '/owner/settlements',
            builder: (context, state) => const SettlementsManagementScreen(),
          ),
          GoRoute(
            path: '/owner/settlement-reports',
            builder: (context, state) => const SettlementReportingScreen(),
          ),
          GoRoute(
            path: '/owner/whatsapp-sync',
            builder: (context, state) => const WhatsAppSyncSetupScreen(),
          ),
          GoRoute(
            path: '/owner/riders',
            builder: (context, state) => const RiderManagementScreen(),
          ),
          GoRoute(
            path: '/owner/fleet-tracking',
            builder: (context, state) => const RiderPulseHeatmapScreen(),
          ),
          GoRoute(
            path: '/owner/shop-settings',
            builder: (context, state) => const ShopSettingsScreen(),
          ),
          GoRoute(
            path: '/owner/shop-location',
            builder: (context, state) => const ShopLocationPickerScreen(),
          ),
          GoRoute(
            path: '/owner/delivery-zones',
            builder: (context, state) => const DeliveryZonesScreen(),
          ),
          GoRoute(
            path: '/owner/branches',
            builder: (context, state) => const BranchManagementScreen(),
          ),
          GoRoute(
            path: '/owner/operating-hours',
            builder: (context, state) => const OperatingHoursScreen(),
          ),
          GoRoute(
            path: '/owner/cash-register',
            builder: (context, state) => const CashRegisterScreen(),
          ),
          GoRoute(
            path: '/owner/bill-scanner',
            builder: (context, state) => const BillScannerScreen(),
          ),
          GoRoute(
            path: '/owner/employees',
            builder: (context, state) => const EmployeeManagementScreen(),
          ),
          GoRoute(
            path: '/owner/scan-activity',
            builder: (context, state) => const ScanActivityScreen(),
          ),
          GoRoute(path: '/owner/chat', builder: (context, state) => const OwnerChatCenterScreen()),
          GoRoute(
            path: '/owner/chat/:chatId',
            builder: (context, state) =>
                OwnerChatDetailScreen(chatId: state.pathParameters['chatId']!),
          ),
          GoRoute(
            path: '/owner/inventory-query',
            builder: (context, state) => const BulkInventoryQueryScreen(),
          ),
          GoRoute(
            path: '/owner/inventory-approval',
            builder: (context, state) => const InventoryApprovalQueueScreen(),
          ),
          GoRoute(
            path: '/owner/customer-segments',
            builder: (context, state) => const CustomerSegmentationScreen(),
          ),
          GoRoute(
            path: '/owner/delivery-sla',
            builder: (context, state) => const DeliverySLADashboardScreen(),
          ),
          GoRoute(
            path: '/owner/failed-deliveries',
            builder: (context, state) => const FailedDeliveryEscalationScreen(),
          ),
          GoRoute(
            path: '/owner/mission-control',
            builder: (context, state) => const TeamRoomScreen(),
          ),
          GoRoute(
            path: '/owner/dashboard-enhanced',
            builder: (context, state) => const OwnerDashboardRedesigned(),
          ),
          GoRoute(
            path: '/owner/inventory-visual',
            builder: (context, state) => const InventoryVisualImprovementsScreen(),
          ),
          GoRoute(
            path: '/owner/subscriptions',
            builder: (context, state) => const OwnerSubscriptionDashboard(),
          ),
        ],
      ),

      // Admin Routes
      ShellRoute(
        builder: (context, state, child) => AdminDashboard(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const Center(child: Text("Admin Overiew")),
          ),
          GoRoute(
            path: '/admin/dead-letter',
            builder: (context, state) => const DeadLetterDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/vendor-approvals',
            builder: (context, state) => const AdminVendorApprovalScreen(),
          ),
        ],
      ),

      // Delivery Agent Routes
      ShellRoute(
        builder: (context, state, child) => DeliveryDashboard(child: child),
        routes: [
          GoRoute(path: '/delivery', builder: (context, state) => const DeliveryOrdersScreen()),
          GoRoute(
            path: '/delivery/orders',
            builder: (context, state) => const DeliveryOrdersScreen(),
          ),
          GoRoute(
            path: '/delivery/earnings',
            builder: (context, state) => const DeliveryEarningsScreen(),
          ),
          GoRoute(
            path: '/delivery/trip-sheet',
            builder: (context, state) => const TripRouteSheet(),
          ),
          GoRoute(
            path: '/delivery/smart-route',
            builder: (context, state) => const SmartRouteScreen(),
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
          GoRoute(path: 'cash', builder: (context, state) => const CashCollectionScreen()),
          GoRoute(path: 'returns', builder: (context, state) => const ReturnsScreen()),
          GoRoute(path: 'transfer', builder: (context, state) => const InventoryTransferScreen()),
          GoRoute(path: 'refill', builder: (context, state) => const ShelfRefillScreen()),
          GoRoute(path: 'expiry', builder: (context, state) => const ExpiryManagementScreen()),

          // ── New scanner screens ─────────────────────────────────────────────
          GoRoute(
            path: 'hub',
            builder: (context, state) {
              final mode = state.uri.queryParameters['mode'];
              return UnifiedScannerHub(initialMode: mode);
            },
          ),
          GoRoute(
            path: 'dispatch',
            builder: (context, state) {
              final orderId = state.uri.queryParameters['orderId'];
              return DispatchScannerScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: 'pod',
            builder: (context, state) {
              final parcelId = state.uri.queryParameters['parcelId'];
              return DeliveryPodScannerScreen(parcelId: parcelId);
            },
          ),
          GoRoute(
            path: 'member',
            builder: (context, state) {
              final customerId = state.uri.queryParameters['customerId'];
              return CustomerMembershipScannerScreen(customerId: customerId);
            },
          ),
          GoRoute(path: 'return-hub', builder: (context, state) => const ReturnDamageHubScreen()),
          GoRoute(
            path: 'tasks',
            builder: (context, state) {
              final employeeId = state.uri.queryParameters['employeeId'];
              return EmployeeTaskBoardScreen(employeeId: employeeId ?? '');
            },
          ),
        ],
      ),

      // Vendor Routes
      GoRoute(
        path: '/vendor/signup',
        pageBuilder: (context, state) =>
            FufajiPageTransition(key: state.pageKey, child: const VendorSignupScreen()),
      ),
      GoRoute(
        path: '/vendor',
        builder: (context, state) => const VendorDashboardScreen(),
        routes: [
          GoRoute(
            path: 'dashboard',
            builder: (context, state) => const VendorDashboardScreen(),
          ),
          GoRoute(
            path: 'products',
            builder: (context, state) => const VendorProductsManagementScreen(),
          ),
          GoRoute(
            path: 'orders',
            builder: (context, state) => const VendorOrdersScreen(),
          ),
          GoRoute(
            path: 'payouts',
            builder: (context, state) => const VendorPayoutScreen(),
          ),
          GoRoute(
            path: 'autopayout',
            builder: (context, state) => const VendorCommissionAutopayoutScreen(),
          ),
          GoRoute(
            path: 'commission',
            builder: (context, state) => const VendorCommissionDashboardScreen(),
          ),
          GoRoute(
            path: 'payout-settings',
            builder: (context, state) => const VendorCommissionAutopayoutScreen(),
          ),
          GoRoute(
            path: 'disputes',
            builder: (context, state) {
              final vendorId = state.uri.queryParameters['vendorId'];
              return VendorDisputeResolutionScreen(vendorId: vendorId ?? '');
            },
          ),
        ],
      ),

      // Rider: Live Map screen
      GoRoute(path: '/rider/map', builder: (context, state) => const RiderMapScreen()),

      // Rider: Route History
      GoRoute(path: '/rider/history', builder: (context, state) => const RiderRouteHistoryScreen()),

      // Delivery: Reschedule failed delivery
      GoRoute(
        path: '/delivery/reschedule/:orderId',
        builder: (context, state) {
          final orderId = state.pathParameters['orderId']!;
          final orderNumber = state.uri.queryParameters['orderNumber'] ?? orderId;
          final customerId = state.uri.queryParameters['customerId'] ?? '';
          return DeliveryRescheduleScreen(
            orderId: orderId,
            orderNumber: orderNumber,
            customerId: customerId,
          );
        },
      ),
    ],

    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final guestProvider = Provider.of<GuestProvider>(context, listen: false);
      final isLoggedIn = authProvider.isLoggedIn;
      final user = authProvider.currentUser;
      final isGuest = guestProvider.isGuestMode;
      final path = state.uri.path;

      // ── Paths always accessible (no auth needed) ─────────────
      final isOpenPath =
          path == '/' ||
          path == '/login' ||
          path.startsWith('/otp/') ||
          path == '/role-select' ||
          path == '/profile-creation' ||
          path == '/security-pin' ||
          path.startsWith('/auth/');

      // ── Paths guests CAN access (browse-only) ────────────────
      final isGuestAllowed =
          path == '/customer/home' ||
          path == '/customer/search' ||
          path.startsWith('/customer/product/') ||
          path == '/customer/snap-to-shop';

      // ── Paths that require verification (guest/unverified blocked) ──
      final isVerificationRequired =
          path == '/customer/orders' ||
          path == '/customer/wallet' ||
          path == '/customer/addresses' ||
          path == '/customer/checkout' ||
          path == '/customer/order-confirmation' ||
          path.startsWith('/customer/order-detail/') ||
          path.startsWith('/customer/track/') ||
          path.startsWith('/customer/dispute/');

      final isOnOnboarding = isOpenPath;

      // 1. Not logged in + not in guest mode → login
      if (!isLoggedIn && !isGuest) {
        if (isOpenPath) return null;
        return '/login';
      }

      // 2. Guest mode — block protected routes → verification wall
      if (isGuest && !isLoggedIn) {
        if (isOpenPath || isGuestAllowed) return null;
        if (isVerificationRequired) {
          final encoded = Uri.encodeComponent(path);
          return '/auth/verify-wall?returnPath=$encoded&reason=${Uri.encodeComponent("Verify your identity to continue")}';
        }
        // Any other customer route → also gate
        if (path.startsWith('/customer/')) {
          final encoded = Uri.encodeComponent(path);
          return '/auth/verify-wall?returnPath=$encoded';
        }
        return '/customer/home';
      }

      // 2. Logged in: Route based on active role
      if (isLoggedIn && user != null) {
        final path = state.uri.path;

        // Security Guard for Owner/Admin
        if (user.role == UserRole.shopOwner ||
            user.role == UserRole.admin ||
            user.role == UserRole.owner ||
            user.role == UserRole.superAdmin) {
          if (authProvider.isPinRequired && path != '/security-pin') {
            return '/security-pin';
          }
          if (authProvider.isDeviceVerificationRequired && path != '/security-pin') {
            // Re-using pin screen or dedicated device screen, but logic is in AuthProvider
            return '/security-pin';
          }
        }

        // Force profile completion for new customers
        if (user.role == UserRole.customer &&
            (user.name == null || user.name!.isEmpty) &&
            path != '/profile-creation') {
          return '/profile-creation';
        }

        // Unverified customer guard: block protected routes even if logged in
        // (covers phone-OTP users who haven't completed profile verification)
        if (user.role == UserRole.customer && !user.isVerified) {
          if (isVerificationRequired) {
            final encoded = Uri.encodeComponent(path);
            return '/auth/verify-wall?returnPath=$encoded&reason=${Uri.encodeComponent("Complete verification to access this feature")}';
          }
        }

        // If on onboarding pages, redirect to dashboard
        if (isOnOnboarding && path != '/profile-creation') {
          switch (user.role) {
            case UserRole.shopOwner:
              return '/owner';
            case UserRole.owner:
              return '/owner';
            case UserRole.superAdmin:
              return '/owner';
            case UserRole.deliveryAgent:
              return '/delivery';
            case UserRole.admin:
              return '/admin';
            case UserRole.employee:
              return '/employee';
            case UserRole.customer:
              return '/customer/home';
            case UserRole.rider:
              return '/delivery';
            case UserRole.dispatcher:
              return '/owner';
            case UserRole.branchManager:
              return '/owner';
            case UserRole.supplier:
              return '/owner';
            case UserRole.franchiseOwner:
              return '/owner';
          }
        }

        // Dashboard Guard: Ensure user is in the correct section for their active role
        if (user.role == UserRole.shopOwner && !path.startsWith('/owner')) return '/owner';
        if (user.role == UserRole.customer &&
            !path.startsWith('/customer') &&
            path != '/profile-creation')
          return '/customer/home';
        if (user.role == UserRole.deliveryAgent && !path.startsWith('/delivery'))
          return '/delivery';
        if (user.role == UserRole.employee && !path.startsWith('/employee')) return '/employee';
        if (user.role == UserRole.admin && !path.startsWith('/admin')) return '/admin';
      }

      return null;
    },
  );
}
