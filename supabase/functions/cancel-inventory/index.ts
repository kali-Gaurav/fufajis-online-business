import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.48.0";

interface CancelRequest {
  reservationId: string;
  userId?: string;
}

interface CancelResponse {
  success: boolean;
  restoredStock?: number;
  message?: string;
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
    const body = (await req.json()) as CancelRequest;

    // Validate input
    if (!body.reservationId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Missing required field: reservationId",
          errorCode: "INVALID_INPUT",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const startTime = Date.now();

    // Call atomic RPC function to cancel reservation
    const { data, error: rpcError } = await supabase.rpc(
      "cancel_inventory_atomic",
      {
        p_reservation_id: body.reservationId,
        p_user_id: body.userId || null,
      }
    );

    if (rpcError) {
      console.error("[cancel-inventory] RPC Error:", rpcError);

      // Handle specific error cases
      if (rpcError.message.includes("Reservation not found")) {
        // Idempotent: return success for already cancelled
        return new Response(
          JSON.stringify({
            success: true,
            message: "Already cancelled or never existed (idempotent)",
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      if (rpcError.message.includes("Already confirmed")) {
        // Can't cancel already confirmed orders
        return new Response(
          JSON.stringify({
            success: false,
            error: "Cannot cancel confirmed order (already sold)",
            errorCode: "ORDER_ALREADY_CONFIRMED",
          }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }

      if (rpcError.message.includes("Stock mismatch")) {
        // Log but still try to cancel
        console.error(
          "[cancel-inventory] Stock mismatch during cancel:",
          rpcError
        );
        return new Response(
          JSON.stringify({
            success: false,
            error: "Stock mismatch detected - inventory may be corrupted",
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
        api_name: "cancel",
        user_id: body.userId || null,
        product_id: data?.product_id,
        quantity: data?.quantity,
        status: "success",
        reservation_id: body.reservationId,
        duration_ms: duration,
        created_at: new Date().toISOString(),
      });

    if (logError) {
      console.warn("[cancel-inventory] Logging error:", logError);
      // Don't fail the API call due to logging errors
    }

    return new Response(
      JSON.stringify({
        success: true,
        restoredStock: data?.restored_stock,
        message: "Reservation cancelled successfully",
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("[cancel-inventory] Unexpected error:", error);

    // Log error
    try {
      await supabase
        .from("inventory_api_logs")
        .insert({
          api_name: "cancel",
          status: "error",
          error_message: String(error),
          duration_ms: 0,
          created_at: new Date().toISOString(),
        });
    } catch (e) {
      console.error("[cancel-inventory] Failed to log error:", e);
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
