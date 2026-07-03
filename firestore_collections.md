# Firestore Collections Schema — Fufaji LOOP 2

**Version:** 1.0  
**Database:** Firebase Firestore  
**Role:** Operational Realtime Cache  
**Canonical Authority:** Supabase (with Firestore mirrors for operational speed)

---

## 1. Collection Tree

```
firestore/
├── catalog_products/{productId}
│   └── variants/{variantId}
├── shops/{shopId}
│   └── inventory/{variantId}
├── carts/{userId}
├── orders/{orderId}
└── search_cache/{cacheId}
```

---

## 2. Ownership & Authority Matrix

| Collection | Write Authority | Read Authority | Source | TTL |
|-----------|-----------------|----------------|--------|-----|
| catalog_products | Supabase Sync | Public (app) | Supabase → Firestore | 7 days |
| catalog_products/variants | Supabase Sync | Public (app) | Supabase → Firestore | 7 days |
| shops/inventory | Supabase Sync | Staff/Customer | Supabase → Firestore | 5 min |
| carts | App Client | Owner only | App → Firestore | 24 hours |
| orders | Firebase Function | Owner/Rider/Admin | App (via Function) | Never |
| search_cache | Supabase Sync | Public (app) | Supabase → Firestore | 1 hour |

---

## 3. Collection Schemas

### 3.1 `catalog_products/{productId}`

**Purpose:** Fast product browsing, category discovery, product cards

**Authority:** Supabase canonical → Synced to Firestore

**Update Frequency:** Every 5 minutes (scheduled) + immediate for active product status changes

**Schema:**

```json
{
  "productId": "uuid",
  "productCode": "PROD-OIL-0001",
  "name": "Fortune Sunflower Oil",
  "hindiName": "फॉर्च्यून सूरजमुखी तेल",
  "brand": "Fortune",
  "brandId": "uuid",
  "category": "Oils",
  "categoryId": "uuid",
  "description": "100% Pure Sunflower Oil",
  "productType": "packaged|loose|fresh|frozen",
  "unitType": "weight|volume|count",
  "isActive": true,
  "isDeleted": false,
  "variantCount": 3,
  "lowestPrice": 165,
  "highestPrice": 895,
  "hasImage": true,
  "imageUrl": "https://cdn.fufaji.com/products/PROD-OIL-0001.jpg",
  "createdAt": "2026-06-01T10:00:00Z",
  "updatedAt": "2026-07-03T14:30:00Z",
  "syncVersion": 12,
  "lastSupabaseSyncAt": "2026-07-03T14:30:00Z"
}
```

**Read Access:** Public (anon + authenticated)  
**Write Access:** Backend only (Supabase sync)  
**Indexes:** category, brand, isActive  
**TTL:** 7 days from lastSupabaseSyncAt

---

### 3.2 `catalog_products/{productId}/variants/{variantId}`

**Purpose:** Variant browsing, size selection, price display

**Authority:** Supabase canonical → Synced to Firestore

**Schema:**

```json
{
  "variantId": "uuid",
  "productId": "uuid",
  "variantCode": "VAR-OIL-0001-500ML",
  "quantity": 500,
  "unit": "ml",
  "mrp": 180,
  "sellingPrice": 165,
  "gst": 5.00,
  "discount": 8.33,
  "barcode": "8901030131240",
  "isActive": true,
  "createdAt": "2026-06-01T10:00:00Z",
  "updatedAt": "2026-07-03T14:30:00Z",
  "syncVersion": 12,
  "lastSupabaseSyncAt": "2026-07-03T14:30:00Z"
}
```

**Read Access:** Public  
**Write Access:** Backend only  
**Indexes:** productId, variantCode  
**TTL:** 7 days from lastSupabaseSyncAt

---

### 3.3 `shops/{shopId}/inventory/{variantId}`

**Purpose:** Real-time stock visibility, checkout validation, low stock alerts

**Authority:** Supabase canonical → Synced to Firestore (realtime)

**Update Frequency:** < 2 seconds on critical events (stock change, order placed)

**Schema:**

```json
{
  "shopId": "FUFAJI_MAIN_001",
  "variantId": "uuid",
  "variantCode": "VAR-OIL-0001-500ML",
  "productName": "Fortune Sunflower Oil 500ml",
  "stockTotal": 100,
  "stockReserved": 10,
  "stockDamaged": 2,
  "stockAvailable": 88,
  "buyPrice": 145.50,
  "sellingPrice": 165,
  "lowStockThreshold": 15,
  "isLowStock": false,
  "reorderThreshold": 20,
  "reorderQuantity": 50,
  "lastRestockedAt": "2026-07-01T09:00:00Z",
  "updatedAt": "2026-07-03T16:45:23Z",
  "syncVersion": 45,
  "lastSupabaseSyncAt": "2026-07-03T16:45:23Z",
  "driftDetected": false,
  "driftNotes": null
}
```

**Read Access:** Public (customers), Staff (managers)  
**Write Access:** Backend only (Supabase sync)  
**Realtime Updates:** Yes (listeners on stockAvailable, isLowStock)  
**Indexes:** shopId + variantId (composite), stockAvailable, isLowStock  
**TTL:** 5 minutes from lastSupabaseSyncAt (with continuous refresh on writes)

**Drift Detection:**
- If Firestore stockAvailable != (Supabase stockTotal - stockReserved - stockDamaged), set `driftDetected = true`
- Scheduled reconciliation runs every 5 min to detect drifts

---

### 3.4 `carts/{userId}`

**Purpose:** Logged-in user cart persistence, cross-device sync

**Authority:** Firestore canonical (local-first for guests, synced for logged-in)

**Update Frequency:** Realtime on item add/remove/quantity change

**Schema:**

```json
{
  "userId": "firebase-user-id",
  "items": [
    {
      "variantId": "uuid",
      "variantCode": "VAR-OIL-0001-500ML",
      "productName": "Fortune Sunflower Oil 500ml",
      "quantity": 2,
      "price": 165,
      "totalPrice": 330,
      "addedAt": "2026-07-03T15:00:00Z",
      "isValid": true,
      "stockAvailableAtTime": 88
    }
  ],
  "itemCount": 1,
  "subtotal": 330,
  "gst": 16.50,
  "total": 346.50,
  "currency": "INR",
  "cartStatus": "active|checkout|abandoned",
  "reservedUntil": "2026-07-03T18:00:00Z",
  "cartHash": "a1b2c3d4e5f6",
  "lastValidatedAt": "2026-07-03T16:45:00Z",
  "createdAt": "2026-07-03T15:00:00Z",
  "updatedAt": "2026-07-03T16:50:00Z",
  "expiresAt": "2026-07-04T15:00:00Z"
}
```

**Write Access:** Owner (userId) only + Firebase Functions for system updates  
**Read Access:** Owner only  
**Realtime Updates:** Yes (listeners on items, total, cartStatus)  
**Indexes:** userId + cartStatus, expiresAt  
**TTL:** 24 hours from createdAt (auto-delete abandoned carts)

**Reservation Logic:**
- When cart item added: Reserve stock in Supabase inventory
- `reservedUntil`: When reservation expires (typically 3 hours)
- On checkout: Reservation becomes order
- On cart abandon: Reservation released back to available stock

---

### 3.5 `orders/{orderId}`

**Purpose:** Operational source of truth for order lifecycle, rider tracking, customer updates

**Authority:** Firestore canonical → Replicated to Supabase for analytics

**Update Frequency:** Realtime on status change, rider assignment, delivery event

**Schema:**

```json
{
  "orderId": "ORD-2026-07-03-001",
  "orderCode": "ORD123456",
  "userId": "firebase-user-id",
  "createdAt": "2026-07-03T17:00:00Z",
  "updatedAt": "2026-07-03T17:45:00Z",
  "orderStatus": "PLACED|CONFIRMED|PACKED|OUT_FOR_DELIVERY|DELIVERED|CANCELLED|REFUNDED",
  "statusHistory": [
    {
      "status": "PLACED",
      "timestamp": "2026-07-03T17:00:00Z",
      "note": "Order placed by customer"
    },
    {
      "status": "CONFIRMED",
      "timestamp": "2026-07-03T17:05:00Z",
      "note": "Payment confirmed"
    }
  ],
  "items": [
    {
      "variantId": "uuid",
      "variantCode": "VAR-OIL-0001-500ML",
      "productName": "Fortune Sunflower Oil 500ml",
      "quantity": 2,
      "price": 165,
      "subtotal": 330,
      "gst": 16.50,
      "total": 346.50
    }
  ],
  "subtotal": 330,
  "gst": 16.50,
  "deliveryFee": 0,
  "discount": 0,
  "total": 346.50,
  "currency": "INR",
  "paymentMethod": "UPI|CARD|NETBANKING",
  "paymentStatus": "PENDING|AUTHORIZED|CAPTURED|FAILED|REFUNDED",
  "paymentId": "stripe-payment-intent-id",
  "paymentReference": "TXN-123456789",
  "paymentConfirmedAt": "2026-07-03T17:05:00Z",
  "customerDetails": {
    "name": "Rajesh Kumar",
    "phone": "+91-9876543210",
    "email": "rajesh@example.com"
  },
  "deliveryAddress": {
    "street": "123 Main St",
    "city": "Bangalore",
    "state": "Karnataka",
    "postalCode": "560001",
    "country": "India"
  },
  "rider": {
    "riderId": "uuid",
    "riderName": "Amit",
    "riderPhone": "+91-9876543211",
    "riderLocation": {
      "lat": 12.9716,
      "lng": 77.5946,
      "updatedAt": "2026-07-03T17:30:00Z"
    },
    "assignedAt": "2026-07-03T17:10:00Z"
  },
  "delivery": {
    "estimatedDeliveryAt": "2026-07-03T18:30:00Z",
    "actualDeliveryAt": null,
    "deliveryOtp": "1234",
    "otpVerifiedAt": null,
    "deliverySignature": null,
    "deliveryNotes": "Leave at door"
  },
  "refund": {
    "status": null,
    "amount": 0,
    "reason": null,
    "initiatedAt": null,
    "completedAt": null
  },
  "syncVersion": 1,
  "lastSyncToSupabaseAt": null
}
```

**Write Access:** Firebase Function only (on payment, status change, rider assignment)  
**Read Access:** Owner (customer), Assigned Rider, Staff, Admin  
**Realtime Updates:** Yes (listeners on orderStatus, rider, delivery)  
**Indexes:** userId + orderStatus, orderStatus + createdAt, riderId  
**TTL:** Never (orders kept forever for audit trail)

**Order Status Workflow:**
```
PLACED (payment initiated)
  ↓
CONFIRMED (payment captured)
  ↓
PACKED (staff prepared)
  ↓
OUT_FOR_DELIVERY (rider picked up)
  ↓
DELIVERED (customer received)
  ↓ (if issue)
CANCELLED or REFUNDED
```

---

### 3.6 `search_cache/{cacheId}`

**Purpose:** Lightweight category suggestions, popular product suggestions, search autocomplete

**Authority:** Supabase → Synced to Firestore

**Update Frequency:** Every 1 hour

**Schema:**

```json
{
  "cacheId": "search-category-oils-2026-07-03",
  "category": "Oils",
  "categoryId": "uuid",
  "type": "category|popular|recent_searches",
  "suggestions": [
    {
      "productName": "Fortune Sunflower Oil",
      "productCode": "PROD-OIL-0001",
      "lowestPrice": 165,
      "searchFrequency": 245,
      "popularity": "high"
    }
  ],
  "suggestionsCount": 1,
  "lastUpdatedAt": "2026-07-03T14:00:00Z",
  "expiresAt": "2026-07-03T15:00:00Z"
}
```

**Read Access:** Public  
**Write Access:** Backend only (Supabase sync)  
**Indexes:** category, type  
**TTL:** 1 hour from expiresAt (auto-delete stale suggestions)

**Note:** This is NOT for voice search. Voice search remains in Supabase (FTS + trigram). This cache is only for UI autocomplete suggestions.

---

## 4. Read/Write Rules Summary

| Collection | Public Read | Auth Read | Auth Write | Admin Write | Backend Sync |
|-----------|------------|-----------|-----------|-----------|------------|
| catalog_products | ✅ | ✅ | ❌ | ✅ | ✅ |
| variants | ✅ | ✅ | ❌ | ✅ | ✅ |
| inventory | ✅ | ✅ | ❌ | ✅ | ✅ |
| carts | ❌ | ✅ (own) | ✅ (own) | ✅ | ✅ |
| orders | ❌ | ✅ (own) | ❌ | ✅ | ✅ |
| search_cache | ✅ | ✅ | ❌ | ✅ | ✅ |

---

## 5. Sync Rules

### Supabase → Firestore (Read Direction)

| Supabase Table | Firestore Collection | Sync Type | Frequency | Latency Target |
|---------------|----------------------|-----------|-----------|----------------|
| catalog_products | catalog_products | Scheduled | Every 5 min | < 5 min |
| catalog_variants | catalog_products/variants | Scheduled | Every 5 min | < 5 min |
| shop_inventory | shops/inventory | Realtime | On change | < 2 sec |
| product_search_index | search_cache | Scheduled | Every 1 hour | < 1 hour |

### Firestore → Supabase (Write Direction)

| Firestore Collection | Supabase Table | Sync Type | Trigger |
|----------------------|----------------|-----------|---------|
| orders | orders + analytics | Async | Order status change |
| carts | (not synced) | — | — |

### No Bidirectional Sync

- Firestore never writes back to Supabase product/inventory data
- Only orders replicate backward (operational → analytics)
- Carts are operational only (no persistence to Supabase)

---

## 6. TTL & Cleanup Rules

| Collection | TTL Duration | Cleanup Trigger | Cleanup Action |
|-----------|--------------|-----------------|----------------|
| catalog_products | 7 days | lastSupabaseSyncAt | Delete if stale + not changed |
| inventory | 5 min (rolling) | lastSupabaseSyncAt | Re-sync immediately on change |
| carts | 24 hours | createdAt | Delete if abandoned + expiresAt passed |
| orders | Never | — | Keep forever (audit trail) |
| search_cache | 1 hour | expiresAt | Delete + re-sync |

**Cleanup Strategy:**
- Scheduled Cloud Function runs daily
- Checks TTL timestamps
- Deletes expired documents
- Logs cleanup events for audit

---

## 7. Cross-Collection Relationships

```
catalog_products
  ├─ productId → used in variants
  ├─ productId → used in inventory (via variantId)
  ├─ brandId → references catalog_brands (Supabase)
  └─ categoryId → references catalog_categories (Supabase)

carts
  ├─ userId → maps to Firebase Auth
  ├─ variantId → references catalog_products/variants/{variantId}
  └─ quantity → validates against shops/inventory/{variantId}/stockAvailable

orders
  ├─ userId → maps to Firebase Auth
  ├─ variantId → references catalog_products/variants/{variantId}
  ├─ riderId → references rider profile (Supabase)
  └─ paymentId → references Stripe payment intent
```

---

## 8. Document Validation Rules

### Cart Items Validation
Before cart checkout:
1. Verify variant exists: `catalog_products/{productId}/variants/{variantId}`
2. Verify inventory available: `shops/inventory/{variantId}/stockAvailable >= cartItem.quantity`
3. Verify price hasn't changed (warn if > 5% difference)
4. Verify reservation not expired: `now() < cart.reservedUntil`

### Order Items Validation
At order creation:
1. All cart validations above
2. Stock is reserved in Supabase inventory
3. Payment is captured successfully
4. Address is validated

---

## 9. Performance Targets

| Operation | Target | Collection |
|-----------|--------|-----------|
| Load catalog (50 products) | < 500ms | catalog_products |
| Add item to cart | < 200ms | carts |
| Get user cart | < 150ms | carts |
| Get order status | < 100ms | orders |
| Update inventory | < 2s | shops/inventory |
| List user orders | < 300ms | orders |

---

## 10. Production Guarantees

✅ Clear ownership per collection  
✅ Realtime sync for operational data (inventory, orders)  
✅ Scheduled sync for catalog data (5 min freshness)  
✅ TTL-based cleanup (no data sprawl)  
✅ No circular sync (Firestore → Supabase is read-only)  
✅ Drift detection (sync version tracking)  
✅ Reservation logic (cart ↔ inventory alignment)  
✅ Audit trail (orders never deleted)

---

**Next:** firestore_security.rules (RBAC enforcement)
