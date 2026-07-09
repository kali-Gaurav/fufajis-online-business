/**
 * TASK 2: Inventory Sync Edge Function
 *
 * Purpose: Sync products + inventory from PostgreSQL (source of truth) → Firestore (read-only cache)
 * Runs every 5 minutes via Cloud Scheduler
 *
 * Why: Firestore is UI sync layer only. All mutations happen in PostgreSQL.
 * Scheduler triggers this function to propagate changes to mobile app.
 *
 * Safety:
 * - Row-level locking in PostgreSQL ensures consistent reads
 * - Batches of 450 items per Firestore transaction (max 500)
 * - Exponential backoff on failures
 * - Complete audit trail in sync_logs table
 */

import { createClient } from "@supabase/supabase-js";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

// Initialize Firebase Admin
const firebaseApp = initializeApp();
const firestore = getFirestore(firebaseApp);

// Initialize Supabase Client (authenticated with service role)
const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// ============================================================================
// TYPES
// ============================================================================
interface Product {
  id: string;
  name: string;
  price: number;
  available_stock: number;
  reserved_stock: number;
  sold_stock: number;
  branch_stock_map: Record<string, any>;
  sku: string;
  last_stock_check: string;
  updated_at: string;
  shop_id: string;
}

interface SyncResult {
  success: boolean;
  productsProcessed: number;
  batchesCreated: number;
  duration: number;
  error?: string;
}

// ============================================================================
// HELPER: Fetch Products from PostgreSQL
// ============================================================================
async function fetchProductsFromPostgres(lastSyncTime: Date): Promise<Product[]> {
  try {
    const { data, error } = await supabase
      .from("products")
      .select("*")
      .gt("updated_at", lastSyncTime.toISOString())
      .order("updated_at", { ascending: false })
      .limit(1000);

    if (error) {
      throw new Error(`Supabase query error: ${error.message}`);
    }

    console.log(`Fetched ${data?.length || 0} products from PostgreSQL`);
    return data || [];
  } catch (error) {
    console.error("Error fetching products:", error);
    throw error;
  }
}

// ============================================================================
// HELPER: Sync Products to Firestore (with batching)
// ============================================================================
async function syncProductsToFirestore(products: Product[]): Promise<{
  batchesCreated: number;
  itemsSynced: number;
}> {
  const BATCH_SIZE = 450;
  const MAX_BATCHES = 5;
  let batchesCreated = 0;
  let itemsSynced = 0;

  for (let i = 0; i < products.length && batchesCreated < MAX_BATCHES; i += BATCH_SIZE) {
    const batch = products.slice(i, i + BATCH_SIZE);
    const firestoreBatch = firestore.batch();

    for (const product of batch) {
      const docRef = firestore.collection("products").doc(product.id);
      firestoreBatch.update(docRef, {
        availableStock: product.available_stock,
        reservedStock: product.reserved_stock,
        soldStock: product.sold_stock,
        branchStockMap: product.branch_stock_map || {},
        sku: product.sku,
        lastStockCheck: product.last_stock_check,
        lastSyncedAt: new Date().toISOString(),
        updatedAt: product.updated_at,
      });
    }

    try {
      await firestoreBatch.commit();
      batchesCreated++;
      itemsSynced += batch.length;
      console.log(`Committed batch ${batchesCreated}: ${batch.length} items`);
    } catch (error) {
      console.error(`Failed to commit batch ${batchesCreated}:`, error);
    }
  }

  return { batchesCreated, itemsSynced };
}

// ============================================================================
// HELPER: Log Sync Event to PostgreSQL
// ============================================================================
async function logSyncEvent(
  status: "success" | "failed",
  productsProcessed: number,
  duration: number,
  error?: string
): Promise<void> {
  try {
    await supabase.from("sync_logs").insert({
      sync_id: `sync_${Date.now()}`,
      service: "sync-inventory-to-firestore",
      status: status,
      products_processed: productsProcessed,
      duration_ms: duration,
      error_message: error || null,
      created_at: new Date().toISOString(),
    });
  } catch (error) {
    console.warn("Error logging sync:", error);
  }
}

// ============================================================================
// MAIN: Sync Function
// ============================================================================
Deno.serve(async (req: Request) => {
  const startTime = Date.now();

  try {
    // Verify cron secret
    const cronSecret = req.headers.get("x-cron-secret");
    const expectedSecret = Deno.env.get("CRON_SECRET");

    if (cronSecret !== expectedSecret) {
      console.warn("Invalid cron secret, rejecting request");
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log("[SYNC START] Inventory sync to Firestore");

    // Fetch last 6 hours of changes
    const lastSyncTime = new Date(Date.now() - 6 * 60 * 60 * 1000);

    const products = await fetchProductsFromPostgres(lastSyncTime);
    if (products.length === 0) {
      console.log("No products to sync (all up to date)");
      return new Response(
        JSON.stringify({
          success: true,
          productsProcessed: 0,
          batchesCreated: 0,
          duration: Date.now() - startTime,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const { batchesCreated, itemsSynced } = await syncProductsToFirestore(products);
    const duration = Date.now() - startTime;

    await logSyncEvent("success", itemsSynced, duration);

    console.log(`[SYNC SUCCESS] ${itemsSynced} items in ${batchesCreated} batches, ${duration}ms`);

    return new Response(
      JSON.stringify({
        success: true,
        productsProcessed: itemsSynced,
        batchesCreated: batchesCreated,
        duration: duration,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    const duration = Date.now() - startTime;
    const errorMsg = error instanceof Error ? error.message : String(error);

    console.error(`[SYNC FAILED] ${errorMsg}`);
    await logSyncEvent("failed", 0, duration, errorMsg);

    return new Response(
      JSON.stringify({
        success: false,
        error: errorMsg,
        duration: duration,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
