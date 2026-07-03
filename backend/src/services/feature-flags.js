/**
 * Feature Flags Service
 *
 * Implements stable, consistent rollout.
 * Same user always gets same code path (critical for A/B testing).
 *
 * Routing: hash(user_id) % 100 < rollout_percentage
 * This ensures:
 * - Deterministic (same user always same path)
 * - Fair (random distribution across users)
 * - Stable (no thrashing between paths)
 */

const { db } = require('../db');
const crypto = require('crypto');

// In-memory cache with TTL
const flagCache = new Map();
const CACHE_TTL_MS = 60 * 1000; // 1 minute

/**
 * Get stable hash for user (0-100)
 * Same user_id always produces same hash
 */
function getUserHash(userId) {
  const hash = crypto.createHash('md5').update(userId).digest();
  const hashValue = hash.readUInt32BE(0);
  return hashValue % 100;
}

/**
 * Check if feature flag is enabled for user
 *
 * @param {string} flagName - Feature flag name (e.g., 'USE_BACKEND_INVENTORY_API')
 * @param {string} userId - User ID for stable routing
 * @returns {boolean} Whether feature is enabled
 */
async function isFeatureFlagEnabled(flagName, userId) {
  try {
    // Check cache first
    const cacheKey = `${flagName}:${userId}`;
    const cached = flagCache.get(cacheKey);

    if (cached && cached.expiresAt > Date.now()) {
      return cached.enabled;
    }

    // Query database
    const result = await db.query(
      `SELECT enabled, enable_percentage FROM feature_flags WHERE flag_name = $1`,
      [flagName]
    );

    if (result.rows.length === 0) {
      return false;
    }

    const { enabled, enable_percentage } = result.rows[0];

    if (!enabled) {
      return false;
    }

    // If 100%, everyone gets it
    if (enable_percentage >= 100) {
      flagCache.set(cacheKey, { enabled: true, expiresAt: Date.now() + CACHE_TTL_MS });
      return true;
    }

    // Percentage rollout: stable hash-based routing
    const userHash = getUserHash(userId);
    const isEnabled = userHash < enable_percentage;

    // Cache result
    flagCache.set(cacheKey, { enabled: isEnabled, expiresAt: Date.now() + CACHE_TTL_MS });

    return isEnabled;
  } catch (error) {
    console.error('Feature flag check failed:', error);
    return false; // Fail closed (use old path)
  }
}

/**
 * Enable feature flag for percentage of users
 *
 * @param {string} flagName
 * @param {number} enablePercentage - 0-100
 */
async function enableFeatureFlag(flagName, enablePercentage = 100) {
  try {
    await db.query(
      `UPDATE feature_flags
       SET enabled = TRUE, enable_percentage = $1, updated_at = NOW()
       WHERE flag_name = $2`,
      [Math.max(0, Math.min(100, enablePercentage)), flagName]
    );

    // Clear cache for this flag
    flagCache.forEach((value, key) => {
      if (key.startsWith(`${flagName}:`)) {
        flagCache.delete(key);
      }
    });

    console.log(`Feature flag ${flagName} enabled at ${enablePercentage}%`);
  } catch (error) {
    console.error('Failed to enable feature flag:', error);
    throw error;
  }
}

/**
 * Disable feature flag entirely
 */
async function disableFeatureFlag(flagName) {
  try {
    await db.query(
      `UPDATE feature_flags
       SET enabled = FALSE, enable_percentage = 0, updated_at = NOW()
       WHERE flag_name = $1`,
      [flagName]
    );

    // Clear cache
    flagCache.forEach((value, key) => {
      if (key.startsWith(`${flagName}:`)) {
        flagCache.delete(key);
      }
    });

    console.log(`Feature flag ${flagName} disabled (rollback to 0%)`);
  } catch (error) {
    console.error('Failed to disable feature flag:', error);
    throw error;
  }
}

/**
 * Get all feature flags with current state
 */
async function getAllFeatureFlags() {
  try {
    const result = await db.query(
      `SELECT flag_name, enabled, enable_percentage, updated_at
       FROM feature_flags
       ORDER BY flag_name ASC`
    );

    return result.rows.map(row => ({
      name: row.flag_name,
      enabled: row.enabled,
      rolloutPercentage: row.enable_percentage,
      lastUpdated: row.updated_at,
    }));
  } catch (error) {
    console.error('Failed to get feature flags:', error);
    return [];
  }
}

/**
 * Rollout plan example
 *
 * Week 1: Test
 * await enableFeatureFlag('USE_BACKEND_INVENTORY_API', 10);  // 10% users
 *
 * Week 2: Expand
 * await enableFeatureFlag('USE_BACKEND_INVENTORY_API', 50);  // 50% users
 *
 * Week 3: Full
 * await enableFeatureFlag('USE_BACKEND_INVENTORY_API', 100); // 100% users
 *
 * Emergency Rollback (instant)
 * await disableFeatureFlag('USE_BACKEND_INVENTORY_API');     // Back to 0%
 */

/**
 * Usage in middleware/route handlers:
 *
 * router.post('/inventory/adjust', verifyAuth, async (req, res) => {
 *   const useBackendAPI = await isFeatureFlagEnabled('USE_BACKEND_INVENTORY_API', req.user.uid);
 *
 *   if (useBackendAPI) {
 *     // NEW PATH: PostgreSQL + atomic transactions
 *     return await handleInventoryAdjustViaBackend(req, res);
 *   } else {
 *     // OLD PATH: Direct Firestore write (for backward compatibility during migration)
 *     return await handleInventoryAdjustViaFirestore(req, res);
 *   }
 * });
 */

module.exports = {
  isFeatureFlagEnabled,
  enableFeatureFlag,
  disableFeatureFlag,
  getAllFeatureFlags,
  getUserHash, // Exposed for testing
};
