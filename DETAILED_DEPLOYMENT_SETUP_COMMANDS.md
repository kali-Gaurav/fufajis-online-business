# 🔧 FUFAJI STORE - DETAILED DEPLOYMENT SETUP (STEP-BY-STEP COMMANDS)

**Last Updated:** June 28, 2026  
**Format:** Copy-paste ready commands  
**Tested On:** Windows 10/11, macOS, Linux

---

## 📝 TABLE OF CONTENTS

1. [Windows Terminal Setup](#windows-terminal-setup)
2. [Environment Variables Collection (MASTER LIST)](#environment-variables-master-list)
3. [Option 1: Supabase Edge Functions Deployment](#option-1-supabase-edge-functions-deployment)
4. [Option 2: Railway.app Backend Deployment](#option-2-railwayapp-backend-deployment)
5. [Option 3: Render.com Backend Deployment](#option-3-rendercom-backend-deployment)
6. [Database Setup Commands](#database-setup-commands)
7. [Mobile App Build & Release Commands](#mobile-app-build--release-commands)
8. [Testing Verification Commands](#testing-verification-commands)

---

## 🪟 WINDOWS TERMINAL SETUP

### Step 1: Install Required Tools

Open **Windows PowerShell as Administrator** and run:

```powershell
# Install Chocolatey (if not already installed)
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Node.js
choco install nodejs -y

# Install Git
choco install git -y

# Install Flutter SDK
choco install flutter -y

# Install Android Studio
choco install androidstudio -y

# Close and reopen PowerShell for changes to take effect
```

### Step 2: Verify Installations

```powershell
node --version
# Expected: v18.x.x or higher

npm --version
# Expected: 8.x.x or higher

git --version
# Expected: git version 2.x.x

flutter --version
# Expected: Flutter 3.x.x

docker --version
# Expected: Docker version 20.x.x (if needed)
```

### Step 3: Setup Flutter

```powershell
# Navigate to your project
cd C:\Projects\fufaji-online-business

# Get Flutter packages
flutter pub get

# Run pub get in all packages
flutter pub upgrade

# Check Flutter setup
flutter doctor
```

---

## 🔐 ENVIRONMENT VARIABLES MASTER LIST

### Create Secure Credentials File

**Location:** `C:\Users\[YourUsername]\fufaji-secrets.txt` (KEEP THIS SECURE - DO NOT COMMIT)

Copy this template and fill in your actual values:

```
================================================================================
FUFAJI STORE - COMPLETE CREDENTIALS LIST (2026-06-28)
================================================================================

SECTION 1: FIREBASE CREDENTIALS
--------------------------------------------------------------------------------
Firebase Project ID: fufaji-store-prod
Firebase Private Key: -----BEGIN PRIVATE KEY-----
[Copy entire private key here including newlines]
-----END PRIVATE KEY-----

Firebase Client Email: firebase-adminsdk-xxxxx@fufaji-store-prod.iam.gserviceaccount.com
Firebase Client ID: 123456789
Firebase Auth Domain: fufaji-store-prod.firebaseapp.com
Firebase Database URL: https://fufaji-store-prod.firebaseio.com
Firebase Storage Bucket: fufaji-store-prod.appspot.com
Firebase Public API Key: AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

SECTION 2: RAZORPAY CREDENTIALS
--------------------------------------------------------------------------------
Razorpay Key ID (Public): rzp_live_xxxxx
Razorpay Key Secret (Private): xxxxxxxxxxxxxxxxxxxxx
Razorpay Webhook Secret: xxxxxxxxxxxxxxxxxxxxx
Razorpay Test Key ID: rzp_test_xxxxx
Razorpay Test Key Secret: xxxxxxxxxxxxxxxxxxxxx

SECTION 3: SUPABASE CREDENTIALS
--------------------------------------------------------------------------------
Supabase Project ID: mxjtgpunctckovtuyfmz
Supabase URL: https://mxjtgpunctckovtuyfmz.supabase.co
Supabase Public Key (anon): eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Supabase Secret Key (service role): eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Supabase Database Password: xxxxxxxxxxxxxxxxxxxxx
Supabase Database User: postgres
Supabase Database Host: mxjtgpunctckovtuyfmz.supabase.co
Supabase Database Port: 5432

SECTION 4: TWILIO CREDENTIALS
--------------------------------------------------------------------------------
Twilio Account SID: ACxxxxxxxxxxxxxxxxxxxxx
Twilio Auth Token: xxxxxxxxxxxxxxxxxxxxx
Twilio Phone Number: +1XXXXXXXXXX
Twilio Service SID: MGxxxxxxxxxxxxxxxxxxxxxx

SECTION 5: SENDGRID CREDENTIALS
--------------------------------------------------------------------------------
SendGrid API Key: SG.xxxxxxxxxxxxxxxxxxxxx
SendGrid From Email: noreply@fufaji.com
SendGrid From Name: Fufaji Store

SECTION 6: SENTRY CREDENTIALS
--------------------------------------------------------------------------------
Sentry DSN (Public): https://xxxxx@xxxxx.ingest.sentry.io/xxxxxx
Sentry Auth Token: sntrys_eyJ...
Sentry Organization: fufaji-org
Sentry Project: fufaji-store-mobile

SECTION 7: JWT & SECURITY SECRETS
--------------------------------------------------------------------------------
JWT Secret: your-super-secret-jwt-key-min-32-chars-xxxxxxxx
JWT Expiry (hours): 24
Refresh Token Expiry (days): 7
OTP Expiry (minutes): 5

SECTION 8: DATABASE SECRETS
--------------------------------------------------------------------------------
PostgreSQL Username: postgres
PostgreSQL Password: xxxxxxxxxxxxxxxxxxxxx
PostgreSQL Database: fufaji_store
PostgreSQL Host: mxjtgpunctckovtuyfmz.supabase.co
PostgreSQL Port: 5432

SECTION 9: STRIPE (Optional - if using Stripe)
--------------------------------------------------------------------------------
Stripe Public Key: pk_live_xxxxxx
Stripe Secret Key: sk_live_xxxxxx

SECTION 10: GOOGLE CLOUD CREDENTIALS (Optional)
--------------------------------------------------------------------------------
GCP Project ID: fufaji-store-gcp
GCS Bucket: fufaji-store-bucket
GCP Service Account Key: [JSON content]

================================================================================
STORAGE LOCATIONS:
- Keep this file OFFLINE, ENCRYPTED, and PRIVATE
- DO NOT commit to GitHub
- DO NOT share via email or messaging
- Access only from secure machine
- Rotate keys quarterly
================================================================================
```

**IMPORTANT SECURITY RULES:**
1. ✅ Store in encrypted password manager (LastPass, 1Password, Bitwarden)
2. ✅ Store one copy in secure offline location (USB drive, physical safe)
3. ✅ DO NOT share via email, Slack, or messaging
4. ✅ DO NOT store in Google Drive or cloud
5. ✅ DO NOT commit to GitHub
6. ✅ Rotate all keys every 3 months

---

## 📦 OPTION 1: SUPABASE EDGE FUNCTIONS DEPLOYMENT

### Step 1: Install Supabase CLI

```bash
# Open PowerShell or Terminal
# Install globally
npm install -g supabase

# Verify installation
supabase --version
# Expected: supabase-cli 1.x.x
```

### Step 2: Create Environment Variables File

**Location:** `C:\Projects\fufaji-online-business\.env`

```bash
# DO NOT COMMIT THIS FILE TO GIT
# Add to .gitignore first

# Supabase Configuration
SUPABASE_PROJECT_ID=mxjtgpunctckovtuyfmz
SUPABASE_URL=https://mxjtgpunctckovtuyfmz.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Firebase Configuration
FIREBASE_PROJECT_ID=fufaji-store-prod
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@fufaji-store-prod.iam.gserviceaccount.com

# Razorpay Configuration
RAZORPAY_KEY_ID=rzp_live_xxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=xxxxxxxxxxxxxxxxxxxxx

# Twilio Configuration
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxx
TWILIO_PHONE_NUMBER=+1XXXXXXXXXX

# SendGrid Configuration
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxx

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-min-32-chars
```

### Step 3: Login to Supabase

```bash
# Start login process
supabase login

# Follow browser prompt to authenticate
# Select your project when prompted
```

### Step 4: Link to Your Project

```bash
cd C:\Projects\fufaji-online-business

# Link to Supabase project
supabase link --project-ref mxjtgpunctckovtuyfmz

# You'll be prompted to enter your database password
# Enter: [your PostgreSQL password from MASTER LIST]
```

### Step 5: Set Secrets

**For Auth Endpoints:**
```bash
supabase secrets set FIREBASE_PROJECT_ID "fufaji-store-prod"

supabase secrets set FIREBASE_PRIVATE_KEY "-----BEGIN PRIVATE KEY-----
[Paste entire private key here - copy from MASTER LIST]
-----END PRIVATE KEY-----"

supabase secrets set FIREBASE_CLIENT_EMAIL "firebase-adminsdk-xxxxx@fufaji-store-prod.iam.gserviceaccount.com"

supabase secrets set JWT_SECRET "your-super-secret-jwt-key-min-32-chars"

supabase secrets set TWILIO_ACCOUNT_SID "ACxxxxxxxxxxxxxxxxxxxxx"

supabase secrets set TWILIO_AUTH_TOKEN "xxxxxxxxxxxxxxxxxxxxx"

supabase secrets set TWILIO_PHONE_NUMBER "+1XXXXXXXXXX"

supabase secrets set SENDGRID_API_KEY "SG.xxxxxxxxxxxxxxxxxxxxx"
```

**For Payment Endpoints:**
```bash
supabase secrets set RAZORPAY_KEY_ID "rzp_live_xxxxx"

supabase secrets set RAZORPAY_KEY_SECRET "xxxxxxxxxxxxxxxxxxxxx"

supabase secrets set RAZORPAY_WEBHOOK_SECRET "xxxxxxxxxxxxxxxxxxxxx"
```

### Step 6: Verify Secrets

```bash
# List all secrets (without values)
supabase secrets list

# Expected output:
# name                               created_at
# FIREBASE_PROJECT_ID                2026-06-28T10:00:00Z
# FIREBASE_PRIVATE_KEY               2026-06-28T10:00:01Z
# RAZORPAY_KEY_ID                    2026-06-28T10:00:02Z
# ...
```

### Step 7: Deploy Functions

```bash
# Deploy Auth Endpoints
supabase functions deploy auth-endpoints

# Expected output:
# ✓ Function auth-endpoints deployed successfully
# Endpoint: https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/auth-endpoints

# Deploy Payment Endpoints
supabase functions deploy payment-endpoints

# Deploy Error Handling
supabase functions deploy error-handling
```

### Step 8: Verify Deployment

```bash
# Get function URLs
supabase functions list

# Test auth endpoint (replace with actual URL)
curl -X POST "https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/auth-endpoints" \
  -H "Content-Type: application/json" \
  -d '{"action":"test"}'

# Expected: { "status": "ok" } or error response
```

---

## 🚂 OPTION 2: RAILWAY.APP BACKEND DEPLOYMENT

### Step 1: Create Railway.app Account

1. Go to: https://railway.app
2. Click "Sign up"
3. Select "GitHub" authentication
4. Authorize Railway to access your GitHub
5. Create project: "Fufaji Store Production"

### Step 2: Install Railway CLI

```bash
# Install Railway CLI
npm install -g @railway/cli

# Verify installation
railway --version
# Expected: Railway CLI v5.x.x

# Login to Railway
railway login

# Follow browser prompt to authenticate
```

### Step 3: Initialize Railway Project

```bash
cd C:\Projects\fufaji-online-business

# Initialize Railway project
railway init

# Select:
# - Project name: "Fufaji Store"
# - Environment: "production"
```

### Step 4: Create Dockerfile

**Location:** `C:\Projects\fufaji-online-business\Dockerfile`

```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8080/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# Start server
CMD ["node", "supabase/functions/auth-endpoints/index.ts"]
```

### Step 5: Create package.json

**Location:** `C:\Projects\fufaji-online-business\package.json`

```json
{
  "name": "fufaji-store-backend",
  "version": "1.0.0",
  "description": "Fufaji Store Backend API",
  "main": "index.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.38.0",
    "firebase-admin": "^12.0.0",
    "express": "^4.18.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "axios": "^1.5.0",
    "crypto": "^1.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.7.0"
  }
}
```

### Step 6: Set Environment Variables in Railway

```bash
# Set variables in Railway dashboard
railway service add env

# Or via CLI:
railway variables set FIREBASE_PROJECT_ID="fufaji-store-prod"
railway variables set FIREBASE_PRIVATE_KEY="[paste from MASTER LIST]"
railway variables set RAZORPAY_KEY_ID="rzp_live_xxxxx"
railway variables set RAZORPAY_KEY_SECRET="[paste from MASTER LIST]"
railway variables set TWILIO_ACCOUNT_SID="ACxxxxxxxxxxxxxxxxxxxxx"
railway variables set TWILIO_AUTH_TOKEN="[paste from MASTER LIST]"
railway variables set SENDGRID_API_KEY="SG.[paste from MASTER LIST]"
railway variables set JWT_SECRET="[paste from MASTER LIST]"
```

### Step 7: Deploy to Railway

```bash
# Link to project (if not done in init)
railway link

# Deploy
railway up

# Expected output:
# ✓ Deployment successful
# App URL: https://fufaji-store-production.railway.app

# View logs
railway logs

# View all deployments
railway deployments
```

### Step 8: Configure Domain

In Railway Dashboard:
1. Navigate to "Settings" → "Custom Domain"
2. Add domain: `api.fufaji.com` or `backend.fufaji.com`
3. Update DNS records at your registrar:
   ```
   Type: CNAME
   Name: api
   Value: [Railway provided domain]
   ```

---

## 🎨 OPTION 3: RENDER.COM BACKEND DEPLOYMENT

### Step 1: Create Render.com Account

1. Go to: https://render.com
2. Click "Sign up"
3. Select "GitHub" authentication
4. Authorize Render to access your GitHub
5. Create new Web Service

### Step 2: Create render.yaml Configuration

**Location:** `C:\Projects\fufaji-online-business\render.yaml`

```yaml
services:
  - type: web
    name: fufaji-store-api
    env: node
    plan: standard
    buildCommand: npm install
    startCommand: node index.js
    healthCheckPath: /health
    envVars:
      - key: FIREBASE_PROJECT_ID
        value: fufaji-store-prod
      - key: NODE_ENV
        value: production
    envVarsFile: .env
    disk:
      name: data
      mountPath: /var/data
      sizeGB: 10

databases:
  - name: fufaji-postgres
    databaseName: fufaji_store
    user: postgres
    plan: standard
    postgresVersion: "15"
```

### Step 3: Deploy to Render

**Option A: Via Web Dashboard**

1. Go to https://dashboard.render.com
2. Click "Create +" → "Web Service"
3. Connect GitHub repository
4. Select repository: `kali-Gaurav/fufajis-online-business`
5. Branch: `main`
6. Build command: `npm install`
7. Start command: `node index.js`
8. Environment: Node.js
9. Plan: Standard ($7/month)

**Option B: Via CLI** (if available)

```bash
# Install Render CLI
npm install -g @render-sh/cli

# Login
render login

# Deploy
render deploy
```

### Step 4: Set Environment Variables

In Render Dashboard:
1. Go to Web Service → Environment
2. Add each variable:
   ```
   FIREBASE_PROJECT_ID = fufaji-store-prod
   FIREBASE_PRIVATE_KEY = [from MASTER LIST]
   RAZORPAY_KEY_ID = rzp_live_xxxxx
   RAZORPAY_KEY_SECRET = [from MASTER LIST]
   TWILIO_ACCOUNT_SID = ACxxxxxxxxxxxxxxxxxxxxx
   TWILIO_AUTH_TOKEN = [from MASTER LIST]
   SENDGRID_API_KEY = SG.[from MASTER LIST]
   JWT_SECRET = [from MASTER LIST]
   ```

### Step 5: Configure Database

In Render Dashboard:
1. Create PostgreSQL Instance
2. Select "PostgreSQL 15"
3. Plan: Starter (free tier)
4. Name: `fufaji-postgres`
5. Database: `fufaji_store`
6. User: `postgres`
7. Password: [generate strong password]

### Step 6: Add Database Connection

1. Copy database connection string from Render
2. Add to Environment Variables:
   ```
   DATABASE_URL = postgresql://postgres:[password]@[host]:[port]/fufaji_store
   ```

### Step 7: Monitor Deployment

```bash
# View deployment logs
# In Render Dashboard → Web Service → Logs

# Expected:
# Server listening on port 3000
# Database connected
```

---

## 💾 DATABASE SETUP COMMANDS

### Step 1: Connect to Database

```bash
# Using Supabase SQL Editor (Recommended)
# 1. Go to Supabase Dashboard
# 2. Click "SQL Editor"
# 3. Paste commands below

# Using psql CLI
# Install PostgreSQL client
choco install postgresql -y

# Connect to database
psql -h mxjtgpunctckovtuyfmz.supabase.co \
     -U postgres \
     -d postgres \
     -p 5432

# Enter password when prompted
```

### Step 2: Create Database

```sql
-- Create main database
CREATE DATABASE fufaji_store;

-- Connect to new database
\c fufaji_store

-- Create schema
CREATE SCHEMA IF NOT EXISTS public;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20) UNIQUE,
    name VARCHAR(255),
    role VARCHAR(50) NOT NULL DEFAULT 'customer',
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_role ON users(role);

-- Create products table
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    category VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES users(id),
    shop_id UUID NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    payment_status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create payment_transactions table
CREATE TABLE IF NOT EXISTS payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(id),
    razorpay_payment_id VARCHAR(255),
    razorpay_order_id VARCHAR(255),
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_payment_order_id ON payment_transactions(order_id);
```

### Step 3: Run Migrations

```bash
# Using Supabase CLI
supabase db push

# Expected output:
# ✓ Running migration 01_init_core_schema.sql
# ✓ Running migration 02_rls_policies.sql
# ✓ Running migration 03_production_schema_advanced.sql
# ✓ Running migration 04_storage_buckets_firestore_sync.sql
```

### Step 4: Verify Tables

```sql
-- In Supabase SQL Editor, run:
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema='public' 
ORDER BY table_name;

-- Should return:
-- users
-- products
-- orders
-- payment_transactions
-- wallets
-- refunds
-- deliveries
-- coupons
-- audit_log
```

---

## 📱 MOBILE APP BUILD & RELEASE COMMANDS

### Step 1: Build APK (Debug)

```bash
cd C:\Projects\fufaji-online-business

# Build debug APK
flutter build apk --debug

# Output: build/app/outputs/flutter-apk/app-debug.apk
# Size: ~150 MB
# Install on device: adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Step 2: Build APK (Release)

```bash
# Set environment variables (Windows)
$env:KEYSTORE_PASSWORD = "your-keystore-password"
$env:KEY_ALIAS = "fufaji-store"
$env:KEY_PASSWORD = "your-key-password"

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
# Size: ~50 MB
```

### Step 3: Build AAB (For Google Play Store)

```bash
# Set environment variables
$env:KEYSTORE_PASSWORD = "your-keystore-password"
$env:KEY_ALIAS = "fufaji-store"
$env:KEY_PASSWORD = "your-key-password"

# Build AAB
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### Step 4: Sign APK Manually (If Needed)

```bash
# Generate signing key (do this ONCE and keep secure)
keytool -genkey -v -keystore keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias fufaji-store \
  -storepass your-keystore-password \
  -keypass your-key-password

# Sign APK
jarsigner -verbose \
  -sigalg SHA1withRSA \
  -digestalg SHA1 \
  -keystore keystore.jks \
  build/app/outputs/flutter-apk/app-release.apk \
  fufaji-store \
  -storepass your-keystore-password \
  -keypass your-key-password
```

### Step 5: Upload to Google Play Store

```bash
# Step 1: Go to https://play.google.com/console
# Step 2: Select your app
# Step 3: Release → Production
# Step 4: Create Release → Upload AAB

# Or use command line (if Play Console API enabled)
# Requires: Google Play API credentials (JSON file)
```

### Step 6: Test App (Before Release)

```bash
# Install on Android device
adb install build/app/outputs/flutter-apk/app-release.apk

# Open app and test:
# 1. Email login
# 2. Google sign-in
# 3. Phone OTP
# 4. Payment flow
# 5. Order tracking
# 6. Real-time updates

# Check logs
flutter logs
```

---

## ✅ TESTING VERIFICATION COMMANDS

### Step 1: Test Supabase Connection

```bash
# Create test script: test-supabase.js
cat > test-supabase.js << 'EOF'
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://mxjtgpunctckovtuyfmz.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
);

// Test connection
async function testConnection() {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .limit(1);
    
    if (error) {
      console.error('Connection error:', error.message);
    } else {
      console.log('✓ Supabase connection successful');
      console.log('Sample user:', data[0]);
    }
  } catch (err) {
    console.error('Error:', err.message);
  }
}

testConnection();
EOF

# Run test
node test-supabase.js
```

### Step 2: Test Firebase Connection

```bash
# Create test script: test-firebase.js
cat > test-firebase.js << 'EOF'
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./firebase-credentials.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'fufaji-store-prod'
});

// Test connection
async function testConnection() {
  try {
    const doc = await admin.firestore().collection('users').limit(1).get();
    console.log('✓ Firebase connection successful');
    console.log('Document count:', doc.size);
  } catch (err) {
    console.error('Connection error:', err.message);
  }
}

testConnection();
EOF

# Run test
node test-firebase.js
```

### Step 3: Test API Endpoints

```bash
# Test Auth Endpoint
curl -X POST "https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/auth-endpoints" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "signup-email",
    "email": "test@example.com",
    "password": "Test@123456"
  }'

# Test Payment Endpoint
curl -X POST "https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/payment-endpoints" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "create-order",
    "items": [{"product_id": "xxx", "quantity": 1}],
    "delivery_address": {"lat": 28.6139, "lng": 77.2090}
  }'
```

### Step 4: Test Email Sending (SendGrid)

```bash
# Create test script: test-sendgrid.js
cat > test-sendgrid.js << 'EOF'
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey('SG.xxxxxxxxxxxxxxxxxxxxx');

const msg = {
  to: 'test@example.com',
  from: 'noreply@fufaji.com',
  subject: 'Fufaji Store - Test Email',
  html: '<strong>Test email successful!</strong>',
};

sgMail.send(msg)
  .then(() => console.log('✓ Email sent successfully'))
  .catch(error => console.error('Error:', error.message));
EOF

# Run test
node test-sendgrid.js
```

### Step 5: Test SMS Sending (Twilio)

```bash
# Create test script: test-twilio.js
cat > test-twilio.js << 'EOF'
const twilio = require('twilio');

const client = twilio('ACxxxxxxxxxxxxxxxxxxxxx', 'xxxxxxxxxxxxxxxxxxxxx');

client.messages
  .create({
    body: 'Fufaji Store: Test SMS',
    from: '+1XXXXXXXXXX',
    to: '+919876543210'
  })
  .then(message => {
    console.log('✓ SMS sent successfully');
    console.log('Message SID:', message.sid);
  })
  .catch(error => console.error('Error:', error.message));
EOF

# Run test
node test-twilio.js
```

### Step 6: Test Razorpay Integration

```bash
# Create test script: test-razorpay.js
cat > test-razorpay.js << 'EOF'
const crypto = require('crypto');
const axios = require('axios');

const RAZORPAY_KEY_ID = 'rzp_test_xxxxx';
const RAZORPAY_KEY_SECRET = 'xxxxxxxxxxxxxxxxxxxxx';

// Create order
async function createOrder() {
  const auth = Buffer.from(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`).toString('base64');
  
  try {
    const response = await axios.post('https://api.razorpay.com/v1/orders', {
      amount: 50000, // 500 INR in paise
      currency: 'INR',
      receipt: `receipt_${Date.now()}`
    }, {
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json'
      }
    });
    
    console.log('✓ Order created successfully');
    console.log('Order ID:', response.data.id);
    return response.data.id;
  } catch (error) {
    console.error('Error:', error.response.data);
  }
}

createOrder();
EOF

# Run test
npm install axios
node test-razorpay.js
```

---

## 🚀 QUICK START SUMMARY

### Complete Deployment in 15 Minutes:

```bash
# 1. Setup environment (5 min)
cd C:\Projects\fufaji-online-business
npm install -g supabase
supabase login
supabase link --project-ref mxjtgpunctckovtuyfmz

# 2. Set secrets (3 min)
supabase secrets set FIREBASE_PROJECT_ID "fufaji-store-prod"
supabase secrets set RAZORPAY_KEY_ID "rzp_live_xxxxx"
# ... set remaining secrets

# 3. Deploy functions (4 min)
supabase functions deploy auth-endpoints
supabase functions deploy payment-endpoints
supabase functions deploy error-handling

# 4. Verify (3 min)
supabase functions list
curl -X POST "https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/auth-endpoints" ...

# DONE! ✅
```

---

## 📞 SUPPORT & TROUBLESHOOTING

### Common Issues & Fixes:

**Issue: "Unauthorized" when deploying**
```bash
# Fix: Re-login
supabase logout
supabase login
```

**Issue: "Secret not found" error**
```bash
# Fix: Verify secret is set
supabase secrets list

# Re-set secret
supabase secrets set RAZORPAY_KEY_ID "your-key"
```

**Issue: Database connection refused**
```bash
# Fix: Verify database password
# Check in Supabase Dashboard → Project Settings → Database

# Re-link project
supabase unlink
supabase link --project-ref mxjtgpunctckovtuyfmz
```

**Issue: Functions deploy fails**
```bash
# Fix: Check function syntax
supabase functions push auth-endpoints --dry-run

# View error details
supabase functions push auth-endpoints --verbose
```

---

**Ready to deploy? Follow the appropriate option (Supabase/Railway/Render) above and refer back to COMPLETE_DEPLOYMENT_GUIDE.md for post-deployment verification!**
