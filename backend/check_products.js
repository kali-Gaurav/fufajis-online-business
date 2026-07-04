const { createClient } = require('@supabase/supabase-js');
const dotenv = require('dotenv');
const path = require('path');
dotenv.config({ path: path.join(__dirname, '../.env') });

const supabase = createClient(process.env.SUPABASE_URL, process.env.supabase_service_role);

async function check() {
  const { data, error } = await supabase.from('products').select('id').limit(1);
  console.log("products table error:", error);
  console.log("products data:", data);
}
check();
