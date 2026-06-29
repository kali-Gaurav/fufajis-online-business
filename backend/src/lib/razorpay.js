// Thin Razorpay REST helper. Same endpoints/auth the old Firebase Functions
// used (Basic auth with key_id:key_secret), just centralized here.

const axios = require('axios');
const secrets = require('../secrets');

const BASE = 'https://api.razorpay.com/v1';

function authHeader() {
  const keyId = secrets.get('razorpay/key_id');
  const keySecret = secrets.get('razorpay/key_secret');
  if (!keyId || !keySecret) throw new Error('Razorpay is not configured on the backend.');
  return 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64');
}

async function createOrder({ amount, currency, receipt, notes }) {
  return axios.post(
    `${BASE}/orders`,
    {
      amount: Math.round(amount * 100), // rupees -> paise
      currency: currency || 'INR',
      receipt: receipt || `receipt_${Date.now()}`,
      notes: notes || {},
    },
    {
      headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
      validateStatus: () => true,
    }
  );
}

async function refund(paymentId, { amount, notes }) {
  const body = { notes: notes || { reason: 'Refund from Owner Panel' } };
  if (amount) body.amount = Math.round(amount * 100); // partial refund, in paise
  return axios.post(`${BASE}/payments/${paymentId}/refund`, body, {
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    validateStatus: () => true,
  });
}

module.exports = { createOrder, refund };
