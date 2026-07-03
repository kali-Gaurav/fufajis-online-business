/**
 * Fufaji Backend Server - Production Ready
 * Handles all startup concerns: env loading, module verification, graceful degradation
 */

const fs = require('fs');
const path = require('path');

// ═══════════════════════════════════════════════════════════════════════
// PHASE 1: Load Environment Variables
// ═══════════════════════════════════════════════════════════════════════

function loadEnvironment() {
  const envPaths = [
    path.join(__dirname, '../../.env'),           // Root .env
    path.join(__dirname, '../.env'),              // Backend .env
    path.join(__dirname, '../../.env.production'), // Production override
  ];

  for (const envPath of envPaths) {
    try {
      if (fs.existsSync(envPath)) {
        const envContent = fs.readFileSync(envPath, 'utf8');
        envContent.split(/\r?\n/).forEach(line => {
          const trimmed = line.trim();
          if (!trimmed || trimmed.startsWith('#')) return;
          const index = trimmed.indexOf('=');
          if (index === -1) return;
          const key = trimmed.substring(0, index).trim();
          let value = trimmed.substring(index + 1).trim();
          value = value.replace(/^['"]|['"]$/g, '');
          if (key && !process.env[key]) {  // Don't override existing vars
            process.env[key] = value;
          }
        });
        console.log(`✅ Loaded environment from: ${envPath}`);
      }
    } catch (e) {
      console.warn(`⚠️  Could not load ${envPath}: ${e.message}`);
    }
  }

  if (!process.env.NODE_ENV) {
    process.env.NODE_ENV = 'production';
  }
  if (!process.env.PORT) {
    process.env.PORT = '3001';
  }
  console.log(`📋 Environment: ${process.env.NODE_ENV}, Port: ${process.env.PORT}`);
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 2: Verify Critical Dependencies
// ═══════════════════════════════════════════════════════════════════════

function verifyDependencies() {
  const critical = ['express', 'firebase-admin', 'dotenv', 'cors'];
  const optional = ['speakeasy', 'twilio', '@sendgrid/mail'];

  console.log('🔍 Verifying dependencies...');

  for (const pkg of critical) {
    try {
      require.resolve(pkg);
      console.log(`  ✅ ${pkg}`);
    } catch (e) {
      console.error(`  ❌ CRITICAL: ${pkg} not found!`);
      process.exit(1);
    }
  }

  for (const pkg of optional) {
    try {
      require.resolve(pkg);
      console.log(`  ✅ ${pkg}`);
    } catch (e) {
      console.warn(`  ⚠️  Optional: ${pkg} not installed (will be mocked)`);
      process.env[`MOCK_${pkg.toUpperCase().replace(/[^A-Z0-9]/g, '_')}`] = 'true';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 3: Setup Graceful Degradation for External Services
// ═══════════════════════════════════════════════════════════════════════

function setupGracefulFallbacks() {
  console.log('🛡️  Setting up graceful fallbacks for external services...');

  // Twilio Mock
  if (!process.env.TWILIO_ACCOUNT_SID || process.env.MOCK_TWILIO) {
    console.warn('⚠️  [SmsService] Twilio not configured - SMS will be logged only');
    process.env.TWILIO_MOCK = 'true';
  }

  // SendGrid Mock
  if (!process.env.SENDGRID_API_KEY || process.env.MOCK_SENDGRID) {
    console.warn('⚠️  [EmailService] SendGrid not configured - Emails will be logged only');
    process.env.SENDGRID_MOCK = 'true';
  }

  // Firebase
  if (!process.env.FIREBASE_PROJECT_ID) {
    console.error('❌ FIREBASE_PROJECT_ID is required!');
    process.exit(1);
  }

  if (!process.env.RAZORPAY_KEY_ID || !process.env.RAZORPAY_KEY_SECRET) {
    console.warn('⚠️  [PaymentService] Razorpay not fully configured');
  }

  console.log('✅ Fallbacks configured');
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 4: Initialize Services
// ═══════════════════════════════════════════════════════════════════════

async function initializeServices() {
  console.log('⏳ Initializing services...');

  try {
    // Load dotenv last (lowest priority)
    require('dotenv').config();

    // Firebase Admin
    const firebaseAdmin = require('./services/firebaseAdmin');
    await firebaseAdmin.init();
    console.log('✅ Firebase Admin initialized');

    // Secrets
    const secrets = require('./secrets');
    await secrets.loadSecrets();
    console.log('✅ Secrets loaded');

    // Initialize database pool
    const pool = require('./db/pool');
    await pool.init();
    console.log('✅ Database pool initialized');

    // Schedule Phase 1 cron jobs
    await scheduleCronJobs();
    console.log('✅ Cron jobs scheduled');

    return true;
  } catch (e) {
    console.error('❌ Failed to initialize services:', e.message);
    throw e;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 5a: Schedule Cron Jobs
// ═══════════════════════════════════════════════════════════════════════

async function scheduleCronJobs() {
  const cron = require('node-cron');
  const CleanupCron = require('./jobs/cleanup-cron');
  const ReconciliationCron = require('./jobs/reconciliation-cron');

  console.log('📅 Scheduling Phase 1 cron jobs...');

  // Cleanup cron: Run every 5 minutes (expire stale reservations, cleanup idempotency keys)
  cron.schedule('*/5 * * * *', async () => {
    try {
      console.log('[Cron] Running cleanup job (every 5 min)...');
      await CleanupCron.execute();
    } catch (err) {
      console.error('[Cron] Cleanup job failed:', err.message);
    }
  });
  console.log('  ✅ Cleanup cron scheduled: every 5 minutes');

  // Reconciliation cron: Run every 1 hour (check stale payments)
  cron.schedule('0 * * * *', async () => {
    try {
      console.log('[Cron] Running reconciliation job (every 1 hour)...');
      await ReconciliationCron.execute();
    } catch (err) {
      console.error('[Cron] Reconciliation job failed:', err.message);
    }
  });
  console.log('  ✅ Reconciliation cron scheduled: every 1 hour');
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 5b: Start Event Worker
// ═══════════════════════════════════════════════════════════════════════

async function startEventWorker() {
  try {
    const EventWorker = require('./workers/event-worker');
    const worker = new EventWorker(`worker-${process.pid}`);

    console.log('⚡ Starting Phase 1 event worker...');
    await worker.start();
    console.log('✅ Event worker started (polling for events every 2 seconds)');

    // Graceful shutdown hook for worker
    process.on('SIGTERM', async () => {
      console.log('\n⏹️  Stopping event worker...');
      await worker.stop();
    });

    process.on('SIGINT', async () => {
      console.log('\n⏹️  Stopping event worker...');
      await worker.stop();
    });
  } catch (err) {
    console.error('⚠️  Failed to start event worker:', err.message);
    console.error('   Event processing disabled. Stale events will accumulate.');
    // Don't exit - event worker is not critical, system can function without it
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PHASE 5: Start Server
// ═══════════════════════════════════════════════════════════════════════

async function startServer() {
  try {
    loadEnvironment();
    verifyDependencies();
    setupGracefulFallbacks();
    await initializeServices();

    const app = require('./app');
    const port = process.env.PORT || 3001;

    app.listen(port, async () => {
      console.log(`\n🚀 ════════════════════════════════════════════════════════`);
      console.log(`🚀 Fufaji Backend Server running on port ${port}`);
      console.log(`🚀 Environment: ${process.env.NODE_ENV}`);
      console.log(`🚀 Health check: GET /health`);
      console.log(`🚀 ════════════════════════════════════════════════════════\n`);

      // Start event worker (non-blocking)
      startEventWorker().catch(err => {
        console.error('Failed to start event worker:', err.message);
      });
    });

    // Graceful shutdown
    process.on('SIGTERM', () => {
      console.log('\n⏹️  SIGTERM received, shutting down gracefully...');
      process.exit(0);
    });

    process.on('SIGINT', () => {
      console.log('\n⏹️  SIGINT received, shutting down gracefully...');
      process.exit(0);
    });

  } catch (error) {
    console.error('\n❌ ════════════════════════════════════════════════════════');
    console.error('❌ Failed to start server:', error.message);
    console.error('❌ Stack:', error.stack);
    console.error('❌ ════════════════════════════════════════════════════════\n');
    process.exit(1);
  }
}

// Start
startServer();
