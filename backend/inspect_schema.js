const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.supabase_service_role;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function inspect() {
  console.log('Inspecting:', SUPABASE_URL);

  const tables = ['catalog_products', 'catalog_variants', 'catalog_categories', 'products'];

  for (const table of tables) {
    console.log(`\n--- Table: ${table} ---`);
    const { data, error } = await supabase.from(table).select('*').limit(1);
    if (error) {
      console.error(`Error: ${error.message} (${error.code})`);
    } else if (data && data.length > 0) {
      console.log('Columns:', Object.keys(data[0]));
    } else {
      console.log('Table exists but is empty.');
      // Try to get columns via a more complex query if empty
      const { data: cols, error: colError } = await supabase.rpc('get_table_columns', { table_name: table }).catch(() => ({ data: null, error: null }));
      if (cols) console.log('Columns (from RPC):', cols);
      else console.log('Could not retrieve columns for empty table.');
    }
  }
}

inspect();
