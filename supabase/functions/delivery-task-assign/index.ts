import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface AssignDeliveryTaskRequest {
  taskId: string;
  riderId: string;
  riderName?: string;
  riderPhone?: string;
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
    const body: AssignDeliveryTaskRequest = await req.json();

    // VALIDATION
    if (!body.taskId || !body.riderId) {
      return new Response(
        JSON.stringify({
          error: "MISSING_FIELDS",
          message: "taskId and riderId are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // SECURITY: Get current task state
    const { data: task, error: taskError } = await supabase
      .from("delivery_tasks")
      .select("*")
      .eq("id", body.taskId)
      .single();

    if (taskError || !task) {
      return new Response(
        JSON.stringify({ error: "TASK_NOT_FOUND" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // VALIDATE TRANSITION: Can only assign from 'assigned' or 'failed' (reassign)
    const currentStatus = task.status;
    if (currentStatus !== "assigned" && currentStatus !== "failed") {
      return new Response(
        JSON.stringify({
          error: "INVALID_STATE",
          message: `Cannot assign delivery in status '${currentStatus}'`,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // SECURITY: Verify rider exists
    const { data: rider, error: riderError } = await supabase
      .from("delivery_agents")
      .select("id, name, phone")
      .eq("id", body.riderId)
      .single();

    if (riderError || !rider) {
      return new Response(
        JSON.stringify({ error: "RIDER_NOT_FOUND" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // ASSIGN TASK (atomic update with state machine validation)
    const { data: updated, error: updateError } = await supabase
      .from("delivery_tasks")
      .update({
        assigned_rider_id: body.riderId,
        assigned_rider_name: body.riderName || rider.name,
        assigned_rider_phone: body.riderPhone || rider.phone,
        assigned_at: new Date(),
        status: "assigned", // Explicitly set to assigned
        updated_at: new Date(),
      })
      .eq("id", body.taskId)
      .eq("status", currentStatus) // Optimistic lock: only update if status hasn't changed
      .select("*")
      .single();

    if (updateError || !updated) {
      return new Response(
        JSON.stringify({
          error: "ASSIGNMENT_FAILED",
          message: "Task status may have changed. Retry assignment.",
        }),
        { status: 409, headers: { "Content-Type": "application/json" } }
      );
    }

    // AUDIT LOG
    await supabase.from("audit_log").insert({
      action: "DELIVERY_TASK_ASSIGNED",
      delivery_task_id: body.taskId,
      rider_id: body.riderId,
      from_status: currentStatus,
      to_status: "assigned",
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Delivery task assigned successfully",
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
