import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import firebaseBridge from "../_shared/firebase-bridge.ts";

// This webhook is triggered by Postgres Database Webhooks
serve(async (req) => {
  try {
    const payload = await req.json();
    console.log("Received Postgres Webhook Payload:", JSON.stringify(payload));

    const { type, table, record, old_record } = payload;

    if (!table || !record) {
      return new Response("Invalid payload", { status: 400 });
    }

    let success = false;

    // Depending on the table that triggered the webhook, sync to Firestore
    switch (table) {
      case "products":
        if (type === "DELETE" && old_record) {
          // If we wanted to handle deletes, we'd add a deleteToFirestore in the bridge.
          console.log(`Product ${old_record.id} deleted. Firestore sync skipped in this example.`);
          success = true;
        } else {
          success = await firebaseBridge.syncProductToFirestore(record.id, record);
        }
        break;

      case "inventory":
        // Sync inventory changes downstream
        success = await firebaseBridge.syncInventoryToFirestore(record.id, record);
        break;
        
      case "orders":
        success = await firebaseBridge.syncOrderToFirestore(record.id, record);
        break;

      case "wallet_balance":
        if (record.user_id) {
          success = await firebaseBridge.syncWalletBalanceToFirestore(record.user_id, record);
        } else {
          console.log(`Wallet balance record missing user_id. Skip sync.`);
          success = true;
        }
        break;

      case "wallet_transactions":
        if (record.user_id && record.id) {
          success = await firebaseBridge.syncWalletTransactionToFirestore(record.user_id, record.id, record);
        } else {
          console.log(`Wallet transaction record missing user_id or id. Skip sync.`);
          success = true;
        }
        break;

      default:
        console.log(`Table ${table} not configured for Downstream Sync.`);
        success = true; // Ignore tables we don't care about
    }

    if (success) {
      return new Response(JSON.stringify({ success: true, message: "Synced to Firestore" }), {
        headers: { "Content-Type": "application/json" },
      });
    } else {
      return new Response(JSON.stringify({ success: false, error: "Failed to sync to Firestore" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  } catch (error) {
    console.error("Webhook processing error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
