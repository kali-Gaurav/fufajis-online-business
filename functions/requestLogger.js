const logger = require('./LoggerService');
const { v4: uuidv4 } = require('uuid');

/**
 * Request logging middleware
 * Wraps Firebase Functions with structured logging
 */
function requestLogger(handler) {
  return async (req, res) => {
    // Add unique request ID if not present
    req.id = req.headers['x-request-id'] || uuidv4();
    const startTime = Date.now();

    // Store original res.json/res.send
    const originalJson = res.json.bind(res);
    const originalSend = res.send.bind(res);

    // Intercept response to log it
    res.json = function (data) {
      const duration = Date.now() - startTime;
      logRequest(req, res, duration);
      return originalJson(data);
    };

    res.send = function (data) {
      const duration = Date.now() - startTime;
      logRequest(req, res, duration);
      return originalSend(data);
    };

    // Handle errors
    const originalStatus = res.status.bind(res);
    res.status = function (code) {
      res.statusCode = code;
      return originalStatus(code);
    };

    try {
      // Call the handler
      return await handler(req, res);
    } catch (error) {
      const duration = Date.now() - startTime;
      logError(req, res, error, duration);
      res.status(500).json({
        error: 'Internal server error',
        requestId: req.id,
      });
    }
  };
}

/**
 * Log successful request
 */
function logRequest(req, res, duration) {
  const context = {
    requestId: req.id,
    method: req.method,
    path: req.path || req.url,
    statusCode: res.statusCode || 200,
    duration: `${duration}ms`,
    userId: req.user?.uid || 'anonymous',
    ip: req.ip,
  };

  if (res.statusCode >= 400) {
    logger.warning(`API request: ${req.method} ${req.path}`, context);
  } else {
    logger.info(`API request: ${req.method} ${req.path}`, context);
  }
}

/**
 * Log error request
 */
function logError(req, res, error, duration) {
  const context = {
    requestId: req.id,
    method: req.method,
    path: req.path || req.url,
    statusCode: res.statusCode || 500,
    duration: `${duration}ms`,
    userId: req.user?.uid || 'anonymous',
    ip: req.ip,
    errorMessage: error?.message,
    errorStack: error?.stack,
  };

  logger.error(`API error: ${req.method} ${req.path}`, error, context);
}

module.exports = { requestLogger, logRequest, logError };
