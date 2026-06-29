/// Practical Examples for Fufaji Navigation
///
/// Copy-paste ready code snippets for common routing tasks.
/// Replace [context] with your BuildContext.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ==============================================================================
// CUSTOMER NAVIGATION EXAMPLES
// ==============================================================================

class CustomerNavigationExamples {
  /// Browse a product from home screen
  static void goToProduct(BuildContext context, String productId) {
    context.push('/customer/product/$productId');
  }

  /// Search for products
  static void searchProducts(BuildContext context, String query) {
    final encoded = Uri.encodeComponent(query);
    context.push('/customer/search?q=$encoded');
  }

  /// View shopping cart
  static void viewCart(BuildContext context) {
    context.go('/customer/cart');
  }

  /// Start checkout
  static void startCheckout(BuildContext context) {
    context.push('/customer/checkout');
  }

  /// Show order confirmation
  static void showOrderConfirmation(
    BuildContext context,
    String orderId,
    String orderNumber,
  ) {
    context.push(
      '/customer/order-confirmation?orderId=$orderId&orderNumber=$orderNumber',
    );
  }

  /// View all orders
  static void viewOrders(BuildContext context) {
    context.push('/customer/orders');
  }

  /// View specific order details
  static void viewOrderDetail(BuildContext context, String orderId) {
    context.push('/customer/order-detail/$orderId');
  }

  /// Track a specific order
  static void trackOrder(BuildContext context, String orderId) {
    context.push('/customer/track/$orderId');
  }

  /// Raise dispute for order
  static void raiseDispute(BuildContext context, String orderId) {
    context.push('/customer/dispute/$orderId');
  }

  /// Add review for product
  static void addReview(
    BuildContext context,
    String productId,
    String productName,
    String? orderId,
  ) {
    final encoded = Uri.encodeComponent(productName);
    final query = orderId != null ? '&orderId=$orderId' : '';
    context.push('/customer/add-review/$productId?name=$encoded$query');
  }

  /// View addresses
  static void viewAddresses(BuildContext context) {
    context.push('/customer/addresses');
  }

  /// View wallet
  static void viewWallet(BuildContext context) {
    context.push('/customer/wallet');
  }

  /// Support chat for order
  static void openSupportChat(BuildContext context, String? orderId) {
    if (orderId != null) {
      context.push('/customer/support-chat/$orderId');
    } else {
      context.push('/customer/support');
    }
  }

  /// Join group buying room
  static void joinGroupBuying(BuildContext context, String groupId) {
    context.push('/customer/group-buying?groupId=$groupId');
  }

  /// View festival bundles
  static void viewFestivalBundles(BuildContext context, String festivalName) {
    final encoded = Uri.encodeComponent(festivalName);
    context.push('/customer/festival-bundles/$encoded');
  }

  /// Show missing item options
  static void missingItemChoice(BuildContext context, String orderId) {
    context.push('/customer/missing-item-choice?orderId=$orderId');
  }
}

// ==============================================================================
// OWNER NAVIGATION EXAMPLES
// ==============================================================================

class OwnerNavigationExamples {
  /// Go to owner dashboard
  static void goDashboard(BuildContext context) {
    context.go('/owner');
  }

  /// View all products
  static void viewProducts(BuildContext context) {
    context.go('/owner/products');
  }

  /// Add new product (with optional barcode)
  static void addProduct(BuildContext context, {String? barcode}) {
    if (barcode != null) {
      context.push('/owner/products/add?barcode=$barcode');
    } else {
      context.push('/owner/products/add');
    }
  }

  /// Edit existing product
  static void editProduct(BuildContext context, String productId) {
    context.push('/owner/products/add?productId=$productId');
  }

  /// View all orders
  static void viewOrders(BuildContext context) {
    context.go('/owner/orders');
  }

  /// View inventory
  static void viewInventory(BuildContext context) {
    context.go('/owner/inventory');
  }

  /// View inventory alerts
  static void viewInventoryAlerts(BuildContext context) {
    context.go('/owner/inventory-alerts');
  }

  /// Perform inventory audit
  static void startInventoryAudit(BuildContext context) {
    context.push('/owner/inventory-audit');
  }

  /// Track product expiry
  static void viewExpiryTracking(BuildContext context) {
    context.go('/owner/expiry-tracking');
  }

  /// Configure dynamic pricing
  static void configurePricing(BuildContext context) {
    context.go('/owner/pricing-rules');
  }

  /// View pending price changes
  static void viewPriceChanges(BuildContext context) {
    context.go('/owner/pending-price-changes');
  }

  /// View sales analytics
  static void viewAnalytics(BuildContext context) {
    context.push('/owner/analytics');
  }

  /// Open Khata (accounting book)
  static void openKhata(BuildContext context) {
    context.push('/owner/khata');
  }

  /// Setup WhatsApp sync
  static void setupWhatsApp(BuildContext context) {
    context.push('/owner/whatsapp-sync');
  }

  /// Manage delivery riders
  static void manageRiders(BuildContext context) {
    context.push('/owner/riders');
  }

  /// Manage employees
  static void manageEmployees(BuildContext context) {
    context.push('/owner/employees');
  }

  /// Go to shop settings
  static void shopSettings(BuildContext context) {
    context.go('/owner/shop-settings');
  }

  /// Go to packing dashboard
  static void packingDashboard(BuildContext context) {
    context.go('/owner/packing-dashboard');
  }

  /// Open packing terminal for specific order
  static void packOrder(BuildContext context, String? orderId) {
    if (orderId != null) {
      context.push('/owner/packing-terminal?orderId=$orderId');
    } else {
      context.push('/owner/packing-dashboard');
    }
  }

  /// Manage settlements
  static void manageSettlements(BuildContext context) {
    context.push('/owner/settlements');
  }

  /// Track attendance
  static void trackAttendance(BuildContext context) {
    context.push('/owner/attendance');
  }

  /// Moderate reviews
  static void moderateReviews(BuildContext context) {
    context.push('/owner/reviews');
  }

  /// Smart dispatch optimization
  static void smartDispatch(BuildContext context) {
    context.push('/owner/smart-dispatch');
  }

  /// Mandi pricing dashboard
  static void mandiPricing(BuildContext context) {
    context.push('/owner/mandi-pricing');
  }

  /// Chat center
  static void chatCenter(BuildContext context) {
    context.go('/owner/chat');
  }

  /// Chat with specific customer
  static void chatWith(BuildContext context, String chatId) {
    context.push('/owner/chat/$chatId');
  }
}

// ==============================================================================
// DELIVERY AGENT NAVIGATION EXAMPLES
// ==============================================================================

class DeliveryNavigationExamples {
  /// Go to delivery home (map/smart route)
  static void goHome(BuildContext context) {
    context.go('/delivery/smart-route');
  }

  /// View active orders
  static void viewOrders(BuildContext context) {
    context.push('/delivery/orders');
  }

  /// View order details
  static void viewOrderDetail(BuildContext context, String orderId) {
    context.push('/delivery/detail/$orderId');
  }

  /// View trip route sheet
  static void viewTripSheet(BuildContext context) {
    context.push('/delivery/trip-sheet');
  }

  /// View smart routing
  static void viewSmartRoute(BuildContext context) {
    context.go('/delivery/smart-route');
  }

  /// View delivery cluster
  static void viewCluster(BuildContext context, String clusterId) {
    context.push('/delivery/cluster/$clusterId');
  }

  /// Scan delivery barcode
  static void scanDelivery(BuildContext context) {
    context.push('/delivery/scanner');
  }

  /// View earnings
  static void viewEarnings(BuildContext context) {
    context.go('/delivery/earnings');
  }

  /// Open chat with customer
  static void chatWithCustomer(BuildContext context) {
    context.push('/delivery/chat');
  }
}

// ==============================================================================
// EMPLOYEE NAVIGATION EXAMPLES
// ==============================================================================

class EmployeeNavigationExamples {
  /// Go to employee home (tasks)
  static void goHome(BuildContext context) {
    context.go('/employee');
  }

  /// View task priority
  static void viewTasks(BuildContext context) {
    context.push('/employee/tasks');
  }

  /// Open unified scanner
  static void openScanner(BuildContext context, {String? mode}) {
    if (mode != null) {
      context.push('/employee/hub?mode=$mode');
    } else {
      context.push('/employee/hub');
    }
  }

  /// Start inventory receiving
  static void receiveInventory(BuildContext context, {String? barcode}) {
    if (barcode != null) {
      context.push('/employee/receiving?barcode=$barcode');
    } else {
      context.push('/employee/receiving');
    }
  }

  /// Start order packing
  static void packOrder(BuildContext context, {String? orderId}) {
    if (orderId != null) {
      context.push('/employee/packing?orderId=$orderId');
    } else {
      context.push('/employee/packing');
    }
  }

  /// Start delivery
  static void startDelivery(BuildContext context, {String? parcelId}) {
    if (parcelId != null) {
      context.push('/employee/delivery?parcelId=$parcelId');
    } else {
      context.push('/employee/delivery');
    }
  }

  /// Open dispatch scanner
  static void dispatchScan(BuildContext context, {String? orderId}) {
    if (orderId != null) {
      context.push('/employee/dispatch?orderId=$orderId');
    } else {
      context.push('/employee/dispatch');
    }
  }

  /// Scan delivery pod
  static void scanDeliveryPod(BuildContext context, {String? parcelId}) {
    if (parcelId != null) {
      context.push('/employee/pod?parcelId=$parcelId');
    } else {
      context.push('/employee/pod');
    }
  }

  /// Start inventory audit
  static void startAudit(BuildContext context, {String? auditId}) {
    if (auditId != null) {
      context.push('/employee/audit?auditId=$auditId');
    } else {
      context.push('/employee/audit');
    }
  }

  /// Report damage
  static void reportDamage(BuildContext context, {String? barcode}) {
    if (barcode != null) {
      context.push('/employee/damage?barcode=$barcode');
    } else {
      context.push('/employee/damage');
    }
  }

  /// Mark attendance
  static void markAttendance(BuildContext context, {String? qrCode}) {
    if (qrCode != null) {
      context.push('/employee/attendance?qr=$qrCode');
    } else {
      context.push('/employee/attendance');
    }
  }

  /// Collect cash
  static void collectCash(BuildContext context) {
    context.push('/employee/cash');
  }

  /// Process returns
  static void processReturns(BuildContext context) {
    context.push('/employee/returns');
  }

  /// Transfer inventory between locations
  static void transferInventory(BuildContext context) {
    context.push('/employee/transfer');
  }

  /// Refill shelves
  static void refillShelves(BuildContext context) {
    context.push('/employee/refill');
  }

  /// Manage expiry items
  static void manageExpiry(BuildContext context) {
    context.push('/employee/expiry');
  }

  /// Scan customer membership
  static void scanMembership(BuildContext context, {String? customerId}) {
    if (customerId != null) {
      context.push('/employee/member?customerId=$customerId');
    } else {
      context.push('/employee/member');
    }
  }

  /// Chat with team
  static void chat(BuildContext context, String chatId) {
    context.push('/employee/chat/$chatId');
  }
}

// ==============================================================================
// ADMIN NAVIGATION EXAMPLES
// ==============================================================================

class AdminNavigationExamples {
  /// Go to admin dashboard
  static void goDashboard(BuildContext context) {
    context.go('/admin');
  }

  /// Manage users
  static void manageUsers(BuildContext context) {
    context.push('/admin/users');
  }

  /// Manage shops
  static void manageShops(BuildContext context) {
    context.push('/admin/shops');
  }

  /// Moderate products
  static void moderateProducts(BuildContext context) {
    context.push('/admin/products');
  }

  /// Manage orders
  static void manageOrders(BuildContext context) {
    context.push('/admin/orders');
  }

  /// Manage coupons
  static void manageCoupons(BuildContext context) {
    context.push('/admin/coupons');
  }

  /// View analytics
  static void viewAnalytics(BuildContext context) {
    context.push('/admin/analytics');
  }
}

// ==============================================================================
// AUTHENTICATION & ROLE SWITCHING EXAMPLES
// ==============================================================================

class AuthNavigationExamples {
  /// Go to login
  static void goLogin(BuildContext context) {
    context.go('/login');
  }

  /// Go to role selection
  static void selectRole(BuildContext context) {
    context.push('/role-select');
  }

  /// Start OTP verification for phone
  static void verifyPhone(BuildContext context, String phoneNumber) {
    final encoded = Uri.encodeComponent(phoneNumber);
    context.push('/otp/$encoded');
  }

  /// Verify with role parameter
  static void verifyPhoneForRole(
    BuildContext context,
    String phoneNumber,
    String role,
  ) {
    final encoded = Uri.encodeComponent(phoneNumber);
    context.push('/otp/$encoded?role=$role');
  }

  /// Complete profile
  static void completeProfile(BuildContext context) {
    context.push('/profile-creation');
  }

  /// Handle verification wall (when guest tries protected action)
  static void verifyIdentity(
    BuildContext context,
    String returnPath,
    String? reason,
  ) {
    final encoded = Uri.encodeComponent(returnPath);
    final reasonQuery = reason != null ? '&reason=${Uri.encodeComponent(reason)}' : '';
    context.go('/auth/verify-wall?returnPath=$encoded$reasonQuery');
  }

  /// Enter security PIN (owner/admin)
  static void enterSecurityPin(BuildContext context) {
    context.push('/security-pin');
  }

  /// Switch account
  static void switchAccount(BuildContext context) {
    context.push('/account-picker');
  }
}

// ==============================================================================
// ERROR HANDLING EXAMPLES
// ==============================================================================

class ErrorNavigationExamples {
  /// Show unauthorized access screen
  static void showUnauthorized(
    BuildContext context,
    String? reason,
    String? returnPath,
  ) {
    final reasonQuery = reason != null ? '&reason=${Uri.encodeComponent(reason)}' : '';
    final pathQuery = returnPath != null ? '?returnPath=${Uri.encodeComponent(returnPath)}' : '';
    context.go('/unauthorized$pathQuery$reasonQuery');
  }

  /// Show network error screen
  static void showNetworkError(BuildContext context) {
    context.go('/network-error');
  }

  /// Go back
  static void goBack(BuildContext context) {
    context.pop();
  }

  /// Go back with result
  static void goBackWithResult(BuildContext context, dynamic result) {
    context.pop(result);
  }

  /// Go back to home for current role
  static void goHome(BuildContext context, String role) {
    switch (role) {
      case 'customer':
        context.go('/customer/home');
      case 'owner':
        context.go('/owner');
      case 'delivery':
        context.go('/delivery');
      case 'employee':
        context.go('/employee');
      case 'admin':
        context.go('/admin');
      default:
        context.go('/login');
    }
  }
}

// ==============================================================================
// CONDITIONAL NAVIGATION EXAMPLES
// ==============================================================================

class ConditionalNavigationExamples {
  /// Navigate based on authentication state
  static void navigateToHome(
    BuildContext context,
    bool isLoggedIn,
    String userRole,
  ) {
    if (!isLoggedIn) {
      context.go('/login');
      return;
    }

    switch (userRole) {
      case 'customer':
        context.go('/customer/home');
        break;
      case 'shopOwner':
        context.go('/owner');
        break;
      case 'deliveryAgent':
        context.go('/delivery');
        break;
      case 'employee':
        context.go('/employee');
        break;
      case 'admin':
        context.go('/admin');
        break;
      default:
        context.go('/role-select');
    }
  }

  /// Navigate to checkout if cart has items, else to shop
  static void goCheckoutOrShop(BuildContext context, int cartItemCount) {
    if (cartItemCount > 0) {
      context.go('/customer/checkout');
    } else {
      context.go('/customer/home');
    }
  }

  /// Navigate based on verification status
  static void navigateIfVerified(
    BuildContext context,
    bool isVerified,
    String intendedPath,
  ) {
    if (isVerified) {
      context.go(intendedPath);
    } else {
      final encoded = Uri.encodeComponent(intendedPath);
      context.go('/auth/verify-wall?returnPath=$encoded');
    }
  }
}

// ==============================================================================
// DEEP LINKING EXAMPLES
// ==============================================================================

/// These URIs can be opened via:
/// - Push notification
/// - Web links
/// - App shortcuts
/// - Deeplink registration

class DeepLinkExamples {
  // Customer deeplinks
  static const String productDetail = 'fufaji://customer/product/PRODUCT_ID';
  static const String orderTracking = 'fufaji://customer/track/ORDER_ID';
  static const String searchProducts = 'fufaji://customer/search?q=milk';

  // Owner deeplinks
  static const String ownerOrders = 'fufaji://owner/orders';
  static const String ownerAnalytics = 'fufaji://owner/analytics';
  static const String packOrder = 'fufaji://owner/packing-terminal?orderId=ORDER_ID';

  // Delivery deeplinks
  static const String deliveryMap = 'fufaji://delivery/smart-route';
  static const String deliveryOrders = 'fufaji://delivery/orders';

  // Admin deeplinks
  static const String adminUsers = 'fufaji://admin/users';
  static const String adminOrders = 'fufaji://admin/orders';

  // Usage in code:
  // Share link via: Share.share(productDetail.replaceAll('PRODUCT_ID', '123'));
  // Open in browser: launchUrl(Uri.parse(productDetail));
}
