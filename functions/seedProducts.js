/**
 * FUFAJI STORE — Seed Products to Firestore
 * Usage: firebase deploy --only functions:seedProducts
 * Then call: https://your-project.cloudfunctions.net/seedProducts
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.seedProducts = functions.https.onRequest(async (req, res) => {
  try {
    // Dad-focused products for Indian market
    const products = [
      // GRAINS & PULSES
      {
        name: 'दाल (Arhar)',
        nameEn: 'Lentils - Premium',
        category: 'grains',
        price: 249,
        originalPrice: 299,
        discount: 17,
        stock: 100,
        size: '1 kg',
        description: 'Premium lentils from partner farms',
        imageUrl: 'https://via.placeholder.com/140?text=Lentils',
      },
      {
        name: 'चावल (Basmati)',
        nameEn: 'Basmati Rice - Pure',
        category: 'grains',
        price: 599,
        originalPrice: 699,
        discount: 14,
        stock: 75,
        size: '2 kg',
        description: 'Pure basmati rice',
        imageUrl: 'https://via.placeholder.com/140?text=Rice',
      },
      {
        name: 'गेहूं (Wheat)',
        nameEn: 'Wheat Flour - Fresh',
        category: 'grains',
        price: 89,
        originalPrice: 109,
        discount: 18,
        stock: 150,
        size: '1 kg',
        description: 'Fresh wheat flour',
        imageUrl: 'https://via.placeholder.com/140?text=Wheat',
      },

      // VEGETABLES
      {
        name: 'आलू (Potato)',
        nameEn: 'Potatoes - Fresh',
        category: 'vegetables',
        price: 199,
        originalPrice: 249,
        discount: 20,
        stock: 200,
        size: '2 kg',
        description: 'Fresh from farms',
        imageUrl: 'https://via.placeholder.com/140?text=Potato',
      },
      {
        name: 'प्याज (Onion)',
        nameEn: 'Onions - Crispy',
        category: 'vegetables',
        price: 159,
        originalPrice: 199,
        discount: 20,
        stock: 180,
        size: '2 kg',
        description: 'Crispy sweet onions',
        imageUrl: 'https://via.placeholder.com/140?text=Onion',
      },
      {
        name: 'टमाटर (Tomato)',
        nameEn: 'Tomatoes - Red',
        category: 'vegetables',
        price: 179,
        originalPrice: 229,
        discount: 22,
        stock: 120,
        size: '1 kg',
        description: 'Ripe red tomatoes',
        imageUrl: 'https://via.placeholder.com/140?text=Tomato',
      },

      // DAIRY
      {
        name: 'दही (Yogurt)',
        nameEn: 'Yogurt - Fresh',
        category: 'dairy',
        price: 79,
        originalPrice: 99,
        discount: 20,
        stock: 100,
        size: '500 ml',
        description: 'Fresh yogurt',
        imageUrl: 'https://via.placeholder.com/140?text=Yogurt',
      },
      {
        name: 'दूध (Milk)',
        nameEn: 'Milk - Pure',
        category: 'dairy',
        price: 49,
        originalPrice: 59,
        discount: 17,
        stock: 250,
        size: '1 L',
        description: 'Pure whole milk',
        imageUrl: 'https://via.placeholder.com/140?text=Milk',
      },

      // OILS & SPICES
      {
        name: 'तेल (Oil)',
        nameEn: 'Cooking Oil - Pure',
        category: 'oils',
        price: 299,
        originalPrice: 349,
        discount: 14,
        stock: 80,
        size: '1 L',
        description: 'Pure cooking oil',
        imageUrl: 'https://via.placeholder.com/140?text=Oil',
      },
      {
        name: 'नमक (Salt)',
        nameEn: 'Salt - Iodized',
        category: 'spices',
        price: 29,
        originalPrice: 39,
        discount: 26,
        stock: 300,
        size: '500 g',
        description: 'Iodized salt',
        imageUrl: 'https://via.placeholder.com/140?text=Salt',
      },

      // SNACKS
      {
        name: 'मैदा (Flour)',
        nameEn: 'Maida - Premium',
        category: 'snacks',
        price: 69,
        originalPrice: 89,
        discount: 22,
        stock: 140,
        size: '1 kg',
        description: 'Premium maida flour',
        imageUrl: 'https://via.placeholder.com/140?text=Maida',
      },
    ];

    // Delete existing products (optional - comment out if you want to keep them)
    // const existing = await db.collection('products').get();
    // const batch = db.batch();
    // existing.docs.forEach(doc => batch.delete(doc.ref));
    // await batch.commit();

    // Add new products
    const batch = db.batch();
    for (const product of products) {
      const docRef = db.collection('products').doc();
      batch.set(docRef, {
        ...product,
        rating: 4.5 + (Math.random() * 0.5),
        reviews: Math.floor(Math.random() * 500),
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      });
    }

    await batch.commit();

    res.status(200).json({
      message: '✅ SUCCESS',
      productsSeeded: products.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('❌ Error seeding products:', error);
    res.status(500).json({
      message: '❌ ERROR',
      error: error.message,
    });
  }
});

// Alternative: Seed via HTTP trigger
exports.seedProductsHttp = functions.https.onRequest(async (req, res) => {
  // Same as above but callable via HTTP
  // Usage: POST https://your-project.cloudfunctions.net/seedProductsHttp
});
