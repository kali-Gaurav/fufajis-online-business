/**
 * FUFAJI STORE - MASTER CATALOG SEEDING SCRIPT
 * Seeds Batches 1, 2, and 3 to Supabase and Firestore (via dual-write triggers)
 * Date: 2026-07-04
 */

const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const { createClient } = require('@supabase/supabase-js');

// 1. CONFIGURATION
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://mxjtgpunctckovtuyfmz.supabase.co';
const SUPABASE_KEY = process.env.supabase_service_role;

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('❌ ERROR: SUPABASE_URL or supabase_service_role missing in .env');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const BATCH_FILES = [
  'batch_1_products_catalog.json',
  'batch_2_products_catalog.json',
  'batch_3_products_catalog.json'
];

// 2. TOKEN GENERATION HELPERS
function generateSearchTokens(name, hindiName) {
  const tokens = new Set();
  if (name) name.split(" ").forEach((word) => {
    if (word.length > 2) tokens.add(word.toLowerCase());
  });
  if (hindiName) hindiName.split(" ").forEach((word) => {
    if (word.length > 0) tokens.add(word);
  });
  return Array.from(tokens);
}

function generatePhoneticTokens(name, aliases) {
  const tokens = new Set();
  if (name) tokens.add(name.toLowerCase());
  if (aliases) aliases.forEach((alias) => tokens.add(alias.toLowerCase()));
  return Array.from(tokens);
}

// 3. MAIN EXECUTION
async function seedCatalog() {
  console.log('============================================');
  console.log('🚀 FUFAJI CATALOG SEEDING INITIATED');
  console.log('============================================');

  // FETCH MAPPINGS
  console.log('📡 Fetching category and brand mappings...');
  const { data: categories, error: catErr } = await supabase.from('catalog_categories').select('id, slug');
  if (catErr) { console.error('Error fetching categories:', catErr.message); process.exit(1); }

  const { data: brands, error: brandErr } = await supabase.from('catalog_brands').select('id, name');
  if (brandErr) { console.error('Error fetching brands:', brandErr.message); process.exit(1); }

  const categoryMap = {};
  categories.forEach(c => categoryMap[c.slug] = c.id);

  const brandMap = {};
  brands.forEach(b => brandMap[b.name] = b.id);

  const genericBrandId = brandMap['Generic'];

  let totalProductsProcessed = 0;
  let totalVariantsProcessed = 0;
  let totalFailed = 0;

  for (const fileName of BATCH_FILES) {
    const filePath = path.join(__dirname, fileName);
    if (!fs.existsSync(filePath)) {
      console.warn(`⚠️ Warning: ${fileName} not found, skipping.`);
      continue;
    }

    console.log(`\n📦 Processing ${fileName}...`);
    let data;
    try {
      data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (e) {
      console.error(`❌ Failed to parse ${fileName}:`, e.message);
      continue;
    }

    const products = data.products || [];

    for (const productData of products) {
      try {
        // Prepare Product Data
        const searchTokens = generateSearchTokens(productData.name, productData.hindiName);
        const voiceMetadata = productData.voiceMetadata || {};
        const phoneticTokens = generatePhoneticTokens(
          productData.name,
          voiceMetadata.aliases || []
        );

        // Resolve Category and Brand
        let categoryId = categoryMap[productData.category];
        if (!categoryId) {
            const normalized = productData.category.toLowerCase().replace(/ /g, '_');
            categoryId = categoryMap[normalized];
        }

        const brandId = brandMap[productData.brand] || genericBrandId;

        // A. Insert/Update Product
        const { data: product, error: productError } = await supabase
          .from('catalog_products')
          .upsert({
            product_code: productData.productId,
            name: productData.name,
            hindi_name: productData.hindiName,
            category_id: categoryId,
            brand_id: brandId,
            description: productData.description,
            product_type: productData.productType || 'packaged',
            unit_type: productData.unitType || 'weight',
            search_tokens: searchTokens,
            phonetic_tokens: phoneticTokens,
            aliases: voiceMetadata.aliases || [],
            hindi_aliases: voiceMetadata.hindiKeywords || [],
            voice_enabled: true,
            voice_patterns: voiceMetadata.voicePatterns || [],
            is_active: true,
            metadata: {
              batch: data.batchId,
              generated_at: data.generatedDate
            }
          }, { onConflict: 'product_code' })
          .select('id')
          .single();

        if (productError) {
          console.error(`\n❌ Supabase product error [${productData.productId}]:`, productError.message);
          throw productError;
        }

        // B. Insert Variants
        const variants = productData.variants || [];
        for (const variantData of variants) {
          const { error: variantError } = await supabase
            .from('catalog_variants')
            .upsert({
              product_id: product.id,
              variant_code: variantData.variantId,
              quantity: variantData.quantity,
              unit: variantData.unit,
              mrp: variantData.mrp,
              default_selling_price: variantData.sellingPrice,
              gst: variantData.gst || 0,
              stock: variantData.stock || 0,
              barcode: variantData.barcode,
              is_active: true
            }, { onConflict: 'variant_code' });

          if (variantError) {
            console.error(`\n❌ Supabase variant error [${variantData.variantId}]:`, variantError.message);
            throw variantError;
          }
          totalVariantsProcessed++;
        }

        totalProductsProcessed++;
        process.stdout.write('.'); // Progress indicator
      } catch (err) {
        totalFailed++;
      }
    }
    console.log(`\n✅ Finished ${fileName}`);
  }

  console.log('\n============================================');
  console.log('🏁 SEEDING SUMMARY');
  console.log(`Total Products: ${totalProductsProcessed}`);
  console.log(`Total Variants: ${totalVariantsProcessed}`);
  console.log(`Total Failed:   ${totalFailed}`);
  console.log('============================================');
}

seedCatalog();
