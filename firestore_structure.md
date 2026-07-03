# Firestore Structure — Fufaji LOOP 2 Operational Layer

**Version:** 1.0  
**Architecture:** LOOP 2 — Firestore Operational Layer  
**Database Role:** Realtime Operational Cache  
**Primary Purpose:** Customer-facing realtime operations

---

## 1. Firestore Role in System

Fufaji uses a hybrid architecture with clear ownership.

```text
Supabase = Master Database (Truth)
Firestore = Operational Realtime Layer
```

---

## 2. Responsibilities Split

| Domain                | Owner        | Reason                      |
|-----------------------|--------------|----------------------------|
| Product Catalog       | Supabase     | Strong relational integrity |
| Product Variants/SKUs | Supabase     | Constraints + joins         |
| Inventory Authority   | Supabase     | Audit trail                 |
| Pricing               | Supabase     | History + reporting         |
| Voice Search          | Supabase     | FTS + trigram               |
| Product Browse Cache  | Firestore    | Fast app reads              |
| Logged-in Cart        | Firestore    | Realtime sync               |
| Guest Cart            | Local Device | Offline-first               |
| Orders                | Firestore    | Realtime operations         |
| Rider Tracking        | Firestore    | Realtime listeners          |
| Analytics             | Supabase     | Reporting                   |

---

## 3. Firestore Core Principles

### Principle 1 — Realtime First

Firestore exists for:
* Fast reads
* Live updates
* Realtime listeners

Examples:
* Cart updates
* Order status
* Inventory changes

### Principle 2 — No Business Truth

Firestore is cache or operational state.

Never authoritative for:
* Product pricing
* Master inventory
* Search ranking

Those remain in Supabase.

### Principle 3 — Offline-First UX

Village-first requirement:
* App must remain usable with weak internet
* Guest browsing must work
* Cart should survive network failure

---

## 4. Firestore Collections Overview

```text
catalog_products/{productId}
catalog_products/{productId}/variants/{variantId}
shops/{shopId}/inventory/{variantId}
carts/{userId}
orders/{orderId}
search_cache/{category}
```

---

## 5. Collection Responsibilities

### catalog_products

**Purpose:**
* Fast catalog browsing
* Product cards
* Category listing

**Contains:**
* Active products only
* No deleted products
* Lightweight metadata

**Updated:**
* Every 5 minutes
* Or immediate for critical changes

**Source:**
* Supabase sync

---

### variants (subcollection)

**Purpose:**
* Variant browsing
* Product details
* Price display

**Contains:**
* Active sellable variants only

**Examples:**
* 500ml
* 1L
* 5kg

---

### shop inventory

**Purpose:**
* Fast stock visibility
* Checkout validation
* Cart validation

**Contains:**
* Current stock availability
* Low stock flags

**Critical updates:**
* Realtime

**Source:**
* Supabase authoritative sync

---

### carts

**Purpose:**
* Logged-in cart persistence
* Cross-device sync

**Guest carts:**
* Device local only

**Logged-in carts:**
* Firestore

**Realtime updates:**
* Yes

---

### orders

**Purpose:**
* Operational source of truth for order lifecycle

**Examples:**
* Order placed
* Packed
* Out for delivery
* Delivered
* Cancelled

**Authority:**
* Firestore canonical

**Sync:**
* Firestore → Supabase async

---

### search_cache

**Purpose:**
* Category suggestions
* Quick prefix suggestions
* Popular searches

**NOT for:**
* Main voice search (Supabase)

---

## 6. Order Lifecycle

### Order Creation

```text
Customer Checkout
    ↓
Firestore orders/{orderId}
    ↓
Realtime listeners
    ↓
Owner Dashboard + Rider App + Customer App
```

### Order Sync

```text
Firestore Order Event
    ↓
Cloud Function Trigger
    ↓
Supabase Orders Table
    ↓
Analytics / Reporting
```

---

## 7. Inventory Sync Flow

### Realtime Updates

Critical events:
* Checkout success
* Order cancel
* Refund
* Stock adjustment

**Flow:**
```text
Inventory change in Supabase
    ↓
Webhook / Function Trigger
    ↓
Firestore inventory update
```

### Scheduled Reconciliation

Runs every 5 min.

**Checks:**
* Stock drift
* Price drift
* Missing variants
* Stale products

**Purpose:**
* Prevent data drift

---

## 8. Cart Architecture

### Guest Cart

**Storage:**
```text
Device Local Storage (AsyncStorage)
```

**Pros:**
* Instant
* Offline-safe
* No server dependency

### Logged-in Cart

**Storage:**
```text
Firestore carts/{userId}
```

**Pros:**
* Cross-device sync
* Backup
* Persistent

---

## 9. Sync Strategy

Hybrid sync model.

### Realtime Sync

**Used for:**
* Inventory
* Carts
* Orders

**Latency target:**
* < 2 sec

### Scheduled Sync

**Used for:**
* Products
* Variants
* Metadata
* Prices

**Schedule:**
* Every 5 minutes

---

## 10. Failure Recovery

### Drift Detection

**Detect:**
* Mismatched inventory
* Missing products
* Stale pricing

### Recovery Strategy

```text
Firestore Drift
    ↓
Scheduled Sync
    ↓
Repair State
```

---

## 11. Security Model

Role-based access.

| Role     | Access                         |
|----------|--------------------------------|
| Customer | Read catalog, own cart/orders  |
| Rider    | Assigned orders                |
| Employee | Inventory view                 |
| Manager  | Inventory update               |
| Admin    | Full operational access        |
| Owner    | Full system access             |

---

## 12. Production Guarantees

* ✅ Fast catalog reads
* ✅ Realtime order tracking
* ✅ Cross-device cart sync
* ✅ Offline-first UX
* ✅ Hybrid sync safety
* ✅ Inventory drift protection
* ✅ Scalable for future multi-shop

---

## 13. Performance Targets

| Operation               | Target  |
|-------------------------|---------|
| Catalog Load            | <500ms  |
| Cart Update             | <200ms  |
| Order Creation          | <500ms  |
| Order Status Update     | <300ms  |
| Inventory Sync          | <2s     |

---

## 14. Future Multi-Shop Expansion

**Current:**
```text
Single shop MVP
```

**Future:**
```text
shops/{shopId}/...
```

**Architecture already supports:**
* Franchises
* Multiple stores
* Regional inventory

---

**Next:** firestore_collections.md (schema per collection)
