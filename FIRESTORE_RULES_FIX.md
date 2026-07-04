# Firestore Security Rules Fix
**Issue**: PERMISSION_DENIED when fetching `users/{uid}/reorder_templates`  
**Status**: CRITICAL - Blocks reorder feature  
**Date**: 2026-07-03

---

## Current Problem

The app repeatedly fails with:
```
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.}
Listen for QueryWrapper(query=Query(target=Query(users/KvbIF1rSfPbF9vYfwX6Ld9hEBqh2/reorder_templates order by -updatedAt, -__name__)))
```

User `KvbIF1rSfPbF9vYfwX6Ld9hEBqh2` cannot read their own `reorder_templates` collection.

---

## Root Cause

The Firestore security rules do not grant `read` permission for users to access their own `users/{uid}/reorder_templates` subcollection.

---

## Fix: Update Firestore Rules

Go to **Firebase Console** → **Firestore Database** → **Rules** tab

### Current Rules (Likely)
```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    // ... existing rules ...
    
    // BUG: Users cannot read their own reorder_templates
    match /users/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if request.auth.uid == uid;
      // ❌ No rule for subcollections!
    }
  }
}
```

### CORRECT Rules (Add These)

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    // ... existing rules ...
    
    match /users/{uid} {
      allow read: if request.auth.uid == uid;
      allow write: if request.auth.uid == uid;
      
      // ✅ FIX: Allow users to read/write their own reorder templates
      match /reorder_templates/{document=**} {
        allow read: if request.auth.uid == uid;
        allow write: if request.auth.uid == uid;
        allow delete: if request.auth.uid == uid;
      }
      
      // Add similar rules for other user subcollections if needed
      match /cart_items/{document=**} {
        allow read: if request.auth.uid == uid;
        allow write: if request.auth.uid == uid;
      }
      
      match /addresses/{document=**} {
        allow read: if request.auth.uid == uid;
        allow write: if request.auth.uid == uid;
      }
      
      match /payment_methods/{document=**} {
        allow read: if request.auth.uid == uid;
        allow write: if request.auth.uid == uid;
      }
    }
  }
}
```

---

## Step-by-Step Deployment

### 1. **Test Locally (Firestore Emulator)**
```bash
# If using Firebase Emulator Suite
firebase emulators:start --only firestore

# Run app against emulator with test rules
# Verify reorder_templates fetching works
```

### 2. **Deploy to Staging**
```bash
firebase deploy --only firestore:rules --project fufaji-staging
```

### 3. **Deploy to Production**
```bash
firebase deploy --only firestore:rules --project fufaji-production
```

### 4. **Verify Fix**
- Rebuild and run the app
- Logcat should show:
  ```
  I/flutter: [ReorderService] Templates fetched successfully
  I/flutter: [ReorderService] Found N reorder templates
  ```
- ❌ NO MORE "PERMISSION_DENIED" errors

---

## Alternative: Simpler Rules (If You Want)

If you want very simple rules for testing (NOT FOR PRODUCTION):

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

⚠️ This is **insecure** — users can read/write ANY collection. Use only for debugging.

---

## Verification Checklist

- [ ] Reviewed existing Firestore rules in Firebase Console
- [ ] Added `reorder_templates` subcollection rules
- [ ] Tested on Firestore Emulator (if available)
- [ ] Deployed to staging
- [ ] Verified app can fetch reorder_templates
- [ ] No PERMISSION_DENIED errors in logcat
- [ ] Deployed to production
- [ ] Monitored Firebase for 24h - no new permission errors

---

## Additional Notes

- **Collection**: `users/{uid}/reorder_templates`
- **Document fields** (likely): `id`, `shopId`, `items[]`, `updatedAt`, `createdAt`
- **Indexes**: May need composite index if querying by multiple fields + ordering
- **Backfill**: No existing data needs to be migrated

