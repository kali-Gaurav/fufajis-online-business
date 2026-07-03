# 🚀 FUFAJI STORE — DEPLOY NOW

**Status:** ✅ All files ready  
**Time to deploy:** 30 minutes

---

## ⚡ QUICK START (3 STEPS)

### STEP 1: Deploy Firebase Rules (5 min)

1. Open: **Firebase Console** → Firestore → **Rules** tab
2. Copy content from: `firebaseRules.production.js`
3. Paste into Rules editor (replace everything)
4. Click **Publish**

**Rules:**
```
- Public read for /products
- User auto-creation on sign-in
- User-only order access
- Admin write permissions
```

### STEP 2: Setup .env (10 min)

1. Copy `.env.example` → `.env`
2. Fill in YOUR Firebase credentials:
   - Go to Firebase Console → Settings → Your apps → Web
   - Copy: API Key, Project ID, etc.
3. Fill in Stripe keys (from Stripe Dashboard)

### STEP 3: Import Products (15 min)

Run this Firebase Function to seed products:

```javascript
// In Firebase Console → Functions → Deploy new function
// Or run: firebase deploy --only functions:seedProducts

const admin = require('firebase-admin');

exports.seedProducts = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  
  const products = [
    { name: 'दाल', nameEn: 'Lentils', price: 149, stock: 100, category: 'grains' },
    { name: 'चावल', nameEn: 'Rice', price: 299, stock: 50, category: 'grains' },
    { name: 'आलू', nameEn: 'Potatoes', price: 89, stock: 200, category: 'vegetables' },
    { name: 'प्याज', nameEn: 'Onions', price: 79, stock: 150, category: 'vegetables' },
    { name: 'टमाटर', nameEn: 'Tomatoes', price: 99, stock: 120, category: 'vegetables' },
    // Add more products...
  ];

  const batch = db.batch();
  for (const product of products) {
    const docRef = db.collection('products').doc();
    batch.set(docRef, {
      ...product,
      price: parseFloat(product.price),
      discount: 0,
      imageUrl: 'https://via.placeholder.com/140',
      createdAt: new Date().toISOString(),
      rating: 4.5,
      reviews: 0,
    });
  }

  await batch.commit();
  res.send(`✅ Seeded ${products.length} products`);
});
```

---

## 📁 Files Created

✅ `constants/designTokens.js` - Design system  
✅ `components/ProductCard.js` - Product card (fixed layout)  
✅ `screens/HomeScreen.js` - Home screen (fixed FlatList)  
✅ `services/AuthService.js` - Google Sign-In  
✅ `services/FirebaseService.js` - Firebase setup  

---

## ✔️ Verification

After deployment, test:

```
[ ] Firebase rules published
[ ] .env created with keys
[ ] npm start → No errors
[ ] Home screen → Products load
[ ] Google Sign-In → Works
[ ] Firestore → /users/{uid} created
[ ] Product cards → No overflow
```

---

## 🎯 What Gets Fixed

| Issue | Status |
|---|---|
| Firebase permission-denied | ✅ FIXED |
| BOTTOM OVERFLOWED 189px | ✅ FIXED |
| Hardcoded API keys | ✅ FIXED |
| No design consistency | ✅ FIXED |

---

## 📞 Need Help?

**Problem:** Still getting permission error?  
**Solution:** Make sure firebaseRules.production.js is published to Firebase Console

**Problem:** Products not showing?  
**Solution:** Run the seedProducts function to populate /products collection

**Problem:** App won't start?  
**Solution:** Check that designTokens.js is in constants/ folder and imported correctly

---

**Next:** Follow step-by-step above. Takes 30 minutes.
