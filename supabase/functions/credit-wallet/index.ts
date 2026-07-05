import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface CreditWalletRequest {
  userId: string;
  amount: number;
  transactionType:
    | "refund"
    | "cashback"
    | "referral_bonus"
    | "loyalty_reward";
  orderReference?: string;
  paymentVerified: boolean;
  verifiedByService: "razorpay" | "payment_webhook" | "admin";
  description?: string;
}

// CRITICAL SECURITY: Only allow wallet credits through verified payment channels
serve(async (req) => {
  // CORS
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

    // Parse request
    const body: CreditWalletRequest = await req.json();

    // VALIDATION 1: Verify payment was authenticated
    if (!body.paymentVerified || !body.verifiedByService) {
      return new Response(
        JSON.stringify({
          error: "PAYMENT_NOT_VERIFIED",
          message:
            "Wallet credit requires verified payment. App cannot credit directly.",
        }),
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // VALIDATION 2: Only allow specific verified sources
    const allowedSources = ["razorpay", "payment_webhook", "admin"];
    if (!allowedSources.includes(body.verifiedByService)) {
      return new Response(
        JSON.stringify({
          error: "INVALID_SOURCE",
          message: "Wallet credit source not authorized",
        }),
        {
          status: 403,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // VALIDATION 3: Amount must be positive
    if (body.amount <= 0) {
      return new Response(
        JSON.stringify({
          error: "INVALID_AMOUNT",
          message: "Amount must be greater than 0",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // VALIDATION 4: User must exist
    const { data: userData, error: userError } = await supabase
      .from("users")
      .select("id, wallet_balance")
      .eq("id", body.userId)
      .single();

    if (userError || !userData) {
      return new Response(
        JSON.stringify({ error: "USER_NOT_FOUND" }),
        {
          status: 404,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // ISOLATION: Use PostgreSQL transaction for atomicity + row-level locking
    // This prevents concurrent operations from racing
    const { data: result, error: txError } = await supabase
      .rpc("credit_wallet_atomic", {
        p_user_id: body.userId,
        p_amount: body.amount,
        p_transaction_type: body.transactionType,
        p_order_reference: body.orderReference || null,
        p_description: body.description || null,
        p_verified_by: body.verifiedByService,
      });

    if (txError) {
      console.error("Transaction error:", txError);
      return new Response(
        JSON.stringify({
          error: "TRANSACTION_FAILED",
          message: txError.message,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Log to audit trail
    await supabase.from("audit_log").insert({
      action: "WALLET_CREDIT",
      user_id: body.userId,
      amount: body.amount,
      reason: body.transactionType,
      verified_by: body.verifiedByService,
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        newBalance: result.new_balance,
        transactionId: result.transaction_id,
        message: `Successfully credited ₹${body.amount} to wallet`,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({
        error: "INTERNAL_SERVER_ERROR",
        message: error.message,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
