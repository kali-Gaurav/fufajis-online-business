import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface UpdateOrderStatusRequest {
  orderId: string;
  currentStatus: string;
  newStatus: string;
  reason?: string;
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

    // VALIDATION 1: Both statuses provided
    if (!body.orderId || !body.currentStatus || !body.newStatus) {
      return new Response(
        JSON.stringify({
          error: "MISSING_FIELDS",
          message: "orderId, currentStatus, and newStatus are required",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // VALIDATION 2: Status is not same
    if (body.currentStatus === body.newStatus) {
      return new Response(
        JSON.stringify({
          error: "SAME_STATUS",
          message: "Order is already in this status",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // VALIDATION 3: Use PostgreSQL function to validate state machine
    // This ensures the transition is valid BEFORE updating
    const { data: result, error: validationError } = await supabase
      .rpc("update_order_status_validated", {
        p_order_id: body.orderId,
        p_current_status: body.currentStatus,
        p_new_status: body.newStatus,
      });

    if (validationError || !result || !result[0]?.success) {
      const errorMsg = result?.[0]?.error_message || "Order status transition failed";
      console.error("State machine validation failed:", errorMsg);

      return new Response(
        JSON.stringify({
          error: "INVALID_TRANSITION",
          message: errorMsg,
          currentStatus: body.currentStatus,
          attemptedStatus: body.newStatus,
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Log the action for audit
    await supabase.from("audit_log").insert({
      action: "ORDER_STATUS_UPDATE",
      order_id: body.orderId,
      from_status: body.currentStatus,
      to_status: body.newStatus,
      reason: body.reason || null,
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Order status updated successfully",
        orderId: body.orderId,
        newStatus: body.newStatus,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({
        error: "INTERNAL_SERVER_ERROR",
        message: error.message,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
