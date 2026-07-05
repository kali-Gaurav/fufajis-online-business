import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface DeductFromWalletRequest {
  userId: string;
  amount: number;
  transactionType: string; // 'payment', 'redemption', etc
  orderId?: string;
  description?: string;
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
    const body: DeductFromWalletRequest = await req.json();

    // VALIDATION
    if (!body.userId || body.amount === undefined || body.amount <= 0 || !body.transactionType) {
      return new Response(
        JSON.stringify({
          error: "INVALID_INPUT",
          message: "userId, amount (>0), and transactionType are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // MODULE 4 FIX: WIRING - Call PostgreSQL function (server-side)
    // All wallet deductions go through server validation
    // Ensures sufficient balance before deduction

    const { data: result, error: walletError } = await supabase
      .rpc("deduct_from_wallet_atomic", {
        p_user_id: body.userId,
        p_amount: body.amount,
        p_transaction_type: body.transactionType,
        p_order_id: body.orderId || null,
        p_description: body.description || null,
      })
      .single();

    if (walletError || !result?.success) {
      console.error(`Failed to deduct from wallet: ${result?.error_message}`);

      return new Response(
        JSON.stringify({
          error: "WALLET_UPDATE_FAILED",
          message: result?.error_message || "Failed to deduct from wallet",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // AUDIT LOG
    await supabase.from("audit_log").insert({
      action: "WALLET_DEBIT",
      user_id: body.userId,
      transaction_type: body.transactionType,
      amount: body.amount,
      new_balance: result.new_balance,
      transaction_id: result.transaction_id,
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Wallet deducted successfully",
        userId: body.userId,
        transactionType: body.transactionType,
        amount: body.amount,
        newBalance: result.new_balance,
        transactionId: result.transaction_id,
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
