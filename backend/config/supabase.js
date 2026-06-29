const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = process.env.SUPABASE_URL || 'https://mxjtgpunctckovtuyfmz.supabase.co';

// Map keys from multiple possible environment variable names
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY ||
                              process.env.SUPABASE_SECRET_KEY ||
                              process.env.SUPABASE_SECRET;

const supabaseAnonKey = process.env.SUPABASE_ANON_KEY ||
                        process.env.SUPABASE_PUBLISHABLE_KEY ||
                        process.env.SUPABASE_ANON;

if (!supabaseUrl) {
  console.error('❌ SUPABASE_URL is missing from environment variables');
}

// Initialize clients only if keys are available to prevent crash on startup
let supabaseAdmin = null;
if (supabaseUrl && supabaseServiceRoleKey) {
  try {
    supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: true,
        persistSession: false,
      },
    });
    console.log('✅ Supabase Admin initialized');
  } catch (e) {
    console.error('❌ Failed to initialize Supabase Admin:', e.message);
  }
} else {
  console.warn('⚠️ Supabase Admin key missing (SUPABASE_SERVICE_ROLE_KEY or SUPABASE_SECRET_KEY). Admin operations will fail.');
}

let supabasePublic = null;
if (supabaseUrl && supabaseAnonKey) {
  try {
    supabasePublic = createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: true,
        persistSession: false,
      },
    });
    console.log('✅ Supabase Public initialized');
  } catch (e) {
    console.error('❌ Failed to initialize Supabase Public:', e.message);
  }
} else {
  console.warn('⚠️ Supabase Anon key missing (SUPABASE_ANON_KEY or SUPABASE_PUBLISHABLE_KEY). Public operations will fail.');
}

/**
 * Supabase service for database operations
 */
class SupabaseService {
  constructor() {
    this.admin = supabaseAdmin;
    this.public = supabasePublic;
  }

  /**
   * Get admin client (for server-side operations)
   */
  getAdmin() {
    if (!this.admin) throw new Error('Supabase Admin client not initialized. Check environment variables.');
    return this.admin;
  }

  /**
   * Get public client (for user-facing operations)
   */
  getPublic() {
    if (!this.public) throw new Error('Supabase Public client not initialized. Check environment variables.');
    return this.public;
  }

  /**
   * Execute query with error handling
   */
  async query(table, operation, data = {}) {
    try {
      const client = (data.useAdmin !== false ? this.admin : this.public) || this.admin || this.public;

      if (!client) {
        throw new Error('No Supabase client available. Check environment variables.');
      }

      let query = client.from(table);

      switch (operation) {
        case 'select':
          query = query.select(data.select || '*');
          if (data.filters) {
            Object.entries(data.filters).forEach(([key, value]) => {
              query = query.eq(key, value);
            });
          }
          if (data.order) {
            query = query.order(data.order.column, {
              ascending: data.order.ascending !== false,
            });
          }
          if (data.limit) {
            query = query.limit(data.limit);
          }
          break;

        case 'insert':
          query = query.insert(data.payload).select();
          break;

        case 'update':
          query = query.update(data.payload);
          Object.entries(data.filters || {}).forEach(([key, value]) => {
            query = query.eq(key, value);
          });
          query = query.select();
          break;

        case 'delete':
          query = query.delete();
          Object.entries(data.filters || {}).forEach(([key, value]) => {
            query = query.eq(key, value);
          });
          break;

        default:
          throw new Error(`Unknown operation: ${operation}`);
      }

      const { data: result, error } = await query;

      if (error) {
        throw new Error(`Database error: ${error.message}`);
      }

      return result;
    } catch (error) {
      console.error(`[Supabase] ${table} ${operation} failed:`, error.message);
      throw error;
    }
  }

  // ... (rest of the methods should check for this.admin/this.public before use)

  async createAuthUser(email, password, metadata = {}) {
    if (!this.admin) throw new Error('Supabase Admin client required');
    try {
      const { data, error } = await this.admin.auth.admin.createUser({
        email,
        password,
        email_confirm: false,
        user_metadata: metadata,
      });

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('[Supabase] Create auth user failed:', error.message);
      throw error;
    }
  }

  async getUserByEmail(email) {
    if (!this.admin) throw new Error('Supabase Admin client required');
    try {
      const { data, error } = await this.admin.auth.admin.getUserByEmail(email);
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('[Supabase] Get user by email failed:', error.message);
      throw error;
    }
  }

  async deleteUser(userId) {
    if (!this.admin) throw new Error('Supabase Admin client required');
    try {
      const { error } = await this.admin.auth.admin.deleteUser(userId);
      if (error) throw error;
    } catch (error) {
      console.error('[Supabase] Delete user failed:', error.message);
      throw error;
    }
  }

  async generateToken(userId) {
    if (!this.admin) throw new Error('Supabase Admin client required');
    try {
      const { data, error } = await this.admin.auth.admin.generateLink({
        type: 'magiclink',
        email: userId,
        options: {
          redirectTo: process.env.REDIRECT_URL || 'http://localhost:3000',
        },
      });

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('[Supabase] Generate token failed:', error.message);
      throw error;
    }
  }

  async uploadFile(bucket, path, file, options = {}) {
    if (!this.admin) throw new Error('Supabase Admin client required');
    try {
      const { data, error } = await this.admin.storage
        .from(bucket)
        .upload(path, file, options);

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('[Supabase] Upload file failed:', error.message);
      throw error;
    }
  }

  getPublicUrl(bucket, path) {
    const client = this.admin || this.public;
    if (!client) throw new Error('Supabase client required');
    try {
      const { data } = client.storage.from(bucket).getPublicUrl(path);
      return data.publicUrl;
    } catch (error) {
      console.error('[Supabase] Get public URL failed:', error.message);
      throw error;
    }
  }

  async deleteFile(bucket, path) {
    if (!this.admin) throw new Error('Supabase Admin client required');
    try {
      const { data, error } = await this.admin.storage
        .from(bucket)
        .remove([path]);

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('[Supabase] Delete file failed:', error.message);
      throw error;
    }
  }

  async batchInsert(table, records) {
    const client = this.admin || this.public;
    if (!client) throw new Error('Supabase client required');
    try {
      const { data, error } = await client
        .from(table)
        .insert(records)
        .select();

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('[Supabase] Batch insert failed:', error.message);
      throw error;
    }
  }

  async batchUpdate(table, records, keyField = 'id') {
    const client = this.admin || this.public;
    if (!client) throw new Error('Supabase client required');
    try {
      const updates = [];
      for (const record of records) {
        const key = record[keyField];
        const update = await client
          .from(table)
          .update(record)
          .eq(keyField, key)
          .select();

        updates.push(update.data);
      }
      return updates.flat();
    } catch (error) {
      console.error('[Supabase] Batch update failed:', error.message);
      throw error;
    }
  }

  async rawQuery(sql, params = []) {
    if (!this.admin) throw new Error('Supabase Admin client required');
    try {
      const { data, error } = await this.admin.rpc('exec_sql', {
        sql,
        params,
      });

      if (error) throw error;
      return data;
    } catch (error) {
      console.error('[Supabase] Raw query failed:', error.message);
      throw error;
    }
  }
}

// Create singleton instance
const supabaseService = new SupabaseService();

module.exports = supabaseService;
module.exports.SupabaseService = SupabaseService;
module.exports.supabaseAdmin = supabaseAdmin;
module.exports.supabasePublic = supabasePublic;
