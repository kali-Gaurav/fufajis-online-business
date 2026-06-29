# POS Blockers - Quick Start Guide

## Files Modified
1. `lib/screens/owner/cash_register_screen.dart` - PIN loading + validation
2. `lib/screens/customer/barcode_scanner_screen.dart` - Barcode validation
3. `lib/utils/payment_service.dart` - Enhanced Razorpay handler
4. No changes needed in `lib/providers/pos_provider.dart` (order building works correctly)

## Firestore Setup (MUST DO BEFORE TESTING)

```
Collection: config
Document ID: pos_settings

{
  "manager_pin": "1234"
}
```

Steps:
1. Open Firebase Console → Firestore
2. Click "Create Collection" → Name: `config`
3. Click "Add Document" → Document ID: `pos_settings`
4. Add field:
   - Field: `manager_pin` (type: String)
   - Value: `1234` (change this to secure value in production!)
5. Save

## What Was Fixed

### 1. Manager PIN (BLOCKER 1)
- PIN now loaded from Firestore `config/pos_settings`
- Falls back to device storage when offline
- Validation in discount dialog uses loaded PIN (not hardcoded '1234')

### 2. Barcode Validation (BLOCKER 4)
- Validates barcode length: 8, 12, 13, or 14 digits
- Validates barcode is numeric only
- Works for both scanned and manually entered barcodes
- Shows error message and re-enables scanning on invalid barcode

### 3. Razorpay Handler (BLOCKER 3)
- Added input validation (amount > 0, valid phone)
- Added currency field
- Added fallback for missing email/name
- Better error handling

### 4. Order Building (BLOCKER 2)
- ✅ No changes needed - already working correctly
- Orders built properly in `PosProvider.checkout()`

## Testing Order

1. **Setup Firestore PIN**
   - Create config/pos_settings document
   - Set manager_pin to "1234"

2. **Test PIN Validation**
   - Open Cash Register screen
   - Add items to cart
   - Click discount button
   - Try discount > 15% of subtotal
   - Enter wrong PIN → Should reject
   - Enter correct PIN (1234) → Should accept

3. **Test Barcode Scanning**
   - Click barcode scanner icon
   - Try scanning/entering 12-digit barcode → Should accept
   - Try entering 10-digit barcode → Should reject
   - Try entering non-numeric barcode → Should reject
   - Try entering with spaces → Should trim and validate

4. **Test Payment**
   - Add items, go to checkout
   - Click "Online" payment
   - Razorpay dialog should open with correct amount
   - Complete payment flow

5. **Test Offline Mode**
   - Go offline (airplane mode)
   - Try discount with PIN → Should use device storage
   - Create order → Should save to device storage
   - Go online → Orders should sync

## Quick Verification

After deployment, check:
- [ ] PIN loads on app startup
- [ ] Discount rejects incorrect PIN
- [ ] Barcode validates length/format
- [ ] Razorpay payment opens correctly
- [ ] Offline mode still works

## Production Checklist

- [ ] Change manager_pin from "1234" to secure value
- [ ] Update Firestore security rules (see FIRESTORE_CONFIG_SETUP.md)
- [ ] Test with real Razorpay account
- [ ] Test with real customer data
- [ ] Monitor error logs for PIN/barcode issues

## Support

If you encounter issues:
1. Check Firestore config/pos_settings exists
2. Check app logs for PIN loading errors
3. Verify barcode format (must be 8/12/13/14 digits)
4. Check internet connection for PIN loading

