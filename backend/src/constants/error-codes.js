/**
 * Standardized Error Codes
 * Used across all API responses for consistent error handling
 * Mobile frontend can parse error code for localized messages
 */

const ERROR_CODES = {
  // ──────────────────────────────────────────────────────────
  // INVENTORY & STOCK
  // ──────────────────────────────────────────────────────────
  STOCK_001: {
    code: 'STOCK_001',
    message: 'Product not found',
    httpStatus: 404,
    category: 'inventory',
  },
  STOCK_002: {
    code: 'STOCK_002',
    message: 'Insufficient stock for requested quantity',
    httpStatus: 409,
    category: 'inventory',
  },
  STOCK_003: {
    code: 'STOCK_003',
    message: 'Stock reserved by another customer',
    httpStatus: 409,
    category: 'inventory',
  },
  STOCK_004: {
    code: 'STOCK_004',
    message: 'Multiple shops in order not supported',
    httpStatus: 400,
    category: 'inventory',
  },

  // ──────────────────────────────────────────────────────────
  // PAYMENT
  // ──────────────────────────────────────────────────────────
  PAY_001: {
    code: 'PAY_001',
    message: 'Payment gateway unavailable',
    httpStatus: 502,
    category: 'payment',
    retryable: true,
  },
  PAY_002: {
    code: 'PAY_002',
    message: 'Payment amount mismatch',
    httpStatus: 400,
    category: 'payment',
    retryable: false,
  },
  PAY_003: {
    code: 'PAY_003',
    message: 'Payment timeout',
    httpStatus: 504,
    category: 'payment',
    retryable: true,
  },
  PAY_004: {
    code: 'PAY_004',
    message: 'Payment declined by bank',
    httpStatus: 402,
    category: 'payment',
    retryable: false,
  },
  PAY_005: {
    code: 'PAY_005',
    message: 'Invalid payment method',
    httpStatus: 400,
    category: 'payment',
    retryable: false,
  },
  PAY_006: {
    code: 'PAY_006',
    message: 'Order not found for payment',
    httpStatus: 404,
    category: 'payment',
    retryable: false,
  },

  // ──────────────────────────────────────────────────────────
  // COUPON & DISCOUNTS
  // ──────────────────────────────────────────────────────────
  COUP_001: {
    code: 'COUP_001',
    message: 'Coupon code not found',
    httpStatus: 404,
    category: 'coupon',
  },
  COUP_002: {
    code: 'COUP_002',
    message: 'Coupon has expired',
    httpStatus: 410,
    category: 'coupon',
  },
  COUP_003: {
    code: 'COUP_003',
    message: 'Coupon usage limit exceeded',
    httpStatus: 429,
    category: 'coupon',
  },
  COUP_004: {
    code: 'COUP_004',
    message: 'Minimum order value not met for this coupon',
    httpStatus: 400,
    category: 'coupon',
  },
  COUP_005: {
    code: 'COUP_005',
    message: 'Coupon not applicable to these items',
    httpStatus: 400,
    category: 'coupon',
  },

  // ──────────────────────────────────────────────────────────
  // DELIVERY & SHIPPING
  // ──────────────────────────────────────────────────────────
  DEL_001: {
    code: 'DEL_001',
    message: 'Delivery address not found',
    httpStatus: 404,
    category: 'delivery',
  },
  DEL_002: {
    code: 'DEL_002',
    message: 'Address coordinates are missing',
    httpStatus: 400,
    category: 'delivery',
  },
  DEL_003: {
    code: 'DEL_003',
    message: 'Delivery distance exceeds limit',
    httpStatus: 400,
    category: 'delivery',
  },
  DEL_004: {
    code: 'DEL_004',
    message: 'Invalid delivery type',
    httpStatus: 400,
    category: 'delivery',
  },
  DEL_005: {
    code: 'DEL_005',
    message: 'Order weight exceeds delivery limit',
    httpStatus: 400,
    category: 'delivery',
  },

  // ──────────────────────────────────────────────────────────
  // AUTHENTICATION & AUTHORIZATION
  // ──────────────────────────────────────────────────────────
  AUTH_001: {
    code: 'AUTH_001',
    message: 'Unauthorized - authentication required',
    httpStatus: 401,
    category: 'auth',
  },
  AUTH_002: {
    code: 'AUTH_002',
    message: 'Authentication token expired',
    httpStatus: 401,
    category: 'auth',
  },
  AUTH_003: {
    code: 'AUTH_003',
    message: 'Forbidden - insufficient permissions',
    httpStatus: 403,
    category: 'auth',
  },
  AUTH_004: {
    code: 'AUTH_004',
    message: 'Invalid or tampered token',
    httpStatus: 401,
    category: 'auth',
  },
  AUTH_005: {
    code: 'AUTH_005',
    message: 'User account not found',
    httpStatus: 404,
    category: 'auth',
  },

  // ──────────────────────────────────────────────────────────
  // VALIDATION ERRORS
  // ──────────────────────────────────────────────────────────
  VAL_001: {
    code: 'VAL_001',
    message: 'Invalid input data',
    httpStatus: 400,
    category: 'validation',
  },
  VAL_002: {
    code: 'VAL_002',
    message: 'Missing required field',
    httpStatus: 400,
    category: 'validation',
  },
  VAL_003: {
    code: 'VAL_003',
    message: 'Invalid JSON format',
    httpStatus: 400,
    category: 'validation',
  },
  VAL_004: {
    code: 'VAL_004',
    message: 'Request body too large',
    httpStatus: 413,
    category: 'validation',
  },

  // ──────────────────────────────────────────────────────────
  // REFUNDS
  // ──────────────────────────────────────────────────────────
  REF_001: {
    code: 'REF_001',
    message: 'Order cannot be refunded (invalid status)',
    httpStatus: 400,
    category: 'refund',
  },
  REF_002: {
    code: 'REF_002',
    message: 'Refund request not found',
    httpStatus: 404,
    category: 'refund',
  },
  REF_003: {
    code: 'REF_003',
    message: 'Refund request already exists',
    httpStatus: 409,
    category: 'refund',
  },
  REF_004: {
    code: 'REF_004',
    message: 'Refund time window has passed (30 days)',
    httpStatus: 400,
    category: 'refund',
  },

  // ──────────────────────────────────────────────────────────
  // GENERAL SERVER ERRORS
  // ──────────────────────────────────────────────────────────
  INTERNAL_001: {
    code: 'INTERNAL_001',
    message: 'Internal server error',
    httpStatus: 500,
    category: 'server',
    retryable: true,
  },
  INTERNAL_002: {
    code: 'INTERNAL_002',
    message: 'Database error',
    httpStatus: 500,
    category: 'server',
    retryable: true,
  },
  INTERNAL_003: {
    code: 'INTERNAL_003',
    message: 'Request timeout',
    httpStatus: 504,
    category: 'server',
    retryable: true,
  },
  INTERNAL_004: {
    code: 'INTERNAL_004',
    message: 'Service temporarily unavailable',
    httpStatus: 503,
    category: 'server',
    retryable: true,
  },
};

/**
 * Helper function to get error details
 */
function getError(code) {
  if (!ERROR_CODES[code]) {
    console.warn(`Unknown error code: ${code}`);
    return ERROR_CODES.INTERNAL_001;
  }
  return ERROR_CODES[code];
}

/**
 * Helper function to format error response
 */
function errorResponse(code, additionalMessage = null) {
  const error = getError(code);
  return {
    success: false,
    error: error.code,
    message: additionalMessage || error.message,
    httpStatus: error.httpStatus,
    retryable: error.retryable || false,
  };
}

module.exports = {
  ERROR_CODES,
  getError,
  errorResponse,
};
