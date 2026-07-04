const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '../.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.supabase_service_role;

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error("Missing SUPABASE_URL or supabase_service_role");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const batches = [
  'batch_1_products_catalog.json',
  'batch_2_products_catalog.json',
  'batch_3_products_catalog.json'
];

async function seedLegacyProducts() {
  console.log("============================================");
  console.log("SEEDING LEGACY 'PRODUCTS' TABLE");
  console.log("This will trigger sync-to-firestore webhook.");
  console.log("============================================");

  // Get a shop
  let shopId;
  const { data: shops } = await supabase.from('shops').select('id').limit(1);
  if (shops && shops.length > 0) {
    shopId = shops[0].id;
  } else {
    // We need an owner_id from customers for the new shop.
    let ownerId;
    const { data: customers } = await supabase.from('customers').select('id').limit(1);
    if (customers && customers.length > 0) {
      ownerId = customers[0].id;
    } else {
      const { data: newCust, error: custErr } = await supabase.from('customers').insert({
        id: '11111111-1111-1111-1111-111111111111',
        email: 'dummy@fufaji.com',
        phone: '+919999999999',
        full_name: 'Dummy Owner',
        account_type: 'shop_owner'
      }).select('id').single();
      
      if (custErr) {
        console.error("Failed to create customer:", custErr);
        process.exit(1);
      }
      ownerId = newCust.id;
    }
    
    const { data: newShop, error: shopErr } = await supabase
      .from('shops')
      .insert({ 
        name: 'Fufaji Store MVP', 
        owner_id: ownerId,
        address_line: '123 Test St',
        latitude: 28.6139,
        longitude: 77.2090
      })
      .select('id')
      .single();
      
    if (shopErr) {
      console.error("Failed to create shop:", shopErr);
      process.exit(1);
    }
    shopId = newShop.id;
  }

  let totalCreated = 0;

  for (const batchFile of batches) {
    console.log(`\nProcessing ${batchFile}...`);
    const filePath = path.join(__dirname, batchFile);
    if (!fs.existsSync(filePath)) continue;

    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const products = data.products || [];

    for (const p of products) {
      try {
        const mainVariant = (p.variants && p.variants.length > 0) ? p.variants[0] : null;
        
        // We do NOT provide an ID, we let Postgres generate a UUID.
        // We will store the original code in the description or name if needed,
        // but the app doesn't seem to care as long as it has a name and price.
        
        const { error } = await supabase.from('products').insert({
          shop_id: shopId,
          name: p.name,
          description: p.description || p.productId,
          category: p.category || 'other',
          subcategory: '',
          price: mainVariant ? mainVariant.sellingPrice : 0,
          compare_price: mainVariant ? mainVariant.mrp : null,
          main_image_url: `https://via.placeholder.com/300?text=${encodeURIComponent(p.name)}`,
          total_quantity: mainVariant ? (mainVariant.stock || 50) : 0,
          is_active: true
        });

        if (error) {
           console.error(`Failed on product ${p.name}:`, error.message);
        } else {
           totalCreated++;
        }
      } catch (e) {
        console.error(`Failed on product ${p.name}:`, e.message);
      }
    }
    console.log(`Finished ${batchFile}`);
  }

  console.log(`\nLegacy Seeding Complete. Inserted ${totalCreated} products.`);
  console.log("These should now be synced to Firestore via the edge function.");
}

seedLegacyProducts();
