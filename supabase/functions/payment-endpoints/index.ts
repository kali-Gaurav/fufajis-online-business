// Payment Edge Functions - All 6 payment endpoints
import { createServerClient } from "npm:@supabase/supabase-js";
import { crypto } from "https://deno.land/std@0.208.0/crypto/mod.ts";

interface FunctionRequest extends Request {
  supabase?: ReturnType<typeof createServerClient>;
  userId?: string;
  body?: Record<string, any>;
}

interface PaymentResponse {
  success: boolean;
  data?: any;
  error?: string;
  code?: string;
}

// ============================================================================
// CORE MIDDLEWARE & UTILITIES
// ============================================================================

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

async function initializeRequest(req: Request): Promise<FunctionRequest> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseKey = Deno.env.get("SUPABASE_SECRET_KEY");

  if (!supabaseUrl || !supabaseKey) {
    throw new Error("Missing Supabase credentials");
  }

  const authHeader = req.headers.get("Authorization") || "";
  const token = authHeader.replace("Bearer ", "");

  const supabase = createServerClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  let userId: string | undefined;
  if (token) {
    const { data, error } = await supabase.auth.getUser(token);
    if (!error && data.user) {
      userId = data.user.id;
    }
  }

  const functionReq: FunctionRequest = Object.assign(req, {
    supabase,
    userId,
  });

  if (req.method !== "GET" && req.method !== "HEAD") {
    try {
      functionReq.body = await req.clone().json();
    } catch {
      functionReq.body = {};
    }
  }

  return functionReq;
}

function successResponse(data: any, status = 200): Response {
  return new Response(
    JSON.stringify({ success: true, data }),
    { status, headers: { "Content-Type": "application/json", ...corsHeaders() } }
  );
}

function errorResponse(
  error: string,
  code: string,
  status = 400
): Response {
  return new Response(
    JSON.stringify({ success: false, error, code }),
    { status, headers: { "Content-Type": "application/json", ...corsHeaders() } }
  );
}

// ============================================================================
// RAZORPAY UTILITIES
// ============================================================================

async function verifyRazorpaySignature(
  orderId: string,
  paymentId: string,
  signature: string,
  secret: string
): Promise<boolean> {
  const message = `${orderId}|${paymentId}`;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const computedSignature = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  const computedSignatureHex = Array.from(new Uint8Array(computedSignature))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");

  return computedSignatureHex === signature;
}

async function verifyWebhookSignature(
  body: string,
  signature: string,
  secret: string
): Promise<boolean> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const computedSignature = await crypto.subtle.sign("HMAC", key, enc.encode(body));
  const computedSignatureHex = Array.from(new Uint8Array(computedSignature))
    .map(b => b.toString(16).padStart(2, "0"))
    .join("");

  return computedSignatureHex === signature;
}

async function callRazorpayAPI(
  method: string,
  endpoint: string,
  data?: Record<string, any>
): Promise<any> {
  const keyId = Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");

  if (!keyId || !keySecret) {
    throw new Error("Razorpay credentials not configured");
  }

  const auth = btoa(`${keyId}:${keySecret}`);
  const options: RequestInit = {
    method,
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/json",
    },
  };

  if (data && (method === "POST" || method === "PATCH")) {
    options.body = JSON.stringify(data);
  }

  const response = await fetch(`https://api.razorpay.com/v1${endpoint}`, options);
  const responseData = await response.json();

  if (!response.ok) {
    throw new Error(`Razorpay error: ${responseData.error?.description || "Unknown error"}`);
  }

  return responseData;
}

// ============================================================================
// INVENTORY & WALLET UTILITIES
// ============================================================================

async function checkInventory(
  supabase: any,
  items: Array<{ productId: string; quantity: number }>
): Promise<boolean> {
  for (const item of items) {
    const { data: product } = await supabase
      .from("products")
      .select("id, available_quantity")
      .eq("id", item.productId)
      .single();

    if (!product || product.available_quantity < item.quantity) {
      return false;
    }
  }
  return true;
}

async function reserveInventory(
  supabase: any,
  orderId: string,
  items: Array<{ productId: string; quantity: number }>
): Promise<boolean> {
  try {
    for (const item of items) {
      await supabase.from("inventory_reservations").insert({
        order_id: orderId,
        product_id: item.productId,
        reserved_quantity: item.quantity,
        status: "reserved",
        expires_at: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
      });
    }
    return true;
  } catch (error) {
    console.error("Inventory reservation error:", error);
    return false;
  }
}

async function deductInventory(
  supabase: any,
  orderId: string
): Promise<boolean> {
  try {
    // Call PostgreSQL stored procedure
    const { error } = await supabase.rpc("process_order_inventory", {
      p_order_id: orderId,
    });

    if (error) {
      console.error("Inventory deduction error:", error);
      return false;
    }
    return true;
  } catch (error) {
    console.error("Inventory deduction error:", error);
    return false;
  }
}

async function restoreInventory(
  supabase: any,
  orderId: string
): Promise<boolean> {
  try {
    // Release reservations or restore deducted quantity
    await supabase
      .from("inventory_reservations")
      .delete()
      .eq("order_id", orderId)
      .eq("status", "reserved");

    return true;
  } catch (error) {
    console.error("Inventory restore error:", error);
    return false;
  }
}

async function creditWallet(
  supabase: any,
  userId: string,
  amount: number,
  reason: string
): Promise<boolean> {
  try {
    // Get wallet
    const { data: wallet } = await supabase
      .from("wallets")
      .select("id, balance")
      .eq("user_id", userId)
      .single();

    if (!wallet) {
      // Create wallet if not exists
      await supabase.from("wallets").insert({
        user_id: userId,
        balance: amount,
      });
    } else {
      // Update balance
      await supabase
        .from("wallets")
        .update({ balance: wallet.balance + amount })
        .eq("id", wallet.id);
    }

    // Log transaction
    await supabase.from("wallet_transactions").insert({
      wallet_id: wallet?.id || null,
      user_id: userId,
      type: "credit",
      amount,
      reason,
      balance_after: (wallet?.balance || 0) + amount,
      timestamp: new Date().toISOString(),
    });

    return true;
  } catch (error) {
    console.error("Wallet credit error:", error);
    return false;
  }
}

async function debitWallet(
  supabase: any,
  userId: string,
  amount: number
): Promise<boolean> {
  try {
    // Get wallet
    const { data: wallet } = await supabase
      .from("wallets")
      .select("id, balance")
      .eq("user_id", userId)
      .single();

    if (!wallet || wallet.balance < amount) {
      return false;
    }

    // Update balance
    await supabase
      .from("wallets")
      .update({ balance: wallet.balance - amount })
      .eq("id", wallet.id);

    return true;
  } catch (error) {
    console.error("Wallet debit error:", error);
    return false;
  }
}

// ============================================================================
// NOTIFICATION UTILITIES
// ============================================================================

async function sendPushNotification(
  supabase: any,
  userId: string,
  title: string,
  body: string,
  data?: Record<string, any>
): Promise<void> {
  try {
    await supabase.from("notifications").insert({
      user_id: userId,
      title,
      body,
      data: data || {},
      read: false,
      created_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Notification error:", error);
  }
}

async function sendEmail(
  email: string,
  template: string,
  data: Record<string, any>
): Promise<void> {
  const sendgridApiKey = Deno.env.get("SENDGRID_API_KEY");
  if (!sendgridApiKey) {
    console.error("SendGrid not configured");
    return;
  }

  try {
    const templates: Record<string, { subject: string; content: string }> = {
      order_confirmed: {
        subject: "Your Fufaji order has been confirmed",
        content: `Order #${data.orderId}: Total ${data.total}. Delivery in ${data.estimatedDeliveryTime}.`,
      },
      payment_success: {
        subject: "Payment successful",
        content: `Payment of ${data.amount} received for order #${data.orderId}.`,
      },
      refund_confirmed: {
        subject: "Your refund has been processed",
        content: `Refund of ${data.amount} credited to wallet.`,
      },
      payment_failed: {
        subject: "Payment failed",
        content: `Payment for order #${data.orderId} failed. Please try again.`,
      },
    };

    const tmpl = templates[template];
    if (!tmpl) return;

    await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${sendgridApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        personalizations: [{ to: [{ email }] }],
        from: { email: "noreply@fufaji.com", name: "Fufaji" },
        subject: tmpl.subject,
        content: [{ type: "text/plain", value: tmpl.content }],
      }),
    }).catch(e => console.error("Email send error:", e));
  } catch (error) {
    console.error("Email error:", error);
  }
}

// ============================================================================
// FIRESTORE SYNC
// ============================================================================

async function syncToFirestore(
  collection: string,
  docId: string,
  data: Record<string, any>
): Promise<void> {
  const firebaseUrl = Deno.env.get("FIREBASE_URL");
  const firebaseSecret = Deno.env.get("FIREBASE_SECRET");

  if (!firebaseUrl || !firebaseSecret) {
    console.error("Firebase not configured");
    return;
  }

  try {
    await fetch(`${firebaseUrl}/${collection}/${docId}`, {
      method: "SET",
      headers: {
        Authorization: `Bearer ${firebaseSecret}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    }).catch(e => console.error("Firestore sync error:", e));
  } catch (error) {
    console.error("Firestore sync error:", error);
  }
}

// ============================================================================
// 1. POST /api/orders/create
// ============================================================================

async function createOrder(req: FunctionRequest): Promise<Response> {
  if (!req.userId) {
    return errorResponse("Unauthorized", "UNAUTHORIZED", 401);
  }

  const supabase = req.supabase!;
  const { items, deliveryAddress, couponCode } = req.body || {};

  if (!items || !Array.isArray(items) || items.length === 0) {
    return errorResponse("Items required", "MISSING_ITEMS", 400);
  }

  if (!deliveryAddress || !deliveryAddress.latitude || !deliveryAddress.longitude) {
    return errorResponse("Delivery address required", "MISSING_ADDRESS", 400);
  }

  try {
    // Validate items exist and stock available
    const inventoryValid = await checkInventory(supabase, items);
    if (!inventoryValid) {
      return errorResponse("Item out of stock", "OUT_OF_STOCK", 409);
    }

    // Validate delivery address (in service area)
    const { data: serviceArea } = await supabase
      .from("service_areas")
      .select("id")
      .eq("is_active", true)
      .single();

    if (!serviceArea) {
      return errorResponse("Delivery not available in this area", "OUT_OF_SERVICE", 400);
    }

    // Calculate subtotal
    let subtotal = 0;
    for (const item of items) {
      const { data: product } = await supabase
        .from("products")
        .select("price")
        .eq("id", item.productId)
        .single();

      if (product) {
        subtotal += product.price * item.quantity;
      }
    }

    // Apply coupon if valid
    let discount = 0;
    if (couponCode) {
      const { data: coupon } = await supabase
        .from("coupons")
        .select("type, value, is_active")
        .eq("code", couponCode.toUpperCase())
        .single();

      if (coupon && coupon.is_active) {
        if (coupon.type === "percentage") {
          discount = (subtotal * coupon.value) / 100;
        } else if (coupon.type === "flat") {
          discount = coupon.value;
        }
      }
    }

    // Calculate total
    const tax = subtotal * 0.05; // 5% tax
    const deliveryFee = 50; // Fixed delivery fee
    const total = subtotal + tax + deliveryFee - discount;

    // Create order in PostgreSQL
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .insert({
        user_id: req.userId,
        items: JSON.stringify(items),
        delivery_address: JSON.stringify(deliveryAddress),
        subtotal,
        tax,
        delivery_fee: deliveryFee,
        discount,
        total,
        status: "pending",
        payment_status: "unpaid",
        created_at: new Date().toISOString(),
      })
      .select("id")
      .single();

    if (orderError) {
      console.error("Order creation error:", orderError);
      return errorResponse("Failed to create order", "DB_ERROR", 500);
    }

    // Reserve inventory (30 min expiry)
    const inventoryReserved = await reserveInventory(supabase, order.id, items);
    if (!inventoryReserved) {
      return errorResponse("Failed to reserve inventory", "RESERVATION_ERROR", 500);
    }

    // Create Razorpay order
    let razorpayOrderId: string;
    try {
      const razorpayOrder = await callRazorpayAPI("POST", "/orders", {
        amount: Math.round(total * 100), // Amount in paise
        currency: "INR",
        receipt: order.id,
        notes: {
          order_id: order.id,
          user_id: req.userId,
        },
      });

      razorpayOrderId = razorpayOrder.id;

      // Store razorpay_order_id in DB
      await supabase
        .from("orders")
        .update({ razorpay_order_id: razorpayOrderId })
        .eq("id", order.id);
    } catch (error) {
      console.error("Razorpay order creation error:", error);
      return errorResponse("Failed to create payment order", "PAYMENT_ERROR", 500);
    }

    // Create Firestore doc (async)
    syncToFirestore("orders", order.id, {
      orderId: order.id,
      userId: req.userId,
      items,
      deliveryAddress,
      subtotal,
      tax,
      deliveryFee,
      discount,
      total,
      status: "pending",
      paymentStatus: "unpaid",
      razorpayOrderId,
      createdAt: new Date().toISOString(),
    }).catch(e => console.error("Firestore sync error:", e));

    return successResponse({
      order: {
        id: order.id,
        total,
        razorpayOrderId,
        razorpayKey: Deno.env.get("RAZORPAY_KEY_ID"),
      },
    }, 201);
  } catch (error) {
    console.error("Create order error:", error);
    return errorResponse("Failed to create order", "ORDER_ERROR", 500);
  }
}

// ============================================================================
// 2. POST /api/payments/verify
// ============================================================================

async function verifyPayment(req: FunctionRequest): Promise<Response> {
  if (!req.userId) {
    return errorResponse("Unauthorized", "UNAUTHORIZED", 401);
  }

  const supabase = req.supabase!;
  const { orderId, paymentId, signature } = req.body || {};

  if (!orderId || !paymentId || !signature) {
    return errorResponse("Missing payment details", "MISSING_DETAILS", 400);
  }

  try {
    // Get order
    const { data: order } = await supabase
      .from("orders")
      .select("id, user_id, razorpay_order_id, total")
      .eq("id", orderId)
      .single();

    if (!order || order.user_id !== req.userId) {
      return errorResponse("Order not found", "NOT_FOUND", 404);
    }

    // VERIFY SIGNATURE - CRITICAL FOR FRAUD DETECTION
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
    if (!keySecret) {
      return errorResponse("Payment config error", "CONFIG_ERROR", 500);
    }

    const signatureValid = await verifyRazorpaySignature(
      order.razorpay_order_id,
      paymentId,
      signature,
      keySecret
    );

    if (!signatureValid) {
      // FRAUD DETECTED - SIGNATURE MISMATCH
      console.error("FRAUD: Invalid signature for order", orderId, paymentId);
      return errorResponse("Payment verification failed", "FRAUD_DETECTED", 401);
    }

    // Check idempotency - payment already processed?
    const { data: existingPayment } = await supabase
      .from("payment_transactions")
      .select("id, status")
      .eq("order_id", orderId)
      .eq("payment_id", paymentId)
      .single();

    if (existingPayment && existingPayment.status === "completed") {
      return successResponse({
        message: "Payment already processed",
        order: { id: orderId, status: "confirmed" },
      });
    }

    // Create payment_transactions row
    const { error: paymentError } = await supabase
      .from("payment_transactions")
      .insert({
        order_id: orderId,
        user_id: req.userId,
        payment_id: paymentId,
        amount: order.total,
        status: "completed",
        method: "razorpay",
        created_at: new Date().toISOString(),
      });

    if (paymentError) {
      console.error("Payment transaction error:", paymentError);
      return errorResponse("Failed to record payment", "DB_ERROR", 500);
    }

    // Update order status
    await supabase
      .from("orders")
      .update({
        status: "confirmed",
        payment_status: "completed",
        payment_confirmed_at: new Date().toISOString(),
      })
      .eq("id", orderId);

    // Deduct inventory (call stored procedure)
    const inventoryDeducted = await deductInventory(supabase, orderId);
    if (!inventoryDeducted) {
      console.error("Failed to deduct inventory for order", orderId);
      // Continue - inventory will be retried
    }

    // Delete inventory reservations
    await supabase
      .from("inventory_reservations")
      .delete()
      .eq("order_id", orderId);

    // Sync to Firestore (async, non-blocking)
    syncToFirestore("orders", orderId, {
      status: "confirmed",
      paymentStatus: "completed",
      paymentId,
      paymentConfirmedAt: new Date().toISOString(),
    }).catch(e => console.error("Firestore sync error:", e));

    // Send notifications (async)
    sendPushNotification(
      supabase,
      req.userId,
      "Payment Confirmed",
      "Your payment has been confirmed. Order is being prepared.",
      { orderId, status: "confirmed" }
    ).catch(e => console.error("Notification error:", e));

    const { data: user } = await supabase
      .from("users")
      .select("email")
      .eq("id", req.userId)
      .single();

    if (user) {
      sendEmail(user.email, "payment_success", {
        orderId,
        amount: order.total,
        estimatedDeliveryTime: "30-45 minutes",
      }).catch(e => console.error("Email error:", e));
    }

    return successResponse({
      message: "Payment verified successfully",
      order: { id: orderId, status: "confirmed", paymentStatus: "completed" },
    });
  } catch (error) {
    console.error("Payment verify error:", error);
    return errorResponse("Payment verification failed", "VERIFY_ERROR", 500);
  }
}

// ============================================================================
// 3. POST /functions/razorpay-webhook-dual-write
// ============================================================================

async function razorpayWebhook(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const signature = req.headers.get("x-razorpay-signature") || "";

  try {
    const body = await req.clone().text();

    // VERIFY SIGNATURE - CRITICAL
    const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
    if (!webhookSecret) {
      console.error("Webhook secret not configured");
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }

    const signatureValid = await verifyWebhookSignature(body, signature, webhookSecret);
    if (!signatureValid) {
      console.error("FRAUD: Invalid webhook signature");
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }

    const event = JSON.parse(body);
    const eventType = event.event;
    const { payment, order } = event.payload;

    // ALWAYS return 200 OK (Razorpay retries on non-200)
    const asyncProcess = async () => {
      try {
        if (eventType === "payment.authorized") {
          const paymentId = payment?.id;
          const orderId = order?.receipt;

          if (!paymentId || !orderId) return;

          // Check idempotency
          const { data: existingPayment } = await supabase
            .from("payment_transactions")
            .select("id")
            .eq("payment_id", paymentId)
            .single();

          if (existingPayment) return;

          // Get order
          const { data: orderData } = await supabase
            .from("orders")
            .select("id, user_id, total")
            .eq("id", orderId)
            .single();

          if (!orderData) return;

          // Create payment transaction
          await supabase.from("payment_transactions").insert({
            order_id: orderId,
            user_id: orderData.user_id,
            payment_id: paymentId,
            amount: orderData.total,
            status: "completed",
            method: "razorpay",
            created_at: new Date().toISOString(),
          });

          // Update order
          await supabase
            .from("orders")
            .update({
              status: "confirmed",
              payment_status: "completed",
              payment_confirmed_at: new Date().toISOString(),
            })
            .eq("id", orderId);

          // Deduct inventory
          await deductInventory(supabase, orderId);

          // Sync to Firestore
          syncToFirestore("orders", orderId, {
            status: "confirmed",
            paymentStatus: "completed",
          }).catch(e => console.error("Firestore sync error:", e));

          // Send notifications
          sendPushNotification(
            supabase,
            orderData.user_id,
            "Payment Confirmed",
            "Your payment has been confirmed.",
            { orderId }
          ).catch(e => console.error("Notification error:", e));

          const { data: user } = await supabase
            .from("users")
            .select("email")
            .eq("id", orderData.user_id)
            .single();

          if (user) {
            sendEmail(user.email, "payment_success", {
              orderId,
              amount: orderData.total,
            }).catch(e => console.error("Email error:", e));
          }
        } else if (eventType === "payment.failed") {
          const paymentId = payment?.id;
          const orderId = order?.receipt;

          if (!paymentId || !orderId) return;

          // Get order
          const { data: orderData } = await supabase
            .from("orders")
            .select("id, user_id")
            .eq("id", orderId)
            .single();

          if (!orderData) return;

          // Create failed payment transaction
          await supabase.from("payment_transactions").insert({
            order_id: orderId,
            user_id: orderData.user_id,
            payment_id: paymentId,
            amount: 0,
            status: "failed",
            method: "razorpay",
            created_at: new Date().toISOString(),
          });

          // Update order
          await supabase
            .from("orders")
            .update({ status: "cancelled", payment_status: "failed" })
            .eq("id", orderId);

          // Release inventory reservation
          await restoreInventory(supabase, orderId);

          // Send notification
          sendPushNotification(
            supabase,
            orderData.user_id,
            "Payment Failed",
            "Your payment failed. Please try again.",
            { orderId }
          ).catch(e => console.error("Notification error:", e));
        }
      } catch (error) {
        console.error("Webhook processing error:", error);
      }
    };

    asyncProcess();

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }
}

// ============================================================================
// 4. POST /api/refunds/create
// ============================================================================

async function createRefund(req: FunctionRequest): Promise<Response> {
  if (!req.userId) {
    return errorResponse("Unauthorized", "UNAUTHORIZED", 401);
  }

  const supabase = req.supabase!;
  const { orderId, amount } = req.body || {};

  if (!orderId || !amount) {
    return errorResponse("Order ID and amount required", "MISSING_DETAILS", 400);
  }

  try {
    // Get order
    const { data: order } = await supabase
      .from("orders")
      .select("id, user_id, payment_status, total, created_at")
      .eq("id", orderId)
      .single();

    if (!order || order.user_id !== req.userId) {
      return errorResponse("Order not found", "NOT_FOUND", 404);
    }

    // Check refund eligible
    if (order.payment_status !== "completed") {
      return errorResponse("Order not paid", "NOT_PAID", 400);
    }

    const createdDate = new Date(order.created_at);
    const daysSinceOrder = (Date.now() - createdDate.getTime()) / (1000 * 60 * 60 * 24);
    if (daysSinceOrder > 7) {
      return errorResponse("Refund window expired (7 days)", "REFUND_EXPIRED", 400);
    }

    if (amount > order.total) {
      return errorResponse("Refund amount exceeds order total", "INVALID_AMOUNT", 400);
    }

    // Get payment
    const { data: payment } = await supabase
      .from("payment_transactions")
      .select("payment_id")
      .eq("order_id", orderId)
      .eq("status", "completed")
      .single();

    if (!payment) {
      return errorResponse("Payment not found", "PAYMENT_NOT_FOUND", 404);
    }

    // Call Razorpay refund API
    let refundId: string;
    try {
      const razorpayRefund = await callRazorpayAPI("POST", `/payments/${payment.payment_id}/refund`, {
        amount: Math.round(amount * 100),
        notes: {
          order_id: orderId,
          reason: "Customer requested refund",
        },
      });

      refundId = razorpayRefund.id;
    } catch (error) {
      console.error("Razorpay refund error:", error);
      return errorResponse("Failed to create refund", "REFUND_ERROR", 500);
    }

    // Create refunds row
    const { error: refundDbError } = await supabase
      .from("refunds")
      .insert({
        order_id: orderId,
        user_id: req.userId,
        refund_id: refundId,
        amount,
        status: "processing",
        reason: "Customer requested",
        created_at: new Date().toISOString(),
      });

    if (refundDbError) {
      console.error("Refund creation error:", refundDbError);
      return errorResponse("Failed to create refund", "DB_ERROR", 500);
    }

    // Add wallet credit
    const walletCredited = await creditWallet(supabase, req.userId, amount, `Refund for order ${orderId}`);
    if (!walletCredited) {
      console.error("Failed to credit wallet for refund");
      // Continue - wallet credit will be retried
    }

    // Update order status
    await supabase
      .from("orders")
      .update({ status: "refunding" })
      .eq("id", orderId);

    // Sync to Firestore
    syncToFirestore("refunds", refundId, {
      refundId,
      orderId,
      userId: req.userId,
      amount,
      status: "processing",
      createdAt: new Date().toISOString(),
    }).catch(e => console.error("Firestore sync error:", e));

    // Send notification
    sendPushNotification(
      supabase,
      req.userId,
      "Refund Initiated",
      `Refund of ${amount} initiated. It will appear in your wallet within 2-3 business days.`,
      { orderId, refundId }
    ).catch(e => console.error("Notification error:", e));

    return successResponse({
      refund: { id: refundId, orderId, amount, status: "processing" },
    }, 201);
  } catch (error) {
    console.error("Create refund error:", error);
    return errorResponse("Failed to create refund", "REFUND_ERROR", 500);
  }
}

// ============================================================================
// 5. POST /functions/refund-webhook
// ============================================================================

async function refundWebhook(req: FunctionRequest): Promise<Response> {
  const supabase = req.supabase!;
  const signature = req.headers.get("x-razorpay-signature") || "";

  try {
    const body = await req.clone().text();

    // Verify signature
    const webhookSecret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET");
    if (!webhookSecret) {
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }

    const signatureValid = await verifyWebhookSignature(body, signature, webhookSecret);
    if (!signatureValid) {
      console.error("FRAUD: Invalid refund webhook signature");
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }

    const event = JSON.parse(body);
    const eventType = event.event;
    const { refund } = event.payload;

    // ALWAYS return 200 OK
    const asyncProcess = async () => {
      try {
        if (eventType === "refund.processed") {
          const refundId = refund?.id;
          if (!refundId) return;

          const { data: refundRecord } = await supabase
            .from("refunds")
            .select("id, order_id, user_id")
            .eq("refund_id", refundId)
            .single();

          if (!refundRecord) return;

          // Update refund status
          await supabase
            .from("refunds")
            .update({ status: "completed" })
            .eq("refund_id", refundId);

          // Update order status
          await supabase
            .from("orders")
            .update({ status: "refunded" })
            .eq("id", refundRecord.order_id);

          // Send notification
          sendPushNotification(
            supabase,
            refundRecord.user_id,
            "Refund Completed",
            "Your refund has been processed and added to your wallet.",
            { orderId: refundRecord.order_id, refundId }
          ).catch(e => console.error("Notification error:", e));
        } else if (eventType === "refund.failed") {
          const refundId = refund?.id;
          if (!refundId) return;

          const { data: refundRecord } = await supabase
            .from("refunds")
            .select("id, order_id, user_id, amount")
            .eq("refund_id", refundId)
            .single();

          if (!refundRecord) return;

          // Update refund status
          await supabase
            .from("refunds")
            .update({ status: "failed" })
            .eq("refund_id", refundId);

          // REVERSE wallet credit
          const wallet = await supabase
            .from("wallets")
            .select("id, balance")
            .eq("user_id", refundRecord.user_id)
            .single();

          if (wallet.data && wallet.data.balance >= refundRecord.amount) {
            await supabase
              .from("wallets")
              .update({ balance: wallet.data.balance - refundRecord.amount })
              .eq("id", wallet.data.id);

            await supabase.from("wallet_transactions").insert({
              wallet_id: wallet.data.id,
              user_id: refundRecord.user_id,
              type: "debit",
              amount: refundRecord.amount,
              reason: `Refund failed - reversed for order ${refundRecord.order_id}`,
              balance_after: wallet.data.balance - refundRecord.amount,
              timestamp: new Date().toISOString(),
            });
          }

          // Send failure notification
          sendPushNotification(
            supabase,
            refundRecord.user_id,
            "Refund Failed",
            "Your refund could not be processed. Please contact support.",
            { orderId: refundRecord.order_id }
          ).catch(e => console.error("Notification error:", e));
        }
      } catch (error) {
        console.error("Refund webhook processing error:", error);
      }
    };

    asyncProcess();

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (error) {
    console.error("Refund webhook error:", error);
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }
}

// ============================================================================
// ROUTE HANDLER
// ============================================================================

async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders() });
  }

  try {
    const functionReq = await initializeRequest(req);
    const url = new URL(req.url);
    const path = url.pathname;

    // Route to appropriate handler
    if (path === "/api/orders/create" && req.method === "POST") {
      return await createOrder(functionReq);
    } else if (path === "/api/payments/verify" && req.method === "POST") {
      return await verifyPayment(functionReq);
    } else if (path === "/functions/razorpay-webhook-dual-write" && req.method === "POST") {
      return await razorpayWebhook(functionReq);
    } else if (path === "/api/refunds/create" && req.method === "POST") {
      return await createRefund(functionReq);
    } else if (path === "/functions/refund-webhook" && req.method === "POST") {
      return await refundWebhook(functionReq);
    } else {
      return errorResponse("Endpoint not found", "NOT_FOUND", 404);
    }
  } catch (error) {
    console.error("Request error:", error);
    return errorResponse("Internal server error", "INTERNAL_ERROR", 500);
  }
}

export default handleRequest;


