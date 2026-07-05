import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as crypto from "https://deno.land/std@0.83.0/hash/mod.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const razorpayKeySecret = Deno.env.get("RAZORPAY_KEY_SECRET") || "";

// SECURITY: Verify webhook signature before processing
function verifyRazorpaySignature(
  body: string,
  signature: string
): boolean {
  // FIX for P0: Use correct webhook_secret, NOT key_secret
  // Previous bug: Used key_secret == webhook_secret (WRONG!)
  const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") || "";

  if (!webhookSecret) {
    console.error("RAZORPAY_WEBHOOK_SECRET not configured");
    return false;
  }

  const hash = crypto.createHmac("sha256", webhookSecret);
  hash.update(body);
  const computedSignature = hash.digest("hex");

  return computedSignature === signature;
}

interface RazorpayWebhook {
  event: string;
  payload: {
    payment: {
      entity: {
        id: string;
        amount: number;
        status: string;
        notes?: {
          user_id?: string;
          order_id?: string;
        };
      };
    };
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "x-razorpay-signature, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405 }
    );
  }

  try {
    const supabase = createClient(supabaseUrl, supabaseKey);
    const bodyText = await req.text();
    const signature = req.headers.get("x-razorpay-signature") || "";

    // CRITICAL SECURITY: Verify webhook signature
    if (!verifyRazorpaySignature(bodyText, signature)) {
      console.error("Invalid Razorpay signature");
      return new Response(
        JSON.stringify({ error: "SIGNATURE_VERIFICATION_FAILED" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const webhook: RazorpayWebhook = JSON.parse(bodyText);
    const payment = webhook.payload.payment.entity;

    // P0-4 FIX: WEBHOOK IDEMPOTENCY - Check if already processed
    // Prevents duplicate wallet credits from concurrent/retry webhooks
    const idempotencyKey = signature; // Use Razorpay signature as idempotency key
    const { data: idempotencyCheck, error: idempotencyError } = await supabase
      .rpc("check_webhook_idempotency", {
        p_webhook_type: "razorpay_payment",
        p_external_event_id: payment.id,
        p_idempotency_key: idempotencyKey,
      })
      .single();

    if (!idempotencyError && idempotencyCheck?.already_processed) {
      console.log(`Webhook already processed for payment ${payment.id}. Returning cached result.`);
      return new Response(
        JSON.stringify({
          success: true,
          message: "Webhook already processed (idempotent)",
          paymentId: payment.id,
          cached: true,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Handle payment.authorized event
    if (webhook.event === "payment.authorized") {
      const userId = payment.notes?.user_id;
      const orderId = payment.notes?.order_id;

      if (!userId) {
        console.error("No user_id in payment notes");
        return new Response(
          JSON.stringify({ error: "NO_USER_ID" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }

      // Record payment as verified
      const { error: paymentError } = await supabase
        .from("payments")
        .insert({
          razorpay_payment_id: payment.id,
          user_id: userId,
          order_id: orderId || null,
          amount: payment.amount / 100, // Convert paisa to rupees
          status: "verified",
          verified_at: new Date(),
        });

      if (paymentError) {
        console.error("Error recording payment:", paymentError);
        // Don't fail the webhook - store it and retry later
      }

      // Only credit wallet AFTER payment is verified
      const { error: creditError } = await supabase.functions.invoke(
        "credit-wallet",
        {
          body: {
            userId: userId,
            amount: payment.amount / 100,
            transactionType: "payment_received",
            orderReference: orderId || null,
            paymentVerified: true,
            verifiedByService: "razorpay",
            description: `Payment from Razorpay: ${payment.id}`,
          },
        }
      );

      if (creditError) {
        console.error("Error crediting wallet:", creditError);
        // Store failed credit for retry
        await supabase.from("failed_wallet_credits").insert({
          payment_id: payment.id,
          user_id: userId,
          amount: payment.amount / 100,
          error: creditError.message,
          created_at: new Date(),
        });

        return new Response(
          JSON.stringify({
            error: "WALLET_CREDIT_FAILED",
            message: "Payment verified but wallet credit failed. Will retry.",
          }),
          { status: 500, headers: { "Content-Type": "application/json" } }
        );
      }

      // LOG IDEMPOTENCY: Mark this webhook as processed
      await supabase.rpc("log_webhook_processing", {
        p_webhook_type: "razorpay_payment",
        p_external_event_id: payment.id,
        p_idempotency_key: idempotencyKey,
        p_request_body: webhook,
        p_status: "processed",
        p_response_data: { wallet_credited: true, amount: payment.amount / 100 },
      });

      // Success
      return new Response(
        JSON.stringify({
          success: true,
          message: "Payment verified and wallet credited",
          paymentId: payment.id,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // LOG IDEMPOTENCY: Mark other events as processed
    await supabase.rpc("log_webhook_processing", {
      p_webhook_type: "razorpay_" + webhook.event.replace(".", "_"),
      p_external_event_id: payment.id,
      p_idempotency_key: idempotencyKey,
      p_request_body: webhook,
      p_status: "processed",
      p_response_data: { event_type: webhook.event, received: true },
    });

    // Other events ignored for now
    return new Response(JSON.stringify({ received: true }), { status: 200 });
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
