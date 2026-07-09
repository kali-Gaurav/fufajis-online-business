// Inventory Sync: PostgreSQL (source of truth) → Firestore (read-only cache)
// Runs every 5 minutes via external HTTP cron scheduler
// NEVER use Firebase Cloud Functions per CLAUDE.md
// Idempotent: safe to run multiple times

import { withSupabase, FunctionRequest } from "../_shared/withSupabase.ts";

interface SyncResult {
  timestamp: string;
  total_products: number;
  synced_count: number;
  failed_count: number;
  errors: Array<{
    product_id: string;
    reason: string;
  }>;
  duration_ms: number;
}

const handler = async (req: FunctionRequest): Promise<Response> => {
  const startTime = Date.now();

  // CORS headers
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    // Verify authorization (basic secret-based auth for cron jobs)
    const cronSecret = Deno.env.get("INVENTORY_SYNC_CRON_SECRET");
    const providedSecret = req.headers.get("X-Cron-Secret");

    if (!cronSecret || providedSecret !== cronSecret) {
      console.warn("Unauthorized sync attempt");
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    if (!req.supabase) {
      return new Response(
        JSON.stringify({ error: "Supabase client not initialized" }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const result = await syncInventoryToFirestore(req.supabase);

    const duration = Date.now() - startTime;
    return new Response(
      JSON.stringify({
        ...result,
        duration_ms: duration,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    const duration = Date.now() - startTime;
    console.error("Sync error:", error);

    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : "Unknown error",
        timestamp: new Date().toISOString(),
        duration_ms: duration,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
};

async function syncInventoryToFirestore(
  supabase: any
): Promise<SyncResult> {
  const errors: Array<{ product_id: string; reason: string }> = [];
  let syncedCount = 0;

  try {
    // 1. Fetch all products with inventory from PostgreSQL (source of truth)
    console.log("Fetching products from Supabase PostgreSQL...");

    const { data: products, error: fetchError } = await supabase
      .from("products")
      .select(
        `
        id,
        name,
        price,
        shop_id,
        is_active,
        total_quantity,
        reserved_quantity,
        inventory (
          quantity,
          reserved_quantity,
          available_quantity
        )
      `
      )
      .is("deleted_at", null);

    if (fetchError) {
      throw new Error(`Failed to fetch products: ${fetchError.message}`);
    }

    if (!products || products.length === 0) {
      console.log("No products found to sync");
      return {
        timestamp: new Date().toISOString(),
        total_products: 0,
        synced_count: 0,
        failed_count: 0,
        errors: [],
        duration_ms: 0,
      };
    }

    console.log(`Found ${products.length} products to sync`);

    // 2. Initialize Firestore client
    const firebaseAdminSdk = await initFirebaseAdmin();
    const db = firebaseAdminSdk.firestore();

    // 3. Batch write to Firestore (max 500 per batch)
    const batchSize = 450; // Leave some headroom
    for (let i = 0; i < products.length; i += batchSize) {
      const batch = db.batch();
      const chunk = products.slice(i, i + batchSize);

      for (const product of chunk) {
        try {
          const inventoryData = product.inventory?.[0];

          // Build inventory sync payload
          const syncData = {
            id: product.id,
            name: product.name,
            price: product.price,
            shop_id: product.shop_id,
            is_active: product.is_active,

            // 3-layer inventory model
            available_stock: inventoryData?.available_quantity || 0,
            reserved_stock: inventoryData?.reserved_quantity || 0,
            sold_stock: 0, // Calculated from products table total_quantity

            // Legacy compatibility fields
            stock_quantity: inventoryData?.quantity || product.total_quantity || 0,
            total_quantity: product.total_quantity || 0,
            reserved_quantity: product.reserved_quantity || 0,

            // Sync metadata
            synced_at: new Date().toISOString(),
            source: "postgresql",
          };

          const docRef = db.collection("products").doc(product.id);
          batch.set(docRef, syncData, { merge: true });
          syncedCount++;
        } catch (itemError) {
          errors.push({
            product_id: product.id,
            reason:
              itemError instanceof Error
                ? itemError.message
                : "Unknown error",
          });
          console.error(`Error processing product ${product.id}:`, itemError);
        }
      }

      // Commit batch
      await batch.commit();
      console.log(
        `Committed batch of ${chunk.length} products (${i + chunk.length}/${products.length})`
      );
    }

    // 4. Log sync completion
    await logSyncEvent(supabase, {
      total_products: products.length,
      synced_count: syncedCount,
      failed_count: errors.length,
      status: errors.length === 0 ? "success" : "partial_failure",
    });

    console.log(
      `Sync complete: ${syncedCount}/${products.length} products synced`
    );

    return {
      timestamp: new Date().toISOString(),
      total_products: products.length,
      synced_count: syncedCount,
      failed_count: errors.length,
      errors,
      duration_ms: 0,
    };
  } catch (error) {
    const errorMsg =
      error instanceof Error ? error.message : "Unknown sync error";

    // Log error
    await logSyncEvent(supabase, {
      total_products: 0,
      synced_count: 0,
      failed_count: 1,
      status: "error",
      error: errorMsg,
    }).catch((e) => {
      console.error("Failed to log sync error:", e);
    });

    throw error;
  }
}

async function initFirebaseAdmin() {
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");

  if (!serviceAccountJson) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON environment variable not set");
  }

  const serviceAccount = JSON.parse(serviceAccountJson);

  // Import Firebase Admin SDK dynamically
  const admin = await import("npm:firebase-admin@11.11.0");

  // Initialize if not already done
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }

  return admin;
}

async function logSyncEvent(
  supabase: any,
  eventData: {
    total_products: number;
    synced_count: number;
    failed_count: number;
    status: string;
    error?: string;
  }
): Promise<void> {
  try {
    const { error } = await supabase.from("sync_logs").insert({
      sync_type: "inventory_to_firestore",
      status: eventData.status,
      total_products: eventData.total_products,
      synced_count: eventData.synced_count,
      failed_count: eventData.failed_count,
      details: eventData.error ? { error: eventData.error } : null,
      synced_at: new Date().toISOString(),
    });

    if (error) {
      console.warn("Failed to log sync event:", error);
    }
  } catch (e) {
    console.error("Error logging sync event:", e);
  }
}

export default withSupabase(handler);
