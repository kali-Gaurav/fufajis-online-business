/**
 * Structured Logging Service
 *
 * Provides centralized logging with:
 * - Winston for structured logs (console + file)
 * - Sentry for error tracking
 * - Request correlation IDs for tracing
 * - Contextual logging (user, request, service)
 */

const winston = require('winston');
const * as Sentry = require('@sentry/node');

// ═══════════════════════════════════════════════════════════════════════
// SENTRY INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════

function initSentry() {
  if (!process.env.SENTRY_DSN) {
    console.warn('[Logger] SENTRY_DSN not set — error tracking disabled');
    return null;
  }

  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV || 'development',
    tracesSampleRate: 1.0,
    attachStacktrace: true,
  });

  console.log('[Logger] Sentry initialized');
  return Sentry;
}

// ═══════════════════════════════════════════════════════════════════════
// WINSTON LOGGER SETUP
// ═══════════════════════════════════════════════════════════════════════

const logger = winston.createLogger({
  defaultMeta: {
    service: 'fufaji-backend',
    environment: process.env.NODE_ENV || 'development',
    version: process.env.APP_VERSION || '1.0.0',
  },
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    // Console (development + production)
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message, ...meta }) => {
          const metaStr = Object.keys(meta).length
            ? ` ${JSON.stringify(meta)}`
            : '';
          return `[${timestamp}] [${level}] ${message}${metaStr}`;
        })
      ),
    }),
    // File transport (errors only in prod, all logs in dev)
    ...(process.env.NODE_ENV === 'production'
      ? [
          new winston.transports.File({
            filename: '/var/log/fufaji-backend/error.log',
            level: 'error',
            maxsize: 10485760, // 10MB
            maxFiles: 5,
          }),
          new winston.transports.File({
            filename: '/var/log/fufaji-backend/combined.log',
            maxsize: 10485760,
            maxFiles: 10,
          }),
        ]
      : [
          new winston.transports.File({
            filename: 'logs/debug.log',
            level: 'debug',
          }),
          new winston.transports.File({
            filename: 'logs/error.log',
            level: 'error',
          }),
        ]),
  ],
});

// ═══════════════════════════════════════════════════════════════════════
// CONTEXT MANAGEMENT (AsyncLocalStorage for request-scoped context)
// ═══════════════════════════════════════════════════════════════════════

const { AsyncLocalStorage } = require('async_hooks');
const logContext = new AsyncLocalStorage();

function setLogContext(context) {
  return logContext.run(context, () => context);
}

function getLogContext() {
  return logContext.getStore() || {};
}

// ═══════════════════════════════════════════════════════════════════════
// LOGGER INTERFACE
// ═══════════════════════════════════════════════════════════════════════

const createLogger = (serviceName) => {
  return {
    debug: (message, meta = {}) => {
      logger.debug(message, {
        ...meta,
        ...getLogContext(),
        service: serviceName,
      });
    },

    info: (message, meta = {}) => {
      logger.info(message, {
        ...meta,
        ...getLogContext(),
        service: serviceName,
      });
    },

    warn: (message, meta = {}) => {
      logger.warn(message, {
        ...meta,
        ...getLogContext(),
        service: serviceName,
      });
    },

    error: (message, error, meta = {}) => {
      const errorMeta = {
        ...meta,
        ...getLogContext(),
        service: serviceName,
        error: {
          message: error?.message || String(error),
          stack: error?.stack,
          code: error?.code,
          statusCode: error?.statusCode,
        },
      };

      logger.error(message, errorMeta);

      // Also send to Sentry
      if (Sentry) {
        Sentry.captureException(error, {
          extra: errorMeta,
          level: 'error',
        });
      }
    },

    fatal: (message, error, meta = {}) => {
      const errorMeta = {
        ...meta,
        ...getLogContext(),
        service: serviceName,
        error: {
          message: error?.message || String(error),
          stack: error?.stack,
          code: error?.code,
        },
      };

      logger.error(message, { ...errorMeta, level: 'FATAL' });

      // Send to Sentry with fatal level
      if (Sentry) {
        Sentry.captureException(error, {
          extra: errorMeta,
          level: 'fatal',
        });
      }

      // Exit process (fatal error)
      process.exit(1);
    },
  };
};

// ═══════════════════════════════════════════════════════════════════════
// MIDDLEWARE FOR EXPRESS
// ═══════════════════════════════════════════════════════════════════════

/**
 * Middleware to add request correlation ID and user context to logs
 */
const requestLoggingMiddleware = (req, res, next) => {
  const correlationId = req.headers['x-correlation-id'] || generateCorrelationId();
  const userId = req.user?.id || req.headers['x-user-id'] || 'anonymous';
  const method = req.method;
  const path = req.path;

  // Set context for this request
  setLogContext({
    correlationId,
    userId,
    method,
    path,
    ip: req.ip,
    userAgent: req.headers['user-agent'],
  });

  // Log request
  const appLogger = createLogger('request');
  appLogger.info(`${method} ${path}`, {
    query: req.query,
    body: req.body ? sanitizeBody(req.body) : undefined,
  });

  // Track response time
  const startTime = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const level = res.statusCode >= 400 ? 'warn' : 'info';
    appLogger[level](`${method} ${path} completed`, {
      statusCode: res.statusCode,
      duration: `${duration}ms`,
    });
  });

  next();
};

// ═══════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════

function generateCorrelationId() {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

function sanitizeBody(body) {
  // Remove sensitive fields from logs
  const sensitiveFields = [
    'password',
    'pin',
    'token',
    'secret',
    'apiKey',
    'creditCard',
  ];
  const sanitized = { ...body };
  for (const field of sensitiveFields) {
    if (sanitized[field]) {
      sanitized[field] = '***REDACTED***';
    }
  }
  return sanitized;
}

// ═══════════════════════════════════════════════════════════════════════
// EXPORTS
// ═══════════════════════════════════════════════════════════════════════

module.exports = {
  logger,
  createLogger,
  initSentry,
  requestLoggingMiddleware,
  getLogContext,
  setLogContext,
  generateCorrelationId,
};
