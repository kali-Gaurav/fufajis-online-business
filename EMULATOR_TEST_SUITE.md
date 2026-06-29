# 🧪 Firebase Emulator Test Suite
**Purpose:** Validate all P0 security fixes work correctly  
**Setup:** Firebase Emulator + test scripts  
**Duration:** 2-3 hours  
**Run locally before deployment**

---

## ⚙️ Setup (First Time Only)

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Start Emulator
```bash
cd C:\Projects\fufaji-online-business
firebase emulators:start --only firestore
# You'll see: ✔ Emulator Suite started at http://localhost:4000
```

### 3. Keep Running
Leave the emulator running while you execute tests. Open a new terminal for test execution.

---

## 🔐 Test 1: Role Self-Write Protection (P0 Security Fix #8)

**Objective:** Customer cannot self-elevate to owner role

### Test 1a: Try to elevate role (should FAIL)
```dart
// In your Flutter app or test suite:
final FirebaseFirestore db = FirebaseFirestore.instance;

// Simulate: customer tries to change own role to 'owner'
await db.collection('users').doc('test-customer-123').update({
  'role': 'owner'  // Should be BLOCKED by rule
});

// Expected: throws FirebaseException with message containing "PERMISSION_DENIED"
```

**Manual test (Firestore Emulator UI):**
1. Go to http://localhost:4000 → Firestore
2. Create doc: `users/test-customer-123` with data: `{role: "customer"}`
3. Try to edit: change `role` to `"owner"`
4. Expected: ❌ Permission denied

### Test 1b: Keep role unchanged (should SUCCEED)
```dart
// Customer updates other fields but keeps role same
await db.collection('users').doc('test-customer-123').update({
  'role': 'customer',  // Same as before
  'name': 'Updated Name'
});

// Expected: succeeds (rule allows no-op)
```

**Expected Result:**
- ✅ Test 1a fails (permission denied)
- ✅ Test 1b succeeds (no-op allowed)
- ✅ Role field is effectively immutable for non-admins

---

## 🔒 Test 2: Missing Collection Rules (P0 Security Fix #9)

**Objective:** Regular users cannot create/write to protected collections

### Test 2a: Cannot create active_sessions (should FAIL)
```dart
// Regular user tries to create session
await db.collection('active_sessions').doc('any-session-id').set({
  'userId': 'test-user',
  'createdAt': FieldValue.serverTimestamp()
});

// Expected: Permission denied (only owning user or admin can create)
```

### Test 2b: Can read own active_sessions (should SUCCEED)
```dart
// User reads their own session (userId matches)
final snapshot = await db.collection('active_sessions')
  .where('userId', isEqualTo: currentUserId)
  .get();

// Expected: succeeds and returns matching documents
```

### Test 2c: Cannot write to owners collection (should FAIL)
```dart
// Regular user tries to write to owners
await db.collection('owners').doc('some-owner').set({
  'name': 'Hacker'
});

// Expected: Permission denied (admin only)
```

### Test 2d: Can write to pre_authorized_users as admin (should SUCCEED)
```dart
// Admin (isGlobalAdmin() = true) can write pre_authorized_users
await db.collection('pre_authorized_users').doc('email@example.com').set({
  'role': 'shopOwner'
});

// Expected: succeeds for admin
```

**Expected Results:**
- ✅ Test 2a fails (permission denied)
- ✅ Test 2b succeeds (own data readable)
- ✅ Test 2c fails (permission denied)
- ✅ Test 2d succeeds for admin

---

## 🚚 Test 3: Delivery Collection Consolidation (Module 9 Fix)

**Objective:** Delivery operations use unified delivery_tasks collection with proper scoping

### Test 3a: Rider can read own delivery_tasks (should SUCCEED)
```dart
// Rider (riderId = currentUserId) can read task
final snapshot = await db.collection('delivery_tasks')
  .where('riderId', isEqualTo: currentUserId)
  .get();

// Expected: returns tasks assigned to this rider
```

### Test 3b: Dispatcher can update delivery_tasks in own branch (should SUCCEED)
```dart
// Dispatcher updates task in their branch
await db.collection('delivery_tasks').doc('task-123').update({
  'status': 'in_transit',
  'location': {'lat': 25.1, 'lng': 76.5}
});

// Expected: succeeds if dispatcher's branchId matches task's branchId
```

### Test 3c: Random user cannot update delivery_tasks (should FAIL)
```dart
// Non-dispatcher, non-rider tries to update
await db.collection('delivery_tasks').doc('task-123').update({
  'status': 'completed'
});

// Expected: Permission denied
```

### Test 3d: Old delivery_* collections are read-only (should FAIL on write)
```dart
// Try to write to deprecated delivery_agents collection
await db.collection('delivery_agents').doc('agent-123').set({
  'name': 'Hacker'
});

// Expected: Permission denied (deprecated collection blocked)
```

**Expected Results:**
- ✅ Test 3a succeeds (rider sees own tasks)
- ✅ Test 3b succeeds (dispatcher can update own branch)
- ✅ Test 3c fails (permission denied)
- ✅ Test 3d fails (deprecated collection blocked)

---

## 📋 Test Execution Checklist

### Pre-Test
- [ ] Firebase Emulator running on http://localhost:4000
- [ ] Firestore tab accessible in emulator UI
- [ ] Test user account created (or use app auth)

### During Tests
- [ ] Test 1 (Role lock): All assertions pass
- [ ] Test 2 (Missing rules): All assertions pass
- [ ] Test 3 (Delivery): All assertions pass

### Post-Test
- [ ] All 3 test groups show ✅
- [ ] No unexpected permission errors
- [ ] No unexpected successes on blocked operations
- [ ] Rules are ready for production deployment

---

## ✅ Sign-Off Gate

**When all tests pass:**
- [ ] Role self-write protection verified ✅
- [ ] Missing collection rules verified ✅
- [ ] Delivery consolidation verified ✅
- [ ] Safe to deploy to production Firebase

**If ANY test fails:**
1. Note the failing test number
2. Check Firestore Emulator logs for error details
3. Verify rule matches source code
4. Redeploy rules if needed
5. Re-run failing test

---

## 🚀 Next Steps After Verification

1. **Deploy to Firebase:**
   ```bash
   firebase deploy --only firestore:rules
   # Wait for confirmation: ✔ Deploy complete!
   ```

2. **Deploy to Supabase:**
   - Apply migration 019 (role constraint fix)
   - Verify constraint in SQL Editor

3. **Start Task #6:** Cloud Functions migration (once secrets rotated)

---

## 📞 Troubleshooting

### Emulator not starting
```bash
firebase emulators:start --only firestore --debug
# Check port 8080 is free
# If port conflict: firebase emulators:start --only firestore --export-on-exit=./emulator-data
```

### Permission denied on allowed operation
- Check rule syntax matches source code
- Verify custom claims are set in test auth context
- Check collection/document paths exactly match rules

### Cannot find emulator UI
- Default: http://localhost:4000
- Check if running: `firebase emulators:start --only firestore`
- Firestore tab appears after few seconds

---

**Status:** Ready to run  
**Effort:** 2-3 hours  
**Owner:** Claude (Dev) + QA (if needed)  
**Blocker:** None (Firebase Emulator is local)
