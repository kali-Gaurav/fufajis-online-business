import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface ApplyCouponRequest {
  couponCode: string;
  userId: string;
  orderId: string;
  orderSubtotal: number;
  shopId: string;
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
    const body: ApplyCouponRequest = await req.json();

    // VALIDATION
    if (
      !body.couponCode ||
      !body.userId ||
      !body.orderId ||
      body.orderSubtotal === undefined ||
      !body.shopId
    ) {
      return new Response(
        JSON.stringify({
          error: "MISSING_FIELDS",
          message:
            "couponCode, userId, orderId, orderSubtotal, and shopId are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // MODULE 3 FIX: APPLY COUPON SERVER-SIDE ONLY
    // All validation happens on server, not client
    // Prevents zero-cap exploit and other coupon abuse

    const { data: result, error: couponError } = await supabase
      .rpc("apply_coupon_validated", {
        p_coupon_code: body.couponCode,
        p_user_id: body.userId,
        p_order_id: body.orderId,
        p_order_subtotal: body.orderSubtotal,
        p_shop_id: body.shopId,
      })
      .single();

    if (couponError || !result?.success) {
      console.error(
        `Failed to apply coupon ${body.couponCode}: ${result?.error_message}`
      );

      return new Response(
        JSON.stringify({
          error: "COUPON_APPLICATION_FAILED",
          message: result?.error_message || "Coupon could not be applied",
          couponCode: body.couponCode,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // AUDIT LOG: Coupon applied
    await supabase.from("audit_log").insert({
      action: "COUPON_APPLIED",
      user_id: body.userId,
      order_id: body.orderId,
      coupon_id: result.coupon_id,
      discount_amount: result.discount_amount,
      final_amount: result.final_amount,
      timestamp: new Date(),
    });

    // UPDATE ORDER with discount
    const { error: orderError } = await supabase
      .from("orders")
      .update({
        coupon_code: body.couponCode,
        discount_amount: result.discount_amount,
        final_amount: result.final_amount,
        updated_at: new Date(),
      })
      .eq("id", body.orderId);

    if (orderError) {
      console.error("Error updating order with coupon:", orderError);
      // Don't fail - coupon is applied, order update is secondary
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Coupon applied successfully",
        couponCode: body.couponCode,
        discountAmount: result.discount_amount,
        finalAmount: result.final_amount,
        savingsPercent: Math.round(
          (result.discount_amount / body.orderSubtotal) * 100
        ),
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
