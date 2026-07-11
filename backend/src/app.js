// Express app. Webhooks MUST be mounted with a raw body parser (for HMAC)
// BEFORE express.json(), otherwise the JSON parser consumes the stream and the
// signature can't be verified.

const express = require('express');
const cors = require('cors');
const firebaseAdmin = require('./services/firebaseAdmin');

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
const authOperational = require('./routes/auth-operational');
const adminAuth = require('./routes/admin-auth');
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

// 1) Raw body ONLY for webhooks (signature verification).
app.use('/webhooks', express.raw({ type: '*/*', limit: '1mb' }), webhooks);

// 2) JSON for everything else.
app.use(express.json({ limit: '1mb' }));

// Health check (no auth) — ported from verifyBackendHealth's basic ping.
app.get('/health', (req, res) => res.json({ success: true, status: 'ok', ts: Date.now() }));

// Public configuration (no auth) — loaded by app at startup
app.use('/config', config);

// Feature routes.
app.use('/checkout', checkout);
app.use('/payments', payments);
app.use('/admin', admin);
app.use('/admin/auth', adminAuth);
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
