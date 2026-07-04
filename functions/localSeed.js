const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Ensure app is only initialized once
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'fufaji-online-business'
  });
}
const db = admin.firestore();

async function run() {
  try {
    const filePath = path.join(__dirname, 'PRODUCTS_INVENTORY.json');
    const rawData = fs.readFileSync(filePath, 'utf8');
    const inventory = JSON.parse(rawData);
    const products = inventory.products || [];

    if (products.length === 0) {
      console.error('❌ ERROR: No products found in JSON');
      process.exit(1);
    }

    const batch = db.batch();
    
    for (const product of products) {
      const docRef = product.id 
        ? db.collection('products').doc(product.id) 
        : db.collection('products').doc();
        
      batch.set(docRef, {
        ...product,
        rating: 4.5 + (Math.random() * 0.5),
        reviews: Math.floor(Math.random() * 500),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    console.log(`✅ SUCCESS. Products seeded: ${products.length}`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding products:', error);
    process.exit(1);
  }
}

run();
