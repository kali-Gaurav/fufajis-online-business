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
   * Periodic health check to ensure pool is alive
   * Runs every 30 seconds
   */
  startHealthCheck() {
    this.healthCheckInterval = setInterval(async () => {
      try {
        const client = await this.pool.connect();
        await client.query('SELECT 1');
        client.release();
        // Health check passed silently
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
   * Usage: pool.transaction(async (client) => {
   *   await client.query('BEGIN');
   *   await client.query('UPDATE ...');
   *   await client.query('COMMIT');
   * })
   */
  async transaction(callback) {
    const client = await this.getClient();
    try {
      await client.query('BEGIN');
      const result = await callback(client);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      await client.query('ROLLBACK');
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
