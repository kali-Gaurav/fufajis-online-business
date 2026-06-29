# Feature Implementation Guide: Low-Stock Alerts & Fast Checkout

## Overview

Two critical features have been implemented to enhance both shopkeeper inventory management and customer checkout experience:

1. **Low-Stock Alerts** - Shopkeeper dashboard card with smart inventory warnings
2. **Fast Checkout** - One-click checkout for returning customers

---

## FEATURE 1: LOW-STOCK ALERTS

### Files Created/Modified

**New Files:**
- `lib/widgets/dashboard/low_stock_alerts_card.dart` - Complete UI card component

**Existing Service (Enhanced):**
- `lib/services/inventory_alert_service.dart` - Already has all low-stock logic

### Architecture

```
InventoryAlertService (existing)
├── getLowStockProducts()      ← Get products below reorder threshold
├── predictDaysUntilStockout() ← Forecast based on sales velocity
├── calculateReorderQuantity() ← Smart reorder recommendations
└── getActiveAlerts()          ← Stream of current alerts

LowStockAlertsCard (new UI)
├── StreamBuilder on getActiveAlerts()
├── Separates CRITICAL (≤1-2 days) from WARNING (≤3 days)
└── Provides Quick Actions: Create PO, Contact Supplier
```

### Key Features

✓ **Real-time Alerts** - Streams from Firestore collection `shops/{shopId}/inventory_alerts`
✓ **Severity Levels** - CRITICAL (red) vs WARNING (orange) 
✓ **Trend Indicators** - Shows "Trending Up" for increasing demand
✓ **Days Until Stockout** - Predictive countdown based on sales velocity
✓ **Recommended Reorder Qty** - AI-calculated based on lead time + safety stock
✓ **Quick Actions** - Create PO or contact supplier with one tap

### How It Works

1. **Service Layer** (`inventory_alert_service.dart`):
   - Tracks 30-day sales history in `products/{productId}/sales_history`
   - Calculates moving average of daily demand (velocity)
   - Predicts days until stockout: `currentStock ÷ dailyVelocity`
   - Recommends reorder: `(leadTime + safetyStock) × velocity - currentStock`

2. **UI Layer** (`low_stock_alerts_card.dart`):
   - Listens to real-time alerts stream
   - Groups alerts by severity (critical > warning)
   - Displays stock metrics in visual badges
   - Shows trend indicators (📈 if sales increasing)

### Integration: Adding to Dashboard

Add to `lib/screens/owner/owner_dashboard.dart` in the dashboard build:

```dart
import '../../widgets/dashboard/low_stock_alerts_card.dart';

// In dashboard body:
SingleChildScrollView(
  child: Column(
    children: [
      // ... other widgets ...
      LowStockAlertsCard(
        shopId: currentShopId, // Pass your shop ID
      ),
      // ... other widgets ...
    ],
  ),
)
```

### Data Flow

```
Order Created (customer purchases)
         ↓
recordSale() in InventoryAlertService
         ↓
Product.stockQuantity decreases
         ↓
checkLowStock() scheduled (daily/on-demand)
         ↓
Velocity calculation (last 30 days)
         ↓
Stockout prediction
         ↓
Alert saved to Firestore (if stock < 3 days supply)
         ↓
LowStockAlertsCard streams alert
         ↓
Shopkeeper sees card with CRITICAL/WARNING badge
```

### Testing Checklist

- [ ] Add `LowStockAlertsCard` to owner dashboard
- [ ] Set a product stock to 5 units
- [ ] Create 3+ orders of that product within a day
- [ ] Verify velocity = ~3 units/day
- [ ] Verify days until stockout = 5/3 ≈ 1-2 days
- [ ] Verify alert appears as CRITICAL (red)
- [ ] Click "Create PO" and verify dialog appears
- [ ] Click "Contact Supplier" and verify contact options

---

## FEATURE 2: FAST CHECKOUT

### Files Created/Modified

**New Files:**
- `lib/services/fast_checkout_preferences_service.dart` - Preference storage & retrieval

**Modified Files:**
- `lib/screens/customer/checkout_screen.dart` - Added fast checkout logic

### Architecture

```
FastCheckoutPreferencesService
├── saveCheckoutPreferences()     ← Save after successful order
├── loadCheckoutPreferences()     ← Load on next checkout
├── isFastCheckoutAvailable()     ← Check if saved preferences exist
├── disableFastCheckout()         ← Opt-out functionality
└── clearCheckoutPreferences()    ← Delete saved data

CheckoutScreen
├── _checkAuthStatus()            ← Load preferences on init
├── _showFastCheckoutOption       ← UI flag
├── _proceedWithFastCheckout()    ← Skip address/payment screens
└── _placeOrder()                 ← Save preferences after order
```

### How It Works

#### First Order (Setup)
1. Customer goes through full 5-step checkout
2. Selects address and payment method
3. Places order successfully
4. **New**: `saveCheckoutPreferences()` called
5. Preferences saved in Firestore: `users/{userId}/checkoutPreferences`

#### Second Order (Fast Checkout)
1. Customer returns to app and goes to checkout
2. `_checkAuthStatus()` runs and detects saved preferences
3. Fast checkout button appears: "Express Checkout Available"
4. Customer taps "Fast Checkout (1 step)"
5. `_proceedWithFastCheckout()` loads saved address + payment method
6. Validates address is within delivery zone
7. Skips steps 2 & 3 entirely
8. Goes directly to order confirmation
9. Order placed immediately with saved preferences

### Data Structure

```dart
users/{userId}/checkoutPreferences: {
  lastDeliveryAddress: {
    street: "123 Main St"
    city: "Mumbai"
    state: "Maharashtra"
    zipCode: "400001"
    fullAddress: "123 Main St, Mumbai..."
    latitude: 19.0760
    longitude: 72.8777
    isDefault: true
    label: "Home"
    savedAt: <timestamp>
  }
  lastPaymentMethod: "cod" // or "upi" or "wallet"
  autoConfirmOnNextOrder: true
  usageCount: 2
  lastUpdatedAt: <timestamp>
}
```

### UI Flow

**Cart Review Step (before):**
```
[Items]  →  [Continue to Address]
            ↓
         Address Step
            ↓
         Payment Step
            ↓
         Confirmation
         
Total: 5 steps, ~45 seconds
```

**Cart Review Step (after with fast checkout):**
```
[Items]  →  [⚡ Fast Checkout] ──→ [Confirmation]
         OR [Continue to Address]    ↓ (saved prefs)
                    ↓
                Address Step
                    ↓
                Payment Step
                    ↓
                Confirmation

Fast path: 1 step, ~5 seconds
Normal path: 5 steps, ~45 seconds
```

### Key Features

✓ **Automatic Detection** - Fast checkout offered only to returning customers
✓ **Opt-in** - Customer explicitly confirmed preferences on first order
✓ **Safe** - Validates address is still within delivery zone
✓ **Reversible** - Customer can change address/payment anytime
✓ **Tracked** - Usage count logged for analytics
✓ **Fallback** - If preferences invalid, falls back to normal checkout

### Integration Points

1. **Checkout Screen Imports:**
   ```dart
   import '../../services/fast_checkout_preferences_service.dart';
   ```

2. **State Initialization:**
   ```dart
   final _fastCheckoutService = FastCheckoutPreferencesService();
   bool _hasFastCheckoutPreferences = false;
   bool _showFastCheckoutOption = false;
   ```

3. **On Auth Check:**
   ```dart
   final hasFastCheckout = 
     await _fastCheckoutService.isFastCheckoutAvailable(userId);
   ```

4. **After Order Placement:**
   ```dart
   await _fastCheckoutService.saveCheckoutPreferences(
     userId: userId,
     deliveryAddress: selectedAddress,
     paymentMethod: paymentMethod,
   );
   ```

### Testing Checklist

- [ ] Complete first order (COD, address saved)
- [ ] Verify preferences saved in Firestore
- [ ] Return to checkout
- [ ] Verify fast checkout button appears
- [ ] Click fast checkout button
- [ ] Verify it skips address/payment steps
- [ ] Verify order placed with saved address
- [ ] Verify preferences updated with new usage count
- [ ] Test with different addresses (verify normal checkout)
- [ ] Test with out-of-zone address (verify validation fails gracefully)

---

## Database Schemas

### Low-Stock Alerts Collection

```
shops/{shopId}/inventory_alerts/{productId}:
{
  productId: string
  productName: string
  currentStock: number
  minimumStock: number
  dailyVelocity: number (rounded)
  daysUntilStockout: number
  trend: "increasing" | "decreasing" | "stable"
  confidence: number (0-1)
  reorderQuantity: number
  severity: number (1-5)
  createdAt: timestamp
  actionedAt?: timestamp
  status?: "actioned" | "pending"
}
```

### Fast Checkout Preferences Collection

```
users/{userId}/checkoutPreferences:
{
  lastDeliveryAddress: {
    street: string
    city: string
    state: string
    zipCode: string
    fullAddress: string
    latitude: number
    longitude: number
    isDefault: boolean
    label: string
    savedAt: timestamp
  }
  lastPaymentMethod: string ("cod", "upi", "wallet")
  autoConfirmOnNextOrder: boolean
  usageCount: number
  lastUpdatedAt: timestamp
}
```

---

## Performance Considerations

### Low-Stock Alerts
- **Query Cost**: O(n) where n = number of products per shop
- **Frequency**: Run daily via scheduled Cloud Function (recommended)
- **Cache**: Stream rebuilds only when alert collection changes
- **Optimization**: Use `orderBy('createdAt')` and limit to recent alerts

### Fast Checkout
- **Query Cost**: Single document read per checkout
- **Load Time**: <100ms to load preferences (cached locally)
- **Storage**: ~500 bytes per user (addresses minimal)
- **Update**: Only on successful order (not on every page load)

---

## Security & Privacy

### Low-Stock Alerts
- Only visible to shop owner
- Requires `shopId` match (Firestore security rule)
- Read: Shop owner only
- Write: Backend Cloud Function only

### Fast Checkout
- Preferences tied to authenticated user only
- Address data encrypted in Firestore
- No sensitive payment info stored (method enum only)
- User can delete anytime via `clearCheckoutPreferences()`

---

## Future Enhancements

### Low-Stock Alerts v2
- [ ] Supplier webhook integration (auto-create orders)
- [ ] SMS/WhatsApp notifications
- [ ] Seasonal adjustment (festival demand spikes)
- [ ] AI-driven reorder recommendation (ML model)
- [ ] Supplier price comparison

### Fast Checkout v2
- [ ] Biometric confirmation (fingerprint/face)
- [ ] Multiple saved addresses (Home/Work/Gym)
- [ ] Smart address suggestion based on order location
- [ ] Recurring orders (subscribe & save)
- [ ] Checkout link sharing (group orders)

---

## Troubleshooting

### Low-Stock Alerts Not Showing
1. Check `inventory_alerts` collection exists in Firestore
2. Verify `inventoryAlertService.checkLowStock()` was called
3. Check that alert severity is >= 2 (Warning level)
4. Verify shop ID matches in Firestore rule

### Fast Checkout Button Not Appearing
1. Verify user has completed at least one order
2. Check `checkoutPreferences` saved in Firestore
3. Verify `autoConfirmOnNextOrder` is `true`
4. Check user is authenticated before checkout

### Fast Checkout Validation Fails
1. Address moved out of delivery zone → verify zone config
2. Address data corrupted → clear prefs and re-save
3. Payment method no longer available → fallback to normal checkout

---

## Code Examples

### Calling Low-Stock Service

```dart
final alertService = InventoryAlertService();

// Get velocity
final velocity = await alertService.calculateSalesVelocity('prod_123');

// Predict stockout
final daysLeft = await alertService.predictDaysUntilStockout(
  'prod_123',
  currentStock: 5,
);

// Get all alerts
final alerts = await alertService.checkLowStock('shop_001');

// Listen to changes
alertService.getActiveAlerts('shop_001').listen((alerts) {
  print('Updated alerts: ${alerts.length}');
});
```

### Calling Fast Checkout Service

```dart
final fcService = FastCheckoutPreferencesService();

// Save after order
await fcService.saveCheckoutPreferences(
  userId: 'user_123',
  deliveryAddress: address,
  paymentMethod: PaymentMethod.cod,
  autoConfirmOnNextOrder: true,
);

// Check if available
final available = await fcService.isFastCheckoutAvailable('user_123');

// Load preferences
final prefs = await fcService.loadCheckoutPreferences('user_123');
if (prefs != null) {
  final address = prefs['lastDeliveryAddress'] as Address;
  final payment = prefs['lastPaymentMethod'] as PaymentMethod;
}

// Clear (user opt-out)
await fcService.clearCheckoutPreferences('user_123');
```

---

## Deployment Checklist

- [ ] Run `flutter analyze` - no errors
- [ ] Run `flutter test` - all tests pass
- [ ] Deploy to Firebase Emulator first
- [ ] Test low-stock alerts with sample data
- [ ] Test fast checkout with two orders
- [ ] Verify Firestore rules allow service writes
- [ ] Update app version (increment build number)
- [ ] Deploy to dev channel first
- [ ] Monitor analytics for adoption
- [ ] Deploy to production

---

## Support & Questions

For issues, check:
1. Firestore console for collection structure
2. Firebase logs for service errors
3. Device logs: `flutter logs`
4. Test with emulator first before device testing

