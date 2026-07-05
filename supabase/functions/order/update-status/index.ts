import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface UpdateOrderStatusRequest {
  orderId: string;
  newStatus:
    | "confirmed"
    | "processing"
    | "packed"
    | "shipped"
    | "delivered"
    | "cancelled"
    | "failed_delivery"
    | "refunded"
    | "returned";
  userId: string; // who is making this change
  reason?: string;
  idempotencyKey: string; // CRITICAL: Prevents duplicate status updates
  currentVersion: number; // CRITICAL: Optimistic locking - must match current version
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
    const body: UpdateOrderStatusRequest = await req.json();

    // VALIDATION
    if (!body.orderId || !body.newStatus || !body.userId || !body.idempotencyKey || body.currentVersion === undefined) {
      return new Response(
        JSON.stringify({
          error: "MISSING_FIELDS",
          message: "orderId, newStatus, userId, idempotencyKey, and currentVersion are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const validStatuses = [
      "confirmed",
      "processing",
      "packed",
      "shipped",
      "delivered",
      "cancelled",
      "failed_delivery",
      "refunded",
      "returned",
    ];
    if (!validStatuses.includes(body.newStatus)) {
      return new Response(
        JSON.stringify({
          error: "INVALID_STATUS",
          message: `newStatus must be one of: ${validStatuses.join(", ")}`,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // P0-A FIX: COMMAND-BASED API (Domain-specific state machine)
    // Order status updates are governed by strict state machine rules
    // Only valid transitions allowed

    const { data: result, error: statusError } = await supabase
      .rpc("update_order_status_command", {
        p_order_id: body.orderId,
        p_new_status: body.newStatus,
        p_user_id: body.userId,
        p_reason: body.reason || null,
        p_idempotency_key: body.idempotencyKey,
        p_current_version: body.currentVersion,
      })
      .single();

    if (statusError || !result?.success) {
      console.error(`Failed to update order status: ${result?.error_message}`);

      // If version mismatch, it's a concurrency error (user tried to update stale data)
      if (result?.error_message?.includes("version")) {
        return new Response(
          JSON.stringify({
            error: "CONCURRENCY_ERROR",
            message: "Order was modified by someone else. Please refresh and try again.",
            currentVersion: result?.current_version,
          }),
          { status: 409, headers: { "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({
          error: "STATUS_UPDATE_FAILED",
          message: result?.error_message || "Failed to update order status",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // AUDIT LOG
    await supabase.from("audit_log").insert({
      action: "ORDER_STATUS_UPDATED",
      user_id: body.userId,
      order_id: body.orderId,
      old_status: result.old_status,
      new_status: body.newStatus,
      reason: body.reason || null,
      idempotency_key: body.idempotencyKey,
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Order status updated successfully",
        orderId: body.orderId,
        oldStatus: result.old_status,
        newStatus: body.newStatus,
        version: result.version, // CRITICAL: New version for next update
        updatedAt: result.updated_at,
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
