import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.0";

interface ConfirmRequest {
  reservationId: string;
  orderId: string;
  userId?: string;
}

interface ConfirmResponse {
  success: boolean;
  orderId?: string;
  finalSoldStock?: number;
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
    const body = (await req.json()) as ConfirmRequest;

    // Validate input
    if (!body.reservationId || !body.orderId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Missing required fields: reservationId, orderId",
          errorCode: "INVALID_INPUT",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const startTime = Date.now();

    // Call atomic RPC function to confirm reservation
    const { data, error: rpcError } = await supabase.rpc(
      "confirm_inventory_atomic",
      {
        p_reservation_id: body.reservationId,
        p_order_id: body.orderId,
        p_user_id: body.userId || null,
      }
    );

    if (rpcError) {
      console.error("[confirm-inventory] RPC Error:", rpcError);

      // Handle specific error cases
      if (rpcError.message.includes("Reservation not found")) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Reservation not found or already confirmed (idempotent)",
            errorCode: "RESERVATION_NOT_FOUND",
          }),
          { status: 404, headers: { "Content-Type": "application/json" } }
        );
      }

      if (rpcError.message.includes("Reservation expired")) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Reservation has expired",
            errorCode: "RESERVATION_EXPIRED",
          }),
          { status: 410, headers: { "Content-Type": "application/json" } }
        );
      }

      if (rpcError.message.includes("Already confirmed")) {
        // Idempotent: return success for already confirmed
        return new Response(
          JSON.stringify({
            success: true,
            message: "Already confirmed (idempotent)",
            orderId: body.orderId,
          }),
          {
            status: 200,
            headers: { "Content-Type": "application/json" },
          }
        );
      }

      if (rpcError.message.includes("Stock mismatch")) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Stock mismatch - inventory changed during checkout",
            errorCode: "STOCK_MISMATCH",
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
        api_name: "confirm",
        user_id: body.userId || null,
        product_id: data?.product_id,
        quantity: data?.quantity,
        status: "success",
        reservation_id: body.reservationId,
        order_id: body.orderId,
        duration_ms: duration,
        created_at: new Date().toISOString(),
      });

    if (logError) {
      console.warn("[confirm-inventory] Logging error:", logError);
      // Don't fail the API call due to logging errors
    }

    return new Response(
      JSON.stringify({
        success: true,
        orderId: body.orderId,
        finalSoldStock: data?.final_sold_stock,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("[confirm-inventory] Unexpected error:", error);

    // Log error
    try {
      await supabase
        .from("inventory_api_logs")
        .insert({
          api_name: "confirm",
          status: "error",
          error_message: String(error),
          duration_ms: 0,
          created_at: new Date().toISOString(),
        });
    } catch (e) {
      console.error("[confirm-inventory] Failed to log error:", e);
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
