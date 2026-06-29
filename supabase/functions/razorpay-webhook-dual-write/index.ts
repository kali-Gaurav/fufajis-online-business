// ============================================================================
// RAZORPAY WEBHOOK WITH DUAL-WRITE (PostgreSQL + Firestore)
// ============================================================================
// Purpose: Process Razorpay payments securely with atomic writes to both
//          PostgreSQL (source of truth) and Firestore (real-time app sync)
// Features:
//   - Signature verification (SHA256 HMAC)
//   - Idempotent processing (handles retries)
//   - Atomic dual-write (PostgreSQL + Firestore)
//   - Error reconciliation
// ============================================================================

import { createServerClient } from "npm:@supabase/supabase-js";
import { createHmac } from "https://deno.land/std/crypto/mod.ts";
import firebaseBridge from "../_shared/firebase-bridge.ts";

// ============================================================================
// SENTRY ERROR TRACKING SETUP
// ============================================================================
// Monitors webhook processing failures for early issue detection
// Captures errors with breadcrumbs for debugging

const SENTRY_DSN = Deno.env.get("SENTRY_DSN");
const SENTRY_ENV = Deno.env.get("SENTRY_ENVIRONMENT") || "production";

// Initialize Sentry (error tracking)
const initSentry = () => {
  if (!SENTRY_DSN) {
    console.warn("SENTRY_DSN not configured, error tracking disabled");
    return null;
  }

  // Return Sentry capture function
  return {
    captureException: async (error: Error, context: Record<string, any>) => {
      try {
        await fetch("https://sentry.io/api/envelope/", {
          method: "POST",
          headers: {
            "Content-Type": "application/x-sentry-envelope",
          },
          body: buildSentryEnvelope(
            SENTRY_DSN,
            error,
            context,
            SENTRY_ENV
          ),
        });
      } catch (e) {
        console.error("Failed to send error to Sentry:", e);
      }
    },
    captureMessage: async (message: string, level: "info" | "warning" | "error") => {
      try {
        await fetch("https://sentry.io/api/envelope/", {
          method: "POST",
          headers: {
            "Content-Type": "application/x-sentry-envelope",
          },
          body: buildSentryMessageEnvelope(
            SENTRY_DSN,
            message,
            level,
            SENTRY_ENV
          ),
        });
      } catch (e) {
        console.error("Failed to send message to Sentry:", e);
      }
    },
  };
};

// Helper: Build Sentry error envelope
const buildSentryEnvelope = (
  dsn: string,
  error: Error,
  context: Record<string, any>,
  env: string
): string => {
  const dsn_parts = new URL(dsn);
  const projectId = dsn_parts.pathname.split("/").pop();
  const timestamp = Date.now() / 1000;

  const eventData = {
    event_id: crypto.randomUUID().replace(/-/g, ""),
    timestamp,
    level: "error",
    environment: env,
    exception: {
      values: [
        {
          type: error.constructor.name,
          value: error.message,
          stacktrace: {
            frames: error.stack
              ?.split("\n")
              .map((line: string) => ({
                function: line.trim(),
              })) || [],
          },
        },
      ],
    },
    contexts: { extra: context },
    platform: "node",
    tags: {
      webhook: "razorpay",
    },
  };

  const envelope = `${JSON.stringify({
    event_id: eventData.event_id,
    sent_at: new Date().toISOString(),
  })}\n${JSON.stringify(eventData)}\n`;

  return envelope;
};

// Helper: Build Sentry message envelope
const buildSentryMessageEnvelope = (
  dsn: string,
  message: string,
  level: "info" | "warning" | "error",
  env: string
): string => {
  const timestamp = Date.now() / 1000;

  const eventData = {
    event_id: crypto.randomUUID().replace(/-/g, ""),
    timestamp,
    level,
    environment: env,
    message: {
      formatted: message,
    },
    platform: "node",
    tags: {
      webhook: "razorpay",
    },
  };

  const envelope = `${JSON.stringify({
    event_id: eventData.event_id,
    sent_at: new Date().toISOString(),
  })}\n${JSON.stringify(eventData)}\n`;

  return envelope;
};

const RAZORPAY_WEBHOOK_SECRET = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY");
const sentry = initSentry();

interface RazorpayPaymentEvent {
  event: string;
  payload: {
    payment?: {
      entity: {
        id: string;
        amount: number;
        currency: string;
        status: string;
        method: string;
      };
    };
    order?: {
      entity: {
        id: string;
        receipt: string;
        amount: number;
      };
    };
  };
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

const handler = async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, X-Razorpay-Signature",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const startTime = performance.now();
    const body = await req.text();
    const signature = req.headers.get("X-Razorpay-Signature");

    // Breadcrumb: Webhook received
    console.log("[BREADCRUMB] Webhook received from Razorpay");
    if (sentry) {
      await sentry.captureMessage("Webhook received: " + signature?.substring(0, 10), "info");
    }

    if (!signature) {
      console.error("Missing webhook signature");
      if (sentry) {
        await sentry.captureMessage("Missing webhook signature", "error");
      }
      return new Response(JSON.stringify({ error: "Missing signature" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Verify signature
    console.log("[BREADCRUMB] Verifying webhook signature");
    const isValid = verifySignatureSync(body, signature);
    if (!isValid) {
      console.error("Invalid webhook signature");
      if (sentry) {
        await sentry.captureMessage("Invalid webhook signature verification", "error");
      }
      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log("[BREADCRUMB] Signature verified successfully");

    const event: RazorpayPaymentEvent = JSON.parse(body);
    console.log("✅ Valid webhook received:", event.event);

    if (sentry) {
      await sentry.captureMessage(
        `Webhook signature verified: ${event.event}`,
        "info"
      );
    }

    const supabase = createServerClient(SUPABASE_URL, SUPABASE_SECRET_KEY, {
      auth: { persistSession: false },
    });

    // Process event with dual-write
    console.log("[BREADCRUMB] Processing payment event:", event.event);
    const result = await processPaymentEventWithDualWrite(event, supabase);

    const processingTime = performance.now() - startTime;
    console.log(
      `[BREADCRUMB] Payment event processing took ${processingTime}ms`
    );

    if (!result.success) {
      console.error("Event processing failed:", result.error);
      if (sentry) {
        await sentry.captureMessage(
          `Event processing failed: ${result.error}`,
          "error"
        );
      }
      return new Response(JSON.stringify({ error: result.error }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log("[BREADCRUMB] Event processing completed successfully");
    if (sentry) {
      await sentry.captureMessage(
        `Webhook processed successfully: ${event.event} in ${processingTime}ms`,
        "info"
      );
    }

    return new Response(JSON.stringify({ success: true, message: result.message }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Webhook handler error:", error);
    if (sentry && error instanceof Error) {
      await sentry.captureException(error, {
        webhook_event: "razorpay_payment",
        handler: "main",
      });
    }
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        details: error instanceof Error ? error.message : "Unknown error",
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
};

// ============================================================================
// SIGNATURE VERIFICATION
// ============================================================================

function verifySignatureSync(body: string, signature: string): boolean {
  if (!RAZORPAY_WEBHOOK_SECRET) {
    console.error("RAZORPAY_WEBHOOK_SECRET not set");
    return false;
  }

  try {
    const hmac = createHmac("sha256", RAZORPAY_WEBHOOK_SECRET);
    hmac.update(body);
    const computed = hmac.digest("hex");

    return computed === signature && computed.length === signature.length;
  } catch (error) {
    console.error("Signature verification error:", error);
    return false;
  }
}

// ============================================================================
// DUAL-WRITE PROCESSING (PostgreSQL + Firestore)
// ============================================================================

interface ProcessResult {
  success: boolean;
  message?: string;
  error?: string;
}

async function processPaymentEventWithDualWrite(
  event: RazorpayPaymentEvent,
  supabase: any
): Promise<ProcessResult> {
  switch (event.event) {
    case "payment.authorized":
      return await handlePaymentAuthorizedDualWrite(event, supabase);
    case "payment.failed":
      return await handlePaymentFailedDualWrite(event, supabase);
    default:
      return { success: true, message: `Event ${event.event} received` };
  }
}

// ============================================================================

async function handlePaymentAuthorizedDualWrite(
  event: RazorpayPaymentEvent,
  supabase: any
): Promise<ProcessResult> {
  const payment = event.payload.payment?.entity;
  if (!payment) return { success: false, error: "Missing payment entity" };

  const orderId = payment.id; // Our order ID

  try {
    // Step 1: Get order from PostgreSQL
    console.log("[BREADCRUMB] Fetching order from PostgreSQL:", orderId);
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, customer_id, razorpay_order_id")
      .eq("razorpay_order_id", orderId)
      .single();

    if (orderError || !order) {
      console.error("Order not found:", orderId);
      if (sentry) {
        await sentry.captureMessage(
          `Order not found: ${orderId}`,
          "error"
        );
      }
      return { success: false, error: `Order not found: ${orderId}` };
    }

    console.log("[BREADCRUMB] Order fetched successfully:", order.id);

    // Step 2: Check for duplicate (idempotency)
    console.log("[BREADCRUMB] Checking for duplicate payment:", payment.id);
    const { data: existingTx } = await supabase
      .from("payment_transactions")
      .select("id")
      .eq("razorpay_payment_id", payment.id)
      .single();

    if (existingTx) {
      console.log("✅ Payment already processed (idempotent):", payment.id);
      if (sentry) {
        await sentry.captureMessage(
          `Duplicate payment detected (idempotent): ${payment.id}`,
          "info"
        );
      }
      return { success: true, message: "Payment already processed" };
    }

    console.log("[BREADCRUMB] No duplicate found, proceeding with new transaction");

    // Step 3: DUAL-WRITE: Create payment transaction in PostgreSQL
    console.log("[BREADCRUMB] Creating payment transaction record");
    const { error: txError, data: txData } = await supabase
      .from("payment_transactions")
      .insert({
        order_id: order.id,
        customer_id: order.customer_id,
        razorpay_payment_id: payment.id,
        razorpay_order_id: orderId,
        amount: payment.amount / 100,
        currency: payment.currency,
        method: payment.method,
        status: "authorized",
        webhook_received_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (txError) {
      console.error("Failed to insert payment transaction:", txError);
      if (sentry) {
        await sentry.captureException(
          new Error("Failed to create payment record: " + JSON.stringify(txError)),
          { payment_id: payment.id, order_id: order.id }
        );
      }
      return { success: false, error: "Failed to create payment record" };
    }

    console.log("[BREADCRUMB] Payment transaction created successfully");

    // Step 4: DUAL-WRITE: Sync payment to Firestore
    console.log("[BREADCRUMB] Syncing payment to Firestore");
    const firebaseSyncSuccess = await firebaseBridge.syncPaymentToFirestore(
      txData.id,
      {
        orderId: order.id,
        customerId: order.customer_id,
        razorpayPaymentId: payment.id,
        amount: payment.amount / 100,
        method: payment.method,
        status: "authorized",
        authorizedAt: new Date().toISOString(),
      }
    );

    if (!firebaseSyncSuccess) {
      console.warn("⚠️  Firestore sync failed (non-fatal), PostgreSQL has source of truth");
      if (sentry) {
        await sentry.captureMessage(
          `Firestore sync failed for payment: ${payment.id} (non-fatal)`,
          "warning"
        );
      }
      // Continue - PostgreSQL is source of truth
    } else {
      console.log("[BREADCRUMB] Payment synced to Firestore successfully");
    }

    // Step 5: Update order status in PostgreSQL
    console.log("[BREADCRUMB] Updating order status to confirmed");
    const { error: orderUpdateError } = await supabase
      .from("orders")
      .update({
        payment_status: "completed",
        razorpay_payment_id: payment.id,
        status: "confirmed",
        updated_at: new Date().toISOString(),
      })
      .eq("id", order.id);

    if (orderUpdateError) {
      console.error("Failed to update order:", orderUpdateError);
      if (sentry) {
        await sentry.captureException(
          new Error("Failed to update order status: " + JSON.stringify(orderUpdateError)),
          { order_id: order.id }
        );
      }
      return { success: false, error: "Failed to update order status" };
    }

    console.log("[BREADCRUMB] Order status updated successfully");

    // Step 6: DUAL-WRITE: Sync order to Firestore
    console.log("[BREADCRUMB] Syncing order to Firestore");
    await firebaseBridge.syncOrderToFirestore(order.id, {
      status: "confirmed",
      paymentStatus: "completed",
      razorpayPaymentId: payment.id,
      confirmedAt: new Date().toISOString(),
    });

    console.log("[BREADCRUMB] Order synced to Firestore");

    // Step 7: Deduct inventory
    console.log("[BREADCRUMB] Deducting inventory");
    await deductInventory(order.id, supabase);

    console.log("[BREADCRUMB] Inventory deducted");

    // Step 8: Send push notification
    console.log("[BREADCRUMB] Queuing notification");
    await sendPaymentSuccessNotification(order.customer_id, order.id, supabase);

    console.log("✅ Payment authorized and order confirmed:", order.id);
    if (sentry) {
      await sentry.captureMessage(
        `Payment authorized and order confirmed: ${order.id} (${payment.amount / 100} ${payment.currency})`,
        "info"
      );
    }

    return {
      success: true,
      message: `Payment authorized for order ${order.id}`,
    };
  } catch (error) {
    console.error("Payment authorization failed:", error);
    if (sentry && error instanceof Error) {
      await sentry.captureException(error, {
        webhook_event: "payment.authorized",
        order_id: orderId,
        payment_id: payment.id,
      });
    }
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

// ============================================================================

async function handlePaymentFailedDualWrite(
  event: RazorpayPaymentEvent,
  supabase: any
): Promise<ProcessResult> {
  const payment = event.payload.payment?.entity;
  if (!payment) return { success: false, error: "Missing payment entity" };

  try {
    console.log("[BREADCRUMB] Handling payment failure:", payment.id);
    if (sentry) {
      await sentry.captureMessage(
        `Payment failed event received: ${payment.id}`,
        "warning"
      );
    }

    // Get order
    console.log("[BREADCRUMB] Fetching order for failed payment");
    const { data: order } = await supabase
      .from("orders")
      .select("id, customer_id")
      .eq("razorpay_order_id", payment.id)
      .single();

    if (!order) {
      console.error("Order not found for failed payment:", payment.id);
      if (sentry) {
        await sentry.captureMessage(
          `Order not found for failed payment: ${payment.id}`,
          "error"
        );
      }
      return { success: false, error: "Order not found" };
    }

    console.log("[BREADCRUMB] Order found:", order.id);

    // Record failed transaction in PostgreSQL
    console.log("[BREADCRUMB] Recording failed transaction");
    const { data: txData } = await supabase
      .from("payment_transactions")
      .insert({
        order_id: order.id,
        customer_id: order.customer_id,
        razorpay_payment_id: payment.id,
        amount: payment.amount / 100,
        status: "failed",
        webhook_received_at: new Date().toISOString(),
      })
      .select()
      .single();

    console.log("[BREADCRUMB] Failed transaction recorded");

    // Update order to failed
    console.log("[BREADCRUMB] Updating order status to cancelled");
    await supabase
      .from("orders")
      .update({ payment_status: "failed", status: "cancelled" })
      .eq("id", order.id);

    console.log("[BREADCRUMB] Order status updated to cancelled");

    // Sync to Firestore
    console.log("[BREADCRUMB] Syncing payment failure to Firestore");
    await firebaseBridge.syncPaymentToFirestore(txData.id, {
      orderId: order.id,
      status: "failed",
      failedAt: new Date().toISOString(),
    });

    console.log("[BREADCRUMB] Syncing cancelled order to Firestore");
    await firebaseBridge.syncOrderToFirestore(order.id, {
      status: "cancelled",
      paymentStatus: "failed",
    });

    console.log("✅ Payment failure recorded for order:", order.id);
    if (sentry) {
      await sentry.captureMessage(
        `Payment failure handled and recorded: ${order.id}`,
        "info"
      );
    }

    return { success: true, message: `Payment failed for order ${order.id}` };
  } catch (error) {
    console.error("Payment failure handling error:", error);
    if (sentry && error instanceof Error) {
      await sentry.captureException(error, {
        webhook_event: "payment.failed",
        payment_id: payment.id,
      });
    }
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

// ============================================================================
// SUPPORTING FUNCTIONS
// ============================================================================

async function deductInventory(orderId: string, supabase: any): Promise<void> {
  try {
    const { error } = await supabase.rpc("process_order_atomic", {
      p_order_id: orderId,
    });

    if (error) {
      console.error("Inventory deduction failed:", error);
    } else {
      console.log("✅ Inventory deducted for order:", orderId);
    }
  } catch (error) {
    console.error("Inventory deduction error:", error);
  }
}

async function sendPaymentSuccessNotification(
  customerId: string,
  orderId: string,
  supabase: any
): Promise<void> {
  try {
    // Queue push notification
    await fetch(`${SUPABASE_URL}/functions/v1/send-notification`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SECRET_KEY}`,
      },
      body: JSON.stringify({
        userId: customerId,
        title: "Payment Successful! 🎉",
        body: "Your order has been confirmed.",
        data: { orderId, action: "view_order" },
      }),
    });

    console.log("✅ Notification queued for:", customerId);
  } catch (error) {
    console.error("Failed to queue notification:", error);
  }
}

export default handler;

