const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const SUPABASE_URL = 'https://mxjtgpunctckovtuyfmz.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14anRncHVuY3Rja292dHV5Zm16Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ4OTYzNywiZXhwIjoyMDk4MDY1NjM3fQ.BjMsLfwX1dxing4-lX6vSxG4Zx7XoSA2ZJOpwHd-ShI';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function seed() {
  const batch1 = JSON.parse(fs.readFileSync('batch_1_products_catalog.json', 'utf8'));
  const batch2 = JSON.parse(fs.readFileSync('batch_2_products_catalog.json', 'utf8'));
  
  const allProducts = [...batch1.products, ...batch2.products];
  console.log(`Loaded ${allProducts.length} products`);
  
  let successCount = 0;
  let failCount = 0;

  for (const p of allProducts) {
    const item = {
      // Try mapping fields
      // id: p.productId, // maybe sku instead?
      sku: p.productId,
      name: p.name,
      hindi_name: p.hindiName,
      
      category: p.category,
      product_type: p.productType,
      description: p.description,
      unit: p.unit,
      unit_type: p.unitType,
      variants: p.variants,
      is_active: true,
      search_tokens: [p.name, p.hindiName],
      voice_enabled: true
    };
    
    const { error } = await supabase.from('products').insert(item);
    
    if (error) {
      console.log(`Failed to insert ${p.productId}: ${error.message}`);
      failCount++;
      // Just print first error and exit to inspect
      if (failCount === 1) {
          console.log("First error details:", error);
          break;
      }
    } else {
      successCount++;
    }
  }
  
  console.log(`Success: ${successCount}, Fail: ${failCount}`);
}

seed();
