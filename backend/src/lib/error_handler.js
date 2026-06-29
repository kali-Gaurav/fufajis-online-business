/**
 * error_handler.js - Comprehensive error handling & edge case management
 * Provides standardized error responses, validation, and recovery strategies
 */

class AppError extends Error {
  constructor(message, statusCode = 500, details = {}) {
    super(message);
    this.statusCode = statusCode;
    this.details = details;
    this.timestamp = new Date();
  }
}

class ValidationError extends AppError {
  constructor(message, details = {}) {
    super(message, 400, details);
    this.type = 'ValidationError';
  }
}

class NotFoundError extends AppError {
  constructor(message, details = {}) {
    super(message, 404, details);
    this.type = 'NotFoundError';
  }
}

class ConflictError extends AppError {
  constructor(message, details = {}) {
    super(message, 409, details);
    this.type = 'ConflictError';
  }
}

class ServiceError extends AppError {
  constructor(message, details = {}) {
    super(message, 500, details);
    this.type = 'ServiceError';
  }
}

/**
 * Validates input parameters
 */
function validateInput(input, schema) {
  const errors = [];

  for (const [key, rules] of Object.entries(schema)) {
    const value = input[key];

    if (rules.required && !value) {
      errors.push(`${key} is required.`);
      continue;
    }

    if (value === undefined || value === null) continue;

    // Type check
    if (rules.type) {
      const actualType = Array.isArray(value) ? 'array' : typeof value;
      if (actualType !== rules.type) {
        errors.push(`${key} must be of type ${rules.type}, got ${actualType}`);
      }
    }

    // Min/Max validation
    if (rules.type === 'number') {
      if (rules.min !== undefined && value < rules.min) {
        errors.push(`${key} must be >= ${rules.min}`);
      }
      if (rules.max !== undefined && value > rules.max) {
        errors.push(`${key} must be <= ${rules.max}`);
      }
    }

    // String validation
    if (rules.type === 'string') {
      if (rules.minLength && value.length < rules.minLength) {
        errors.push(`${key} must have at least ${rules.minLength} characters`);
      }
      if (rules.maxLength && value.length > rules.maxLength) {
        errors.push(`${key} must have at most ${rules.maxLength} characters`);
      }
      if (rules.pattern && !rules.pattern.test(value)) {
        errors.push(`${key} does not match required pattern`);
      }
    }

    // Array validation
    if (rules.type === 'array') {
      if (rules.minItems && value.length < rules.minItems) {
        errors.push(`${key} must have at least ${rules.minItems} items`);
      }
      if (rules.maxItems && value.length > rules.maxItems) {
        errors.push(`${key} must have at most ${rules.maxItems} items`);
      }
    }

    // Custom validator
    if (rules.custom) {
      const customError = rules.custom(value);
      if (customError) errors.push(customError);
    }
  }

  if (errors.length > 0) {
    throw new ValidationError('Input validation failed', { errors });
  }

  return true;
}

/**
 * Sanitize user input (prevent injection attacks)
 */
function sanitizeInput(input) {
  if (typeof input === 'string') {
    // Remove potentially dangerous characters, trim
    return input
      .trim()
      .replace(/[<>\"'`;]/g, '') // Remove special chars
      .slice(0, 5000); // Limit length
  }

  if (typeof input === 'object' && input !== null) {
    const sanitized = {};
    for (const [key, value] of Object.entries(input)) {
      sanitized[key] = sanitizeInput(value);
    }
    return sanitized;
  }

  return input;
}

/**
 * Validate product quantities (edge cases)
 */
function validateQuantity(quantity, productName = '') {
  if (!Number.isInteger(quantity)) {
    throw new ValidationError(`Quantity must be an integer for ${productName}`);
  }

  if (quantity <= 0) {
    throw new ValidationError(`Quantity must be positive for ${productName}`);
  }

  if (quantity > 999999) {
    throw new ValidationError(`Quantity too large for ${productName}. Max: 999999`);
  }

  return true;
}

/**
 * Validate stock availability with fallback options
 */
async function validateStockWithFallback(product, requestedQty) {
  const availableQty = product.stockQuantity || 0;

  if (availableQty >= requestedQty) {
    return {
      valid: true,
      fullFulfillment: true,
      availableQty: requestedQty,
    };
  }

  if (availableQty > 0) {
    return {
      valid: true,
      fullFulfillment: false,
      availableQty,
      shortBy: requestedQty - availableQty,
      suggestion: `Only ${availableQty} available. Add fewer quantity?`,
    };
  }

  return {
    valid: false,
    fullFulfillment: false,
    availableQty: 0,
    shortBy: requestedQty,
    suggestion: `Out of stock. Please remove from cart.`,
  };
}

/**
 * Handle and retry API calls with exponential backoff
 */
async function retryWithBackoff(fn, maxRetries = 3, baseDelayMs = 100) {
  let lastError;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      // Don't retry on client errors (4xx) except 408, 429, 503
      if (error.statusCode && error.statusCode >= 400 && error.statusCode < 500) {
        const retryableStatuses = [408, 429]; // Request Timeout, Too Many Requests
        if (!retryableStatuses.includes(error.statusCode)) {
          throw error;
        }
      }

      if (attempt < maxRetries) {
        const delayMs = baseDelayMs * Math.pow(2, attempt - 1) + Math.random() * 100;
        console.warn(`[Retry] Attempt ${attempt}/${maxRetries} failed. Retrying in ${delayMs}ms...`);
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }

  throw new ServiceError(`Operation failed after ${maxRetries} retries`, {
    lastError: lastError.message,
  });
}

/**
 * Convert errors to standard response format
 */
function errorResponse(error, req) {
  const statusCode = error.statusCode || 500;
  const response = {
    success: false,
    error: error.message,
    type: error.type || 'Error',
    timestamp: new Date().toISOString(),
  };

  // Include request ID for debugging
  if (req && req.id) {
    response.requestId = req.id;
  }

  // Include validation details if applicable
  if (error.details) {
    response.details = error.details;
  }

  // Log errors
  if (statusCode >= 500) {
    console.error(`[${statusCode}] ${error.message}`, {
      type: error.type,
      details: error.details,
      stack: error.stack,
    });
  } else {
    console.warn(`[${statusCode}] ${error.message}`, error.details);
  }

  return { statusCode, response };
}

/**
 * Middleware for global error handling
 */
function errorHandlingMiddleware(err, req, res, next) {
  const { statusCode, response } = errorResponse(err, req);
  res.status(statusCode).json(response);
}

/**
 * Async route wrapper to catch errors
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch((error) => {
      const appError =
        error instanceof AppError
          ? error
          : new ServiceError(error.message, { originalError: error.name });
      errorHandlingMiddleware(appError, req, res, next);
    });
  };
}

module.exports = {
  AppError,
  ValidationError,
  NotFoundError,
  ConflictError,
  ServiceError,
  validateInput,
  sanitizeInput,
  validateQuantity,
  validateStockWithFallback,
  retryWithBackoff,
  errorResponse,
  errorHandlingMiddleware,
  asyncHandler,
};
