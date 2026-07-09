// Supabase Edge Function: Sync Inventory from PostgreSQL → Firestore
// Deploy: supabase functions deploy sync-inventory
// Trigger:
//   - Scheduled: `cron: "*/5 * * * *"` (every 5 minutes)
//   - On-demand: POST to function endpoint
//   - Webhook: from order checkout completion

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { initializeApp, cert } from "https://deno.land/x/firebase@1.0.3/mod.ts";
import { getFirestore } from "https://deno.land/x/firebase@1.0.3/firestore.ts";

interface Product {
  id: string;
  name: string;
  available_stock: number;
  reserved_stock: number;
  sold_stock: number;
  stock_quantity: number;
  branch_stock?: Record<string, number>;
  branch_stock_map?: Record<string, Record<string, number>>;
  updated_at: string;
}

interface SyncResult {
  success: boolean;
  synced: number;
  failed: number;
  duration_ms: number;
  errors?: string[];
}

Deno.serve(async (req: Request): Promise<Response> => {
  const startTime = Date.now();
  const errors: string[] = [];

  try {
    // ════════════════════════════════════════════════════════════════════
    // 1. INITIALIZE CLIENTS
    // ════════════════════════════════════════════════════════════════════

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const firebaseKey = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");

    if (!supabaseUrl || !supabaseKey || !firebaseKey) {
      throw new Error(
        "Missing environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or FIREBASE_SERVICE_ACCOUNT_KEY"
      );
    }

    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Initialize Firebase Admin SDK
    const firebaseConfig = JSON.parse(firebaseKey);
    const app = initializeApp({
      credential: cert(firebaseConfig),
      projectId: firebaseConfig.project_id,
    });
    const db = getFirestore(app);

    console.log("✓ Clients initialized");

    // ════════════════════════════════════════════════════════════════════
    // 2. FETCH ALL PRODUCTS FROM SUPABASE
    // ════════════════════════════════════════════════════════════════════

    const { data: products, error: fetchError } = await supabase
      .from("products")
      .select(
        "id, name, available_stock, reserved_stock, sold_stock, stock_quantity, branch_stock, branch_stock_map, updated_at"
      );

    if (fetchError) {
      throw new Error(`Failed to fetch products from Supabase: ${fetchError.message}`);
    }

    if (!products || products.length === 0) {
      console.log("⚠️  No products found in Supabase");
      return new Response(
        JSON.stringify({
          success: true,
          synced: 0,
          failed: 0,
          duration_ms: Date.now() - startTime,
        } as SyncResult),
        {
          headers: { "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    console.log(`📦 Fetched ${products.length} products from Supabase`);

    // ════════════════════════════════════════════════════════════════════
    // 3. BATCH UPDATE FIRESTORE
    // ════════════════════════════════════════════════════════════════════

    let syncedCount = 0;
    let failedCount = 0;

    // Process in batches of 500 (Firestore batch limit)
    for (let i = 0; i < products.length; i += 500) {
      const batch = products.slice(i, i + 500);
      const writeBatch = db.batch();

      for (const product of batch as Product[]) {
        try {
          const docRef = db.collection("products").doc(product.id);

          writeBatch.update(docRef, {
            availableStock: product.available_stock || 0,
            reservedStock: product.reserved_stock || 0,
            soldStock: product.sold_stock || 0,
            stockQuantity: product.stock_quantity || 0,
            branchStock: product.branch_stock || {},
            branchStockMap: product.branch_stock_map || {},
            updatedAt: new Date(product.updated_at || Date.now()),
            lastSyncedAt: new Date(),
          });

          syncedCount++;
        } catch (err) {
          failedCount++;
          const errorMsg = `Failed to sync product ${product.id}: ${err.message}`;
          console.error(errorMsg);
          errors.push(errorMsg);
        }
      }

      try {
        await writeBatch.commit();
        console.log(`✓ Synced batch of ${batch.length} products`);
      } catch (err) {
        const errorMsg = `Firestore batch commit failed: ${err.message}`;
        console.error(errorMsg);
        errors.push(errorMsg);
        failedCount += batch.length;
      }
    }

    // ════════════════════════════════════════════════════════════════════
    // 4. LOG SYNC COMPLETION
    // ════════════════════════════════════════════════════════════════════

    const duration = Date.now() - startTime;
    const result: SyncResult = {
      success: failedCount === 0,
      synced: syncedCount,
      failed: failedCount,
      duration_ms: duration,
      errors: errors.length > 0 ? errors : undefined,
    };

    console.log(`
✓ SYNC COMPLETE
  - Synced: ${syncedCount}
  - Failed: ${failedCount}
  - Duration: ${duration}ms
  - Success: ${result.success}
    `);

    // ════════════════════════════════════════════════════════════════════
    // 5. OPTIONAL: POST TO LOGGING SERVICE
    // ════════════════════════════════════════════════════════════════════

    try {
      const logsUrl = Deno.env.get("LOGS_WEBHOOK_URL");
      if (logsUrl) {
        await fetch(logsUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            timestamp: new Date().toISOString(),
            function: "sync-inventory",
            ...result,
          }),
        });
      }
    } catch (logErr) {
      console.warn(`Failed to post sync logs: ${logErr.message}`);
    }

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    const duration = Date.now() - startTime;
    const errorMsg = error instanceof Error ? error.message : String(error);

    console.error(`✗ SYNC FAILED: ${errorMsg}`);

    return new Response(
      JSON.stringify({
        success: false,
        synced: 0,
        failed: 0,
        duration_ms: duration,
        errors: [errorMsg],
      } as SyncResult),
      {
        headers: { "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});

// ════════════════════════════════════════════════════════════════════
// DEPLOYMENT INSTRUCTIONS
// ════════════════════════════════════════════════════════════════════
/*

### Step 1: Set Environment Variables in Supabase Dashboard

Go to Project Settings → Edge Functions → Environment Variables

Add:
- SUPABASE_URL: your-project.supabase.co
- SUPABASE_SERVICE_ROLE_KEY: (from Settings → API)
- FIREBASE_SERVICE_ACCOUNT_KEY: (paste entire JSON file)
- LOGS_WEBHOOK_URL: (optional, for monitoring)

### Step 2: Deploy Function

```bash
supabase functions deploy sync-inventory
```

### Step 3: Test Sync

```bash
curl -X POST https://your-project.supabase.co/functions/v1/sync-inventory \
  -H "Authorization: Bearer $(supabase functions get-jwt-token)" \
  -H "Content-Type: application/json"
```

### Step 4: Set Up Cron Trigger (Optional but Recommended)

Edit `supabase/functions/sync-inventory/index.ts` to add cron:

```typescript
export const config = {
  schedule: '*/5 * * * *', // Every 5 minutes
};
```

Then redeploy:
```bash
supabase functions deploy sync-inventory
```

### Step 5: Verify Sync Works

1. Update a product's stock in Supabase:
   ```sql
   UPDATE products SET available_stock = 42 WHERE id = 'prod_123' RETURNING *;
   ```

2. Wait up to 5 minutes (or trigger manually)

3. Check Firestore:
   ```javascript
   db.collection('products').doc('prod_123').get()
   // Should show availableStock: 42
   ```

### Monitoring

Check Firestore for `lastSyncedAt` field on products to verify sync is working.

View function logs:
```bash
supabase functions get-logs sync-inventory
```

*/
