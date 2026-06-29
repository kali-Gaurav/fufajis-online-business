/**
 * performance_monitor.js
 * Tracks API performance, detects bottlenecks, and reports metrics
 */

const metrics = {
  endpoints: {},
  errors: [],
  slowRequests: [],
};

const PERFORMANCE_TARGETS = {
  'POST /ai/voice-to-cart': 2000, // ms
  'POST /ai/transcribe': 1500,
  'POST /operations/checkout-order': 500,
  'POST /operations/checkin-order': 500,
  'GET /operations/inventory-audit/:orderId': 300,
  'POST /ai/gemini': 1000,
  'POST /ai/bedrock': 1000,
};

/**
 * Track request start
 */
function startRequest(method, path) {
  return {
    method,
    path,
    startTime: Date.now(),
    marks: {},
  };
}

/**
 * Mark intermediate checkpoint (for detailed timing)
 */
function markCheckpoint(tracker, name) {
  tracker.marks[name] = Date.now() - tracker.startTime;
}

/**
 * Track request completion
 */
function endRequest(tracker, statusCode = 200) {
  const duration = Date.now() - tracker.startTime;
  const key = `${tracker.method} ${tracker.path}`;

  // Initialize endpoint metrics
  if (!metrics.endpoints[key]) {
    metrics.endpoints[key] = {
      count: 0,
      totalDuration: 0,
      minDuration: Infinity,
      maxDuration: 0,
      errors: 0,
      avgDuration: 0,
    };
  }

  const endpoint = metrics.endpoints[key];
  endpoint.count++;
  endpoint.totalDuration += duration;
  endpoint.minDuration = Math.min(endpoint.minDuration, duration);
  endpoint.maxDuration = Math.max(endpoint.maxDuration, duration);
  endpoint.avgDuration = endpoint.totalDuration / endpoint.count;

  // Track errors
  if (statusCode >= 400) {
    endpoint.errors++;
  }

  // Track slow requests
  const target = PERFORMANCE_TARGETS[key];
  if (target && duration > target) {
    metrics.slowRequests.push({
      endpoint: key,
      duration,
      target,
      overBy: duration - target,
      timestamp: new Date().toISOString(),
      marks: tracker.marks,
    });

    // Keep only last 100 slow requests
    if (metrics.slowRequests.length > 100) {
      metrics.slowRequests.shift();
    }

    console.warn(
      `[SLOW] ${key}: ${duration}ms (target: ${target}ms, over by: ${duration - target}ms)`
    );
  }

  return {
    duration,
    endpoint: key,
    statusCode,
    marks: tracker.marks,
    meetsTarget: !target || duration <= target,
  };
}

/**
 * Get performance report
 */
function getPerformanceReport() {
  const report = {
    timestamp: new Date().toISOString(),
    endpoints: {},
    summary: {
      totalRequests: 0,
      totalErrors: 0,
      avgResponseTime: 0,
      slowestEndpoint: null,
      fastestEndpoint: null,
      targetsMetCount: 0,
      targetsMissedCount: 0,
    },
  };

  let allRequests = 0;
  let allErrors = 0;
  let totalDuration = 0;
  let maxAvg = 0;
  let minAvg = Infinity;

  for (const [key, stats] of Object.entries(metrics.endpoints)) {
    const target = PERFORMANCE_TARGETS[key];
    const meetsTarget = !target || stats.avgDuration <= target;

    report.endpoints[key] = {
      ...stats,
      target,
      meetsTarget,
      errorRate: ((stats.errors / stats.count) * 100).toFixed(2) + '%',
    };

    allRequests += stats.count;
    allErrors += stats.errors;
    totalDuration += stats.totalDuration;

    if (stats.avgDuration > maxAvg) {
      maxAvg = stats.avgDuration;
      report.summary.slowestEndpoint = key;
    }
    if (stats.avgDuration < minAvg) {
      minAvg = stats.avgDuration;
      report.summary.fastestEndpoint = key;
    }

    if (meetsTarget) {
      report.summary.targetsMetCount++;
    } else {
      report.summary.targetsMissedCount++;
    }
  }

  report.summary.totalRequests = allRequests;
  report.summary.totalErrors = allErrors;
  report.summary.avgResponseTime = allRequests > 0 ? (totalDuration / allRequests).toFixed(0) : 0;
  report.summary.errorRate = allRequests > 0 ? ((allErrors / allRequests) * 100).toFixed(2) : 0;

  return report;
}

/**
 * Middleware: Track all requests
 */
function performanceMiddleware(req, res, next) {
  const tracker = startRequest(req.method, req.path);

  // Mark Firestore queries
  const originalGet = res.locals.db?.get;
  if (originalGet) {
    res.locals.db.get = function (...args) {
      markCheckpoint(tracker, 'firestore_query_start');
      return originalGet.apply(this, args).then((result) => {
        markCheckpoint(tracker, 'firestore_query_end');
        return result;
      });
    };
  }

  // Track when response is sent
  const originalSend = res.send;
  res.send = function (data) {
    const result = endRequest(tracker, res.statusCode);
    res.locals.performanceMetrics = result;
    return originalSend.apply(this, arguments);
  };

  next();
}

/**
 * Export metrics for monitoring dashboard
 */
function exportMetrics() {
  const report = getPerformanceReport();

  return {
    timestamp: new Date().toISOString(),
    metrics: {
      health: {
        status: report.summary.totalErrors === 0 ? 'healthy' : 'degraded',
        errorRate: report.summary.errorRate,
        totalRequests: report.summary.totalRequests,
      },
      performance: {
        avgResponseTime: report.summary.avgResponseTime,
        slowestEndpoint: report.summary.slowestEndpoint,
        targetsMetCount: report.summary.targetsMetCount,
        targetsMissedCount: report.summary.targetsMissedCount,
      },
      endpoints: report.endpoints,
    },
    slowRequests: metrics.slowRequests.slice(-10), // Last 10
  };
}

/**
 * Cache layer for product catalog
 */
class CatalogCache {
  constructor(ttlMs = 60000) {
    this.cache = null;
    this.ttl = ttlMs;
    this.lastUpdate = 0;
  }

  isExpired() {
    return Date.now() - this.lastUpdate > this.ttl;
  }

  get() {
    if (this.cache && !this.isExpired()) {
      return this.cache;
    }
    return null;
  }

  set(data) {
    this.cache = data;
    this.lastUpdate = Date.now();
  }

  clear() {
    this.cache = null;
    this.lastUpdate = 0;
  }
}

/**
 * Optimize Firestore queries with proper indexes
 */
function getOptimizedQueries() {
  return {
    // Index configuration for Firestore
    indexes: [
      {
        collection: 'products',
        fields: [
          { fieldPath: 'name', order: 'ASCENDING' },
          { fieldPath: 'stockQuantity', order: 'DESCENDING' },
          { fieldPath: 'category', order: 'ASCENDING' },
        ],
      },
      {
        collection: 'inventory_events',
        fields: [
          { fieldPath: 'reference_id', order: 'ASCENDING' },
          { fieldPath: 'timestamp', order: 'DESCENDING' },
        ],
      },
      {
        collection: 'inventory_events',
        fields: [
          { fieldPath: 'product_id', order: 'ASCENDING' },
          { fieldPath: 'timestamp', order: 'DESCENDING' },
        ],
      },
      {
        collection: 'orders',
        fields: [
          { fieldPath: 'status', order: 'ASCENDING' },
          { fieldPath: 'createdAt', order: 'DESCENDING' },
        ],
      },
    ],

    // Query optimization tips
    tips: [
      'Use collection group queries for inventory_events across multiple orders',
      'Create composite indexes for common filter + sort combinations',
      'Batch read products when matching multiple items',
      'Cache product catalog (1 min TTL)',
      'Denormalize product name for faster searches',
    ],
  };
}

module.exports = {
  startRequest,
  markCheckpoint,
  endRequest,
  getPerformanceReport,
  performanceMiddleware,
  exportMetrics,
  CatalogCache,
  getOptimizedQueries,
  PERFORMANCE_TARGETS,
};
