const https = require('https');

function makeRequest(path, method = 'GET') {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'mxjtgpunctckovtuyfmz.supabase.co',
      path: path,
      method: method,
      headers: {
        'apikey': 'sb_publishable_u323xm7LneZqdrsA070dYw_kjtHVImo',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14anRncHVuY3Rja292dHV5Zm16Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ4OTYzNywiImV4cCI6MjA5ODA2NTYzN30.BjMsLfwX1dxing4-lX6vSxG4Zx7XoSA2ZJOpwHd-ShI',
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve({ error: data, status: res.statusCode });
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

async function checkDatabase() {
  console.log('🔍 CHECKING SUPABASE DATABASE SCHEMA...\n');

  try {
    // Get schema info
    const response = await makeRequest('/rest/v1/?apikey=sb_publishable_u323xm7LneZqdrsA070dYw_kjtHVImo');

    if (response.definitions) {
      const tables = Object.keys(response.definitions);
      console.log('📊 Tables found in Supabase:');
      tables.forEach(t => console.log(`   - ${t}`));
    }
  } catch (error) {
    console.error('❌ Error checking database:', error.message);
  }
}

checkDatabase();
