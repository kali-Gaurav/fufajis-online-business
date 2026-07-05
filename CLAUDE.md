# Fufaji Master Architecture Instructions (Permanent)
Spec → Implement → Code Review → Fix → Verify 
   → Loop 2a Check for errors

You are working on **Fufaji Online Business**, a production-grade local commerce operating system for a single-shop grocery business.

Before making ANY architectural, backend, database, auth, payment, or infrastructure decision, you MUST follow these rules.

---

# 0. MOST IMPORTANT RULE

## NEVER USE FIREBASE CLOUD FUNCTIONS.

This is a hard rule.

Reasons:

* We use **Firebase Spark Plan** (very limited)
* Cloud Functions are not part of production architecture
* They increase cost and create architecture inconsistency

If you suggest or implement Firebase Cloud Functions, that is considered WRONG.

---

# 1. OFFICIAL TECH STACK

## Frontend / Client

* Flutter App (Android-first)
* Customer App
* Owner/Admin App
* Employee App
* Delivery App

---

## Authentication

Use Firebase Auth ONLY for:

* Authentication/session management
* Token generation
* Google Sign-In (customer only)

Operational users:

* Owner
* Admin
* Employee
* Delivery Agent

must use:

* Login ID + Password/PIN
* Backend verification
* Custom token session

---

## Database (SOURCE OF TRUTH)

### Supabase PostgreSQL

This is the ONLY source of truth.

All critical writes must go here:

* orders
* products
* inventory
* wallets
* payments
* delivery
* staff
* analytics

Never treat Firestore as source of truth.

---

## Real-Time Layer

### Firestore = Read-only Sync Layer

Firestore exists ONLY for:

* real-time UI updates
* caching
* fast reads
* live order updates

Firestore is NOT source of truth.

Never write critical business logic directly to Firestore.

Flow:

App
→ Backend
→ PostgreSQL
→ sync-to-firestore
→ Firestore UI updates

---

## Backend Functions

### Supabase Edge Functions

Use for:

* transactional business logic
* order lifecycle
* checkout
* inventory locking
* OTP verification
* cancellation
* wallet logic

Examples:

* processCheckout
* changeOrderStatus
* cancelOrder
* verifyDeliveryOtp
* dispatchCluster

Preferred for most transactional operations.

---

## Server Backend

### Render Backend

Use Render for:

* heavy backend services
* long-running processes
* complex business workflows
* external integrations
* cron jobs if needed
* AI processing
* analytics pipelines
* webhook processing
* background workers

Examples:

* Razorpay webhooks
* WhatsApp integrations
* ML jobs
* route optimization
* large sync jobs

---

# 2. BACKEND ARCHITECTURE RULE

ALL critical mutations must follow this flow:

Flutter App
→ Supabase Edge Function or Render Backend
→ PostgreSQL
→ Firestore Sync Layer

NEVER:

Flutter App
→ Direct Firestore write

for critical operations.

---

# 3. CRITICAL OPERATIONS (BACKEND ONLY)

These must NEVER happen on client.

* Checkout
* Payment
* Wallet deduction
* Inventory reservation
* Inventory release
* Order status transition
* Rider dispatch
* OTP verification
* Refunds
* Delivery verification
* Stock mutation

All must happen server-side.

---

# 4. OFFLINE RULES

Offline writes are NOT allowed for critical operations.

Allowed offline:

* browsing
* cached product viewing
* attendance logs
* damage reports
* comments

Not allowed offline:

* checkout
* payments
* order status changes
* delivery verification
* inventory changes

Critical operations require active connection.

---

# 5. INVENTORY RULE

Use 3-layer inventory model.

* availableStock
* reservedStock
* soldStock

Flow:

Checkout:
available → reserved

Payment success:
reserved → sold

Payment failure/cancel:
reserved → available

Never use simplistic stock decrement.

---

# 6. ORDER STATE MACHINE

Only backend controls order state.

Allowed transitions:

pending_payment → confirmed, cancelled
confirmed → processing, cancelled
processing → packed, cancelled
packed → shipped
shipped → delivered, failed_delivery
failed_delivery → retry_dispatch, returned, refunded

Client must never directly change order status.

---

# 7. PAYMENT RULES

Payment provider:

* Razorpay

Rules:

* All payments verified server-side
* Webhooks must be idempotent
* Duplicate webhook events must be ignored
* Refunds must be ledger-driven

Never trust client payment confirmation.

---

# 8. SECURITY RULES

Always prioritize:

* idempotency
* concurrency safety
* race condition prevention
* transaction rollback
* backend verification

Use:

* PostgreSQL transactions
* row locking
* audit logs
* role checks

---

# 9. COST CONSTRAINTS

Infrastructure constraints:

Firebase:

* Spark Plan only
* Minimize usage

Supabase:

* Free tier
* Primary database + edge functions

Render:

* Server-side workloads

Always optimize architecture for low cost.

Avoid expensive solutions.

---

# 10. WHEN SUGGESTING NEW FEATURES

Always ask:

1. Should this live in Flutter?
2. Should this live in Supabase Edge Functions?
3. Should this live in Render backend?
4. Should this write to PostgreSQL?
5. Does Firestore only need synced read data?

Default assumption:

* PostgreSQL = truth
* Firestore = read-only cache

---

# FINAL RULE

If uncertain:

Choose this architecture:

Flutter App
→ Supabase / Render
→ PostgreSQL
→ Firestore Sync

Never choose Firebase Cloud Functions.
