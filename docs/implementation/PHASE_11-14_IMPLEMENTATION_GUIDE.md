# Phase 11-14 UI Integration Implementation Guide

## Overview

This guide provides step-by-step instructions for integrating the Phase 11-14 features (WhatsApp Sync, Inventory Alerts, Expiry Tracking, and Dynamic Pricing) into the Fufaji Online Business app.

## Files Created

### UI Screens
1. **WhatsAppSyncConfigScreen** (`lib/screens/owner/whatsapp_sync_config_screen.dart`)
   - Configuration interface for WhatsApp sync
   - Status display and test functionality
   - Recent synced items list

2. **InventoryAlertsScreen** (`lib/screens/owner/inventory_alerts_screen.dart`)
   - Low-stock alert management
   - Severity filtering and search
   - Reorder recommendations

3. **ExpiryTrackingScreen** (`lib/screens/owner/expiry_tracking_screen.dart`)
   - Expiry date management
   - Dynamic markdown pricing display
   - Mark as sold functionality

4. **PricingRulesScreen** (`lib/screens/owner/pricing_rules_screen.dart`)
   - Pricing strategy configuration
   - Parameter adjustment
   - Price impact preview

5. **PendingPriceChangesScreen** (`lib/screens/owner/pending_price_changes_screen.dart`)
   - Pending price change review
   - Approval/rejection workflow
   - Change history

### Dashboard Widgets
1. **WhatsAppSyncStatusWidget** (`lib/widgets/dashboard/whatsapp_sync_status_widget.dart`)
   - Sync status indicator
   - Items synced count
   - Quick configuration button

2. **InventoryHealthWidget** (`lib/widgets/dashboard/inventory_health_widget.dart`)
   - Health score display (0-100)
   - Healthy products ratio
   - Status indicator

3. **ExpiryTrackingWidget** (`lib/widgets/dashboard/expiry_tracking_widget.dart`)
   - Expiring items count
   - Potential loss calculation
   - Quick navigation

4. **DynamicPricingWidget** (`lib/widgets/dashboard/dynamic_pricing_widget.dart`)
   - Current strategy display
   - Pending changes count
   - Revenue impact

### Provider Extensions
**ProductProviderExtensions** (`lib/providers/product_provider_extensions.dart`)
- WhatsApp sync methods
- Inventory alert methods
- Expiry tracking methods
- Dynamic pricing methods

## Integration Steps

### Step 1: Update App Router

Add routes to `lib/app_router.dart`:

```dart
// Phase 11-14 Routes
GoRoute(
  path: '/whatsapp-sync-config',
  builder: (context, state) => const WhatsAppSyncConfigScreen(),
),
GoRoute(
  path: '/inventory-alerts',
  builder: (context, state) => const InventoryAlertsScreen(),
),
GoRoute(
  path: '/expiry-tracking',
  builder: (context, state) => const ExpiryTrackingScreen(),
),
GoRoute(
  path: '/pricing-rules',
  builder: (context, state) => const PricingRulesScreen(),
),
GoRoute(
  path: '/pending-price-changes',
  builder: (context, state) => const PendingPriceChangesScreen(),
),
```

### Step 2: Update Owner Dashboard

Add widgets to `lib/screens/owner/owner_dashboard.dart`:

```dart
import '../../widgets/dashboard/whatsapp_sync_status_widget.dart';
import '../../widgets/dashboard/inventory_health_widget.dart';
import '../../widgets/dashboard/expiry_tracking_widget.dart';
import '../../widgets/dashboard/dynamic_pricing_widget.dart';

// In the dashboard build method, add to the scrollable column:
const SizedBox(height: 16),
const WhatsAppSyncStatusWidget(),
const SizedBox(height: 16),
const InventoryHealthWidget(),
const SizedBox(height: 16),
const ExpiryTrackingWidget(),
const SizedBox(height: 16),
const DynamicPricingWidget(),
```

### Step 3: Update ProductProvider

Add the extension import to `lib/providers/product_provider.dart`:

```dart
import 'product_provider_extensions.dart';
```

### Step 4: Firebase Functions Setup

Create Firebase Cloud Functions for automation:

#### `functions/src/whatsapp-webhook.ts`
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const VERIFY_TOKEN = 'fufaji_whatsapp_verify';

export const whatsappWebhook = functions.https.onRequest(async (req, res) => {
  // Webhook verification
  if (req.method === 'GET') {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode === 'subscribe' && token === VERIFY_TOKEN) {
      res.status(200).send(challenge);
      return;
    }
    res.sendStatus(403);
    return;
  }

  // Handle incoming messages
  if (req.method === 'POST') {
    const body = req.body;
    
    if (body.object === 'whatsapp_business_account') {
      const entry = body.entry[0];
      const changes = entry.changes[0];
      const value = changes.value;
      
      const messages = value.messages;
      if (messages) {
        for (const message of messages) {
          await processMessage(message, value.contacts[0]);
        }
      }
      
      res.sendStatus(200);
      return;
    }
    res.sendStatus(404);
  }
});

async function processMessage(message: any, contact: any) {
  const from = message.from;
  const type = message.type;
  
  try {
    switch (type) {
      case 'text':
        await handleTextMessage(from, message.text.body);
        break;
      case 'image':
        await handleImageMessage(from, message.image);
        break;
      case 'document':
        await handleDocumentMessage(from, message.document);
        break;
    }
  } catch (error) {
    console.error('Error processing message:', error);
  }
}

async function handleTextMessage(from: string, text: string) {
  // Parse items from text using Gemini API
  // Add to Firestore
  // Send confirmation
}

async function handleImageMessage(from: string, image: any) {
  // Download image
  // Process with OCR/Gemini Vision
  // Extract items
  // Add to Firestore
  // Send confirmation
}

async function handleDocumentMessage(from: string, document: any) {
  // Similar to image processing
}
```

#### `functions/src/inventory-check.ts`
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const inventoryCheck = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const db = admin.firestore();
    
    // Get all shops
    const shopsSnapshot = await db.collection('shops').get();
    
    for (const shopDoc of shopsSnapshot.docs) {
      const shopId = shopDoc.id;
      
      // Get all products for shop
      const productsSnapshot = await db
        .collection('shops')
        .doc(shopId)
        .collection('products')
        .get();
      
      for (const productDoc of productsSnapshot.docs) {
        const product = productDoc.data();
        
        // Calculate sales velocity
        const velocity = await calculateSalesVelocity(productDoc.id);
        
        // Predict stockout
        const daysUntilStockout = Math.floor(
          product.stockQuantity / velocity
        );
        
        // Generate alert if needed
        if (daysUntilStockout <= 7) {
          await createAlert(shopId, productDoc.id, daysUntilStockout);
        }
      }
    }
  });

async function calculateSalesVelocity(productId: string): Promise<number> {
  const db = admin.firestore();
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  const salesSnapshot = await db
    .collection('products')
    .doc(productId)
    .collection('sales_history')
    .where('createdAt', '>=', thirtyDaysAgo)
    .get();
  
  let totalUnits = 0;
  for (const doc of salesSnapshot.docs) {
    totalUnits += doc.data().quantity || 0;
  }
  
  return totalUnits / 30; // Average daily sales
}

async function createAlert(
  shopId: string,
  productId: string,
  daysUntilStockout: number
): Promise<void> {
  const db = admin.firestore();
  
  // Determine severity
  let severity = 'Low';
  if (daysUntilStockout <= 1) severity = 'Critical';
  else if (daysUntilStockout <= 3) severity = 'High';
  else if (daysUntilStockout <= 7) severity = 'Medium';
  
  // Create alert
  await db
    .collection('shops')
    .doc(shopId)
    .collection('inventory_alerts')
    .add({
      productId,
      severity,
      daysUntilStockout,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      dismissed: false,
    });
}
```

#### `functions/src/expiry-check.ts`
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const expiryCheck = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const db = admin.firestore();
    
    // Get all products with expiry dates
    const productsSnapshot = await db
      .collection('products')
      .where('expiryDate', '!=', null)
      .get();
    
    const now = new Date();
    
    for (const productDoc of productsSnapshot.docs) {
      const product = productDoc.data();
      const expiryDate = product.expiryDate.toDate();
      
      // Calculate days until expiry
      const daysUntilExpiry = Math.floor(
        (expiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
      );
      
      // Apply dynamic markdown
      let markdownPercentage = 0;
      if (daysUntilExpiry <= 0) markdownPercentage = 100;
      else if (daysUntilExpiry === 1) markdownPercentage = 50;
      else if (daysUntilExpiry <= 3) markdownPercentage = 30;
      else if (daysUntilExpiry <= 7) markdownPercentage = 15;
      
      // Update product with markdown price
      const markdownPrice = product.price * (1 - markdownPercentage / 100);
      
      await db.collection('products').doc(productDoc.id).update({
        markdownPercentage,
        markdownPrice,
        daysUntilExpiry,
      });
      
      // Archive if expired
      if (daysUntilExpiry < 0) {
        await db.collection('products').doc(productDoc.id).update({
          isExpired: true,
          isAvailable: false,
        });
      }
    }
  });
```

#### `functions/src/pricing-update.ts`
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const pricingUpdate = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async (context) => {
    const db = admin.firestore();
    
    // Get all shops with pricing rules
    const shopsSnapshot = await db.collection('shops').get();
    
    for (const shopDoc of shopsSnapshot.docs) {
      const shopId = shopDoc.id;
      
      // Get pricing rules
      const rulesDoc = await db
        .collection('shops')
        .doc(shopId)
        .collection('settings')
        .doc('pricing_rules')
        .get();
      
      if (!rulesDoc.exists) continue;
      
      const rules = rulesDoc.data();
      
      // Get all products
      const productsSnapshot = await db
        .collection('shops')
        .doc(shopId)
        .collection('products')
        .get();
      
      for (const productDoc of productsSnapshot.docs) {
        const product = productDoc.data();
        
        // Calculate new price based on strategy
        const newPrice = calculatePrice(product, rules);
        
        if (newPrice !== product.price) {
          // Create pending price change
          await db
            .collection('shops')
            .doc(shopId)
            .collection('price_changes')
            .add({
              productId: productDoc.id,
              oldPrice: product.price,
              newPrice,
              reason: `${rules.strategy} strategy applied`,
              status: 'pending',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
      }
    }
  });

function calculatePrice(product: any, rules: any): number {
  const strategy = rules.strategy || 'Match';
  const margin = rules.margin || 10;
  
  switch (strategy) {
    case 'Beat':
      return product.competitorPrice - (rules.beatAmount || 5);
    case 'Premium':
      return product.competitorPrice * (1 + (rules.premiumPercentage || 10) / 100);
    case 'Cost+':
      return product.costPrice * (1 + (rules.costPercentage || 20) / 100);
    default: // Match
      return product.competitorPrice;
  }
}
```

### Step 5: Update Firestore Security Rules

Add rules for Phase 11-14 collections:

```firestore
// WhatsApp Sync Settings
match /shops/{shopId}/settings/whatsapp_sync {
  allow read, write: if request.auth.uid == resource.data.ownerId;
}

// Inventory Alerts
match /shops/{shopId}/inventory_alerts/{alertId} {
  allow read, write: if request.auth.uid == resource.data.ownerId;
}

// Price Changes
match /shops/{shopId}/price_changes/{changeId} {
  allow read, write: if request.auth.uid == resource.data.ownerId;
}

// Pricing Rules
match /shops/{shopId}/settings/pricing_rules {
  allow read, write: if request.auth.uid == resource.data.ownerId;
}
```

### Step 6: Update pubspec.yaml

Ensure all dependencies are present:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cloud_firestore: ^4.13.0
  firebase_storage: ^11.2.0
  provider: ^6.0.0
  intl: ^0.19.0
  # ... other dependencies
```

### Step 7: Testing

#### Unit Tests
Create test files for each feature:

```dart
// test/phase_11_whatsapp_sync_test.dart
void main() {
  group('WhatsApp Sync', () {
    test('Should parse text message correctly', () {
      // Test implementation
    });
    
    test('Should process image message', () {
      // Test implementation
    });
  });
}

// test/phase_12_inventory_alerts_test.dart
void main() {
  group('Inventory Alerts', () {
    test('Should calculate sales velocity', () {
      // Test implementation
    });
    
    test('Should predict stockout correctly', () {
      // Test implementation
    });
  });
}

// test/phase_13_expiry_tracking_test.dart
void main() {
  group('Expiry Tracking', () {
    test('Should calculate markdown percentage', () {
      // Test implementation
    });
    
    test('Should archive expired products', () {
      // Test implementation
    });
  });
}

// test/phase_14_dynamic_pricing_test.dart
void main() {
  group('Dynamic Pricing', () {
    test('Should apply Beat strategy', () {
      // Test implementation
    });
    
    test('Should apply Premium strategy', () {
      // Test implementation
    });
  });
}
```

#### Integration Tests
Test the complete flow:

```dart
// test/phase_11_14_integration_test.dart
void main() {
  group('Phase 11-14 Integration', () {
    testWidgets('WhatsApp Sync Config Screen loads', (WidgetTester tester) async {
      // Test implementation
    });
    
    testWidgets('Inventory Alerts Screen displays alerts', (WidgetTester tester) async {
      // Test implementation
    });
    
    testWidgets('Expiry Tracking Screen shows expiring products', (WidgetTester tester) async {
      // Test implementation
    });
    
    testWidgets('Pricing Rules Screen updates strategy', (WidgetTester tester) async {
      // Test implementation
    });
  });
}
```

## Deployment Checklist

- [ ] All screens created and tested
- [ ] Dashboard widgets integrated
- [ ] Provider methods implemented
- [ ] Firebase Functions deployed
- [ ] Firestore security rules updated
- [ ] Routes added to app router
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Manual testing completed
- [ ] Performance optimized
- [ ] Error handling implemented
- [ ] Logging added for debugging

## Next Steps

1. **Phase 15: Wallet & Rewards**
   - Create WalletHistoryScreen
   - Implement cashback calculation
   - Add reward points system

2. **Phase 16: Notifications**
   - Implement NotificationCenter UI
   - Set up FCM subscriptions
   - Create notification settings

3. **Phase 17: Admin Panel**
   - Build admin dashboard
   - Implement user management
   - Create product moderation

4. **Phase 18: Offline Support**
   - Complete offline manager
   - Implement offline cart operations
   - Add network monitoring

5. **Phase 19: Accessibility & Localization**
   - Add Hindi translations
   - Implement screen reader support
   - Ensure WCAG compliance

6. **Phase 20: Analytics & Crash Reporting**
   - Implement analytics service
   - Set up crash reporting
   - Add performance monitoring

## Support & Troubleshooting

### Common Issues

1. **WhatsApp Webhook not receiving messages**
   - Verify webhook URL is publicly accessible
   - Check verify token matches
   - Ensure CORS is configured

2. **Inventory alerts not generating**
   - Check Firebase Functions are deployed
   - Verify Firestore collections exist
   - Check sales history is being recorded

3. **Expiry tracking not updating**
   - Ensure scheduled function is running
   - Check product expiryDate field format
   - Verify Firestore rules allow updates

4. **Pricing changes not applying**
   - Check pricing rules are saved
   - Verify competitor price data exists
   - Ensure price change approval workflow

## References

- [Firebase Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/start)
- [WhatsApp Business API](https://developers.facebook.com/docs/whatsapp/cloud-api)
- [Flutter Provider Pattern](https://pub.dev/packages/provider)

