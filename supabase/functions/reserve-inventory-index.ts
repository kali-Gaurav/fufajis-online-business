/**
 * TASK 4a: Reserve Inventory Edge Function
 *
 * Purpose: Lock stock when customer starts checkout
 * Creates a reservation entry with 30-minute expiry
 * Uses PostgreSQL row-level locking for atomicity
 *
 * Endpoint: POST /inventory/reserve
 * Body: { productId, quantity, userId, orderId }
 * Response: { reservationId, availableAfter, expiresIn }
 */

import { createClient } from "@supabase/supabase-js";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

interface ReserveRequest {
  productId: string;
  quantity: number;
  userId: string;
  orderId: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const body: ReserveRequest = await req.json();
    const { productId, quantity, userId, orderId } = body;

    // Validate inputs
    if (!productId || !quantity || !userId || !orderId) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (quantity <= 0 || quantity > 1000) {
      return new Response(
        JSON.stringify({ error: "Quantity must be 1-1000" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Call PostgreSQL stored procedure: reserve_inventory_atomic()
    // This procedure:
    // 1. Locks the product row (FOR UPDATE)
    // 2. Checks available_stock >= quantity
    // 3. Moves quantity from available → reserved
    // 4. Returns new available_stock
    // All in one transaction
    const { data, error } = await supabase.rpc("reserve_inventory_atomic", {
      product_id: productId,
      quantity_reserved: quantity,
      order_id: orderId,
      user_id: userId,
    });

    if (error) {
      console.error("Reservation error:", error);

      // Differentiate error types
      if (error.message?.includes("insufficient")) {
        return new Response(
          JSON.stringify({
            error: "insufficient_stock",
            details: error.message,
          }),
          { status: 409, headers: { "Content-Type": "application/json" } }
        );
      }

      if (error.message?.includes("not found")) {
        return new Response(
          JSON.stringify({ error: "product_not_found" }),
          { status: 404, headers: { "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          error: "reservation_failed",
          details: error.message,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Success
    const result = data?.[0];
    const expiryMs = 30 * 60 * 1000; // 30 minutes

    return new Response(
      JSON.stringify({
        success: true,
        reservationId: result?.reservation_id,
        availableAfter: result?.available_stock,
        quantity: quantity,
        expiresIn: expiryMs,
        expiresAt: new Date(Date.now() + expiryMs).toISOString(),
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
