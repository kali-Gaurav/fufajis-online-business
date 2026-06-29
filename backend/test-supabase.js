require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const url = process.env.SUPABASE_URL || '';
const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';

if (!url || !key) {
  console.error('Missing Supabase credentials in .env');
  process.exit(1);
}

console.log('Testing connection to:', url);

const supabase = createClient(url, key);

async function testConnection() {
  try {
    const { data, error } = await supabase.from('users').select('id').limit(1);
    
    if (error) {
      console.error('Connection failed (Error query):', error.message);
      if (error.code === '42P01') {
        console.log('Connection successful! But the "users" table does not exist yet. This means we need to deploy migrations.');
        process.exit(0);
      }
      process.exit(1);
    }
    
    console.log('Connection successful! Database is accessible. Data:', data);
  } catch (err) {
    console.error('Connection completely failed:', err.message);
    process.exit(1);
  }
}

testConnection();
