import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createHmac } from "https://deno.land/std@0.208.0/node/crypto.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const razorpayWebhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") || "";

interface RazorpayPayment {
  id: string;
  entity: string;
  amount: number;
  currency: string;
  status: string;
  order_id: string;
  invoice_id?: string;
  international: boolean;
  method: string;
  description?: string;
  amount_refunded: number;
  refund_status?: string;
  captured: boolean;
  description?: string;
  card_id?: string;
  bank?: string;
  wallet?: string;
  vpa?: string;
  email: string;
  contact: string;
  notes: Record<string, any>;
  fee?: number;
  tax?: number;
  error_code?: string;
  error_description?: string;
  error_source?: string;
  error_reason?: string;
  error_step?: string;
  error_metadata?: Record<string, any>;
  acquirer_data?: Record<string, any>;
  created_at: number;
}

interface RazorpayWebhookPayload {
  entity: string;
  event: string;
  contains: string[];
  payload: {
    payment: {
      entity: RazorpayPayment;
    };
  };
  created_at: number;
}

// Verify Razorpay signature
function verifyRazorpaySignature(
  body: string,
  signature: string,
  secret: string
): boolean {
  try {
    const hmac = createHmac("sha256", secret);
    hmac.update(body);
    const computed = hmac.digest("hex");
    return computed === signature;
  } catch (e) {
    console.error("Signature verification error:", e);
    return false;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, x-client-info, content-type, x-razorpay-signature",
      },
    });
  }

  try {
    const signature = req.headers.get("x-razorpay-signature");
    if (!signature) {
      console.error("Missing Razorpay signature");
      return new Response(
        JSON.stringify({ error: "MISSING_SIGNATURE" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const body = await req.text();

    // GAP 3 FIX: VERIFY RAZORPAY SIGNATURE
    // This prevents webhook spoofing/tampering
    if (!verifyRazorpaySignature(body, signature, razorpayWebhookSecret)) {
      console.error("Signature verification failed");
      return new Response(
        JSON.stringify({ error: "INVALID_SIGNATURE" }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }

    const payload: RazorpayWebhookPayload = JSON.parse(body);

    // Only process payment events
    if (payload.event !== "payment.authorized" && payload.event !== "payment.failed") {
      console.log(`Ignoring event: ${payload.event}`);
      return new Response(JSON.stringify({ status: "ignored" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payment = payload.payload.payment.entity;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // GAP 3 FIX: RECONCILE PAYMENT WITH ORDER
    // This handles the case where app crashed before updating order
    // Example: payment succeeded but order never marked as confirmed

    if (payload.event === "payment.authorized") {
      // PAYMENT SUCCESS: Reconcile and confirm order

      // 1. Find order by Razorpay payment_id
      const { data: paymentRecord, error: paymentError } = await supabase
        .from("payments")
        .select("*")
        .eq("razorpay_payment_id", payment.id)
        .single();

      if (paymentError && paymentError.code !== "PGRST116") {
        console.error("Error fetching payment:", paymentError);
        throw new Error(`Payment fetch failed: ${paymentError.message}`);
      }

      if (!paymentRecord) {
        // Payment record doesn't exist yet - create it
        const { error: insertError } = await supabase.from("payments").insert({
          razorpay_payment_id: payment.id,
          razorpay_order_id: payment.order_id,
          amount: payment.amount / 100, // Convert paise to rupees
          currency: payment.currency,
          status: "authorized",
          method: payment.method,
          email: payment.email,
          contact: payment.contact,
          notes: payment.notes,
          captured: payment.captured,
          created_at: new Date(payment.created_at * 1000),
        });

        if (insertError) {
          console.error("Error creating payment record:", insertError);
          throw new Error(`Payment insert failed: ${insertError.message}`);
        }
      } else {
        // Payment already exists - check if it needs updating
        if (paymentRecord.status !== "authorized") {
          const { error: updateError } = await supabase
            .from("payments")
            .update({
              status: "authorized",
              captured: payment.captured,
              amount: payment.amount / 100,
            })
            .eq("id", paymentRecord.id);

          if (updateError) {
            console.error("Error updating payment:", updateError);
            throw new Error(`Payment update failed: ${updateError.message}`);
          }
        }
      }

      // 2. Find associated order
      const { data: order, error: orderError } = await supabase
        .from("orders")
        .select("*")
        .eq("razorpay_payment_id", payment.id)
        .single();

      if (orderError && orderError.code !== "PGRST116") {
        console.error("Error fetching order:", orderError);
        // Don't fail - payment still succeeded
      } else if (order && order.status === "pending_payment") {
        // Order exists but hasn't been confirmed yet
        // This handles the crash scenario: payment succeeded but order wasn't updated

        // Confirm the order via command function (idempotent)
        const { data: result, error: confirmError } = await supabase
          .rpc("checkout_process_command", {
            p_user_id: order.user_id,
            p_order_id: order.id,
            p_payment_id: payment.id,
            p_payment_amount: payment.amount / 100,
            p_payment_signature: signature,
            p_idempotency_key: `webhook:${payment.id}`, // Use payment_id as idempotency key
          })
          .single();

        if (confirmError || !result?.success) {
          console.error(`Order confirmation failed: ${result?.error_message}`);
          // Log but don't fail - payment is still captured
          await supabase.from("audit_log").insert({
            action: "WEBHOOK_ORDER_CONFIRMATION_FAILED",
            payment_id: payment.id,
            order_id: order.id,
            error: result?.error_message || confirmError?.message,
            timestamp: new Date(),
          });
        }
      }

      // AUDIT LOG
      await supabase.from("audit_log").insert({
        action: "PAYMENT_AUTHORIZED",
        payment_id: payment.id,
        razorpay_order_id: payment.order_id,
        amount: payment.amount / 100,
        method: payment.method,
        email: payment.email,
        timestamp: new Date(),
      });

      return new Response(
        JSON.stringify({
          status: "success",
          message: "Payment authorized and order reconciled",
          payment_id: payment.id,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    } else if (payload.event === "payment.failed") {
      // PAYMENT FAILED: Mark order as cancelled

      const { data: order, error: orderError } = await supabase
        .from("orders")
        .select("*")
        .eq("razorpay_payment_id", payment.id)
        .single();

      if (order && order.status !== "cancelled" && order.status !== "refunded") {
        // Cancel order and release inventory
        const { error: cancelError } = await supabase
          .from("orders")
          .update({
            status: "cancelled",
            cancelled_reason: `Payment failed: ${payment.error_description || "Unknown error"}`,
            cancelled_at: new Date(),
          })
          .eq("id", order.id);

        if (cancelError) {
          console.error("Error cancelling order:", cancelError);
        }

        // Release reserved inventory
        await supabase.rpc("release_inventory_reservation", {
          p_order_id: order.id,
        });
      }

      // AUDIT LOG
      await supabase.from("audit_log").insert({
        action: "PAYMENT_FAILED",
        payment_id: payment.id,
        razorpay_order_id: payment.order_id,
        error_code: payment.error_code,
        error_description: payment.error_description,
        timestamp: new Date(),
      });

      return new Response(
        JSON.stringify({
          status: "success",
          message: "Payment failure processed",
          payment_id: payment.id,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ status: "processed" }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Webhook error:", error);

    // Always return 200 to Razorpay to acknowledge receipt
    // (They'll retry if we return 5xx)
    return new Response(
      JSON.stringify({
        status: "error",
        message: error.message,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  }
});
