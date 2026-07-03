// Idempotency Middleware
// Intercept requests with Idempotency-Key header
// Cache responses in PostgreSQL for safe retries

const pool = require('../db/pool');

/**
 * Middleware: Check for cached response before processing
 * If Idempotency-Key exists in cache, return cached response
 * Otherwise, proceed with request (cache will be populated by service)
 */
const idempotencyMiddleware = async (req, res, next) => {
  const idempotencyKey = req.headers['idempotency-key'];

  if (!idempotencyKey) {
    // No idempotency key, proceed normally
    return next();
  }

  if (!['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
    // Idempotency only for mutating operations
    return next();
  }

  try {
    // Check if this idempotency key was already processed
    const cachedResult = await pool.query(
      `SELECT response_status, response_body
       FROM idempotency_keys
       WHERE idempotency_key = $1
       AND operation_type = $2
       AND expires_at > CURRENT_TIMESTAMP`,
      [idempotencyKey, getOperationType(req)]
    );

    if (cachedResult.rows.length > 0) {
      const { response_status, response_body } = cachedResult.rows[0];
      console.log(
        `[IdempotencyMiddleware] ✅ Cache hit for ${idempotencyKey}: returning cached ${response_status}`
      );

      return res
        .status(response_status)
        .json(JSON.parse(response_body));
    }

    // Not cached, proceed with request
    // Store the original res.json to capture response later
    const originalJson = res.json.bind(res);

    res.json = function(data) {
      // After response is sent, cache it
      setImmediate(async () => {
        try {
          await cacheResponse(
            idempotencyKey,
            getOperationType(req),
            res.statusCode,
            data
          );
        } catch (err) {
          console.error('[IdempotencyMiddleware] Failed to cache response:', err.message);
          // Don't throw - response already sent
        }
      });

      return originalJson(data);
    };

    next();
  } catch (err) {
    console.error('[IdempotencyMiddleware] Error checking cache:', err.message);
    // On error, proceed without caching (fail open)
    next();
  }
};

/**
 * Cache a response for idempotent replay
 */
async function cacheResponse(idempotencyKey, operationType, statusCode, responseBody) {
  // Determine TTL based on operation type
  const ttlMap = {
    'checkout_create_order': '7 days',
    'inventory_confirm': '7 days',
    'inventory_release': '7 days',
    'order_status_transition': '30 days',
    'payment_verify': '90 days',
    'refund_initiate': '180 days',
  };

  const ttl = ttlMap[operationType] || '30 days';

  await pool.query(
    `INSERT INTO idempotency_keys
     (idempotency_key, operation_type, response_status, response_body, expires_at)
     VALUES ($1, $2, $3, $4, NOW() + INTERVAL $5)
     ON CONFLICT (idempotency_key) DO NOTHING`,
    [
      idempotencyKey,
      operationType,
      statusCode,
      JSON.stringify(responseBody),
      ttl,
    ]
  );

  console.log(
    `[IdempotencyMiddleware] ✅ Cached response for ${idempotencyKey} (TTL: ${ttl})`
  );
}

/**
 * Map request to operation type for cache key
 */
function getOperationType(req) {
  const path = req.path;
  const method = req.method;

  if (path === '/checkout/create-order' && method === 'POST') {
    return 'checkout_create_order';
  }
  if (path === '/inventory/confirm' && method === 'POST') {
    return 'inventory_confirm';
  }
  if (path === '/inventory/release' && method === 'POST') {
    return 'inventory_release';
  }
  if (path.match(/^\/orders\/[\w-]+\/status-transition$/) && method === 'POST') {
    return 'order_status_transition';
  }
  if (path === '/payments/verify' && method === 'POST') {
    return 'payment_verify';
  }
  if (path === '/payments/refund' && method === 'POST') {
    return 'refund_initiate';
  }

  return 'unknown';
}

module.exports = idempotencyMiddleware;
