const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '../.env') });

const serviceAccountStr = process.env.FIREBASE_SERVICE_ACCOUNT;
if (!serviceAccountStr) {
  console.error("Missing FIREBASE_SERVICE_ACCOUNT in .env");
  process.exit(1);
}

const serviceAccount = JSON.parse(serviceAccountStr);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const batches = [
  'batch_1_products_catalog.json',
  'batch_2_products_catalog.json',
  'batch_3_products_catalog.json'
];

async function seedFirestore() {
  console.log("============================================");
  console.log("DIRECT SEEDING TO FIRESTORE");
  console.log("Batches 1, 2, and 3");
  console.log("============================================");
  
  let totalCreated = 0;
  let totalFailed = 0;

  for (const batchFile of batches) {
    console.log(`\nProcessing ${batchFile}...`);
    const filePath = path.join(__dirname, batchFile);
    
    if (!fs.existsSync(filePath)) {
      console.error(`ERROR: ${batchFile} not found.`);
      continue;
    }

    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const products = data.products || [];
    console.log(`Found ${products.length} products`);

    let createdCount = 0;
    let failedCount = 0;

    for (const p of products) {
      try {
        // Find default variant or first variant
        const mainVariant = (p.variants && p.variants.length > 0) ? p.variants[0] : null;

        const productDoc = {
          id: p.productId,
          name: p.name,
          hindiName: p.hindiName || p.name,
          description: p.description || '',
          category: p.category || 'other',
          categoryId: p.category || 'other',
          brand: p.brand || '',
          price: mainVariant ? mainVariant.sellingPrice : 0,
          mrpPrice: mainVariant ? mainVariant.mrp : 0,
          unit: mainVariant ? mainVariant.unit : 'piece',
          stockQuantity: mainVariant ? (mainVariant.stock || 50) : 0, // Fake some stock if none
          barcode: mainVariant ? (mainVariant.barcode || '') : '',
          isAvailable: true,
          shopId: 'SHOP_001', // Default MVP shop
          shopName: 'Fufaji Store',
          imageUrl: `https://via.placeholder.com/300?text=${encodeURIComponent(p.name)}`, // Placeholder
          keywords: p.voiceMetadata ? (p.voiceMetadata.keywords || []) : [],
          district: 'Default District',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        await db.collection('products').doc(p.productId).set(productDoc, { merge: true });
        createdCount++;
      } catch (e) {
        console.error(`Failed on product ${p.productId}: ${e.message}`);
        failedCount++;
      }
    }
    
    console.log(`✓ Created/Updated: ${createdCount} products`);
    if (failedCount > 0) console.log(`⚠ Failed: ${failedCount} products`);
    
    totalCreated += createdCount;
    totalFailed += failedCount;
  }

  console.log("\n============================================");
  console.log("FIRESTORE SEED SUMMARY");
  console.log("============================================");
  console.log(`Total Products Synced: ${totalCreated}`);
  console.log(`Total Failed: ${totalFailed}`);
  console.log("============================================");
  process.exit(0);
}

seedFirestore();
