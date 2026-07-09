import { createClient, PostgrestError } from 'npm:@supabase/supabase-js';

// PostgreSQL error codes for retryable errors
const RETRYABLE_ERRORS = [
  '40001', // serialization_failure
  '40P01', // deadlock_detected
  '53300', // too_many_connections
  '57P03', // cannot_connect_now
];

export async function callRpcWithRetry(
  supabase: ReturnType<typeof createClient>,
  rpcName: string,
  args: any,
  maxRetries = 3
) {
  let attempt = 0;
  
  while (attempt < maxRetries) {
    const { data, error } = await supabase.rpc(rpcName, args);
    
    if (error) {
      if (RETRYABLE_ERRORS.includes(error.code) && attempt < maxRetries - 1) {
        attempt++;
        const backoff = Math.pow(2, attempt) * 100 + Math.random() * 50;
        await new Promise(res => setTimeout(res, backoff));
        continue;
      }
      
      // If we hit a known custom exception like CONCURRENT_UPDATE_DETECTED, we can also retry
      if (error.message.includes('CONCURRENT_UPDATE_DETECTED') && attempt < maxRetries - 1) {
        attempt++;
        const backoff = Math.pow(2, attempt) * 100 + Math.random() * 50;
        await new Promise(res => setTimeout(res, backoff));
        continue;
      }

      throw error;
    }
    
    return data;
  }
}
