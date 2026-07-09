import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import firebaseBridge from "../_shared/firebase-bridge.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

// This is called by a scheduled task or webhook to consume the DLQ
// It retries failed Firestore syncs using exponential backoff
serve(async (req) => {
  try {
    const supabase = createClient(supabaseUrl, supabaseKey);

    console.log("🔄 DLQ Consumer: Starting retry batch");

    // Step 1: Fetch all FAILED mutations due for retry
    const { data: failedMutations, error: fetchError } = await supabase
      .from("sync_mutations")
      .select("*")
      .eq("status", "FAILED")
      .lte("next_retry_at", new Date().toISOString())
      .limit(10); // Process in small batches

    if (fetchError) {
      console.error("DLQ Consumer: Failed to fetch mutations:", fetchError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch mutations", details: fetchError.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!failedMutations || failedMutations.length === 0) {
      console.log("✓ DLQ Consumer: No mutations ready for retry");
      return new Response(
        JSON.stringify({ processed: 0, message: "No mutations ready for retry" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log(`📦 DLQ Consumer: Processing ${failedMutations.length} mutations`);

    let successCount = 0;
    let dlqCount = 0;
    const failures: Array<{ id: string; error: string }> = [];

    // Step 2: Retry each mutation
    for (const mutation of failedMutations) {
      try {
        const { entity_type, entity_id, operation, data_after, retry_count } = mutation;

        console.log(
          `🔄 Retry ${entity_type}:${entity_id} (attempt ${retry_count + 1})`
        );

        // Attempt sync with timeout
        let syncSuccess = false;
        try {
          const syncPromise = (async () => {
            switch (entity_type) {
              case "products":
                return await firebaseBridge.syncProductToFirestore(entity_id, data_after);
              case "inventory":
                return await firebaseBridge.syncInventoryToFirestore(entity_id, data_after);
              case "orders":
                return await firebaseBridge.syncOrderToFirestore(entity_id, data_after);
              case "wallet_balance":
                return await firebaseBridge.syncWalletBalanceToFirestore(
                  entity_id,
                  data_after
                );
              case "wallet_transactions":
                return await firebaseBridge.syncWalletTransactionToFirestore(
                  data_after.user_id,
                  entity_id,
                  data_after
                );
              default:
                return false;
            }
          })();

          syncSuccess = await Promise.race([
            syncPromise,
            new Promise<boolean>((_, reject) =>
              setTimeout(() => reject(new Error("Firestore sync timeout")), 5000)
            ),
          ]);
        } catch (syncError) {
          console.error(`✗ Sync failed for ${entity_type}:${entity_id}:`, syncError);
          syncSuccess = false;
        }

        if (syncSuccess) {
          // SUCCESS: Mark as synced
          console.log(`✓ Synced ${entity_type}:${entity_id}`);
          const { error: updateError } = await supabase
            .from("sync_mutations")
            .update({
              status: "SYNCED",
              updated_at: new Date().toISOString(),
            })
            .eq("id", mutation.id);

          if (updateError) {
            console.error(`Failed to mark as SYNCED:`, updateError);
            failures.push({
              id: mutation.id,
              error: `Failed to update status: ${updateError.message}`,
            });
          } else {
            successCount++;
          }
        } else {
          // FAILURE: Check if max retries exceeded
          const nextRetryData = await supabase.rpc("calculate_next_retry_time", {
            p_retry_count: retry_count + 1,
          });

          const { data: retryData, error: retryError } = nextRetryData;

          if (retryError) {
            console.error("Failed to calculate next retry:", retryError);
            failures.push({
              id: mutation.id,
              error: `Failed to calculate retry: ${retryError.message}`,
            });
            continue;
          }

          const { next_retry_at, should_dlq } = retryData[0];

          if (should_dlq) {
            // DLQ: Max retries exceeded
            console.log(
              `💀 Max retries exceeded for ${entity_type}:${entity_id}, moving to DLQ`
            );

            const { error: dlqError } = await supabase
              .from("sync_dead_letter_queue")
              .insert({
                mutation_id: mutation.id,
                entity_type,
                entity_id,
                operation,
                data_after,
                last_error: `Max retries (7) exceeded`,
                total_attempts: retry_count + 1,
                first_attempt_at: mutation.created_at,
                last_attempt_at: new Date().toISOString(),
                priority: "high",
              });

            if (dlqError) {
              console.error(`Failed to insert into DLQ:`, dlqError);
              failures.push({
                id: mutation.id,
                error: `Failed to move to DLQ: ${dlqError.message}`,
              });
            } else {
              dlqCount++;
              // Mark as DEAD_LETTER in sync_mutations
              await supabase
                .from("sync_mutations")
                .update({
                  status: "DEAD_LETTER",
                  updated_at: new Date().toISOString(),
                })
                .eq("id", mutation.id);
            }
          } else {
            // RETRY: Update next retry time
            console.log(
              `⏰ Scheduling retry for ${entity_type}:${entity_id} at ${next_retry_at}`
            );

            const { error: updateError } = await supabase
              .from("sync_mutations")
              .update({
                retry_count: retry_count + 1,
                next_retry_at,
                updated_at: new Date().toISOString(),
              })
              .eq("id", mutation.id);

            if (updateError) {
              console.error(`Failed to update retry time:`, updateError);
              failures.push({
                id: mutation.id,
                error: `Failed to schedule retry: ${updateError.message}`,
              });
            }
          }
        }
      } catch (error) {
        console.error(`Unexpected error processing mutation ${mutation.id}:`, error);
        failures.push({
          id: mutation.id,
          error: `Unexpected error: ${error.message}`,
        });
      }
    }

    console.log(`✓ DLQ Consumer: Batch complete (${successCount} synced, ${dlqCount} dlq'd)`);

    return new Response(
      JSON.stringify({
        processed: failedMutations.length,
        synced: successCount,
        dlq: dlqCount,
        failures: failures.length > 0 ? failures : undefined,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("DLQ Consumer fatal error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
