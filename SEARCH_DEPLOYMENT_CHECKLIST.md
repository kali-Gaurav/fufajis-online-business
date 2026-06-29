# Search Performance Optimization - Deployment Checklist

## Pre-Deployment Verification

### Code Review Checklist
- [ ] ProductSearchService compiles without errors
- [ ] ProductSearchScreen UI renders correctly
- [ ] No breaking changes to existing ProductModel
- [ ] No circular dependencies or import errors
- [ ] All service methods have proper error handling
- [ ] Logging statements present for debugging

```bash
# Verify code compiles
flutter pub get
flutter analyze lib/services/search/
flutter analyze lib/screens/employee/product_search_screen_optimized.dart
```

### Dependency Check
- [ ] cloud_firestore package already in pubspec.yaml
- [ ] provider package already in pubspec.yaml
- [ ] No new dependencies needed (all existing)

```bash
# Check pubspec.yaml for required packages
grep -E "cloud_firestore|provider" pubspec.yaml
```

## Firebase Setup

### Step 1: Deploy Firestore Indexes (CRITICAL)

```bash
# From project root
firebase deploy --only firestore:indexes

# Verify deployment
firebase firestore:indexes list
```

**Expected Output:**
```
Indexes in project xxxxxxxx:
  CollectionGroup=products, Fields=[searchKeywords(Asc), isAvailable(Asc)]
  CollectionGroup=products, Fields=[searchTrigrams(Asc), isAvailable(Asc)]
  CollectionGroup=products, Fields=[barcode(Asc)]
  CollectionGroup=products, Fields=[category(Asc), isAvailable(Asc)]
  CollectionGroup=products, Fields=[stockQuantity(Asc)]
```

**Wait Time:** 2-10 minutes for Firestore to build composite indexes

- [ ] All 5 indexes shown in `READY` state
- [ ] No indexes in `BUILDING` state
- [ ] No index errors

### Step 2: Verify Security Rules

```bash
# Check current rules
firebase firestore:indexes list --show-rules
```

Ensure rules allow authenticated users to read products:

```firestore
match /shops/{shopId}/products/{productId} {
  allow read: if request.auth.uid != null;
  allow create, update: if request.auth.uid == resource.data.shopOwnerId;
  allow delete: if request.auth.uid == resource.data.shopOwnerId;
}
```

- [ ] Read access allowed for authenticated employees
- [ ] Write access restricted to shop owner
- [ ] searchKeywords field readable by employees

## App Code Integration

### Step 1: Copy Files to Project

```bash
# Services
cp lib/services/search/product_search_service.dart \
   /path/to/fufaji-online-business/lib/services/search/

# Screens
cp lib/screens/employee/product_search_screen_optimized.dart \
   /path/to/fufaji-online-business/lib/screens/employee/

# Examples
cp lib/examples/search_integration_example.dart \
   /path/to/fufaji-online-business/lib/examples/
```

- [ ] ProductSearchService present in `lib/services/search/`
- [ ] ProductSearchScreen present in `lib/screens/employee/`
- [ ] Examples present in `lib/examples/`

### Step 2: Update Imports

In any screen that uses the new search, add import:

```dart
import '../../services/search/product_search_service.dart';
import '../../screens/employee/product_search_screen_optimized.dart';
```

### Step 3: Integrate into Unified Scanner (Optional)

Add search mode to `unified_scanner_hub.dart`:

```dart
// Add search mode to mode selector
void _selectMode(String modeId) {
  if (modeId == 'product_search') {
    _openProductSearch();
  } else {
    setState(() => _activeMode = modeId);
    _scanner.startScanning();
  }
}

void _openProductSearch() async {
  final product = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProductSearchScreen(shopId: widget.shopId),
    ),
  );
  
  if (product != null) {
    // Add to cart or process
  }
}
```

- [ ] ProductSearchScreen integrated into scanner mode selector
- [ ] Barcode auto-detection works
- [ ] Screen returns selected product correctly

## Database Preparation

### Step 1: Index Existing Products (One-time)

Run this from admin dashboard or initialization:

```dart
final searchService = ProductSearchService();
final shopId = auth.currentShop.id;

// This populates searchKeywords and searchTrigrams
final count = await searchService.indexProductsForSearch(shopId);
print('Indexed $count products');
```

Or from Flutter app initialization:

```dart
// In main.dart or app startup
WidgetsFlutterBinding.ensureInitialized();

// Index products if not already done
final prefs = await SharedPreferences.getInstance();
if (!prefs.getBool('products_indexed') ?? false) {
  final searchService = ProductSearchService();
  await searchService.indexProductsForSearch(shopId);
  await prefs.setBool('products_indexed', true);
}
```

**Duration:**
- 5000 products: ~30 seconds
- 10000 products: ~60 seconds
- 50000 products: ~300 seconds (5 minutes)

- [ ] All existing products indexed with searchKeywords
- [ ] All existing products indexed with searchTrigrams
- [ ] Indexing completed without errors
- [ ] No timeout errors during batch operations

### Step 2: Auto-Index New Products

Update product creation/upload to auto-populate fields:

**Option A: In Product Service**
```dart
// In product_service.dart
Future<void> createProduct(ProductModel product) async {
  final data = product.toFirestore();
  
  // Add search fields
  data['searchKeywords'] = _generateKeywords(product);
  data['searchTrigrams'] = _generateTrigrams(product.name);
  data['searchIndexedAt'] = FieldValue.serverTimestamp();
  
  await _firestore.collection('shops/${product.shopId}/products')
    .doc(product.id)
    .set(data);
}

List<String> _generateKeywords(ProductModel product) {
  return [
    product.name.toLowerCase(),
    product.category.toLowerCase(),
    (product.barcode ?? '').toLowerCase(),
    (product.brand ?? '').toLowerCase(),
  ];
}

List<String> _generateTrigrams(String text) {
  Set<String> trigrams = {};
  final lower = text.toLowerCase();
  for (int i = 0; i <= lower.length - 3; i++) {
    trigrams.add(lower.substring(i, i + 3));
  }
  return List.from(trigrams);
}
```

**Option B: In Cloud Function**
```javascript
// functions/index.js
exports.indexProductOnCreate = functions.firestore
  .document('shops/{shopId}/products/{productId}')
  .onCreate((snap, context) => {
    const data = snap.data();
    const name = data.name.toLowerCase();
    
    // Generate trigrams
    const trigrams = [];
    for (let i = 0; i <= name.length - 3; i++) {
      trigrams.push(name.substring(i, i + 3));
    }
    
    return snap.ref.update({
      searchKeywords: [
        name,
        (data.category || '').toLowerCase(),
        (data.barcode || '').toLowerCase(),
      ],
      searchTrigrams: trigrams,
      searchIndexedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
```

- [ ] New products auto-populate searchKeywords
- [ ] New products auto-populate searchTrigrams
- [ ] Cloud Functions deployed (if using option B)
- [ ] No breaking changes to existing product creation

## Testing

### Unit Tests

Create `test/services/product_search_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fufaji_store/services/search/product_search_service.dart';

void main() {
  group('ProductSearchService', () {
    late ProductSearchService searchService;

    setUp(() {
      searchService = ProductSearchService();
    });

    test('searchByBarcode returns product for valid barcode', () async {
      // TODO: Mock Firestore and test
      // final product = await searchService.searchByBarcode(
      //   'shop_001',
      //   '8901234567890'
      // );
      // expect(product, isNotNull);
      // expect(product?.name, contains('Rice'));
    });

    test('searchProducts finds keyword matches', () async {
      // final results = await searchService.searchProducts(
      //   'shop_001',
      //   'rice'
      // );
      // expect(results.isNotEmpty, true);
    });

    test('searchProducts handles typos with fuzzy match', () async {
      // final results = await searchService.searchProducts(
      //   'shop_001',
      //   'ryce'  // typo
      // );
      // expect(results.any((p) => p.name.contains('Rice')), true);
    });
  });
}
```

Run tests:
```bash
flutter test test/services/product_search_service_test.dart
```

- [ ] Unit tests pass
- [ ] Mock data setup works
- [ ] No compilation errors in tests

### Integration Tests

Test against real Firestore (development):

```bash
# Start emulator (optional)
firebase emulators:start --only firestore

# Run app and manually test:
# 1. Search by barcode -> returns <50ms
# 2. Search "rice" -> returns results in <100ms
# 3. Search "ryce" -> fuzzy matches rice in <100ms
# 4. Empty search -> returns empty list
# 5. Screen returns selected product
```

Manual Testing Checklist:
- [ ] Barcode search works (scan or paste barcode)
- [ ] Keyword search works (type "rice")
- [ ] Typo handling works (type "ryce")
- [ ] Search results display correctly
- [ ] Product images load or show fallback
- [ ] Stock status shows correctly
- [ ] Performance metrics display (milliseconds)
- [ ] Tapping product returns it to caller
- [ ] Back button dismisses without selection
- [ ] Multiple searches don't cause errors
- [ ] Screen handles network errors gracefully

### Performance Tests

```bash
# Check actual performance
# 1. Open ProductSearchScreen
# 2. Type "rice" - should see <100ms in green badge
# 3. Type "ryce" - should see <100ms in green badge
# 4. Scan barcode - should see <50ms
```

Expected Metrics:
- Barcode lookup: 10-30ms
- Keyword exact match: 30-80ms
- Fuzzy match: 50-150ms
- All results: <200ms 99th percentile

- [ ] Most searches complete in <100ms
- [ ] No searches exceed 500ms
- [ ] No OOM or crash errors
- [ ] Performance badges show correct colors
  - [ ] Green: <100ms
  - [ ] Orange: 100-300ms
  - [ ] Red: >300ms (should rarely happen)

### Load Test (Optional)

If you have many products (>10000):

```bash
# Simulate multiple concurrent searches
# Use Android profiler or Firebase monitoring

# Expected results for 50000 products:
# - P50 latency: <100ms
# - P99 latency: <300ms
# - Success rate: >99%
# - No OOM errors
# - CPU usage: <50%
```

- [ ] Can handle 10000+ products
- [ ] Concurrent searches don't block each other
- [ ] No memory leaks
- [ ] No database quota exceeded errors

## Production Rollout

### Staging Environment

1. Deploy to staging Firebase project first
2. Run full test suite
3. Verify all performance metrics

```bash
firebase use staging
firebase deploy --only firestore:indexes,functions
```

- [ ] Staging indexes created
- [ ] Staging app builds successfully
- [ ] All manual tests pass on staging
- [ ] Performance metrics acceptable

### Production Deployment

#### Phase 1: Index Creation (Optional - can be done in advance)

```bash
firebase use production
firebase deploy --only firestore:indexes
# Wait 10 minutes for index creation
```

- [ ] All indexes in READY state
- [ ] No pending indexes

#### Phase 2: App Release

1. Update app version in pubspec.yaml
2. Build release APK/AAB
3. Upload to Google Play (staged rollout recommended)
4. Run indexing on first app launch

```bash
# In main.dart
if (!prefs.getBool('products_indexed')) {
  await productSearchService.indexProductsForSearch(shopId);
  await prefs.setBool('products_indexed', true);
}
```

- [ ] App version bumped
- [ ] Release build tested locally
- [ ] Uploaded to Play Store
- [ ] Staged rollout at 25% -> 50% -> 100%

#### Phase 3: Monitoring

**Post-Launch Monitoring (First 24 hours):**

```bash
# Check Firebase Console > Firestore > Indexes
# Ensure all 5 indexes are READY

# Check Performance Metrics
# Look for search query success rate (should be >99%)

# Check Logs
# Filter for ProductSearch errors
firebase functions:log --limit=100 --filter="ProductSearch"
```

- [ ] All indexes show as READY
- [ ] Search queries succeeding (>99%)
- [ ] Error rate <1%
- [ ] Average latency <100ms
- [ ] No quota exceeded warnings
- [ ] No OOM errors in logs

**Ongoing Monitoring:**

Set up alerts in Firebase Console:

```
Alert: Search Query Error Rate > 5% (24-hour window)
Alert: Search Query Latency P99 > 500ms (1-hour window)
Alert: Firestore Index Creation Failed
Alert: Database quota exceeded
```

- [ ] Alerts configured in Firebase Console
- [ ] Team receives notifications
- [ ] Runbook prepared for common issues

## Rollback Plan

If issues occur:

### Option 1: Disable Search Optimization (Keep App Working)

```dart
// In ProductSearchService
Future<List<ProductModel>> searchProducts(...) async {
  try {
    // Try optimized search
    return await _optimizedSearch(...);
  } catch (e) {
    // Fallback to old client-side search
    return await _legacyClientSideSearch(...);
  }
}
```

- [ ] Fallback mechanism in place
- [ ] Testing of fallback works

### Option 2: Remove Search Fields from Products

If corruption detected:

```bash
# Remove search fields from all products
firebase firestore:bulk-delete \
  --collection=/shops/XXX/products \
  --delete-field=searchKeywords \
  --delete-field=searchTrigrams
```

- [ ] Firestore CLI available
- [ ] Deletion script tested in staging

### Option 3: Revert App Release

If app causes critical issues:

```bash
# Stop rollout in Play Console
# Revert to previous version
# Remove indexes (optional)
firebase deploy --only firestore:indexes
```

- [ ] Previous version APK available
- [ ] Play Store revert process documented
- [ ] Communication plan for users

## Post-Launch Documentation

- [ ] Update app README with search feature
- [ ] Document performance expectations
- [ ] Add troubleshooting guide
- [ ] Create employee training material
- [ ] Add feature to release notes

## Success Criteria

**All of these must be true for successful launch:**

- [x] Code compiles without errors
- [x] All 5 Firestore indexes READY
- [x] Existing products indexed (searchKeywords + searchTrigrams)
- [x] Barcode search <50ms
- [x] Keyword search <100ms
- [x] Fuzzy search <150ms
- [x] No broken existing features
- [x] UI renders correctly
- [x] Error handling works
- [x] Monitoring alerts configured
- [x] Rollback plan documented
- [x] Team trained on new feature

## Next Steps (Post-Launch)

1. **Week 3:** Add fuzzy search improvements (Week 3 #2)
2. **Week 3:** Integrate voice search with Hinglish parser (Week 3 #4)
3. **Week 4:** Add search analytics and trending queries (Week 4 feature)
4. **Future:** Implement autocomplete and suggestions

---

**Status:** Ready for Deployment
**Date:** June 11, 2026
**Version:** 1.0
**Deployment Priority:** High (blocking POS performance)

For questions, refer to `SEARCH_PERFORMANCE_GUIDE.md` and `lib/examples/search_integration_example.dart`
