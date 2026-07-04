const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.supabase_service_role;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function check() {
  console.log('Connecting to:', SUPABASE_URL);
  const { data, error } = await supabase.from('catalog_products').select('count', { count: 'exact', head: true });
  if (error) {
    console.error('❌ Error accessing catalog_products:', error.message);
    if (error.code === '42P01') {
      console.log('Table does not exist. Migrations needed.');
    }
  } else {
    console.log('✅ Successfully accessed catalog_products. Row count:', data);
  }

  const { data: vData, error: vError } = await supabase.from('catalog_variants').select('count', { count: 'exact', head: true });
  if (vError) {
    console.error('❌ Error accessing catalog_variants:', vError.message);
  } else {
    console.log('✅ Successfully accessed catalog_variants. Row count:', vData);
  }
}

check();
