import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface TransitionDeliveryTaskRequest {
  taskId: string;
  currentStatus: string;
  newStatus: string;
  latitude?: number;
  longitude?: number;
  failureReason?: string;
  proofImageUrl?: string;
  notes?: string;
}

// Unified delivery state machine
const validTransitions: Record<string, string[]> = {
  assigned: ["picked_up", "failed", "cancelled"],
  picked_up: ["in_transit", "failed", "cancelled"],
  in_transit: ["delivered", "failed", "cancelled"],
  delivered: [], // Terminal
  failed: ["assigned"], // Can reassign
  cancelled: [], // Terminal
};

const terminalStatuses = ["delivered", "cancelled"];

function canTransition(from: string, to: string): boolean {
  if (from === to) return false;
  return (validTransitions[from] || []).includes(to);
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
    const body: TransitionDeliveryTaskRequest = await req.json();

    // VALIDATION
    if (!body.taskId || !body.currentStatus || !body.newStatus) {
      return new Response(
        JSON.stringify({
          error: "MISSING_FIELDS",
          message: "taskId, currentStatus, and newStatus are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // SECURITY: Validate state machine transition
    if (!canTransition(body.currentStatus, body.newStatus)) {
      return new Response(
        JSON.stringify({
          error: "INVALID_TRANSITION",
          message: `Invalid transition: ${body.currentStatus} → ${body.newStatus}`,
          currentStatus: body.currentStatus,
          attemptedStatus: body.newStatus,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Build update data based on status
    const updateData: Record<string, any> = {
      status: body.newStatus,
      updated_at: new Date(),
    };

    // Add status-specific fields
    if (body.newStatus === "picked_up") {
      updateData.picked_up_at = new Date();
      if (body.latitude) updateData.pickup_latitude = body.latitude;
      if (body.longitude) updateData.pickup_longitude = body.longitude;
    } else if (body.newStatus === "in_transit") {
      updateData.in_transit_at = new Date();
    } else if (body.newStatus === "delivered") {
      updateData.delivered_at = new Date();
      if (body.latitude) updateData.delivery_latitude = body.latitude;
      if (body.longitude) updateData.delivery_longitude = body.longitude;
      if (body.proofImageUrl) updateData.proof_image_url = body.proofImageUrl;
      if (body.notes) updateData.delivery_notes = body.notes;
    } else if (body.newStatus === "failed") {
      updateData.failed_at = new Date();
      updateData.last_failure_reason = body.failureReason || "Unknown";
      if (body.latitude) updateData.failure_latitude = body.latitude;
      if (body.longitude) updateData.failure_longitude = body.longitude;
    }

    // ATOMIC TRANSITION with optimistic lock
    const { data: updated, error: updateError } = await supabase
      .from("delivery_tasks")
      .update(updateData)
      .eq("id", body.taskId)
      .eq("status", body.currentStatus) // Optimistic lock
      .select("*")
      .single();

    if (updateError || !updated) {
      return new Response(
        JSON.stringify({
          error: "TRANSITION_FAILED",
          message: "Task status may have changed. Please retry.",
        }),
        { status: 409, headers: { "Content-Type": "application/json" } }
      );
    }

    // If delivered, update order status
    if (body.newStatus === "delivered") {
      const { error: orderError } = await supabase
        .from("orders")
        .update({
          status: "delivered",
          delivered_at: new Date(),
          updated_at: new Date(),
        })
        .eq("id", updated.order_id);

      if (orderError) {
        console.error("Error updating order:", orderError);
        // Don't fail - task is transitioned, order update is secondary
      }
    }

    // AUDIT LOG
    await supabase.from("audit_log").insert({
      action: "DELIVERY_TASK_TRANSITION",
      delivery_task_id: body.taskId,
      from_status: body.currentStatus,
      to_status: body.newStatus,
      latitude: body.latitude || null,
      longitude: body.longitude || null,
      notes: body.failureReason || body.notes || null,
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: `Delivery transitioned to ${body.newStatus}`,
        task: updated,
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
