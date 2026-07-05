import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface CreateOrderRequest {
  userId: string;
  shopId: string;
  cartItems: Array<{
    productId: string;
    quantity: number;
    price: number;
  }>;
  deliveryAddress: {
    lat: number;
    lng: number;
    address: string;
  };
  paymentMethod: "card" | "wallet" | "cod";
  couponCode?: string;
  idempotencyKey: string; // CRITICAL: Prevents duplicate orders on retry
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
    const body: CreateOrderRequest = await req.json();

    // VALIDATION
    if (
      !body.userId ||
      !body.shopId ||
      !body.cartItems ||
      !body.deliveryAddress ||
      !body.paymentMethod ||
      !body.idempotencyKey
    ) {
      return new Response(
        JSON.stringify({
          error: "MISSING_FIELDS",
          message: "All fields including idempotencyKey are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (body.cartItems.length === 0) {
      return new Response(
        JSON.stringify({
          error: "EMPTY_CART",
          message: "Cart cannot be empty",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // P0-A FIX: COMMAND-BASED API (Domain-specific, not generic)
    // This is order creation command with explicit business rules
    // Call domain function in PostgreSQL

    const { data: result, error: orderError } = await supabase
      .rpc("create_order_command", {
        p_user_id: body.userId,
        p_shop_id: body.shopId,
        p_cart_items: JSON.stringify(body.cartItems),
        p_delivery_address: JSON.stringify(body.deliveryAddress),
        p_payment_method: body.paymentMethod,
        p_coupon_code: body.couponCode || null,
        p_idempotency_key: body.idempotencyKey,
      })
      .single();

    if (orderError || !result?.success) {
      console.error(`Failed to create order: ${result?.error_message}`);

      return new Response(
        JSON.stringify({
          error: "ORDER_CREATION_FAILED",
          message: result?.error_message || "Failed to create order",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // AUDIT LOG
    await supabase.from("audit_log").insert({
      action: "ORDER_CREATED",
      user_id: body.userId,
      order_id: result.order_id,
      shop_id: body.shopId,
      payment_method: body.paymentMethod,
      total_amount: result.total_amount,
      idempotency_key: body.idempotencyKey,
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Order created successfully",
        orderId: result.order_id,
        totalAmount: result.total_amount,
        status: result.status,
        version: result.version, // CRITICAL: For sync versioning
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
