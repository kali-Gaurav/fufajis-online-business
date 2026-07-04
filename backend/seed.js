const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

// Load environment to get supabase_service_role
dotenv.config({ path: path.join(__dirname, '../.env') });

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://mxjtgpunctckovtuyfmz.supabase.co';
const ADMIN_JWT = process.env.supabase_service_role;

if (!ADMIN_JWT) {
  console.error("ERROR: supabase_service_role not found in root .env");
  process.exit(1);
}

const batches = [
  'batch_1_products_catalog.json',
  'batch_2_products_catalog.json',
  'batch_3_products_catalog.json'
];

async function run() {
  console.log("============================================");
  console.log("FULL CATALOG SEEDING EXECUTION");
  console.log("Batches 1, 2, and 3 (165 Products)");
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

    const data = fs.readFileSync(filePath, 'utf8');
    const parsed = JSON.parse(data);
    console.log(`Found ${parsed.products ? parsed.products.length : 0} products in ${batchFile}`);
    
    const startTime = Date.now();
    try {
      const response = await fetch(`${SUPABASE_URL}/functions/v1/bulk-import-products`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${ADMIN_JWT}`,
          'Content-Type': 'application/json'
        },
        body: data
      });
      
      const resultText = await response.text();
      console.log(`Raw response: ${resultText}`);
      let result;
      try {
        result = JSON.parse(resultText);
      } catch (e) {
        console.error(`Failed to parse response: ${resultText}`);
        continue;
      }
      
      const duration = ((Date.now() - startTime) / 1000).toFixed(1);
      const created = result.createdCount || 0;
      const failed = result.failedCount || 0;
      
      totalCreated += created;
      totalFailed += failed;
      
      console.log(`✓ Created: ${created} products (in ${duration}s)`);
      if (failed > 0) {
        console.warn(`⚠ Warning: ${failed} products failed`);
        if (result.failedProducts) {
          console.warn(`Failed products: ${JSON.stringify(result.failedProducts)}`);
        }
      }
    } catch (e) {
      console.error(`Request failed for ${batchFile}: ${e.message}`);
    }
  }

  console.log("\n============================================");
  console.log("SEED SUMMARY");
  console.log("============================================");
  console.log(`Total Created: ${totalCreated} products`);
  console.log(`Total Failed: ${totalFailed} products`);
  console.log("============================================");
}

run();
