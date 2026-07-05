import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface CreateDeliveryTaskRequest {
  orderId: string;
  shopId: string;
  deliveryFee: number;
  estimatedDistance?: number;
  deliveryAddress?: string;
  customerPhone?: string;
  deliveryType?: string;
  customerId?: string;
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
    const body: CreateDeliveryTaskRequest = await req.json();

    // VALIDATION
    if (!body.orderId || !body.shopId || body.deliveryFee === undefined) {
      return new Response(
        JSON.stringify({
          error: "MISSING_FIELDS",
          message: "orderId, shopId, and deliveryFee are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // SECURITY: Verify order exists and is in valid state
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, status, customer_id")
      .eq("id", body.orderId)
      .single();

    if (orderError || !order) {
      return new Response(
        JSON.stringify({ error: "ORDER_NOT_FOUND", message: "Order does not exist" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Only create delivery task if order is packed (ready for delivery)
    if (order.status !== "packed") {
      return new Response(
        JSON.stringify({
          error: "INVALID_ORDER_STATE",
          message: `Order must be packed, current status: ${order.status}`,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // CREATE DELIVERY TASK (server-side)
    // This ensures all delivery tasks go through one single point of creation
    const { data: task, error: taskError } = await supabase
      .from("delivery_tasks")
      .insert({
        order_id: body.orderId,
        shop_id: body.shopId,
        customer_id: body.customerId || order.customer_id,
        status: "assigned", // Unassigned state
        delivery_fee: body.deliveryFee,
        estimated_distance: body.estimatedDistance || null,
        delivery_address: body.deliveryAddress || null,
        customer_phone: body.customerPhone || null,
        delivery_type: body.deliveryType || "standard",
        created_at: new Date(),
        updated_at: new Date(),
      })
      .select("*")
      .single();

    if (taskError) {
      console.error("Error creating delivery task:", taskError);
      return new Response(
        JSON.stringify({
          error: "CREATION_FAILED",
          message: taskError.message,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // UPDATE ORDER to reference delivery task
    const { error: updateError } = await supabase
      .from("orders")
      .update({
        delivery_task_id: task.id,
        status: "processing", // Move to processing (packing done, delivery started)
        updated_at: new Date(),
      })
      .eq("id", body.orderId);

    if (updateError) {
      console.error("Error updating order:", updateError);
      // Don't fail - task is created, order update is secondary
    }

    // LOG AUDIT
    await supabase.from("audit_log").insert({
      action: "DELIVERY_TASK_CREATED",
      order_id: body.orderId,
      delivery_task_id: task.id,
      shop_id: body.shopId,
      delivery_fee: body.deliveryFee,
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        task: task,
      }),
      { status: 201, headers: { "Content-Type": "application/json" } }
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
