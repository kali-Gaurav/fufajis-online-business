const admin = require('firebase-admin');

/**
 * Centralized logging service for backend
 * Provides structured logging to console and Firestore
 */
class LoggerService {
  constructor() {
    this.db = admin.firestore();
    this.logsCollection = 'backend_logs';
  }

  /**
   * Log structured event
   * @param {string} level - Log level (DEBUG, INFO, WARNING, ERROR, FATAL)
   * @param {string} message - Log message
   * @param {object} context - Additional context object
   */
  async log(level, message, context = {}) {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      level,
      message,
      context,
      requestId: context.requestId || 'unknown',
      userId: context.userId || 'system',
      duration: context.duration || 0,
    };

    // Console log for immediate visibility
    console.log(`[${timestamp}] [${level}] ${message}`, context);

    // Store in Firestore for analytics (async, non-blocking)
    if (level === 'ERROR' || level === 'FATAL' || level === 'WARNING') {
      this.db
        .collection(this.logsCollection)
        .add(logEntry)
        .catch((err) =>
          console.error('[LoggerService] Firestore write error:', err)
        );
    }
  }

  info(message, context = {}) {
    this.log('INFO', message, context);
  }

  warning(message, context = {}) {
    this.log('WARNING', message, context);
  }

  error(message, error = null, context = {}) {
    const errorContext = {
      ...context,
      errorMessage: error?.message || error?.toString(),
      errorStack: error?.stack,
    };
    this.log('ERROR', message, errorContext);
  }

  fatal(message, error = null, context = {}) {
    const errorContext = {
      ...context,
      errorMessage: error?.message || error?.toString(),
      errorStack: error?.stack,
    };
    this.log('FATAL', message, errorContext);
  }

  debug(message, context = {}) {
    // Only in development
    if (process.env.NODE_ENV !== 'production') {
      this.log('DEBUG', message, context);
    }
  }

  /**
   * Log API request details
   */
  async logApiRequest(req, res, startTime) {
    const duration = Date.now() - startTime;
    const context = {
      requestId: req.id || 'unknown',
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userId: req.user?.uid || 'anonymous',
      ip: req.ip,
    };

    if (res.statusCode >= 400) {
      this.warning(`API error: ${req.method} ${req.path}`, context);
    } else {
      this.info(`API request completed: ${req.method} ${req.path}`, context);
    }
  }

  /**
   * Log database operation
   */
  async logDatabaseOp(operation, collection, docId, duration, success = true) {
    const context = {
      operation,
      collection,
      docId,
      duration: `${duration}ms`,
      success,
    };

    if (!success) {
      this.error(`Database operation failed: ${operation}`, null, context);
    } else {
      this.info(`Database operation: ${operation}`, context);
    }
  }

  /**
   * Log payment transaction
   */
  async logPaymentTransaction({
    paymentId,
    orderId,
    amount,
    status,
    method,
    userId,
    duration,
  }) {
    const context = {
      paymentId,
      orderId,
      amount,
      status,
      paymentMethod: method,
      userId,
      duration: `${duration}ms`,
    };

    if (status === 'failed' || status === 'error') {
      this.error('Payment transaction failed', null, context);
    } else {
      this.info('Payment transaction completed', context);
    }
  }

  /**
   * Log inventory/stock change
   */
  async logInventoryChange({
    productId,
    operation,
    quantity,
    before,
    after,
    orderId,
    userId,
  }) {
    const context = {
      productId,
      operation,
      quantity,
      beforeStock: before,
      afterStock: after,
      orderId,
      userId,
    };

    this.info(`Inventory change: ${operation}`, context);
  }

  /**
   * Log order state transition
   */
  async logOrderStateChange({
    orderId,
    fromState,
    toState,
    userId,
    reason,
    duration,
  }) {
    const context = {
      orderId,
      fromState,
      toState,
      userId,
      reason,
      duration: `${duration}ms`,
    };

    this.info(`Order state change: ${fromState} -> ${toState}`, context);
  }

  /**
   * Log security event
   */
  async logSecurityEvent({
    eventType,
    severity,
    userId,
    action,
    details,
  }) {
    const context = {
      eventType,
      severity,
      userId,
      action,
      details,
      timestamp: new Date().toISOString(),
    };

    if (severity === 'critical') {
      this.fatal(`Security event: ${eventType}`, null, context);
    } else if (severity === 'high') {
      this.error(`Security event: ${eventType}`, null, context);
    } else {
      this.warning(`Security event: ${eventType}`, context);
    }
  }
}

module.exports = new LoggerService();
