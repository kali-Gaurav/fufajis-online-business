/**
 * Type definitions for Razorpay webhook and payment reconciliation
 */

/**
 * Razorpay webhook event payload structure
 */
export interface RazorpayWebhookEvent {
  id: string;
  event: RazorpayEventType;
  created_at: number; // Unix timestamp
  payload: {
    payment: RazorpayPayment;
  };
}

/**
 * Supported Razorpay event types
 */
export type RazorpayEventType =
  | 'payment.authorized'
  | 'payment.captured'
  | 'payment.failed'
  | 'payment.upi.authorized'
  | 'invoice.paid'
  | 'invoice.issued'
  | 'invoice.expired'
  | 'invoice.cancelled'
  | 'refund.created'
  | 'refund.failed'
  | 'refund.processed'
  | 'settlement.processed'
  | 'settlement.failed'
  | 'settlement.utr_generated';

/**
 * Razorpay payment object
 * Reference: https://razorpay.com/docs/api/payments/
 */
export interface RazorpayPayment {
  entity: 'payment';
  id: string;
  entity_id: string;
  amount: number; // Amount in paise (smallest unit)
  currency: 'INR';
  status: RazorpayPaymentStatus;
  method: RazorpayPaymentMethod;
  description?: string;
  amount_refunded?: number;
  refund_status?: string;
  captured: boolean;
  card_id?: string;
  bank?: string;
  wallet?: string;
  vpa?: string;
  email: string;
  contact: string;
  order_id?: string;
  invoice_id?: string;
  international?: boolean;
  fee?: number; // Razorpay fee in paise
  tax?: number; // Applicable tax in paise
  created_at: number; // Unix timestamp
  updated_at?: number; // Unix timestamp
  failed_at?: number; // Unix timestamp
  notes?: Record<string, any>;
  acquirer_data?: Record<string, any>;
  error_code?: string;
  error_description?: string;
  error_source?: string;
  error_reason?: string;
  error_step?: string;
  fee_details?: {
    gst?: number;
  };
  recurring?: boolean;
  first_min_amount?: number;
  subscription_id?: string;
  token_id?: string;
  auth_attempts?: number;
}

/**
 * Payment status from Razorpay
 */
export type RazorpayPaymentStatus =
  | 'created'
  | 'authorized'
  | 'captured'
  | 'refunded'
  | 'failed'
  | 'expired'
  | 'deleted';

/**
 * Supported payment methods
 */
export type RazorpayPaymentMethod =
  | 'card'
  | 'netbanking'
  | 'wallet'
  | 'emi'
  | 'emandate'
  | 'upi'
  | 'cardless_emi'
  | 'paypal'
  | 'paylater'
  | 'transfer';

/**
 * Webhook HTTP response structure
 */
export interface WebhookResponse {
  success: boolean;
  message: string;
  eventId?: string;
  paymentId?: string;
  duplicate?: boolean;
  timestamp: string;
  error?: string;
}

/**
 * Webhook log entry for audit trail
 */
export interface WebhookLog {
  id: string;
  eventId: string;
  eventType: RazorpayEventType;
  paymentId: string;
  orderId: string;
  amount: number;
  status: RazorpayPaymentStatus;
  signature: string; // Masked for security
  signatureValid: boolean;
  processed: boolean;
  processedAt?: FirebaseFirestore.Timestamp;
  processedResult?: string;
  error?: string;
  errorCode?: string;
  receivedAt: FirebaseFirestore.Timestamp;
  retryCount: number;
  lastRetryAt?: FirebaseFirestore.Timestamp;
  idempotencyKey: string;
}

/**
 * Payment retry queue entry
 */
export interface PaymentRetryEntry {
  id: string;
  paymentId: string;
  orderId: string;
  customerId?: string; // Will be fetched from order
  amount: number; // Amount in rupees
  status: 'pending' | 'completed' | 'failed' | 'error';
  error: string; // Error message from previous attempt
  retryCount: number;
  maxRetries: number;
  nextRetryAt: FirebaseFirestore.Timestamp;
  createdAt: FirebaseFirestore.Timestamp;
  lastRetryAt?: FirebaseFirestore.Timestamp;
  fallbackToWallet: boolean;
  notes?: string;
}

/**
 * Audit log for retry attempts
 */
export interface PaymentRetryAudit {
  id: string;
  retryEntryId: string;
  paymentId: string;
  orderId: string;
  retryAttempt: number; // 1-based
  status: 'pending' | 'success' | 'failed' | 'wallet_deduction' | 'exhausted';
  previousError: string;
  newError?: string;
  amount: number;
  attemptedAt: FirebaseFirestore.Timestamp;
  nextRetryAt?: FirebaseFirestore.Timestamp;
  reason?: string;
}

/**
 * Order payment tracking fields
 */
export interface OrderPaymentFields {
  paymentStatus?: RazorpayPaymentStatus;
  paymentConfirmed: boolean;
  razorpayPaymentId?: string;
  paymentAmount?: number;
  paymentConfirmedAt?: FirebaseFirestore.Timestamp;
}

/**
 * Wallet transaction for payment fallback
 */
export interface WalletTransaction {
  id: string;
  userId: string;
  type: 'payment_fallback' | 'refund' | 'credit' | 'debit';
  amount: number;
  orderReference: string;
  timestamp: FirebaseFirestore.Timestamp;
  description: string;
  balanceAfter: number;
  reason?: string;
}

/**
 * Razorpay API error response
 */
export interface RazorpayApiError {
  error: {
    code: string;
    description: string;
    source: 'customer' | 'business' | 'razorpay';
    step?: string;
    reason?: string;
    metadata?: Record<string, any>;
  };
}

/**
 * Razorpay capture payment request/response
 */
export interface RazorpayCaptureRequest {
  amount: number; // Amount in paise
}

export interface RazorpayCaptureResponse extends RazorpayPayment {}

/**
 * Cloud Function error types
 */
export enum CloudFunctionErrorCode {
  INVALID_SIGNATURE = 'invalid_signature',
  MISSING_SIGNATURE = 'missing_signature',
  MISSING_PAYMENT_ID = 'missing_payment_id',
  MISSING_ORDER_ID = 'missing_order_id',
  ORDER_NOT_FOUND = 'order_not_found',
  CUSTOMER_NOT_FOUND = 'customer_not_found',
  PAYMENT_ALREADY_PROCESSED = 'payment_already_processed',
  PAYMENT_CAPTURE_FAILED = 'payment_capture_failed',
  WALLET_INSUFFICIENT_BALANCE = 'wallet_insufficient_balance',
  WALLET_DEDUCTION_FAILED = 'wallet_deduction_failed',
  DATABASE_ERROR = 'database_error',
  RAZORPAY_API_ERROR = 'razorpay_api_error',
  INTERNAL_ERROR = 'internal_error',
}

/**
 * Configuration for retry logic
 */
export interface RetryConfig {
  maxRetries: number;
  backoffDelays: number[]; // milliseconds
  timeout: number; // milliseconds
}

/**
 * Configuration for webhook processing
 */
export interface WebhookConfig {
  secret: string;
  timeout: number; // milliseconds
  verifySignature: boolean;
  idempotencyEnabled: boolean;
}
