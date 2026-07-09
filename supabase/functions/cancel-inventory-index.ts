/**
 * TASK 4c: Cancel Inventory Edge Function
 *
 * Purpose: Release reserved stock when customer abandons checkout
 * Fully idempotent: calling 5x with same reservationId = same result
 *
 * Endpoint: POST /inventory/cancel
 * Body: { reservationId }
 * Response: { success: true }
 */

import { createClient } from "@supabase/supabase-js";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

interface CancelRequest {
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
    const body: CancelRequest = await req.json();
    const { reservationId } = body;

    if (!reservationId) {
      return new Response(
        JSON.stringify({ error: "reservationId is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Call PostgreSQL stored procedure: cancel_inventory_reservation_atomic()
    // This procedure:
    // 1. Looks up reservation by ID
    // 2. Moves quantity from reserved → available
    // 3. Marks reservation as cancelled
    // Idempotent: calling again with cancelled reservation returns success
    const { data, error } = await supabase.rpc("cancel_inventory_reservation_atomic", {
      reservation_id: reservationId,
    });

    if (error) {
      console.error("Cancellation error:", error);

      if (error.message?.includes("not found")) {
        // Idempotent: already cancelled or never existed
        console.log("Reservation not found or already cancelled (idempotent)");
        return new Response(
          JSON.stringify({
            success: true,
            message: "Already cancelled or not found (idempotent)",
            reservationId: reservationId,
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      }

      if (error.message?.includes("confirmed")) {
        return new Response(
          JSON.stringify({
            error: "cannot_cancel",
            details: "Cannot cancel confirmed reservations (payment already processed)",
          }),
          { status: 409, headers: { "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          error: "cancellation_failed",
          details: error.message,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Success (idempotent)
    return new Response(
      JSON.stringify({
        success: true,
        message: "Stock reservation cancelled, inventory released",
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
