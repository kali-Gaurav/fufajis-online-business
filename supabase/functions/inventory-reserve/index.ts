import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface ReserveInventoryRequest {
  orderId: string;
  items: Array<{
    productId: string;
    quantity: number;
  }>;
  shopId: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, x-client-info, content-type",
      },
    });
  }

  try {
    const supabase = createClient(supabaseUrl, supabaseKey);
    const body: ReserveInventoryRequest = await req.json();

    // VALIDATION
    if (!body.orderId || !body.items || body.items.length === 0 || !body.shopId) {
      return new Response(
        JSON.stringify({
          error: "MISSING_FIELDS",
          message: "orderId, items, and shopId are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // MODULE 2 FIX: RESERVE INVENTORY FOR EACH ITEM (ATOMIC)
    // For each product, call reserve_inventory_atomic()
    // This moves stock: available → reserved
    // If ANY item fails, entire checkout fails (all-or-nothing)

    const reservations: Array<{
      productId: string;
      quantity: number;
      reserved: boolean;
      availableAfter?: number;
      error?: string;
    }> = [];

    let allSuccess = true;

    // TRANSACTION: Reserve all items or rollback
    for (const item of body.items) {
      const { data: result, error: reserveError } = await supabase
        .rpc("reserve_inventory_atomic", {
          p_product_id: item.productId,
          p_shop_id: body.shopId,
          p_order_id: body.orderId,
          p_quantity: item.quantity,
        })
        .single();

      if (reserveError || !result?.success) {
        allSuccess = false;
        reservations.push({
          productId: item.productId,
          quantity: item.quantity,
          reserved: false,
          error: result?.error_message || "Unknown error",
        });

        console.error(`Failed to reserve ${item.quantity} of ${item.productId}: ${result?.error_message}`);

        // ROLLBACK: Release previously reserved items
        for (const prev of reservations) {
          if (prev.reserved) {
            const { error: releaseError } = await supabase.rpc(
              "cancel_inventory_reservation_atomic",
              {
                p_product_id: prev.productId,
                p_shop_id: body.shopId,
                p_order_id: body.orderId,
                p_quantity: prev.quantity,
              }
            );

            if (releaseError) {
              console.error(`CRITICAL: Failed to rollback reservation for ${prev.productId}`);
            }
          }
        }

        return new Response(
          JSON.stringify({
            error: "RESERVATION_FAILED",
            message: `Cannot reserve all items. ${result?.error_message}`,
            failedItem: item.productId,
            reservations: reservations,
          }),
          { status: 409, headers: { "Content-Type": "application/json" } }
        );
      }

      // Success
      reservations.push({
        productId: item.productId,
        quantity: item.quantity,
        reserved: true,
        availableAfter: result.available_after,
      });
    }

    // AUDIT LOG: All reservations successful
    await supabase.from("audit_log").insert({
      action: "INVENTORY_RESERVED_FOR_CHECKOUT",
      order_id: body.orderId,
      shop_id: body.shopId,
      item_count: body.items.length,
      total_quantity: body.items.reduce((sum, item) => sum + item.quantity, 0),
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Inventory reserved successfully",
        orderId: body.orderId,
        reservations: reservations,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({
        error: "INTERNAL_SERVER_ERROR",
        message: error.message,
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
