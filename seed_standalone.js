#!/usr/bin/env node

/**
 * STANDALONE SEED SCRIPT - NO DEPENDENCIES
 * Fufaji Store - 2026-07-04
 *
 * Runs completely independently with only Node.js built-ins
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

// Supabase credentials
const SUPABASE_URL = 'https://mxjtgpunctckovtuyfmz.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14anRncHVuY3Rja292dHV5Zm16Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ4OTYzNywiZXhwIjoyMDk4MDY1NjM3fQ.BjMsLfwX1dxing4-lX6vSxG4Zx7XoSA2ZJOpwHd-ShI';
const API_KEY = 'sb_publishable_u323xm7LneZqdrsA070dYw_kjtHVImo';

// Helper: Make HTTPS POST request to Supabase REST API
async function supabaseRequest(endpoint, method = 'GET', body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${SUPABASE_URL}/rest/v1${endpoint}`);
    const options = {
      method: method,
      headers: {
        'apikey': API_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      }
    };

    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(data || '{}'));
          } catch (e) {
            resolve({ statusCode: res.statusCode, rawData: data });
          }
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// Add delay between requests
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Main seeding function
async function seedAllProducts() {
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('🚀 FUFAJI STORE — COMPREHENSIVE PRODUCT SEEDING');
  console.log('═══════════════════════════════════════════════════════════\n');

  let stats = {
    categoriesCreated: 0,
    brandsCreated: 0,
    productsCreated: 0,
    productsSkipped: 0,
    variantsCreated: 0,
    variantsSkipped: 0,
    errors: []
  };

  try {
    // STEP 1: Verify schema
    console.log('📊 STEP 1: Checking Supabase schema...');
    try {
      const catalogCheck = await supabaseRequest('/catalog_products?limit=1');
      console.log('   ✅ catalog_products table exists');
    } catch (e) {
      console.log('   ⚠️  catalog_products table may not exist yet');
      console.log('   💡 Please apply Migration 07 to your Supabase database first');
      console.log('   Command: npx supabase db push --schema public\n');
    }

    // STEP 2: Load all batch files
    console.log('📂 STEP 2: Loading product batches...');
    const batches = [];
    const baseDir = path.dirname(__filename);
    const batchFiles = [
      'backend/batch_1_products_catalog.json',
      'backend/batch_2_products_catalog.json',
      'backend/batch_3_products_catalog.json'
    ];

    for (const file of batchFiles) {
      const filePath = path.join(baseDir, file);
      try {
        if (fs.existsSync(filePath)) {
          const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
          console.log(`   ✅ ${path.basename(file)}: ${data.products?.length || 0} products`);
          batches.push(...(data.products || []));
        } else {
          console.log(`   ❌ ${file}: NOT FOUND`);
          stats.errors.push(`Batch file not found: ${file}`);
        }
      } catch (e) {
        console.log(`   ❌ Error loading ${file}: ${e.message}`);
        stats.errors.push(`Failed to load ${file}: ${e.message}`);
      }
    }

    console.log(`   📦 Total: ${batches.length} products to seed\n`);

    if (batches.length === 0) {
      console.log('❌ No products found to seed!');
      process.exit(1);
    }

    // STEP 3: Create categories
    console.log('🏷️  STEP 3: Creating categories...');
    const categories = new Set();
    batches.forEach(p => {
      if (p.category) categories.add(p.category);
    });

    for (const category of Array.from(categories)) {
      try {
        const existing = await supabaseRequest(`/catalog_categories?name=eq.${encodeURIComponent(category)}&select=id`, 'GET');
        if (existing.length === 0) {
          const created = await supabaseRequest('/catalog_categories', 'POST', {
            name: category,
            hindi_name: category,
            slug: category.toLowerCase(),
            is_active: true
          });
          if (created && created.length > 0) {
            stats.categoriesCreated++;
          }
        }
        await delay(100);
      } catch (e) {
        console.log(`   ⚠️  Skipped category: ${category}`);
      }
    }
    console.log(`   ✅ Categories ready: ${stats.categoriesCreated} created\n`);

    // STEP 4: Create brands
    console.log('🏢 STEP 4: Creating brands...');
    const brands = new Set();
    batches.forEach(p => {
      if (p.brand) brands.add(p.brand);
    });

    const brandMap = {};
    for (const brand of Array.from(brands)) {
      try {
        const existing = await supabaseRequest(`/catalog_brands?name=eq.${encodeURIComponent(brand)}&select=id`, 'GET');
        if (existing.length > 0) {
          brandMap[brand] = existing[0].id;
        } else {
          const created = await supabaseRequest('/catalog_brands', 'POST', {
            name: brand,
            hindi_name: brand,
            is_active: true
          });
          if (created && created.length > 0 && created[0].id) {
            brandMap[brand] = created[0].id;
            stats.brandsCreated++;
          }
        }
        await delay(100);
      } catch (e) {
        console.log(`   ⚠️  Skipped brand: ${brand}`);
      }
    }
    console.log(`   ✅ Brands ready: ${stats.brandsCreated} created\n`);

    // STEP 5: Seed products and variants
    console.log('🛒 STEP 5: Seeding products and variants...');
    for (let i = 0; i < batches.length; i++) {
      const product = batches[i];
      try {
        // Check if product exists
        const existing = await supabaseRequest(`/catalog_products?product_code=eq.${encodeURIComponent(product.productId)}&select=id`, 'GET');

        let productId;
        if (existing.length > 0) {
          productId = existing[0].id;
          stats.productsSkipped++;
        } else {
          // Create product
          const created = await supabaseRequest('/catalog_products', 'POST', {
            product_code: product.productId,
            name: product.name,
            hindi_name: product.hindiName || product.name,
            brand_id: product.brand && brandMap[product.brand] ? brandMap[product.brand] : null,
            category_id: null,
            product_type: product.productType || 'packaged',
            unit_type: product.unitType || 'weight',
            description: product.description || '',
            is_active: true
          });

          if (created && created.length > 0 && created[0].id) {
            productId = created[0].id;
            stats.productsCreated++;
          } else {
            console.log(`   ⚠️  Failed to create: ${product.name}`);
            continue;
          }
        }

        // Seed variants
        if (product.variants && Array.isArray(product.variants)) {
          for (const variant of product.variants) {
            try {
              const variantExists = await supabaseRequest(`/catalog_variants?variant_code=eq.${encodeURIComponent(variant.variantId)}&select=id`, 'GET');
              if (variantExists.length === 0) {
                const variantCreated = await supabaseRequest('/catalog_variants', 'POST', {
                  variant_code: variant.variantId,
                  product_id: productId,
                  quantity: variant.quantity,
                  unit: variant.unit,
                  mrp: variant.mrp,
                  default_selling_price: variant.sellingPrice,
                  gst: variant.gst || 0,
                  barcode: variant.barcode,
                  is_active: true
                });
                if (variantCreated && variantCreated.length > 0) {
                  stats.variantsCreated++;
                }
              } else {
                stats.variantsSkipped++;
              }
              await delay(50);
            } catch (e) {
              // Variant error - continue
            }
          }
        }

        // Progress indicator every 10 products
        if ((stats.productsCreated + stats.productsSkipped) % 10 === 0) {
          console.log(`   📍 ${stats.productsCreated + stats.productsSkipped}/${batches.length} products processed...`);
        }

        await delay(50);
      } catch (e) {
        stats.errors.push(`${product.name}: ${e.message}`);
      }
    }

    // STEP 6: Final report
    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('✅ SEEDING COMPLETE');
    console.log('═══════════════════════════════════════════════════════════');
    console.log('📊 RESULTS:');
    console.log(`   Categories created: ${stats.categoriesCreated}`);
    console.log(`   Brands created: ${stats.brandsCreated}`);
    console.log(`   Products created: ${stats.productsCreated}`);
    console.log(`   Products skipped (already exist): ${stats.productsSkipped}`);
    console.log(`   Variants created: ${stats.variantsCreated}`);
    console.log(`   Variants skipped: ${stats.variantsSkipped}`);
    console.log(`   Total processed: ${stats.productsCreated + stats.productsSkipped}/${batches.length}`);
    console.log(`   Errors: ${stats.errors.length}`);

    if (stats.errors.length > 0 && stats.errors.length <= 5) {
      console.log(`\n⚠️  ERRORS:`);
      stats.errors.forEach(e => console.log(`   - ${e}`));
    } else if (stats.errors.length > 5) {
      console.log(`\n⚠️  ERRORS (showing first 5 of ${stats.errors.length}):`);
      stats.errors.slice(0, 5).forEach(e => console.log(`   - ${e}`));
      console.log(`   ... and ${stats.errors.length - 5} more`);
    }

    console.log('\n═══════════════════════════════════════════════════════════');
    const success = (stats.productsCreated + stats.productsSkipped) >= batches.length * 0.9;
    console.log(`✅ GO/NO-GO: ${success ? '🟢 GO' : '🔴 NO-GO'}`);
    console.log('═══════════════════════════════════════════════════════════\n');

    console.log('📋 NEXT STEPS:');
    console.log('   1. Verify counts in Supabase: SELECT COUNT(*) FROM catalog_products;');
    console.log('   2. Check Firestore sync is working');
    console.log('   3. Run voice search tests');
    console.log('   4. Proceed to production launch\n');

  } catch (error) {
    console.error('\n❌ CRITICAL ERROR:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run
console.log('Initializing seeding process...\n');
seedAllProducts().catch(e => {
  console.error('Fatal error:', e);
  process.exit(1);
});
