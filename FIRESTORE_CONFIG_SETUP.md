# Firestore Configuration Setup Guide

## Required Firestore Documents for POS Module

### 1. Manager PIN Configuration
**Collection:** `config`
**Document ID:** `pos_settings`

```json
{
  "manager_pin": "1234",
  "created_at": "2026-06-11T00:00:00Z",
  "updated_at": "2026-06-11T00:00:00Z"
}
```

**Purpose:** Stores the manager PIN required to apply discounts exceeding 15% of subtotal in the POS cash register.

**Security Notes:**
- Change the default PIN immediately after setup
- Only admins should have access to modify this document
- Add security rule: Only authenticated users with 'admin' role can read/write

### 2. Shop Configuration (Existing)
**Collection:** `settings`
**Document ID:** `shop_config`

```json
{
  "upiId": "yourshop@upi",
  "shopName": "Fufaji Store",
  "address": "Your Store Address",
  "phone": "+919999999999"
}
```

---

## Firestore Security Rules

Add these rules to your Firestore to protect sensitive config:

```javascript
match /config/{document=**} {
  // Only admins can read/write config
  allow read, write: if request.auth != null && 
                        request.auth.token.role == 'admin';
}

match /settings/{document=**} {
  // Authenticated users can read shop config
  allow read: if request.auth != null;
  // Only admins can write
  allow write: if request.auth != null && 
                   request.auth.token.role == 'admin';
}
```

---

## Implementation Checklist

- [ ] Create `config/pos_settings` document in Firestore
- [ ] Set `manager_pin` to secure value (NOT '1234' in production)
- [ ] Update Firestore security rules
- [ ] Test PIN validation in discount dialog
- [ ] Verify offline PIN fallback works (uses device storage)
- [ ] Document PIN change procedure for admins

