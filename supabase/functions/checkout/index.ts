import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createServerClient } from "npm:@supabase/supabase-js";
import { syncOrderToFirestore } from "../_shared/firebase-bridge.ts";

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const authHeader = req.headers.get("Authorization") || "";

    const supabase = createServerClient(supabaseUrl, supabaseKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const token = authHeader.replace("Bearer ", "");
    let userId: string | undefined;
    if (token) {
      const { data, error } = await supabase.auth.getUser(token);
      if (!error && data.user) userId = data.user.id;
    }

    if (!userId) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const action = body.action || "checkout";

    if (action === "checkout") {
      const { items, address, couponCode } = body;
      
      if (!items || items.length === 0) {
        return new Response(
          JSON.stringify({ success: false, error: "No items provided" }),
          { status: 400, headers: { ...corsHeaders(), "Content-Type": "application/json" } }
        );
      }

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

      const tax = subtotal * 0.05;
      const deliveryFee = 50;
      const total = subtotal + tax + deliveryFee;

      // Use RPC for transaction if possible
      let order;
      const { data: rpcData, error: rpcError } = await supabase.rpc('process_checkout', {
        p_user_id: userId,
        p_items: items,
        p_address: address,
        p_subtotal: subtotal,
        p_tax: tax,
        p_delivery_fee: deliveryFee,
        p_total: total
      });

      if (rpcError) {
        // Fallback to sequential if RPC is missing
        const { data: insertOrder, error: orderError } = await supabase
          .from("orders")
          .insert({
            user_id: userId,
            items: JSON.stringify(items),
            delivery_address: JSON.stringify(address),
            subtotal,
            tax,
            delivery_fee: deliveryFee,
            total,
            status: "pending_payment",
            created_at: new Date().toISOString()
          })
          .select()
          .single();

        if (orderError) throw new Error(orderError.message);
        order = insertOrder;
      } else {
        order = rpcData;
      }

      await syncOrderToFirestore(order.id, {
        ...order,
        status: "pending_payment",
        total
      });

      return new Response(
        JSON.stringify({ success: true, data: order }),
        { headers: { ...corsHeaders(), "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: false, error: "Invalid action" }),
      { status: 400, headers: { ...corsHeaders(), "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders(), "Content-Type": "application/json" } }
    );
  }
});
