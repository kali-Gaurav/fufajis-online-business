/**
 * FUFAJI STORE — Seed Products to Firestore
 * Usage: firebase deploy --only functions:seedProducts
 * Then call: https://your-project.cloudfunctions.net/seedProducts
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Ensure app is only initialized once
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

exports.seedProducts = functions.https.onRequest(async (req, res) => {
  try {
    // Read products from PRODUCTS_INVENTORY.json
    const filePath = path.join(__dirname, 'PRODUCTS_INVENTORY.json');
    const rawData = fs.readFileSync(filePath, 'utf8');
    const inventory = JSON.parse(rawData);
    const products = inventory.products || [];

    if (products.length === 0) {
      return res.status(400).json({ message: '❌ ERROR: No products found in JSON' });
    }

    const batch = db.batch();
    
    for (const product of products) {
      // Use the existing ID if present, otherwise generate a new one
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

