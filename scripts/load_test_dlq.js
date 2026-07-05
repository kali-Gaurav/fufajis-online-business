/**
 * DLQ Load Testing Script
 * 
 * Purpose: Simulates a high-concurrency burst of events failing to sync,
 * driving them into the Dead Letter Queue (DLQ) to ensure the system
 * handles the backoff and DLQ routing properly under load.
 * 
 * Usage: node scripts/load_test_dlq.js
 */

const { createClient } = require('@supabase/supabase-js');
// Ensure dotenv is installed or load env vars manually if this is a standalone script
require('dotenv').config();

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:54321';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'your-service-role-key';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function runLoadTest() {
  console.log("🚀 Starting DLQ Load Test...");
  const CONCURRENCY = 200; // Number of failed events to inject
  
  // 1. Inject Poison Pills into the outbox_events queue
  // These represent events that will persistently fail (e.g., malformed payload or downstream outage)
  console.log(`Injecting ${CONCURRENCY} poison pill events into outbox...`);
  
  const events = [];
  for (let i = 0; i < CONCURRENCY; i++) {
    events.push({
      event_type: 'inventory_sync',
      payload: { id: `test-item-${i}`, broken: true },
      status: 'failed',
      retry_count: 7, // Max retries reached
      last_error: 'Simulated persistent failure for load test',
      next_retry_at: new Date().toISOString() // Ready to be processed NOW
    });
  }

  const { error: insertError } = await supabase
    .from('outbox_events')
    .insert(events);

  if (insertError) {
    console.error("Failed to inject events:", insertError);
    process.exit(1);
  }

  console.log("✅ Injected successfully. Waiting for background worker to route to DLQ...");
  
  // 2. The outbox_worker or postgres cron should pick these up and move them to DLQ
  // We'll poll the DLQ to see if they arrived.
  
  let dlqCount = 0;
  let attempts = 0;
  
  while (dlqCount < CONCURRENCY && attempts < 10) {
    attempts++;
    console.log(`Polling DLQ (Attempt ${attempts}/10)...`);
    
    // Wait 2 seconds between polls
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const { count, error } = await supabase
      .from('dlq_messages')
      .select('*', { count: 'exact', head: true })
      .like('error_message', '%Simulated persistent failure%');
      
    if (error) {
      console.error("Error querying DLQ:", error);
    } else {
      dlqCount = count || 0;
      console.log(`Current DLQ count for test events: ${dlqCount}/${CONCURRENCY}`);
    }
  }

  if (dlqCount >= CONCURRENCY) {
    console.log("🎉 SUCCESS! All poison pills successfully routed to the DLQ under load.");
    
    // Clean up
    console.log("Cleaning up test data...");
    await supabase
      .from('dlq_messages')
      .delete()
      .like('error_message', '%Simulated persistent failure%');
      
  } else {
    console.error(`❌ FAILED! Only ${dlqCount}/${CONCURRENCY} events made it to the DLQ.`);
    process.exit(1);
  }
}

runLoadTest().catch(console.error);
