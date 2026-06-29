# GoRouter Quick Reference

Quick lookup for common routing tasks in Fufaji.

## Common Navigation Patterns

### Navigate by Role
```dart
// From any screen, navigate to that role's home
context.go('/customer/home');    // Customer
context.go('/owner');             // Owner
context.go('/delivery');          // Delivery
context.go('/employee');          // Employee
context.go('/admin');             // Admin
```

### Navigate with Parameters
```dart
// Path parameter
context.push('/customer/product/abc123');

// Query parameters
context.push('/customer/search?q=milk&category=dairy');

// Encoded parameters (for special chars)
final productName = 'milk (1L)';
context.push('/customer/search?q=${Uri.encodeComponent(productName)}');

// Get parameters
final productId = state.pathParameters['productId'];
final query = state.uri.queryParameters['q'];
```

### Navigate Between Screens (Same Role)
```dart
// Push (adds to navigation stack, can go back)
context.push('/customer/orders');

// Go (replaces current screen, cleans history)
context.go('/customer/home');

// Pop (go back to previous screen)
context.pop();
context.pop('/customer/home');  // Pop with result

// Replace (replace current in stack)
context.replaceNamed('routeName');
```

## Role-Specific Navigation

### Customer Role
```dart
// Browse
context.go('/customer/home');       // Main shop browse
context.push('/customer/search?q=milk');
context.push('/customer/product/abc123');

// Shopping
context.go('/customer/cart');
context.push('/customer/checkout');

// Orders
context.push('/customer/orders');
context.push('/customer/order-detail/ord123');
context.push('/customer/track/ord123');

// Account
context.go('/customer/profile');
context.push('/customer/addresses');
context.push('/customer/wallet');
```

### Owner Role
```dart
context.go('/owner');               // Dashboard
context.go('/owner/orders');
context.go('/owner/products');
context.push('/owner/products/add');
context.go('/owner/inventory');
context.push('/owner/analytics');
context.go('/owner/employees');
context.push('/owner/shop-settings');
```

### Delivery Agent Role
```dart
context.go('/delivery');            // Map/smart route
context.push('/delivery/orders');
context.push('/delivery/detail/ord123');
context.go('/delivery/earnings');
context.push('/delivery/chat');
```

### Employee Role
```dart
context.go('/employee');            // Tasks
context.push('/employee/receiving');
context.push('/employee/packing?orderId=123');
context.push('/employee/delivery');
context.go('/employee/attendance');
```

### Admin Role
```dart
context.go('/admin');               // Overview
context.go('/admin/users');
context.go('/admin/shops');
context.push('/admin/products');
context.go('/admin/orders');
context.push('/admin/analytics');
```

## Shell Routes (Navigation Structure)

### Customer Shell (Bottom Nav - 4 Tabs)
```
Tabs:
0 → /customer/home
1 → /customer/search
2 → /customer/cart
3 → /customer/profile
```
Non-tab screens navigate within shell (no tab change)

### Owner Shell (Drawer)
```
Access via left drawer menu from any route
Current route is highlighted
```

### Delivery Shell (Bottom Nav - 4 Tabs)
```
Tabs:
0 → /delivery/smart-route (map)
1 → /delivery/orders
2 → /delivery/earnings
3 → /delivery/chat
```

### Employee Shell (Bottom Nav - 4 Tabs with Badge)
```
Tabs:
0 → /employee/tasks (badge = pending count)
1 → /employee/receiving
2 → /employee/packing
3 → /employee/attendance
```

### Admin Shell (Sidebar)
```
Access via left drawer from any route
System health indicator in AppBar
```

## Conditional Navigation

### Based on Authentication
```dart
final authProvider = Provider.of<AuthProvider>(context, listen: false);
if (authProvider.isLoggedIn) {
  context.go('/customer/home');
} else {
  context.go('/login');
}
```

### Based on User Role
```dart
final user = authProvider.currentUser;
switch (user.role) {
  case UserRole.customer:
    context.go('/customer/home');
  case UserRole.shopOwner:
    context.go('/owner');
  case UserRole.deliveryAgent:
    context.go('/delivery');
  case UserRole.admin:
    context.go('/admin');
  case UserRole.employee:
    context.go('/employee');
}
```

### Based on Verification Status
```dart
if (user.isVerified) {
  context.go('/customer/orders');
} else {
  context.go('/auth/verify-wall?returnPath=/customer/orders');
}
```

## Error Handling

### Unauthorized Access
```dart
// App will auto-redirect to:
context.go('/unauthorized?reason=No%20permission&returnPath=/customer/orders');
```

### Network Error
```dart
// Manual navigation when offline detected
context.go('/network-error');
```

### Invalid Route
```dart
// GoRouter handles 404 automatically
// Route won't exist = no navigation occurs
```

## Deep Linking

### Setup (Android)
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<activity android:name=".MainActivity" ...>
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
      android:scheme="fufaji"
      android:host="*" />
  </intent-filter>
</activity>
```

### Setup (iOS)
Add to `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>fufaji</string>
    </array>
  </dict>
</array>
```

### Test Deep Links
```bash
# iOS (Simulator)
xcrun simctl openurl booted "fufaji://customer/home"
xcrun simctl openurl booted "fufaji://customer/product/abc123"

# Android (Emulator)
adb shell am start -W -a android.intent.action.VIEW \
  -d "fufaji://customer/home" com.fufaji.online
```

## Routes by Purpose

### Authentication & Onboarding
```
/                      Splash screen
/login                 Login screen
/otp/:contact          OTP verification
/role-select           Role selection
/profile-creation      New user profile
/security-pin          Owner/admin PIN
/auth/verify-wall      Unverified user gate
/account-picker        Multiple accounts
```

### Shopping (Customer)
```
/customer/home                Browse products
/customer/search              Search products
/customer/product/:id         Product detail
/customer/cart                Shopping cart
/customer/checkout            Checkout flow
/customer/order-confirmation  Order receipt
```

### Account (Customer)
```
/customer/profile             Account info
/customer/addresses           Delivery addresses
/customer/wallet              Wallet/prepaid balance
/customer/orders              Order history
/customer/order-detail/:id    Order details
```

### Shop Management (Owner)
```
/owner                        Dashboard
/owner/products               Product list
/owner/products/add           Add product
/owner/orders                 Order list
/owner/inventory              Stock management
/owner/analytics              Sales analytics
```

### Delivery Management (Delivery)
```
/delivery                     Map/routing
/delivery/orders              Active orders
/delivery/detail/:id          Delivery details
/delivery/earnings            Earnings
/delivery/chat                Customer chat
```

### Warehouse (Employee)
```
/employee                     Task dashboard
/employee/receiving           Stock receiving
/employee/packing             Order packing
/employee/delivery            Delivery scanning
/employee/attendance          Time tracking
```

### System Management (Admin)
```
/admin                        Dashboard
/admin/users                  User management
/admin/shops                  Shop management
/admin/orders                 Order management
/admin/analytics              System analytics
```

## Localization in Routes

```dart
// In shell widget
final l10n = AppLocalizations.of(context);

// Use for labels
label: l10n?.translate('home') ?? 'Home'
label: l10n?.translate('orders') ?? 'Orders'
label: l10n?.translate('dashboard') ?? 'Dashboard'
```

## Common Issues & Solutions

### Issue: Shell doesn't appear
**Cause**: Route not within ShellRoute
**Solution**: Ensure route path is in the correct ShellRoute's routes list

### Issue: Bottom nav not updating
**Cause**: Shell's `_calculateSelectedIndex` doesn't match route
**Solution**: Add route pattern to index calculation

### Issue: Can't navigate between roles
**Cause**: Redirect logic routes back to same role
**Solution**: Use `/role-select` to switch roles first

### Issue: Parameters lost on navigation
**Cause**: Using `context.go()` instead of `context.push()`
**Solution**: Use `push()` for params or include in new path

### Issue: Deep link not working
**Cause**: Intent filter not properly configured
**Solution**: Check AndroidManifest.xml and Info.plist setup

### Issue: Back button in AppBar doesn't work
**Cause**: Custom AppBar removes back button
**Solution**: Set `automaticallyImplyLeading: true` or add IconButton manually

## Navigation Best Practices

### 1. Always Use Named Routes for Consistency
```dart
// Good
context.go('/customer/home');

// Avoid
Navigator.of(context).push(MaterialPageRoute(...));
```

### 2. Encode Complex Parameters
```dart
// Good
final encoded = Uri.encodeComponent('search term');
context.push('/customer/search?q=$encoded');

// Avoid
context.push('/customer/search?q=search term');  // Broken
```

### 3. Use Push for Detail Screens
```dart
// Good - allows back navigation
context.push('/customer/product/123');

// Avoid - no back button
context.go('/customer/product/123');
```

### 4. Handle Missing Parameters Safely
```dart
// Good
final id = state.pathParameters['productId'] ?? '';

// Avoid
final id = state.pathParameters['productId']!;  // Crash if null
```

### 5. Validate Route Access in Redirect
```dart
// Good - redirect enforces authorization
redirect: (context, state) {
  if (!authProvider.isLoggedIn && !isPublicRoute) {
    return '/login';
  }
  return null;
}

// Avoid - relying only on UI guards
if (!authProvider.isLoggedIn) {
  return SizedBox();  // Blank screen = bad UX
}
```

## Testing Navigation

### Unit Test
```dart
test('navigate to customer home', () {
  expect('/customer/home', contains('/customer'));
});
```

### Widget Test
```dart
testWidgets('GoRouter navigates', (WidgetTester tester) async {
  final router = AppRouter.router;
  
  router.go('/customer/home');
  await tester.pumpAndSettle();
  
  expect(find.byType(HomeScreen), findsOneWidget);
});
```

### Manual Test Checklist
- [ ] All routes accessible from respective shells
- [ ] Deep links work
- [ ] Back button works correctly
- [ ] Parameters passed correctly
- [ ] Role-based access enforced
- [ ] Authentication guards work
- [ ] Offline mode handled
- [ ] Shell nav updates on route change
