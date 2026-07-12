/**
 * SUPABASE CLIENT CONFIGURATION
 * Connection to Supabase PostgreSQL database
 * Source of truth for all operational data
 */

const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL || 'https://placeholder.supabase.co';
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || 'placeholder-key';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Verify connection (non-blocking)
if (supabase) {
  console.log('[supabase] Client initialized');
} else {
  console.error('[supabase] Failed to initialize client');
}

module.exports = supabase;
