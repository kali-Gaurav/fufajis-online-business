const fs = require('fs');
const path = require('path');
const https = require('https');

// Helper to load .env file
function loadEnv() {
  const envPath = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(envPath)) {
    console.error('.env file not found!');
    process.exit(1);
  }
  const content = fs.readFileSync(envPath, 'utf8');
  const env = {};
  content.split('\n').forEach(line => {
    const match = line.match(/^\s*([\w.-]+)\s*=\s*(.*)?\s*$/);
    if (match) {
      const key = match[1];
      let value = match[2] || '';
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      } else if (value.startsWith("'") && value.endsWith("'")) {
        value = value.substring(1, value.length - 1);
      }
      env[key] = value.trim();
    }
  });
  return env;
}

const env = loadEnv();
const token = env.WHATSAPP_TOKEN;
const phoneId = env.WHATSAPP_PHONE_ID;

if (!token || !phoneId) {
  console.error('WHATSAPP_TOKEN or WHATSAPP_PHONE_ID not found in .env');
  process.exit(1);
}

console.log('Using Phone Number ID:', phoneId);
console.log('Token length:', token.length);

function makeRequest(url, method = 'GET', body = null) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const options = {
      hostname: parsedUrl.hostname,
      path: parsedUrl.pathname + parsedUrl.search,
      method: method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({
            statusCode: res.statusCode,
            body: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            body: data
          });
        }
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function run() {
  try {
    // 1. Get Phone Number ID Info (to find WABA ID)
    console.log('\n--- Fetching Phone Number Details ---');
    const phoneRes = await makeRequest(`https://graph.facebook.com/v23.0/${phoneId}`);
    if (phoneRes.statusCode !== 200) {
      console.error('Failed to fetch phone number details:', phoneRes.body);
      return;
    }
    console.log('Phone details response:', JSON.stringify(phoneRes.body, null, 2));
    
    // The response contains the waba ID inside the "whatsapp_business_account" property, or similar
    const wabaId = phoneRes.body.whatsapp_business_account?.id || phoneRes.body.whatsapp_business_account;
    if (!wabaId) {
      console.error('Could not determine WhatsApp Business Account ID from phone response.');
      return;
    }
    console.log('\nDetected WABA ID (WhatsApp Business Account ID):', wabaId);

    // 2. Fetch Templates
    console.log('\n--- Fetching Existing Message Templates ---');
    const templatesRes = await makeRequest(`https://graph.facebook.com/v23.0/${wabaId}/message_templates?limit=100`);
    if (templatesRes.statusCode !== 200) {
      console.error('Failed to fetch templates:', templatesRes.body);
      return;
    }
    console.log(`Found ${templatesRes.body.data?.length || 0} templates.`);
    if (templatesRes.body.data && templatesRes.body.data.length > 0) {
      templatesRes.body.data.forEach(tpl => {
        console.log(`- Name: ${tpl.name} | Category: ${tpl.category} | Status: ${tpl.status} | Language: ${tpl.language}`);
        const bodyComp = tpl.components?.find(c => c.type === 'BODY');
        if (bodyComp) {
          console.log(`  Text: "${bodyComp.text}"`);
        }
      });
    }
  } catch (error) {
    console.error('Error running script:', error);
  }
}

run();
