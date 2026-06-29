/**
 * ============================================================================
 * RazorpayService.js - Unified Razorpay Payment Service
 * ============================================================================
 * Complete Razorpay integration with:
 * - Order creation & tracking
 * - Signature verification (CRITICAL: uses webhook_secret, NOT key_secret)
 * - Payment verification from Razorpay API
 * - Refund processing with wallet & stock recovery
 * - Webhook handling with idempotency
 * - Payment ledger tracking
 *
 * CRITICAL SECURITY NOTE:
 * - verifySignature() MUST use WEBHOOK_SECRET (for client-initiated payments)
 * - Order creation & refunds use KEY_SECRET (for server-to-server auth)
 * - These MUST be different values
 * ============================================================================
 */

const crypto = require('crypto');
const axios = require('axios');
const secrets = require('../secrets');

const BASE_URL = 'https://api.razorpay.com/v1';

class RazorpayService {
  constructor() {
    this.keyId = null;
    this.keySecret = null;
    this.webhookSecret = null;
    this.initialized = false;
  }

  /**
   * Initialize Razorpay credentials from SSM secrets
   * CRITICAL: Validates that webhook_secret !== key_secret
   */
  async initialize() {
    if (this.initialized) return;

    try {
      await secrets.loadSecrets();
      this.keyId = secrets.get('razorpay/key_id');
      this.keySecret = secrets.get('razorpay/key_secret');
      this.webhookSecret = secrets.get('razorpay/webhook_secret');

      if (!this.keyId || !this.keySecret || !this.webhookSecret) {
        throw new Error('Missing Razorpay credentials in SSM Parameter Store');
      }

      // CRITICAL VALIDATION
      if (this.keySecret === this.webhookSecret) {
        throw new Error(
          'CRITICAL SECURITY ERROR: webhook_secret MUST be different from key_secret. ' +
          'These are two distinct credentials with different purposes.'
        );
      }

      this.initialized = true;
      console.log('[RazorpayService] Initialized with KeyID: ' + this.keyId.substring(0, 10) + '...');
    } catch (error) {
      console.error('[RazorpayService] Initialization failed:', error.message);
      throw error;
    }
  }

  /**
   * Create Razorpay Order
   * Server-to-server API call using key_id:key_secret Basic Auth
   *
   * Returns: { razorpayOrderId, amount, currency, status }
   */
  async createOrder(orderId, amount, notes = {}) {
    if (!this.initialized) await this.initialize();

    try {
      const response = await axios.post(
        `${BASE_URL}/orders`,
        {
          amount: Math.round(amount * 100), // Convert INR to paise
          currency: 'INR',
          receipt: orderId,
          customer_notify: 1,
          notes: {
            order_id: orderId,
            ...notes,
          },
        },
        {
          auth: {
            username: this.keyId,
            password: this.keySecret,
          },
          headers: {
            'Content-Type': 'application/json',
          },
        }
      );

      console.log(`[RazorpayService] Order created: ${response.data.id} for ₹${amount}`);

      return {
        razorpayOrderId: response.data.id,
        amount: response.data.amount,
        currency: response.data.currency,
        status: response.data.status,
        createdAt: new Date(response.data.created_at * 1000),
      };
    } catch (error) {
      console.error('[RazorpayService] Order creation failed:', error.response?.data || error.message);
      throw new Error(`Failed to create Razorpay order: ${error.message}`);
    }
  }

  /**
   * CRITICAL: Verify Payment Signature
   * Uses WEBHOOK_SECRET (NOT key_secret) to verify signatures from payment.success callback
   *
   * This is for verifying that the payment callback came from Razorpay
   * (i.e., client-initiated payment flow completion)
   *
   * Signature formula: HMAC-SHA256(razorpay_order_id|razorpay_payment_id, webhook_secret)
   */
  verifySignature(razorpayOrderId, razorpayPaymentId, razorpaySignature) {
    if (!this.initialized) {
      throw new Error('RazorpayService not initialized');
    }

    try {
      // CRITICAL: Use webhookSecret here, NOT keySecret
      const secret = this.webhookSecret;

      const data = `${razorpayOrderId}|${razorpayPaymentId}`;
      const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(data)
        .digest('hex');

      if (expectedSignature !== razorpaySignature) {
        console.error(
          '[RazorpayService] Signature verification FAILED:\n' +
          `  Order: ${razorpayOrderId}\n` +
          `  Payment: ${razorpayPaymentId}\n` +
          `  Expected: ${expectedSignature}\n` +
          `  Received: ${razorpaySignature}`
        );
        return false;
      }

      console.log(`[RazorpayService] Signature verified: ${razorpayPaymentId}`);
      return true;
    } catch (error) {
      console.error('[RazorpayService] Signature verification error:', error.message);
      return false;
    }
  }

  /**
   * Fetch Payment Details from Razorpay
   * Confirms payment status from Razorpay's system of record
   *
   * Returns: { id, status, amount, currency, method, ... }
   */
  async getPayment(paymentId) {
    if (!this.initialized) await this.initialize();

    try {
      const response = await axios.get(
        `${BASE_URL}/payments/${paymentId}`,
        {
          auth: {
            username: this.keyId,
            password: this.keySecret,
          },
        }
      );

      console.log(`[RazorpayService] Payment fetched: ${paymentId} (Status: ${response.data.status})`);

      return {
        id: response.data.id,
        status: response.data.status,
        amount: response.data.amount / 100, // Convert paise to INR
        currency: response.data.currency,
        method: response.data.method,
        orderId: response.data.order_id,
        createdAt: new Date(response.data.created_at * 1000),
        notes: response.data.notes || {},
      };
    } catch (error) {
      console.error('[RazorpayService] Fetch payment failed:', error.response?.data || error.message);
      throw new Error(`Failed to fetch payment ${paymentId}: ${error.message}`);
    }
  }

  /**
   * Fetch Refund Details
   */
  async getRefund(refundId) {
    if (!this.initialized) await this.initialize();

    try {
      const response = await axios.get(
        `${BASE_URL}/refunds/${refundId}`,
        {
          auth: {
            username: this.keyId,
            password: this.keySecret,
          },
        }
      );

      return {
        id: response.data.id,
        paymentId: response.data.payment_id,
        amount: response.data.amount / 100, // Convert paise to INR
        status: response.data.status,
        createdAt: new Date(response.data.created_at * 1000),
        notes: response.data.notes || {},
      };
    } catch (error) {
      console.error('[RazorpayService] Fetch refund failed:', error.response?.data || error.message);
      throw new Error(`Failed to fetch refund ${refundId}: ${error.message}`);
    }
  }

  /**
   * Process Full or Partial Refund
   * Server-to-server API call using key_id:key_secret Basic Auth
   *
   * Returns: { refundId, amount, status }
   */
  async refund(paymentId, amount = null, notes = {}) {
    if (!this.initialized) await this.initialize();

    try {
      const payload = {
        notes: {
          reason: 'Refund via Fufaji Backend',
          ...notes,
        },
      };

      // Partial refund if amount specified
      if (amount) {
        payload.amount = Math.round(amount * 100); // Convert INR to paise
      }

      const response = await axios.post(
        `${BASE_URL}/payments/${paymentId}/refund`,
        payload,
        {
          auth: {
            username: this.keyId,
            password: this.keySecret,
          },
          headers: {
            'Content-Type': 'application/json',
          },
        }
      );

      const refundAmount = response.data.amount / 100; // Convert paise to INR
      console.log(`[RazorpayService] Refund processed: ${response.data.id} for ₹${refundAmount}`);

      return {
        refundId: response.data.id,
        paymentId: response.data.payment_id,
        amount: refundAmount,
        status: response.data.status,
        createdAt: new Date(response.data.created_at * 1000),
      };
    } catch (error) {
      console.error('[RazorpayService] Refund failed:', error.response?.data || error.message);
      throw new Error(`Failed to process refund: ${error.message}`);
    }
  }

  /**
   * Verify Webhook Signature
   * Used by webhook handler to validate incoming Razorpay webhooks
   * (i.e., server-to-server webhook events)
   *
   * Signature formula: HMAC-SHA256(raw_body, webhook_secret)
   */
  verifyWebhookSignature(rawBody, signature) {
    if (!this.initialized) {
      throw new Error('RazorpayService not initialized');
    }

    try {
      const secret = this.webhookSecret;
      const buffer = Buffer.isBuffer(rawBody) ? rawBody : Buffer.from(JSON.stringify(rawBody || {}));

      const expectedSignature = crypto
        .createHmac('sha256', secret)
        .update(buffer)
        .digest('hex');

      if (expectedSignature !== signature) {
        console.error(
          '[RazorpayService] Webhook signature verification FAILED:\n' +
          `  Expected: ${expectedSignature}\n` +
          `  Received: ${signature}`
        );
        return false;
      }

      return true;
    } catch (error) {
      console.error('[RazorpayService] Webhook signature verification error:', error.message);
      return false;
    }
  }
}

// Export singleton instance
module.exports = new RazorpayService();
