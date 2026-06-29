const fs = require('fs');
const path = require('path');

// 1. Manually load variables from root .env to process.env (like dotenv)
try {
  const envPath = path.join(__dirname, '../../.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    envContent.split(/\r?\n/).forEach(line => {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) return;
      const index = trimmed.indexOf('=');
      if (index === -1) return;
      const key = trimmed.substring(0, index).trim();
      let value = trimmed.substring(index + 1).trim();
      // Remove surrounding quotes if any
      value = value.replace(/^['"]|['"]$/g, '');
      if (key) {
        process.env[key] = value;
      }
    });
    console.log('✅ Loaded root .env environment variables successfully');
  } else {
    console.warn('⚠️ No root .env file found at:', envPath);
  }
} catch (e) {
  console.warn('⚠️ Failed to load root .env:', e.message);
}

const firebaseAdmin = require('./services/firebaseAdmin');
const app = require('./app');
const secrets = require('./secrets');

const port = process.env.PORT || 8000;

async function start() {
  try {
    console.log('⏳ Initializing secrets and Firebase Admin...');
    await secrets.loadSecrets();
    await firebaseAdmin.init();
    console.log('✅ Services initialized successfully.');

    app.listen(port, () => {
      console.log(`\n🚀 Fufaji Backend running locally at http://localhost:${port}`);
      console.log('👉 To check health: curl http://localhost:8000/health');
    });
  } catch (e) {
    console.error('❌ Failed to start local server:', e);
    process.exit(1);
  }
}

start();
