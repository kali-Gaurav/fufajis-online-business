const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const supabaseUrl = process.env.SUPABASE_URL || 'https://mxjtgpunctckovtuyfmz.supabase.co';
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SECRET_KEY;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY;

if (!supabaseUrl) {
  throw new Error('SUPABASE_URL is required');
}

if (!supabaseServiceRoleKey && !supabaseAnonKey) {
  throw new Error(
    'Either SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY is required',
  );
}

// Initialize with service role key for admin operations
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: false,
  },
});

// Initialize with anon key for public operations
const supabasePublic = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: false,
  },
});

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
    return this.admin;
  }

  /**
   * Get public client (for user-facing operations)
   */
  getPublic() {
    return this.public;
  }

  /**
   * Execute query with error handling
   */
  async query(table, operation, data = {}) {
    try {
      const client = data.useAdmin !== false ? this.admin : this.public;
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

  /**
   * Create user in auth
   */
  async createAuthUser(email, password, metadata = {}) {
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

  /**
   * Get user by email
   */
  async getUserByEmail(email) {
    try {
      const { data, error } = await this.admin.auth.admin.getUserByEmail(
        email,
      );
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('[Supabase] Get user by email failed:', error.message);
      throw error;
    }
  }

  /**
   * Delete user
   */
  async deleteUser(userId) {
    try {
      const { error } = await this.admin.auth.admin.deleteUser(userId);
      if (error) throw error;
    } catch (error) {
      console.error('[Supabase] Delete user failed:', error.message);
      throw error;
    }
  }

  /**
   * Generate token for user
   */
  async generateToken(userId) {
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

  /**
   * Upload file to storage
   */
  async uploadFile(bucket, path, file, options = {}) {
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

  /**
   * Get public URL for file
   */
  getPublicUrl(bucket, path) {
    try {
      const { data } = this.admin.storage
        .from(bucket)
        .getPublicUrl(path);
      return data.publicUrl;
    } catch (error) {
      console.error('[Supabase] Get public URL failed:', error.message);
      throw error;
    }
  }

  /**
   * Delete file from storage
   */
  async deleteFile(bucket, path) {
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

  /**
   * Batch insert
   */
  async batchInsert(table, records) {
    try {
      const { data, error } = await this.admin
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

  /**
   * Batch update
   */
  async batchUpdate(table, records, keyField = 'id') {
    try {
      const updates = [];
      for (const record of records) {
        const key = record[keyField];
        const update = await this.admin
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

  /**
   * Raw SQL query (admin only)
   */
  async rawQuery(sql, params = []) {
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
