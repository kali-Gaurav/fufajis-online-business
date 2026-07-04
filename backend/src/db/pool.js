// PostgreSQL Connection Pool
// Production-grade pool with health checks, retry logic, and graceful shutdown

const { Pool } = require('pg');
const { EventEmitter } = require('events');

class PoolManager extends EventEmitter {
  constructor() {
    super();
    this.pool = null;
    this.isInitialized = false;
    this.healthCheckInterval = null;
  }

  /**
   * Initialize connection pool with environment configuration
   * Throws if DATABASE_URL is not set
   */
  async init() {
    if (this.isInitialized) {
      console.log('[PoolManager] Already initialized, skipping re-init');
      return this.pool;
    }

    const databaseUrl = process.env.DATABASE_URL;
    if (!databaseUrl) {
      throw new Error(
        'DATABASE_URL environment variable is required. ' +
        'Format: postgresql://user:password@host:port/database'
      );
    }

    try {
      this.pool = new Pool({
        connectionString: databaseUrl,
        // Connection pool settings
        max: parseInt(process.env.DB_POOL_MAX || '20', 10),
        min: parseInt(process.env.DB_POOL_MIN || '5', 10),
        idleTimeoutMillis: 30000,
        connectionTimeoutMillis: 10000,
        // Retry on startup
        statement_timeout: 30000,
        query_timeout: 30000,
      });

      // Error handler for pool
      this.pool.on('error', (err, client) => {
        console.error('[PoolManager] Unexpected error on idle client:', err);
        this.emit('pool:error', err);
      });

      this.pool.on('connect', () => {
        console.log('[PoolManager] New connection established');
      });

      // Test connection
      const client = await this.pool.connect();
      const result = await client.query('SELECT NOW() as current_time');
      client.release();
      console.log(
        '[PoolManager] ✅ PostgreSQL connection successful. Server time:',
        result.rows[0].current_time
      );

      // Run database migrations
      await this.runMigrations();

      this.isInitialized = true;

      // Start health check interval
      this.startHealthCheck();

      return this.pool;
    } catch (err) {
      console.error('[PoolManager] Failed to initialize pool:', err.message);
      throw err;
    }
  }

  /**
   * Run database migrations on startup
   * ✅ FIXES:
   * - Tracks migration failures and alerts ops
   * - Distinguishes critical vs non-critical migration failures
   * - Proper error reporting
   * Creates tables if they don't exist
   */
  async runMigrations() {
    const fs = require('fs');
    const path = require('path');

    console.log('[PoolManager] 🔧 Running database migrations...');

    try {
      const migrationsDir = path.join(__dirname, 'migrations');
      if (!fs.existsSync(migrationsDir)) {
        console.warn('[PoolManager] ⚠️  No migrations directory found');
        return;
      }

      const files = fs.readdirSync(migrationsDir)
        .filter(f => f.endsWith('.sql'))
        .sort(); // Alphabetical order ensures 001, 002, 003 etc.

      const failedMigrations = [];

      for (const file of files) {
        const filePath = path.join(migrationsDir, file);
        const sqlContent = fs.readFileSync(filePath, 'utf8');

        try {
          await this.pool.query(sqlContent);
          console.log(`[PoolManager] ✅ Migration applied: ${file}`);
        } catch (err) {
          failedMigrations.push({ file, error: err.message });
          console.error(`[PoolManager] ❌ Migration failed ${file}:`, err.message);

          // ✅ FIX: If it's a critical early migration (001, 002), this is fatal
          if (file.startsWith('001') || file.startsWith('002')) {
            console.error(`[PoolManager] 🚨 CRITICAL: Early migration ${file} failed. System cannot proceed.`);
            throw new Error(`Critical migration failed: ${file}. ${err.message}`);
          }
          // For later migrations, continue but alert ops
        }
      }

      if (failedMigrations.length > 0) {
        console.warn(`[PoolManager] ⚠️  ${failedMigrations.length} migrations failed (non-critical). Review logs.`);
        this.emit('migrations:partial-failure', failedMigrations);
      }

      console.log('[PoolManager] ✅ Migrations completed');
    } catch (err) {
      console.error('[PoolManager] ❌ Failed to run migrations:', err.message);
      throw err; // Let startup fail if migrations are critical
    }
  }

  /**
   * Periodic health check to ensure pool is alive
   * ✅ FIXES:
   * - Monitors connection pool exhaustion
   * - Alerts ops when pool is running out of connections
   * Runs every 30 seconds
   */
  startHealthCheck() {
    this.healthCheckInterval = setInterval(async () => {
      try {
        // Health check: simple query
        const client = await this.pool.connect();
        await client.query('SELECT 1');
        client.release();

        // ✅ FIX: Monitor connection pool utilization
        const stats = this.getStats();
        if (stats) {
          const utilization = ((stats.totalConnections - stats.idleConnections) / stats.totalConnections) * 100;

          // Alert if pool is >80% utilized
          if (utilization > 80) {
            console.warn(
              `[PoolManager] ⚠️ Connection pool usage HIGH: ${(utilization).toFixed(1)}% ` +
              `(${stats.totalConnections - stats.idleConnections}/${stats.totalConnections} connections in use)`
            );
          }

          // Alert if there are waiting requests (pool exhaustion)
          if (stats.waitingRequests > 0) {
            console.warn(
              `[PoolManager] 🚨 CRITICAL: ${stats.waitingRequests} requests waiting for connections ` +
              `(pool full: ${stats.totalConnections} connections all in use)`
            );
            this.emit('pool:exhausted', stats);
          }
        }
      } catch (err) {
        console.error('[PoolManager] Health check failed:', err.message);
        this.emit('pool:health:failed', err);
      }
    }, 30000);
  }

  /**
   * Get a client from the pool
   * Automatically retries 3 times on connection failure
   */
  async getClient() {
    let attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        return await this.pool.connect();
      } catch (err) {
        attempts++;
        if (attempts >= maxAttempts) {
          console.error(
            `[PoolManager] Failed to get client after ${maxAttempts} attempts:`,
            err.message
          );
          throw err;
        }
        // Exponential backoff: 100ms, 200ms, 400ms
        const backoffMs = Math.pow(2, attempts - 1) * 100;
        console.warn(
          `[PoolManager] Connection failed (attempt ${attempts}/${maxAttempts}), retrying in ${backoffMs}ms...`
        );
        await new Promise(resolve => setTimeout(resolve, backoffMs));
      }
    }
  }

  /**
   * Execute query with automatic client management
   * Usage: pool.query('SELECT * FROM users WHERE id = $1', [userId])
   */
  async query(text, values) {
    const client = await this.getClient();
    try {
      const result = await client.query(text, values);
      return result;
    } finally {
      client.release();
    }
  }

  /**
   * Execute multiple queries in a transaction
   * ✅ FIXES:
   * - Validates callback is function
   * - Ensures ROLLBACK completes before throwing error
   * - Timeout protection for long-running transactions
   * - Proper error propagation
   * Usage: pool.transaction(async (client) => {
   *   await client.query('UPDATE ...');
   *   return result;
   * })
   */
  async transaction(callback, timeout = 30000) {
    // ✅ FIX: Validate callback
    if (typeof callback !== 'function') {
      throw new Error('INVALID_INPUT: callback must be a function');
    }

    const client = await this.getClient();
    let transactionStarted = false;

    try {
      await client.query('BEGIN');
      transactionStarted = true;

      // ✅ FIX: Add timeout protection
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('TRANSACTION_TIMEOUT: exceeded ' + timeout + 'ms')), timeout)
      );

      const result = await Promise.race([
        callback(client),
        timeoutPromise
      ]);

      await client.query('COMMIT');
      return result;
    } catch (err) {
      // ✅ FIX: Ensure ROLLBACK completes even if it fails
      if (transactionStarted) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackErr) {
          console.error('[PoolManager] 🚨 ROLLBACK failed:', rollbackErr.message);
          // Still throw original error, but log rollback failure for ops
        }
      }
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Graceful shutdown: drain all connections
   */
  async shutdown() {
    if (!this.pool) {
      console.log('[PoolManager] Pool not initialized, skipping shutdown');
      return;
    }

    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
    }

    try {
      console.log('[PoolManager] Shutting down connection pool...');
      await this.pool.end();
      this.isInitialized = false;
      console.log('[PoolManager] ✅ Pool shut down successfully');
    } catch (err) {
      console.error('[PoolManager] Error during shutdown:', err.message);
    }
  }

  /**
   * Get pool stats (for monitoring)
   */
  getStats() {
    if (!this.pool) {
      return null;
    }
    return {
      totalConnections: this.pool.totalCount,
      idleConnections: this.pool.idleCount,
      waitingRequests: this.pool.waitingCount,
    };
  }
}

// Singleton instance
const poolManager = new PoolManager();

module.exports = poolManager;
