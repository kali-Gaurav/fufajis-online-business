// Express app. Webhooks MUST be mounted with a raw body parser (for HMAC)
// BEFORE express.json(), otherwise the JSON parser consumes the stream and the
// signature can't be verified.

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const firebaseAdmin = require('./services/firebaseAdmin');
const { requestLoggingMiddleware } = require('./services/logger');

// Pre-initialize Firebase if we have a service account in env (Railway path)
if (process.env.FIREBASE_SERVICE_ACCOUNT || process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  firebaseAdmin.init().catch(err => console.error('[app] Firebase init failed:', err));
}

const webhooks = require('./routes/webhooks');
const checkout = require('./routes/checkout-routes');
const payments = require('./routes/payments');
const admin = require('./routes/admin');
const storage = require('./routes/storage');
const invoices = require('./routes/invoices');
const auth = require('./routes/auth');
const authOperational = require('./routes/auth_operational_login');
const orders = require('./routes/orders');
const payouts = require('./routes/payouts');
const ai = require('./routes/ai');
const delivery = require('./routes/delivery');
const reports = require('./routes/reports');
const whatsapp = require('./routes/whatsapp');
const operations = require('./routes/operations');
const pricing = require('./routes/pricing');
const support = require('./routes/support');
const recommendations = require('./routes/recommendations');
const notifications = require('./routes/notifications');
const config = require('./routes/config');
const mfa = require('./routes/mfa');
const sync = require('./routes/sync');
const systemFlags = require('./routes/system-flags');

const app = express();

// 0) Enable CORS for all origins (Required for Flutter Web/External access)
app.use(cors());

// 0-logger) Structured logging middleware (MUST be early for request context)
app.use(requestLoggingMiddleware);

// 0a) Security middleware
app.use(helmet()); // Security headers
app.use(compression()); // Response compression
app.use(morgan('combined')); // Structured logging

// 0b) Rate limiting (general)
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
});
app.use(limiter);

// 1) Raw body ONLY for webhooks (signature verification).
app.use('/webhooks', express.raw({ type: '*/*', limit: '1mb' }), webhooks);

// 2) JSON for everything else.
app.use(express.json({ limit: '1mb' }));

// 3) Health check (no auth) — liveness & readiness probes
app.get('/health', (req, res) => res.json({ success: true, status: 'ok', ts: Date.now() }));

// 3a) Sync worker health endpoint
app.get('/health/sync-worker', async (req, res) => {
  try {
    const syncWorker = require('./services/firestore-sync-worker');
    const health = await syncWorker.getHealth();
    return res.json({
      success: true,
      status: 'healthy',
      worker: health,
      ts: Date.now(),
    });
  } catch (error) {
    console.error('[app] /health/sync-worker error:', error.message);
    return res.status(503).json({
      success: false,
      status: 'unhealthy',
      error: error.message,
      ts: Date.now(),
    });
  }
});

// 3b) Worker control endpoints (for ops/monitoring) — require WORKER_CONTROL_TOKEN
const verifyWorkerToken = (req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  const expectedToken = process.env.WORKER_CONTROL_TOKEN;

  if (!expectedToken) {
    console.warn('[app] WORKER_CONTROL_TOKEN not set — worker control disabled');
    return res.status(503).json({ error: 'Worker control not configured', ts: Date.now() });
  }

  if (!token || token !== expectedToken) {
    console.warn('[app] /worker/* unauthorized attempt');
    return res.status(401).json({ error: 'Unauthorized', ts: Date.now() });
  }

  next();
};

app.post('/worker/sync-start', verifyWorkerToken, (req, res) => {
  try {
    const syncWorker = require('./services/firestore-sync-worker');
    syncWorker.start();
    return res.json({ success: true, message: 'Sync worker started', ts: Date.now() });
  } catch (error) {
    console.error('[app] /worker/sync-start error:', error.message);
    return res.status(500).json({ success: false, error: error.message, ts: Date.now() });
  }
});

app.post('/worker/sync-stop', verifyWorkerToken, (req, res) => {
  try {
    const syncWorker = require('./services/firestore-sync-worker');
    syncWorker.stop();
    return res.json({ success: true, message: 'Sync worker stopped', ts: Date.now() });
  } catch (error) {
    console.error('[app] /worker/sync-stop error:', error.message);
    return res.status(500).json({ success: false, error: error.message, ts: Date.now() });
  }
});

// Public configuration (no auth) — loaded by app at startup
app.use('/config', config);

// Feature routes.
app.use('/checkout', checkout);
app.use('/payments', payments);
app.use('/admin', admin);
app.use('/storage', storage);
app.use('/invoices', invoices);
app.use('/auth', auth);
app.use('/auth', authOperational);
app.use('/mfa', mfa);
app.use('/orders', orders);
app.use('/payouts', payouts);
app.use('/ai', ai);
app.use('/delivery', delivery);
app.use('/logistics', delivery);
app.use('/reports', reports);
app.use('/whatsapp', whatsapp);
app.use('/operations', operations);
app.use('/pricing', pricing);
app.use('/support', support);
app.use('/recommendations', recommendations);
app.use('/notifications', notifications);

// PHASE C: Sync Engine Routes
app.use('/sync', sync);
app.use('/system-flags', systemFlags);

// Fallback.
app.use((req, res) => res.status(404).json({ success: false, error: 'not_found' }));

module.exports = app;
