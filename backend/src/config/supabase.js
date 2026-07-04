const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.supabase_service_role;

let supabaseClient = null;
if (supabaseUrl && supabaseKey) {
    supabaseClient = createClient(supabaseUrl, supabaseKey);
    console.log('[Supabase] ✅ Client initialized');
} else {
    console.error('❌ Supabase credentials missing: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
}

/**
 * Supabase Service Wrapper
 * Provides .query() interface that all services expect
 */
class SupabaseService {
  async query(table, operation, options = {}) {
    if (!supabaseClient) throw new Error('Supabase not initialized');

    try {
      let query = supabaseClient.from(table);

      switch (operation.toLowerCase()) {
        case 'select':
          if (options.filters) {
            Object.entries(options.filters).forEach(([key, value]) => {
              query = query.eq(key, value);
            });
          }
          if (options.limit) query = query.limit(options.limit);
          if (options.order) {
            const [col, dir] = options.order;
            query = query.order(col, { ascending: dir === 'asc' });
          }
          return await query;

        case 'insert':
          return await query.insert(options.payload).select();

        case 'update':
          if (!options.id && !options.filters) throw new Error('Update requires id or filters');
          if (options.filters) {
            Object.entries(options.filters).forEach(([key, value]) => {
              query = query.eq(key, value);
            });
          } else {
            query = query.eq('id', options.id);
          }
          return await query.update(options.payload).select();

        case 'delete':
          if (!options.id) throw new Error('Delete requires id in options');
          return await query.eq('id', options.id).delete();

        default:
          throw new Error(`Unknown operation: ${operation}`);
      }
    } catch (error) {
      console.error(`[Supabase] ${operation.toUpperCase()} failed on ${table}:`, error.message);
      throw error;
    }
  }

  /**
   * Direct access to raw Supabase client for complex queries
   */
  getClient() {
    return supabaseClient;
  }

  /**
   * Execute raw SQL via rpc() or direct client access
   * For complex queries like incrementing a field
   */
  async rawQuery(rpcName, params) {
    if (!supabaseClient) throw new Error('Supabase not initialized');
    try {
      return await supabaseClient.rpc(rpcName, params);
    } catch (error) {
      console.error(`[Supabase] RPC ${rpcName} failed:`, error.message);
      throw error;
    }
  }

  /**
   * Batch operations within a transaction
   */
  async batch(operations) {
    // Note: Supabase doesn't support transactions like traditional DBs
    // Implement client-side batching with error handling
    const results = [];
    for (const op of operations) {
      try {
        const result = await this.query(op.table, op.operation, op.options);
        results.push({ success: true, data: result });
      } catch (error) {
        results.push({ success: false, error: error.message });
      }
    }
    return results;
  }
}

module.exports = new SupabaseService();
