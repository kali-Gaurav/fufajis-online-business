# Test Scenarios: Low-Stock Alerts & Fast Checkout

## Test Environment Setup

**Prerequisites:**
- Flutter emulator or Android device
- Firestore emulator running (or test project)
- Test shop with ID: `shop_test_001`
- Test user with ID: `user_test_001`

---

## FEATURE 1: LOW-STOCK ALERTS

### Scenario 1.1: Critical Alert - Stock Running Out

**Setup:**
- Product: "Rice (10kg)" - ID: `prod_rice_10kg`
- Current stock: 5 units
- Daily sales velocity: 3 units/day
- Expected days until stockout: 5/3 = 1-2 days

**Steps:**
1. Add product to inventory with 5 units
2. Place 3 orders in quick succession (simulates 3 sales same day)
3. Open owner dashboard
4. Find Low-Stock Alerts card

**Expected Result:**
- Card appears with RED "CRITICAL" badge
- Shows: "5 in stock" | "1d until stockout" | "+10 recommend"
- "Create PO" and "Contact Supplier" buttons active

**Validation:**
```
Stock: 5 ✓
Velocity: ~3/day ✓
Days until: 1-2 ✓
Severity: CRITICAL ✓
Alert visible: Yes ✓
```

---

### Scenario 1.2: Warning Alert - Low Stock

**Setup:**
- Product: "Oil (500ml)" - ID: `prod_oil_500ml`
- Current stock: 20 units
- Daily sales velocity: 5 units/day
- Expected days until stockout: 20/5 = 4 days

**Steps:**
1. Add product with 20 units
2. Place 10 orders over 2 days
3. Open owner dashboard

**Expected Result:**
- Card shows ORANGE "WARNING" badge
- Days until stockout: 4d
- Grouped under "WARNING" section (not critical)

**Validation:**
```
Stock: 20 ✓
Velocity: ~5/day ✓
Days until: 4 ✓
Severity: WARNING ✓
Position: Below CRITICAL alerts ✓
```

---

### Scenario 1.3: Healthy Stock - No Alert

**Setup:**
- Product: "Sugar (1kg)" - ID: `prod_sugar_1kg`
- Current stock: 100 units
- Daily sales velocity: 2 units/day
- Expected days until stockout: 50 days

**Steps:**
1. Add product with 100 units
2. Place 1 order only
3. Open owner dashboard

**Expected Result:**
- Low-Stock Alerts card shows "Inventory Healthy" (green)
- No critical/warning items listed
- Message: "All items are sufficiently stocked"

**Validation:**
```
Stock: 100 ✓
Velocity: <1/day ✓
Days until: >7 ✓
Alert shown: "Healthy" ✓
No warnings: ✓
```

---

### Scenario 1.4: Trend Analysis - Increasing Demand

**Setup:**
- Product: "Coffee (250g)" - trending up
- Days 1-15: 2 units/day sold
- Days 16-30: 5 units/day sold (150% increase)

**Steps:**
1. Create product with history (use manual Firestore entry)
2. Set sales data: 30 units in first 15 days, 75 in next 15 days
3. Open dashboard

**Expected Result:**
- Alert shows "📈 Trending Up" badge
- Trend detection in alert item
- Recommended reorder increased due to trend

**Validation:**
```
First velocity: 2/day ✓
Second velocity: 5/day ✓
Trend: increasing ✓
Badge shown: "Trending Up" ✓
Reorder adjusted: Yes ✓
```

---

### Scenario 1.5: Quick Action - Create PO

**Setup:**
- Cart with 3 critical items needing restock
- Each with recommended qty: +10, +15, +20

**Steps:**
1. From Low-Stock Alerts card
2. Click "Create PO" button
3. Dialog appears with 3 items and quantities
4. Review recommendations
5. Click "Create PO" to confirm

**Expected Result:**
- Dialog shows all 3 products with reorder quantities
- Each item shows: Product name + "X units"
- Dialog has Cancel and Create PO buttons
- After confirm: Success snackbar appears

**Validation:**
```
Dialog appears: ✓
Items listed: 3 ✓
Quantities correct: ✓
Buttons work: ✓
Confirmation shown: ✓
```

---

### Scenario 1.6: Real-time Updates

**Setup:**
- Product in "WARNING" status (10 units, 2/day)
- Days until stockout: 5 days

**Steps:**
1. Display Low-Stock Alerts card
2. In another tab/device: Sell 8 units
3. Observe card in real-time

**Expected Result:**
- Within 2 seconds: Stock updates to 2 units
- Days until stockout: now "1d" (critical)
- Card badge changes RED (was orange)
- Alert moves to CRITICAL section

**Validation:**
```
Real-time update: <2s ✓
Stock changed: 10→2 ✓
Status upgraded: WARNING→CRITICAL ✓
Badge color changed: ✓
```

---

## FEATURE 2: FAST CHECKOUT

### Scenario 2.1: First Order - Preference Setup

**Setup:**
- Customer: `user_test_001` (new, no orders)
- Product: "Apples (1kg)"

**Steps:**
1. App starts, user not logged in
2. Add product to cart → Checkout
3. Phone verification (OTP)
4. Cart review (No fast checkout button)
5. Address selection: "123 Market St, Mumbai"
6. Payment: COD selected
7. Place order → Success

**Expected Result:**
- Order placed successfully
- Confirmation screen appears
- In background: Preferences saved to Firestore

**Firestore Check:**
```
users/user_test_001/checkoutPreferences: {
  lastDeliveryAddress: {
    street: "123 Market St"
    city: "Mumbai"
    ...
  }
  lastPaymentMethod: "cod"
  autoConfirmOnNextOrder: true
  usageCount: 1
  lastUpdatedAt: <current timestamp>
}
```

**Validation:**
```
Order placed: ✓
Preferences saved: ✓
Address saved: ✓
Payment method saved: ✓
Usage count: 1 ✓
```

---

### Scenario 2.2: Second Order - Fast Checkout Available

**Setup:**
- Same customer, already placed order
- Preferences exist and valid
- New product in cart

**Steps:**
1. Customer logs in again
2. Add product to cart
3. Go to checkout → Cart Review screen
4. Observe cart step

**Expected Result:**
- "Express Checkout Available" section appears
- Shows: "Skip address & payment selection..."
- Button: "⚡ Fast Checkout (1 step)"
- Below it: "OR" divider
- Below that: "Continue to Address" button

**Validation:**
```
Fast checkout section visible: ✓
Icon (lightning): ✓
Button text correct: ✓
OR divider shown: ✓
Normal path still available: ✓
```

---

### Scenario 2.3: Fast Checkout Flow

**Setup:**
- Cart review step with fast checkout available
- Previous order: Address "123 Market St", COD

**Steps:**
1. Click "⚡ Fast Checkout (1 step)" button
2. Observe screen

**Expected Result:**
- Loads saved address: "123 Market St, Mumbai"
- Loads payment method: COD
- Validates address is in delivery zone
- Skips address/payment steps entirely
- Goes directly to order confirmation screen
- Button shows: "Place Order" (not multi-step)
- Order placed with saved data

**Validation:**
```
Button clickable: ✓
Prefs loaded: <100ms ✓
Address validated: ✓
Zone check passed: ✓
Payment method used: ✓
Order placed: ✓
Preferences updated: usageCount=2 ✓
```

---

### Scenario 2.4: Fast Checkout - Address Out of Zone

**Setup:**
- Saved address: "123 Market St, Mumbai" (in zone)
- Delivery zone: 10km radius from shop
- Customer moved to: "456 Outer Road, Suburbs" (out of zone)

**Steps:**
1. In cart review, click "Fast Checkout"
2. System loads "123 Market St"
3. System validates zone

**Expected Result:**
- Zone validation fails
- Snackbar appears: "Address is outside delivery zone"
- User stays on cart screen
- "Continue to Address" button available (fallback)
- User can select new address

**Validation:**
```
Zone check triggered: ✓
Validation failed: ✓
Error message shown: ✓
User not forced through: ✓
Fallback available: ✓
```

---

### Scenario 2.5: Fast Checkout with Different Payment

**Setup:**
- Saved payment: COD
- Customer has wallet balance: Rs. 500
- Order total: Rs. 300

**Steps:**
1. Place first order with Wallet payment
2. Return to checkout
3. Fast checkout available

**Expected Result:**
- Fast checkout loads: COD (saved from earlier)
- OR customer clicks "Continue to Address"
- Changes address, then payment to Wallet
- Places order with Wallet
- Preferences updated: lastPaymentMethod = "wallet"

**Next fast checkout:**
- Loads "wallet" as saved payment
- Can override or accept

**Validation:**
```
First order payment: COD ✓
Second order payment: Wallet ✓
Prefs updated: lastPaymentMethod = wallet ✓
Third order uses Wallet: ✓
```

---

### Scenario 2.6: Disable Fast Checkout

**Setup:**
- Customer has 3 orders with fast checkout enabled
- Want to disable fast checkout (privacy preference)

**Implementation Note:**
- Add UI button in settings: "Clear Saved Checkout"
- Calls: `fastCheckoutService.clearCheckoutPreferences(userId)`

**Steps:**
1. Customer goes to Settings
2. Finds "Checkout Preferences"
3. Clicks "Clear Saved Address & Payment"
4. Confirmation: "Are you sure?"
5. Confirms

**Expected Result:**
- Preferences deleted from Firestore
- Next checkout: No fast checkout option
- Full 5-step flow required
- Can re-enable by completing order with new settings

**Validation:**
```
Settings option available: ✓
Confirmation dialog shown: ✓
Prefs deleted: ✓
Next checkout: No fast option ✓
User can re-enable: ✓
```

---

### Scenario 2.7: Multiple Addresses (Future Feature)

**Setup:**
- Note: Current implementation saves only 1 address
- Future: Support Home, Work, Gym addresses

**Steps:**
1. Complete order to "Home" → saved
2. Complete order to "Work" → updates saved
3. Checkout: Should show 2 options or let user choose

**Expected (v2):**
- Fast checkout shows "Last used: Home" or "Work"
- Option to select from saved list
- Each has separate fast checkout flow

**Validation:**
```
Multiple addresses supportable: ✓
Data structure scalable: ✓
UI can be extended: ✓
```

---

## Performance & Load Testing

### Test P1: Analytics & Metrics

**Measure:**
- Fast checkout adoption rate
- Average time saved per order
- Payment method distribution

**Expected Results (2 weeks):**
- Adoption: 30-40% of repeat customers
- Time saved: 40 seconds/order
- Payment split: 60% COD, 30% UPI, 10% Wallet

---

### Test P2: Database Load

**Setup:**
- 1000 active users
- 100 daily transactions
- Low-stock alert check every 6 hours

**Expected:**
- Firestore read: <1000/day for preferences
- Firestore write: <100/day for preferences
- Alert reads: <200/day (streaming)
- Cost: ~$0.10/day for these features

---

## Edge Cases & Error Handling

### Edge Case 1: Corrupted Preferences
```dart
// Scenario: Address data has missing fields
{
  lastDeliveryAddress: {
    street: "123 Main" 
    // Missing: city, zipCode, etc.
  }
}

// Expected: 
// - Validation fails
// - Fallback to normal checkout
// - Log error for debugging
```

### Edge Case 2: Rapid Orders
```dart
// Scenario: Customer places 2 orders within 5 seconds
// Step 1: Order 1 saves address A + COD
// Step 2: Order 2 saves address B + Wallet
// Step 3: Customer returns to checkout

// Expected:
// - Fast checkout loads address B + Wallet (latest)
// - Usage count incremented correctly
// - No race condition issues
```

### Edge Case 3: Network Timeout
```dart
// Scenario: Firestore unavailable when loading prefs
// Expected:
// - loadCheckoutPreferences() returns null
// - Fast checkout button hidden
// - Normal checkout flow available
// - No app crash
```

---

## Monitoring & Debugging

### Logging Points

**Low-Stock Alerts:**
```dart
print('✓ Checkout preferences saved for user $userId');
print('✗ Error saving checkout preferences: $e');
print('✓ Alert updated: ${alert.productName}');
```

**Fast Checkout:**
```dart
print('✓ Fast checkout triggered for user $userId');
print('✗ Preferences loading failed: $e');
print('✓ Address validated: within zone');
print('✗ Zone validation failed: address outside');
```

### Firebase Console Checks

1. **Collection Structure:**
   - Navigate to `shops/shop_test_001/inventory_alerts`
   - Verify documents exist after order
   - Check `daysUntilStockout` values

2. **Preferences Storage:**
   - Navigate to `users/user_test_001/checkoutPreferences`
   - Verify address saved completely
   - Confirm `usageCount` increments

---

## Rollback Plan

If issues found:

1. **Low-Stock Alerts:** Remove from dashboard, revert to inventory_alert_service only
2. **Fast Checkout:** Remove button from cart screen, delete service file
3. **Data:** No data migration needed (both optional features)

---

## Sign-Off Checklist

- [ ] All 7 scenarios pass on emulator
- [ ] Performance acceptable (< 2s load time)
- [ ] No crashes during edge cases
- [ ] Firestore rules updated (if needed)
- [ ] Analytics events firing
- [ ] Ready for dev deployment

