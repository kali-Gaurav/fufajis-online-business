import * as crypto from 'crypto';
import * as functions from 'firebase-functions';
import { RazorpayPaymentStatus } from '../types/webhook.types';

/**
 * Utility functions for webhook processing
 */

/**
 * Validate HMAC-SHA256 signature for Razorpay webhooks
 *
 * @param body Raw request body (string or JSON)
 * @param signature X-Razorpay-Signature header value
 * @param secret Webhook signing secret from Razorpay Dashboard
 * @returns true if signature is valid
 */
export function validateWebhookSignature(
  body: string,
  signature: string,
  secret: string
): boolean {
  if (!secret) {
    functions.logger.warn('[webhook_utils] No webhook secret configured');
    return false;
  }

  if (!signature) {
    functions.logger.warn('[webhook_utils] No signature provided in request');
    return false;
  }

  try {
    const hash = crypto
      .createHmac('sha256', secret)
      .update(body)
      .digest('hex');

    const isValid = hash === signature;

    if (!isValid) {
      functions.logger.warn(
        `[webhook_utils] Signature mismatch. Expected: ${signature.substring(0, 20)}..., Got: ${hash.substring(0, 20)}...`
      );
    }

    return isValid;
  } catch (error) {
    functions.logger.error('[webhook_utils] Signature validation error:', error);
    return false;
  }
}

/**
 * Generate HMAC-SHA256 signature for testing/verification
 *
 * @param body Request body
 * @param secret Webhook signing secret
 * @returns HMAC-SHA256 hex digest
 */
export function generateSignature(body: string, secret: string): string {
  return crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex');
}

/**
 * Extract raw body from Express request
 * Handle both string and Buffer bodies
 *
 * @param body Request body (string, Buffer, or object)
 * @returns Raw body as string
 */
export function getRawBody(body: any): string {
  if (typeof body === 'string') {
    return body;
  }

  if (Buffer.isBuffer(body)) {
    return body.toString('utf-8');
  }

  // If body is already parsed JSON, stringify it
  return JSON.stringify(body);
}

/**
 * Convert Razorpay amount (paise) to rupees
 *
 * @param paise Amount in paise
 * @returns Amount in rupees
 */
export function paiseToRupees(paise: number): number {
  return paise / 100;
}

/**
 * Convert rupees to Razorpay amount (paise)
 *
 * @param rupees Amount in rupees
 * @returns Amount in paise
 */
export function rupeesToPaise(rupees: number): number {
  return Math.round(rupees * 100);
}

/**
 * Create idempotency key from payment ID and event ID
 *
 * @param paymentId Razorpay payment ID
 * @param eventId Razorpay event ID
 * @returns Idempotency key
 */
export function createIdempotencyKey(paymentId: string, eventId: string): string {
  return `${paymentId}_${eventId}`;
}

/**
 * Map Razorpay payment status to order status
 *
 * @param razorpayStatus Status from Razorpay
 * @returns Order status to set in Firestore
 */
export function mapRazorpayStatusToOrderStatus(
  razorpayStatus: RazorpayPaymentStatus
): string {
  switch (razorpayStatus) {
    case 'authorized':
    case 'captured':
      return 'confirmed';
    case 'failed':
      return 'payment_failed';
    case 'refunded':
      return 'refunded';
    case 'expired':
      return 'payment_expired';
    default:
      return 'payment_pending';
  }
}

/**
 * Check if payment status indicates successful payment
 *
 * @param status Razorpay payment status
 * @returns true if payment is successful
 */
export function isPaymentSuccessful(status: RazorpayPaymentStatus): boolean {
  return status === 'captured' || status === 'authorized';
}

/**
 * Check if payment status indicates failed payment
 *
 * @param status Razorpay payment status
 * @returns true if payment failed
 */
export function isPaymentFailed(status: RazorpayPaymentStatus): boolean {
  return status === 'failed' || status === 'expired';
}

/**
 * Sanitize error message for client response
 * Remove sensitive information
 *
 * @param error Error object or message
 * @returns Sanitized error message
 */
export function sanitizeErrorMessage(error: any): string {
  if (!error) return 'An unknown error occurred';

  const message = error.message || String(error);

  // Remove sensitive patterns
  return message
    .replace(/password[^,]*/gi, '***')
    .replace(/secret[^,]*/gi, '***')
    .replace(/token[^,]*/gi, '***')
    .replace(/key[^,]*/gi, '***')
    .substring(0, 200); // Limit length
}

/**
 * Format timestamp for logging
 *
 * @param timestamp Date or unix timestamp
 * @returns ISO string
 */
export function formatTimestamp(timestamp: Date | number): string {
  const date = typeof timestamp === 'number'
    ? new Date(timestamp * 1000)
    : timestamp;

  return date.toISOString();
}

/**
 * Log webhook event with structured format
 *
 * @param level Log level (info, warn, error)
 * @param message Message to log
 * @param data Additional data to log
 */
export function logWebhookEvent(
  level: 'info' | 'warn' | 'error',
  message: string,
  data?: Record<string, any>
): void {
  const prefix = '[webhook]';
  const logMessage = `${prefix} ${message}`;

  if (level === 'info') {
    functions.logger.info(logMessage, data);
  } else if (level === 'warn') {
    functions.logger.warn(logMessage, data);
  } else if (level === 'error') {
    functions.logger.error(logMessage, data);
  }
}

/**
 * Calculate next retry timestamp with exponential backoff
 *
 * @param retryCount Current retry attempt (0-based)
 * @param baseDelayMs Base delay in milliseconds
 * @param multiplier Backoff multiplier
 * @returns Timestamp for next retry
 */
export function calculateNextRetryTime(
  retryCount: number,
  baseDelayMs: number = 5 * 60 * 1000, // 5 minutes
  multiplier: number = 2
): Date {
  const delayMs = baseDelayMs * Math.pow(multiplier, retryCount);
  return new Date(Date.now() + delayMs);
}

/**
 * Validate Razorpay API key format
 *
 * @param key API key to validate
 * @returns true if key looks valid
 */
export function isValidRazorpayApiKey(key: string): boolean {
  // Razorpay keys start with rzp_live_ or rzp_test_
  return /^rzp_(live|test)_[a-zA-Z0-9]{14,}$/.test(key);
}

/**
 * Validate Razorpay payment ID format
 *
 * @param paymentId Payment ID to validate
 * @returns true if ID is valid format
 */
export function isValidPaymentId(paymentId: string): boolean {
  // Razorpay payment IDs start with pay_
  return /^pay_[a-zA-Z0-9]{14,}$/.test(paymentId);
}

/**
 * Validate Razorpay order ID format
 *
 * @param orderId Order ID to validate
 * @returns true if ID is valid format
 */
export function isValidOrderId(orderId: string): boolean {
  // Razorpay order IDs start with order_
  return /^order_[a-zA-Z0-9]{14,}$/.test(orderId);
}

/**
 * Extract payment details from webhook event
 *
 * @param event Razorpay webhook event
 * @returns Extracted payment details or null if invalid
 */
export function extractPaymentDetails(event: any) {
  try {
    if (!event || !event.payload || !event.payload.payment) {
      return null;
    }

    const payment = event.payload.payment;

    return {
      id: payment.id,
      orderId: payment.order_id,
      amount: payment.amount,
      status: payment.status,
      method: payment.method,
      email: payment.email,
      contact: payment.contact,
      errorCode: payment.error_code,
      errorDescription: payment.error_description,
      createdAt: payment.created_at,
    };
  } catch (error) {
    functions.logger.error('[webhook_utils] Error extracting payment details:', error);
    return null;
  }
}

/**
 * Check if retry should be attempted based on error type
 *
 * @param errorCode Razorpay error code
 * @returns true if retry is recommended
 */
export function shouldRetryPayment(errorCode: string): boolean {
  // Errors that might succeed on retry
  const retryableErrors = [
    'GATEWAY_ERROR', // Temporary gateway issue
    'TIMED_OUT', // Timeout
    'CONNECTION_FAILED', // Network issue
    'SERVICE_UNAVAILABLE', // Temporary unavailability
  ];

  // Errors that shouldn't be retried
  const nonRetryableErrors = [
    'BAD_REQUEST_ERROR', // Invalid request
    'AUTHENTICATION_ERROR', // Auth failed (won't change)
    'INVALID_CARD', // Card is invalid
    'CARD_DECLINED', // Card declined (won't change)
    'INSUFFICIENT_FUNDS', // Not enough funds (might change later)
    'EXPIRED_CARD', // Card expired
    'INVALID_ACCOUNT', // Account issue
  ];

  if (retryableErrors.includes(errorCode)) {
    return true;
  }

  if (nonRetryableErrors.includes(errorCode)) {
    return false;
  }

  // For unknown errors, allow retry
  return true;
}

/**
 * Get human-readable error message for error code
 *
 * @param errorCode Razorpay error code
 * @returns Human-readable error message
 */
export function getErrorMessage(errorCode: string): string {
  const errorMessages: Record<string, string> = {
    BAD_REQUEST_ERROR: 'Invalid request. Please check your payment details.',
    GATEWAY_ERROR: 'Gateway error. Please try again.',
    AUTHENTICATION_ERROR: 'Authentication failed. Please try another payment method.',
    TIMED_OUT: 'Request timed out. Please try again.',
    CONNECTION_FAILED: 'Connection failed. Please check your internet connection.',
    SERVICE_UNAVAILABLE: 'Service temporarily unavailable. Please try again later.',
    INVALID_CARD: 'Invalid card details. Please check and try again.',
    CARD_DECLINED: 'Your card was declined. Please use another card.',
    INSUFFICIENT_FUNDS: 'Insufficient funds in your card.',
    EXPIRED_CARD: 'Your card has expired.',
    INVALID_ACCOUNT: 'Invalid bank account. Please check details.',
  };

  return errorMessages[errorCode] || `Payment failed: ${errorCode}`;
}

/**
 * Create webhook error response
 *
 * @param message Error message
 * @param code HTTP status code (default 400)
 * @returns Response object
 */
export function createErrorResponse(message: string, code: number = 400) {
  return {
    success: false,
    message,
    code,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Create webhook success response
 *
 * @param message Success message
 * @param data Additional data
 * @returns Response object
 */
export function createSuccessResponse(message: string, data?: Record<string, any>) {
  return {
    success: true,
    message,
    ...(data && { data }),
    timestamp: new Date().toISOString(),
  };
}
