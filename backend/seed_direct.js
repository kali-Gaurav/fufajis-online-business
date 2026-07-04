const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '../.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.supabase_service_role; // Must use service role to bypass RLS

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error("Missing SUPABASE_URL or supabase_service_role in root .env");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const batches = [
  'batch_1_products_catalog.json',
  'batch_2_products_catalog.json',
  'batch_3_products_catalog.json'
];

async function seedData() {
  console.log("============================================");
  console.log("DIRECT SEEDING TO SUPABASE");
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
        // Find or create category
        let categoryId = null;
        if (p.category) {
          const { data: catData, error: catErr } = await supabase
            .from('catalog_categories')
            .select('id')
            .eq('slug', p.category)
            .single();
            
          if (catErr && catErr.code === 'PGRST116') {
             // Not found, create
             const { data: newCat, error: newCatErr } = await supabase
               .from('catalog_categories')
               .insert({ name: p.category, slug: p.category })
               .select('id')
               .single();
             if (!newCatErr) categoryId = newCat.id;
          } else if (catData) {
            categoryId = catData.id;
          }
        }
        
        // Find or create brand
        let brandId = null;
        if (p.brand) {
          const { data: brandData, error: brandErr } = await supabase
            .from('catalog_brands')
            .select('id')
            .eq('name', p.brand)
            .single();
            
          if (brandErr && brandErr.code === 'PGRST116') {
             const { data: newBrand, error: newBrandErr } = await supabase
               .from('catalog_brands')
               .insert({ name: p.brand })
               .select('id')
               .single();
             if (!newBrandErr) brandId = newBrand.id;
          } else if (brandData) {
            brandId = brandData.id;
          }
        }

        // Upsert Product
        const { data: prodData, error: prodErr } = await supabase
          .from('catalog_products')
          .upsert({
             product_code: p.productId,
             name: p.name,
             hindi_name: p.hindiName || p.name,
             brand_id: brandId,
             category_id: categoryId,
             product_type: p.productType || 'packaged',
             unit_type: p.unitType || 'weight',
             description: p.description
          }, { onConflict: 'product_code' })
          .select('id')
          .single();

        if (prodErr) throw prodErr;
        const productId = prodData.id;

        // Upsert Variants
        if (p.variants && p.variants.length > 0) {
          for (const v of p.variants) {
            const { error: varErr } = await supabase
              .from('catalog_variants')
              .upsert({
                variant_code: v.variantId,
                product_id: productId,
                mrp: v.mrp,
                default_selling_price: v.sellingPrice,
                unit: v.unit,
                quantity: v.quantity,
                barcode: v.barcode
              }, { onConflict: 'variant_code' });
            
            if (varErr && varErr.code !== '23505') { // Ignore unique constraint if needed, upsert handles it
               throw varErr;
            }
          }
        }
        
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
  console.log("SEED SUMMARY");
  console.log("============================================");
  console.log(`Total Products Synced: ${totalCreated}`);
  console.log(`Total Failed: ${totalFailed}`);
  console.log("============================================");
}

seedData();
