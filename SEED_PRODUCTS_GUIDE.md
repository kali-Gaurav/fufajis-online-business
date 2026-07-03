# Seeding 100 Products to Firestore

This guide explains how to run the product seeding script to populate the database with 100 high-quality Indian grocery products.

## Location

The seed script is located at: `lib/scripts/seed_products_100.dart`

## What Gets Seeded

The script creates 100 products across 10 categories:

- **Vegetables** (15) — potatoes, onions, tomatoes, spinach, carrots, etc.
- **Grains & Flour** (12) — wheat flour, rice flour, besan, cornflour, etc.
- **Spices & Condiments** (20) — turmeric, chili powder, cumin, garam masala, etc.
- **Oils & Ghee** (8) — mustard oil, ghee, coconut oil, sunflower oil, etc.
- **Rice** (8) — basmati, brown rice, white rice, jasmine rice, etc.
- **Dairy & Milk** (10) — milk, yogurt, paneer, cheese, cream, etc.
- **Pulses** (7) — chickpeas, moong dal, masoor dal, etc.
- **Snacks** (10) — namkeen mix, bhujia, chakli, peanuts, etc.
- **Biscuits & Cookies** (7) — marie gold, digestive, chocolate chips, etc.
- **Sugar & Jaggery** (6) — white sugar, jaggery, honey, stevia, etc.

## Data Included for Each Product

Each product is seeded with comprehensive data:

```
- name (English name)
- hindiName (Hindi product name) — NEW
- category (Category)
- keywords (List<String> for voice search) — NEW
- price (Fufaji selling price)
- mrpPrice (Maximum Retail Price) — NEW
- unit (kg, l, packet, bunch, etc.)
- description (Product description)
- nutrition (Map<String, String> with nutrition facts) — NEW
- stock (Current inventory level)
- imageUrl (Placeholder product image)
- tags (Tags like 'organic', 'healthy', 'premium')
- brand (Brand name, if applicable)
- isAvailable (true for all)
- rating (4.5 stars)
```

## How to Run the Seed Script

### Option 1: From Flutter App (Recommended)

Add a button in your admin dashboard or setup screen:

```dart
import 'package:fufaji_store/scripts/seed_products_100.dart';

// In your setup/admin screen
ElevatedButton(
  onPressed: () async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed Products'),
        content: const Text('Seeding 100 test products...'),
      ),
    );
    
    try {
      await seedProducts100(FirebaseFirestore.instance);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 100 products seeded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    
    if (mounted) Navigator.pop(context);
  },
  child: const Text('Seed 100 Test Products'),
)
```

### Option 2: From Firebase Console Cloud Functions

Create a callable Cloud Function:

```dart
// functions/index.js (Node.js example)
exports.seedProducts = functions.https.onCall(async (data, context) => {
  // Call the Dart seed function via admin SDK
  // (requires porting Dart logic to Node.js)
});
```

### Option 3: From Firestore Console (Manual)

Navigate to Firestore Console → Products collection → Add documents manually (tedious, not recommended).

## Verification Steps

After seeding, verify in Firestore Console:

1. **Count products**: Products collection should have 100 documents
2. **Sample product**: Click any product and verify fields:
   - `hindiName` present
   - `keywords` array populated
   - `mrpPrice` present
   - `nutrition` map with at least 2-3 entries
   - `stock` > 0
3. **Test voice search**: Try voice ordering and check if products are matched

## Verify with a Query

Run this Firestore query to verify:

```
db.collection('products').where('isAvailable', '==', true).get()
```

Should return 100 documents.

## Resetting Products (if needed)

To delete all seeded products and start fresh:

```dart
// WARNING: This deletes ALL products!
final batch = firestore.batch();
final snapshot = await firestore.collection('products').get();
for (final doc in snapshot.docs) {
  batch.delete(doc.reference);
}
await batch.commit();
```

## Voice Search Optimization

The seed script includes keywords optimized for Indian voice search:

- **Hindi names** — "आलू" for potato, "दूध" for milk
- **Hinglish keywords** — "aloo", "doodh" for voice users speaking in mix
- **Aliases** — "potato" for "आलू", "milk" for "दूध"
- **Phonetic variations** — handles "mirch" and "mircha" equally

This ensures voice search works well even when users speak in Hindi, English, or Hinglish.

## Next Steps

After seeding:

1. ✅ Run QA voice ordering test (Task #11)
2. ✅ Test voice parsing accuracy (Task #14)
3. ✅ Optimize product images (Task #15)
4. ✅ Final accessibility audit (Task #16)

## Support

If seeding fails:
- Check Firestore quota limits (500 writes/batch)
- Verify Firebase auth credentials
- Ensure `isGlobalAdmin` role is set for your user
- Check Firestore rules allow writes to `products` collection

---

**Seed Status:** ✅ Ready to deploy  
**Date Generated:** 2026-07-02  
**Total Products:** 100
