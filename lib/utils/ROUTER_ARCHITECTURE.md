# Fufaji GoRouter Architecture

Complete navigation setup for multi-role Flutter app using GoRouter 12.0+.

## Overview

The routing system is organized by **user role** with dedicated shell routes for navigation UI (bottom nav, drawer, AppBar). Each role has distinct navigation patterns:

- **Customer**: BottomNavigationBar (5 tabs)
- **Employee**: BottomNavigationBar (4 tabs with badge)
- **Delivery Agent**: BottomNavigationBar (4 tabs, map-prominent)
- **Shop Owner**: Drawer navigation (left sidebar)
- **Admin**: Drawer navigation with system health

## Route Organization

### 1. Authentication Routes (Always Accessible)
```
/                               → SplashScreen (bootstrap)
/login                          → LoginScreen
/otp/:contact                   → OTPScreen
/role-select                    → RoleSelectScreen
/profile-creation               → ProfileCreationScreen
/security-pin                   → SecurityPinScreen
/auth/verify-wall               → VerificationWallScreen (unverified guard)
/account-picker                 → AccountPickerScreen
```

### 2. Customer Routes (ShellRoute with BottomNavigationBar)
```
ShellRoute → CustomerShell
├── /customer/home               → HomeScreen (main explore)
├── /customer/search             → SearchScreen (with query param)
├── /customer/cart               → CartScreen
├── /customer/profile            → ProfileScreen
├── /customer/orders             → OrdersScreen (requires auth + verified)
├── /customer/order-detail/:id   → OrderDetailScreen
├── /customer/track/:orderId     → TrackOrderScreen
├── /customer/checkout           → CheckoutScreen
├── /customer/checkout-confirmation → OrderConfirmationScreen
├── /customer/product/:productId → ProductDetailScreen
├── /customer/dispute/:orderId   → DisputeScreen
├── /customer/addresses          → AddressScreen
├── /customer/wallet             → WalletHistoryScreen
├── /customer/refer              → ReferEarnScreen
├── /customer/voice-order        → VoiceOrderScreen
├── /customer/wishlist           → WishlistScreen
├── /customer/subscriptions      → SubscriptionScreen
├── /customer/loyalty            → LoyaltyScreen
├── /customer/membership         → MembershipDashboardScreen
├── /customer/festival-bundles/:name → FestivalBundlesScreen
├── /customer/add-review/:productId  → AddReviewScreen
├── /customer/settings           → SettingsScreen
├── /customer/notifications      → NotificationCenter
├── /customer/notification-settings → NotificationSettingsScreen
├── /customer/scan               → BarcodeScannerScreen
├── /customer/family             → FamilyManagementScreen
├── /customer/fast-checkout      → FastCheckoutScreen
├── /customer/missing-item-choice → MissingItemChoiceScreen
├── /customer/smart-kitchen      → SmartKitchenScreen
├── /customer/snap-to-shop       → SnapToShopScreen
└── /customer/group-buying       → GroupBuyingRoom
```

### 3. Shop Owner Routes (ShellRoute with Drawer)
```
ShellRoute → OwnerShell (left drawer navigation)
├── /owner                       → OwnerHomePage (dashboard)
├── /owner/products              → ProductsManagementScreen
├── /owner/products/add          → AddProductScreen
├── /owner/orders                → OrdersManagementScreen
├── /owner/inventory             → InventoryScreen
├── /owner/inventory-alerts      → InventoryAlertsScreen
├── /owner/inventory-audit       → InventoryAuditScreen
├── /owner/expiry-tracking       → ExpiryTrackingScreen
├── /owner/pricing-rules         → PricingRulesScreen
├── /owner/pending-price-changes → PendingPriceChangesScreen
├── /owner/vendor-request        → VendorRequestScreen
├── /owner/analytics             → AnalyticsScreen
├── /owner/khata                 → BahiKhataScreen (accounting)
├── /owner/whatsapp-sync         → WhatsAppSyncSetupScreen
├── /owner/riders                → RiderManagementScreen
├── /owner/shop-settings         → ShopSettingsScreen
├── /owner/shop-location         → ShopLocationPickerScreen
├── /owner/delivery-zones        → DeliveryZonesScreen
├── /owner/branches              → BranchManagementScreen
├── /owner/operating-hours       → OperatingHoursScreen
├── /owner/settlements           → SettlementsManagementScreen
├── /owner/attendance            → AttendanceManagementScreen
├── /owner/rider-support         → RiderSupportConsole
├── /owner/dynamic-pricing       → DynamicPricingConsole
├── /owner/reviews               → ReviewsModerationScreen
├── /owner/devices               → DeviceManagementScreen
├── /owner/releases              → ReleaseManagementScreen
├── /owner/broadcast             → BroadcastNotificationScreen
├── /owner/mandi-pricing         → MandiPricingDashboard
├── /owner/smart-dispatch        → SmartDispatchScreen
├── /owner/barcode-inventory     → BarcodeInventoryScreen
├── /owner/packing-terminal      → PackingTerminalScreen
├── /owner/packing-dashboard     → PackingDashboardScreen
├── /owner/cash-register         → CashRegisterScreen
├── /owner/bill-scanner          → BillScannerScreen
├── /owner/employees             → EmployeeManagementScreen
├── /owner/chat                  → OwnerChatCenterScreen
├── /owner/chat/:chatId          → OwnerChatDetailScreen
└── /owner/scan-activity         → ScanActivityScreen
```

### 4. Admin Routes (ShellRoute with Sidebar)
```
ShellRoute → AdminShell (left sidebar with system health)
├── /admin                       → AdminOverviewPage (dashboard)
├── /admin/users                 → UserManagementScreen
├── /admin/shops                 → ShopManagementScreen
├── /admin/products              → ProductModerationScreen
├── /admin/orders                → OrderManagementScreen
├── /admin/coupons               → CouponManagementScreen
└── /admin/analytics             → AnalyticsScreen
```

### 5. Delivery Agent Routes (ShellRoute with Bottom Nav - Map Prominent)
```
ShellRoute → DeliveryShell
├── /delivery                    → DeliveryHomePage (map/smart route)
├── /delivery/orders             → DeliveryOrdersScreen
├── /delivery/earnings           → DeliveryEarningsScreen
├── /delivery/trip-sheet         → TripRouteSheet
├── /delivery/smart-route        → SmartRouteScreen (route optimization)
├── /delivery/detail/:orderId    → DeliveryDetailScreen
├── /delivery/cluster/:clusterId → DeliveryClusterView
├── /delivery/scanner            → DeliveryScannerPage
└── /delivery/chat               → RiderChatScreen
```

### 6. Employee Routes (ShellRoute with Bottom Nav + Badge)
```
ShellRoute → EmployeeShell (badge on Tasks tab)
├── /employee                    → EmployeeHomeScreen
├── /employee/tasks              → TaskPriorityScreen
├── /employee/hub                → UnifiedScannerHub (multi-mode scanner)
├── /employee/scanner            → ScannerScreen
├── /employee/receiving          → InventoryReceivingScreen
├── /employee/packing            → OrderPackingScreen
├── /employee/dispatch           → DispatchScannerScreen
├── /employee/delivery           → DeliveryScreen
├── /employee/pod                → DeliveryPodScannerScreen
├── /employee/audit              → InventoryAuditScreen
├── /employee/damage             → DamageReportingScreen
├── /employee/attendance         → AttendanceScreen
├── /employee/cash               → CashCollectionScreen
├── /employee/returns            → ReturnsScreen
├── /employee/transfer           → InventoryTransferScreen
├── /employee/refill             → ShelfRefillScreen
├── /employee/expiry             → ExpiryManagementScreen
├── /employee/member             → CustomerMembershipScannerScreen
└── /employee/chat/:chatId       → EmployeeChatScreen
```

### 7. Error Routes
```
/unauthorized                   → UnauthorizedScreen (403)
/network-error                  → NetworkErrorScreen (offline)
```

## Route Guards & Redirect Logic

### Authentication States
1. **Not Logged In + Not Guest** → `/login` (except public routes)
2. **Guest Mode** → Can access `/customer/home`, `/customer/search`, `/customer/product/*` only
3. **Logged In** → Redirect to role-specific home based on active role

### Role-Based Access
- **Customer** can only access `/customer/*`
- **Shop Owner** can only access `/owner/*`
- **Employee** can only access `/employee/*`
- **Delivery Agent** can only access `/delivery/*`
- **Admin** can only access `/admin/*`

### Verification Gates
Some customer routes require identity verification:
- `/customer/orders`
- `/customer/wallet`
- `/customer/addresses`
- `/customer/checkout`
- `/customer/order-confirmation`
- `/customer/order-detail/*`
- `/customer/track/*`
- `/customer/dispute/*`

Unverified users → `/auth/verify-wall?returnPath=<encoded>&reason=<msg>`

### Security Checks (Owner/Admin)
- PIN required for owner/admin access → `/security-pin`
- Device verification → `/security-pin`
- Session expired → `/login`

### Onboarding Flow
1. New customer with no profile → `/profile-creation` (forced until complete)
2. After profile → `/customer/home` (or return path if provided)
3. After role selection → Role-specific home

## Shell Routes & Navigation Patterns

### CustomerShell
**Widget**: `lib/shells/customer_shell.dart` (will be refactored from existing)

**Bottom Navigation** (4-5 tabs):
- Home (0) - Browse products
- Search (1) - Product search
- Cart (2) - Shopping cart with badge
- Profile (3) - User account
- Orders (often accessible from home tab)

**Features**:
- Sticky checkout bar when items in cart
- AI shopping assistant FAB
- Location selector in AppBar
- Notification icon
- Role switcher for testing

### EmployeeShell
**Widget**: `lib/shells/employee_shell.dart` ✓ CREATED

**Bottom Navigation** (4 tabs):
- Tasks (0) - Assigned work, badge shows pending count
- Inventory (1) - Stock ops, receiving, transfers
- Delivery (2) - Packing, dispatch, delivery
- Profile (3) - Attendance, settings, chat

**Features**:
- Badge on Tasks showing pending item count
- Grouped routes by operational category
- Localization support
- Dark mode compatible

### DeliveryShell
**Widget**: `lib/shells/delivery_shell.dart` ✓ CREATED

**Bottom Navigation** (4 tabs - Map Prominent):
- Map (0) - Smart routing, cluster view, trip sheet
- Orders (1) - Active deliveries, order details
- Earnings (2) - Trip earnings, daily/weekly stats
- Profile (3) - Rider chat, settings

**Features**:
- Map tab takes priority (real-time navigation)
- Location updates and route optimization
- Real-time delivery tracking
- Chat for customer communication
- Earnings breakdown

### OwnerShell
**Widget**: `lib/shells/owner_shell.dart` ✓ CREATED

**Left Drawer Navigation**:
- **Main Section**
  - Dashboard
  - Orders
  - Products
  - Inventory
  - Analytics
  - Employees
  - Settings

- **Operations Section**
  - Packing Terminal
  - Khata (Accounting)
  - Delivery Riders

- **Tools Section**
  - Role Switcher

**Features**:
- Drawer-based navigation (left sidebar)
- Shop name in AppBar
- Multi-shop switcher (if applicable)
- Notifications icon
- Active route highlighting
- Localization support

### AdminShell
**Widget**: `lib/shells/admin_shell.dart` ✓ CREATED

**Left Sidebar Navigation**:
- Dashboard
- Users Management
- Shops
- Products (moderation)
- Orders
- Coupons
- Analytics

**Features**:
- System health indicator (top-right, live status)
- Real-time monitoring badge
- Drawer-based navigation
- Audit log links (placeholder)
- Settings access
- Role switcher

**Status Indicator**:
```
Color: Green (healthy)
Display: Live system status with dot indicator
Location: AppBar trailing
Updates: Real-time monitoring
```

## DeepLink Support

All routes support deep linking via URL scheme:
```
fufaji://customer/home
fufaji://customer/product/123
fufaji://owner/orders
fufaji://delivery/smart-route
fufaji://admin/users
```

## Localization

All shell routes use `AppLocalizations` for multi-language support:
```dart
label: l10n?.translate('home') ?? 'Home'
```

Supported keys:
- `dashboard`, `home`, `search`, `cart`, `orders`, `profile`
- `inventory`, `delivery`, `tasks`, `analytics`, `settings`
- `employees`, `earnings`, `map`

## Error Handling

### UnauthorizedScreen (`/unauthorized`)
Shown when user attempts unauthorized route access.
- Displays clear denial message
- Option to return home
- Option to try different role
- Sign out button

### NetworkErrorScreen (`/network-error`)
Shown during network connectivity loss.
- Offline mode option (cached data)
- Automatic reconnection detection
- Troubleshooting tips
- Live connection indicator

## Best Practices

### 1. Route Naming
- Always use full paths: `/customer/home`, not `home`
- Namespace by role: `/customer/*`, `/owner/*`, etc.
- Use hyphens for multi-word routes: `/pending-price-changes`

### 2. Parameters
- Path parameters: `/product/:productId`
- Query parameters: `?q=search_term&limit=10`
- Always URL-encode complex values: `Uri.encodeComponent()`

### 3. Navigating Between Roles
```dart
// Only via role-select screen to switch active role
context.go('/role-select');

// Then auth provider updates active role
// Then redirect logic routes to new role home
```

### 4. Back Navigation
```dart
context.pop();           // GoRouter.pop
context.go(path);        // Navigate (no history)
context.push(path);      // Push (adds to history)
```

### 5. Redirect Logic
The redirect function is called on every route change:
```dart
redirect: (context, state) {
  // 1. Check authentication
  // 2. Check role authorization
  // 3. Check verification status
  // 4. Enforce onboarding
  // 5. Return null to allow, or path to redirect
}
```

## Testing Routes

### Manual Testing Checklist
- [ ] Start app → Splash loads
- [ ] Not authenticated → /login
- [ ] Guest mode → /customer/home (limited)
- [ ] Login → Customer home
- [ ] Try protected route as guest → Verify wall
- [ ] Switch role → New role home
- [ ] Click each shell tab → Correct route
- [ ] Deep link to protected route while offline → Network error
- [ ] Offline → Reconnect → Auto continue

### Deep Link Testing
```bash
# iOS
xcrun simctl openurl booted "fufaji://customer/home"

# Android
adb shell am start -W -a android.intent.action.VIEW -d "fufaji://customer/home"
```

## File Structure

```
lib/
├── utils/
│   ├── app_router.dart                 ← Main GoRouter config
│   └── ROUTER_ARCHITECTURE.md          ← This file
├── shells/
│   ├── employee_shell.dart             ← Employee nav (4 tabs + badge)
│   ├── delivery_shell.dart             ← Delivery nav (4 tabs, map-first)
│   ├── owner_shell.dart                ← Owner nav (drawer)
│   └── admin_shell.dart                ← Admin nav (sidebar + health)
├── screens/
│   ├── splash_screen.dart              ← Bootstrap/auth check
│   ├── login_screen.dart               ← Phone/email login
│   ├── otp_screen.dart                 ← OTP verification
│   ├── role_select_screen.dart         ← Multi-role selection
│   ├── unauthorized_screen.dart        ← 403 error
│   ├── network_error_screen.dart       ← Offline/connection error
│   ├── customer/
│   │   ├── customer_shell.dart         ← Customer nav (will refactor)
│   │   ├── home_screen.dart
│   │   ├── search_screen.dart
│   │   ├── cart_screen.dart
│   │   └── ... (30+ customer screens)
│   ├── owner/
│   │   ├── owner_dashboard.dart        ← Replaced by OwnerShell
│   │   ├── products_management.dart
│   │   └── ... (20+ owner screens)
│   ├── delivery/
│   │   ├── delivery_dashboard.dart     ← Replaced by DeliveryShell
│   │   └── ... (8+ delivery screens)
│   ├── employee/
│   │   ├── employee_home_screen.dart
│   │   └── ... (15+ employee screens)
│   └── admin/
│       ├── admin_dashboard.dart        ← Replaced by AdminShell
│       └── ... (6+ admin screens)
└── providers/
    ├── auth_provider.dart              ← Auth state
    ├── employee_provider.dart          ← Employee data
    └── ... (15+ providers)
```

## Future Enhancements

1. **Dynamic Route Loading**: Conditionally load routes based on feature flags
2. **Analytics Integration**: Track route changes for analytics
3. **Route Guards as Middleware**: Create reusable guard functions
4. **Nested Navigation**: Support nested shells for complex flows
5. **Route Naming Constants**: Generate route constants from router config
6. **Breadcrumb Navigation**: Show navigation path for detail screens

## References

- GoRouter Documentation: https://pub.dev/packages/go_router
- Flutter Navigation: https://docs.flutter.dev/navigation
- Deeplink Setup: https://docs.flutter.dev/development/platform-integration/android/app-links
