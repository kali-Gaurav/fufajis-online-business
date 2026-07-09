import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.0";

interface ReserveRequest {
  productId: string;
  quantity: number;
  orderSessionId: string;
  userId?: string;
}

interface ReserveResponse {
  success: boolean;
  reservationId?: string;
  newAvailable?: number;
  error?: string;
  errorCode?: string;
}

// Initialize Supabase client
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseKey) {
  throw new Error("Missing Supabase environment variables");
}

const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req: Request) => {
  // Only POST allowed
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Only POST method allowed" }),
      { status: 405, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const body = (await req.json()) as ReserveRequest;

    // Validate input
    if (!body.productId || !body.quantity || !body.orderSessionId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Missing required fields: productId, quantity, orderSessionId",
          errorCode: "INVALID_INPUT",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (body.quantity <= 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Quantity must be greater than 0",
          errorCode: "INVALID_QUANTITY",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Begin transaction: Lock product row and check availability
    const startTime = Date.now();

    // Use RPC function for atomic operations
    const { data, error: rpcError } = await supabase.rpc(
      "reserve_inventory_atomic",
      {
        p_product_id: body.productId,
        p_quantity: body.quantity,
        p_order_session_id: body.orderSessionId,
        p_user_id: body.userId || null,
      }
    );

    if (rpcError) {
      console.error("[reserve-inventory] RPC Error:", rpcError);

      // Handle specific error cases
      if (rpcError.message.includes("Product not found")) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Product not found",
            errorCode: "PRODUCT_NOT_FOUND",
          }),
          { status: 404, headers: { "Content-Type": "application/json" } }
        );
      }

      if (rpcError.message.includes("Insufficient stock")) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Insufficient stock available",
            errorCode: "INSUFFICIENT_STOCK",
          }),
          { status: 409, headers: { "Content-Type": "application/json" } }
        );
      }

      // Generic database error
      return new Response(
        JSON.stringify({
          success: false,
          error: rpcError.message || "Database error",
          errorCode: "DB_ERROR",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const duration = Date.now() - startTime;

    // Log API call
    const { error: logError } = await supabase
      .from("inventory_api_logs")
      .insert({
        api_name: "reserve",
        user_id: body.userId || null,
        product_id: body.productId,
        quantity: body.quantity,
        status: "success",
        reservation_id: data?.reservation_id,
        duration_ms: duration,
        created_at: new Date().toISOString(),
      });

    if (logError) {
      console.warn("[reserve-inventory] Logging error:", logError);
      // Don't fail the API call due to logging errors
    }

    return new Response(
      JSON.stringify({
        success: true,
        reservationId: data?.reservation_id,
        newAvailable: data?.new_available,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("[reserve-inventory] Unexpected error:", error);

    // Log error
    try {
      await supabase
        .from("inventory_api_logs")
        .insert({
          api_name: "reserve",
          status: "error",
          error_message: String(error),
          duration_ms: 0,
          created_at: new Date().toISOString(),
        });
    } catch (e) {
      console.error("[reserve-inventory] Failed to log error:", e);
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: "Internal server error",
        errorCode: "INTERNAL_ERROR",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
