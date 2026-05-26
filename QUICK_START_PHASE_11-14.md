# Quick Start Guide - Phase 11-14 Integration

## 5-Minute Setup

### Step 1: Update App Router (5 minutes)

Edit `lib/app_router.dart` and add these routes inside the owner shell:

```dart
// Add these imports at the top
import 'screens/owner/whatsapp_sync_config_screen.dart';
import 'screens/owner/inventory_alerts_screen.dart';
import 'screens/owner/expiry_tracking_screen.dart';
import 'screens/owner/pricing_rules_screen.dart';
import 'screens/owner/pending_price_changes_screen.dart';

// Add these routes in the owner shell routes list
GoRoute(
  path: 'whatsapp-sync-config',
  builder: (context, state) => const WhatsAppSyncConfigScreen(),
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
```

### Step 2: Update Owner Dashboard (5 minutes)

Edit `lib/screens/owner/owner_dashboard.dart`:

```dart
// Add these imports
import '../../widgets/dashboard/whatsapp_sync_status_widget.dart';
import '../../widgets/dashboard/inventory_health_widget.dart';
import '../../widgets/dashboard/expiry_tracking_widget.dart';
import '../../widgets/dashboard/dynamic_pricing_widget.dart';

// In the dashboard's scrollable column, add these widgets after existing widgets:
const SizedBox(height: 24),
const Text(
  'Advanced Features',
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
),
const SizedBox(height: 16),
const WhatsAppSyncStatusWidget(),
const SizedBox(height: 16),
const InventoryHealthWidget(),
const SizedBox(height: 16),
const ExpiryTrackingWidget(),
const SizedBox(height: 16),
const DynamicPricingWidget(),
```

### Step 3: Test the Integration (5 minutes)

```bash
# Run the app
flutter run

# Navigate to owner dashboard
# You should see 4 new dashboard widgets
# Click on each widget to navigate to the respective screens
```

---

## File Locations

### Screens (5 files)
```
lib/screens/owner/
├── whatsapp_sync_config_screen.dart
├── inventory_alerts_screen.dart
├── expiry_tracking_screen.dart
├── pricing_rules_screen.dart
└── pending_price_changes_screen.dart
```

### Widgets (4 files)
```
lib/widgets/dashboard/
├── whatsapp_sync_status_widget.dart
├── inventory_health_widget.dart
├── expiry_tracking_widget.dart
└── dynamic_pricing_widget.dart
```

### Provider Extensions (1 file)
```
lib/providers/
└── product_provider_extensions.dart
```

---

## Feature Overview

### Phase 11: WhatsApp Sync
**Screen:** `WhatsAppSyncConfigScreen`
- Configure WhatsApp Business number
- View sync status and history
- Test sync functionality
- See recently synced items

**Widget:** `WhatsAppSyncStatusWidget`
- Shows sync status (Active/Inactive)
- Displays items synced count
- Quick access to configuration

### Phase 12: Inventory Alerts
**Screen:** `InventoryAlertsScreen`
- View low-stock alerts
- Filter by severity (Critical/High/Medium/Low)
- Search products
- Dismiss alerts
- Reorder products

**Widget:** `InventoryHealthWidget`
- Shows health score (0-100)
- Displays healthy products ratio
- Quick navigation to alerts

### Phase 13: Expiry Tracking
**Screen:** `ExpiryTrackingScreen`
- View expiring products
- Filter by expiry range
- See dynamic markdown prices
- Mark products as sold
- Extend expiry dates

**Widget:** `ExpiryTrackingWidget`
- Shows expiring items count
- Displays potential loss
- Quick navigation to details

### Phase 14: Dynamic Pricing
**Screen:** `PricingRulesScreen`
- Configure pricing strategy (Beat/Match/Premium/Cost+)
- Set strategy parameters
- Preview price impact

**Screen:** `PendingPriceChangesScreen`
- Review pending price changes
- Approve/reject changes
- View change history

**Widget:** `DynamicPricingWidget`
- Shows current strategy
- Displays pending changes count
- Shows revenue impact

---

## Testing Checklist

- [ ] App compiles without errors
- [ ] Routes navigate correctly
- [ ] Dashboard widgets display
- [ ] Screens load without errors
- [ ] Search functionality works
- [ ] Filters work correctly
- [ ] Buttons navigate properly
- [ ] No console errors

---

## Common Issues & Solutions

### Issue: "Widget not found" error
**Solution:** Ensure all imports are correct and files are in the right directories

### Issue: Routes not working
**Solution:** Check that routes are added to the correct shell (owner shell)

### Issue: Widgets not displaying
**Solution:** Verify imports in owner_dashboard.dart and check for layout issues

### Issue: Data not loading
**Solution:** Check that ProductProvider methods are implemented and Firestore is connected

---

## Next Steps

1. **Test the UI** - Navigate through all screens and verify functionality
2. **Deploy Firebase Functions** - Follow PHASE_11-14_IMPLEMENTATION_GUIDE.md
3. **Connect Real Data** - Update provider methods to use actual Firestore data
4. **Add Tests** - Create unit and integration tests
5. **Optimize Performance** - Profile and optimize as needed

---

## Firebase Functions Deployment

Once UI is working, deploy Firebase Functions:

```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Deploy functions
firebase deploy --only functions

# Verify deployment
firebase functions:list
```

---

## Useful Commands

```bash
# Run app in debug mode
flutter run

# Run app in release mode
flutter run --release

# Run tests
flutter test

# Build APK
flutter build apk

# Build iOS
flutter build ios

# Check for issues
flutter analyze

# Format code
dart format lib/
```

---

## Documentation References

- **Full Implementation Guide:** `PHASE_11-14_IMPLEMENTATION_GUIDE.md`
- **Complete Roadmap:** `PHASES_11-20_IMPLEMENTATION_PLAN.md`
- **Implementation Summary:** `IMPLEMENTATION_SUMMARY.md`

---

## Support

For detailed information:
1. Check the implementation guide
2. Review code comments
3. Refer to Firebase documentation
4. Check Flutter documentation

---

## Success Indicators

✅ All 5 screens created and functional
✅ All 4 dashboard widgets integrated
✅ App compiles without errors
✅ Navigation works correctly
✅ Widgets display properly
✅ No console errors

---

**Ready to integrate? Start with Step 1 above!**

