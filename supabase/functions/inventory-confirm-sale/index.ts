import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface ConfirmSaleRequest {
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
    const body: ConfirmSaleRequest = await req.json();

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

    // MODULE 2 FIX: CONFIRM SALE (RESERVED → SOLD)
    // Called AFTER payment verification succeeds
    // Moves stock: reserved → sold (payment confirmed)
    // If any item fails, transaction fails (all-or-nothing)

    const confirmations: Array<{
      productId: string;
      quantity: number;
      confirmed: boolean;
      soldCount?: number;
      error?: string;
    }> = [];

    for (const item of body.items) {
      const { data: result, error: confirmError } = await supabase
        .rpc("confirm_inventory_sale_atomic", {
          p_product_id: item.productId,
          p_shop_id: body.shopId,
          p_order_id: body.orderId,
          p_quantity: item.quantity,
        })
        .single();

      if (confirmError || !result?.success) {
        console.error(
          `Failed to confirm sale for ${item.productId}: ${result?.error_message}`
        );

        confirmations.push({
          productId: item.productId,
          quantity: item.quantity,
          confirmed: false,
          error: result?.error_message || "Unknown error",
        });

        // CRITICAL: If even one item fails, we have a data integrity issue
        // Payment was taken but inventory wasn't released from reserved
        // This requires manual reconciliation

        return new Response(
          JSON.stringify({
            error: "SALE_CONFIRMATION_FAILED",
            message: `Cannot confirm sale. ${result?.error_message}. CRITICAL: Payment taken but inventory not released.`,
            orderId: body.orderId,
            failedItem: item.productId,
            confirmations: confirmations,
          }),
          { status: 409, headers: { "Content-Type": "application/json" } }
        );
      }

      confirmations.push({
        productId: item.productId,
        quantity: item.quantity,
        confirmed: true,
        soldCount: result.sold_after,
      });
    }

    // AUDIT LOG: All sales confirmed
    await supabase.from("audit_log").insert({
      action: "INVENTORY_SALE_CONFIRMED",
      order_id: body.orderId,
      shop_id: body.shopId,
      item_count: body.items.length,
      total_quantity: body.items.reduce((sum, item) => sum + item.quantity, 0),
      timestamp: new Date(),
    });

    // UPDATE ORDER STATUS to 'completed' or 'delivered'
    const { error: orderUpdateError } = await supabase
      .from("orders")
      .update({
        status: "completed",
        updated_at: new Date(),
      })
      .eq("id", body.orderId);

    if (orderUpdateError) {
      console.error("Error updating order status:", orderUpdateError);
      // Don't fail - inventory is confirmed, just order update is secondary
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Sale confirmed and inventory moved to sold",
        orderId: body.orderId,
        confirmations: confirmations,
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
