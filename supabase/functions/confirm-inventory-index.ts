/**
 * TASK 4b: Confirm Inventory Edge Function
 *
 * Purpose: Move reserved stock → sold when payment succeeds
 * Fully idempotent: calling 5x with same reservationId = same result
 *
 * Endpoint: POST /inventory/confirm
 * Body: { reservationId }
 * Response: { success: true }
 */

import { createClient } from "@supabase/supabase-js";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

interface ConfirmRequest {
  reservationId: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const body: ConfirmRequest = await req.json();
    const { reservationId } = body;

    if (!reservationId) {
      return new Response(
        JSON.stringify({ error: "reservationId is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Call PostgreSQL stored procedure: confirm_inventory_sale_atomic()
    // This procedure:
    // 1. Looks up reservation by ID
    // 2. Checks expiry (must not be expired)
    // 3. Moves quantity from reserved → sold
    // 4. Marks reservation as confirmed
    // Idempotent: calling again returns success
    const { data, error } = await supabase.rpc("confirm_inventory_sale_atomic", {
      reservation_id: reservationId,
    });

    if (error) {
      console.error("Confirmation error:", error);

      if (error.message?.includes("expired")) {
        return new Response(
          JSON.stringify({
            error: "reservation_expired",
            details: "Reservation expired, please place order again",
          }),
          { status: 410, headers: { "Content-Type": "application/json" } }
        );
      }

      if (error.message?.includes("not found")) {
        return new Response(
          JSON.stringify({
            error: "reservation_not_found",
          }),
          { status: 404, headers: { "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          error: "confirmation_failed",
          details: error.message,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Success (idempotent)
    return new Response(
      JSON.stringify({
        success: true,
        message: "Stock confirmed as sold",
        reservationId: reservationId,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        message: error instanceof Error ? error.message : String(error),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
