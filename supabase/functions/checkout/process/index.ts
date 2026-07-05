import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface CheckoutProcessRequest {
  userId: string;
  orderId: string;
  paymentId: string; // Razorpay payment_id
  paymentAmount: number;
  paymentSignature: string; // Razorpay signature
  idempotencyKey: string; // CRITICAL: Prevents double-charging
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
    const body: CheckoutProcessRequest = await req.json();

    // VALIDATION
    if (
      !body.userId ||
      !body.orderId ||
      !body.paymentId ||
      body.paymentAmount === undefined ||
      !body.paymentSignature ||
      !body.idempotencyKey
    ) {
      return new Response(
        JSON.stringify({
          error: "MISSING_FIELDS",
          message: "All checkout fields including idempotencyKey are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (body.paymentAmount <= 0) {
      return new Response(
        JSON.stringify({
          error: "INVALID_AMOUNT",
          message: "Payment amount must be greater than 0",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // P0-A FIX: COMMAND-BASED API (Payment command with strict validation)
    // Checkout is most critical: payment verification + order confirmation
    // Must be idempotent to prevent double-charging

    const { data: result, error: checkoutError } = await supabase
      .rpc("checkout_process_command", {
        p_user_id: body.userId,
        p_order_id: body.orderId,
        p_payment_id: body.paymentId,
        p_payment_amount: body.paymentAmount,
        p_payment_signature: body.paymentSignature,
        p_idempotency_key: body.idempotencyKey,
      })
      .single();

    if (checkoutError || !result?.success) {
      console.error(`Checkout failed: ${result?.error_message}`);

      return new Response(
        JSON.stringify({
          error: "CHECKOUT_FAILED",
          message: result?.error_message || "Checkout could not be completed",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // AUDIT LOG
    await supabase.from("audit_log").insert({
      action: "CHECKOUT_COMPLETED",
      user_id: body.userId,
      order_id: body.orderId,
      payment_id: body.paymentId,
      payment_amount: body.paymentAmount,
      idempotency_key: body.idempotencyKey,
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Checkout completed successfully",
        orderId: body.orderId,
        paymentId: body.paymentId,
        paymentAmount: body.paymentAmount,
        orderStatus: result.order_status,
        version: result.version,
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
