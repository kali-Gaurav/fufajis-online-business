import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  const url = new URL(req.url);

  // ── Health ──────────────────────────────────────────────
  if (url.pathname.endsWith("/health") || req.method === "GET") {
    return new Response(
      JSON.stringify({ status: "ok", service: "order-lifecycle", timestamp: new Date().toISOString() }),
      { headers: { ...CORS, "Content-Type": "application/json" } }
    );
  }

  // ── Auth ─────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();

  if (!token) {
    return new Response(
      JSON.stringify({ success: false, error: "Unauthorized" }),
      { status: 401, headers: { ...CORS, "Content-Type": "application/json" } }
    );
  }

  // ── Supabase client (lazy — only when needed) ────────────
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  );

  // Verify user
  const { data: { user }, error: authError } = await supabase.auth.getUser(token);
  if (authError || !user) {
    return new Response(
      JSON.stringify({ success: false, error: "Unauthorized" }),
      { status: 401, headers: { ...CORS, "Content-Type": "application/json" } }
    );
  }

  // ── Parse body ───────────────────────────────────────────
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ success: false, error: "Invalid JSON body" }),
      { status: 400, headers: { ...CORS, "Content-Type": "application/json" } }
    );
  }

  const action = (body.action ?? body.path ?? "") as string;

  // ── State machine ────────────────────────────────────────
  const TRANSITIONS: Record<string, string[]> = {
    pending_payment:      ["payment_verified", "cancelled"],
    payment_verified:     ["ready_to_pack", "cancelled"],
    ready_to_pack:        ["picked", "cancelled"],
    picked:               ["packed", "cancelled"],
    packed:               ["assigned_to_delivery", "cancelled"],
    assigned_to_delivery: ["picked_up", "cancelled"],
    picked_up:            ["in_transit", "cancelled"],
    in_transit:           ["delivered", "failed_delivery", "cancelled"],
    delivered:            ["refunded"],
    cancelled:            ["refunded"],
    failed_delivery:      ["in_transit", "cancelled"],
  };

  function validTransition(from: string, to: string): boolean {
    return TRANSITIONS[from]?.includes(to) ?? false;
  }

  async function writeOutboxEvent(
    client: ReturnType<typeof createClient>,
    eventType: string,
    aggregateId: string,
    payload: unknown
  ): Promise<void> {
    await client.from("outbox_events").insert({
      event_type: eventType,
      aggregate_id: aggregateId,
      payload,
    });
    // Fire-and-forget — no throw; Firestore sync worker picks this up later
  }

  // ── change-status ─────────────────────────────────────────
  if (action === "change-status" || action === "/change-status") {
    const { orderId, newStatus } = body as { orderId: string; newStatus: string };

    const { data: order, error: fetchErr } = await supabase
      .from("orders").select("status").eq("id", orderId).single();

    if (fetchErr || !order) {
      return new Response(
        JSON.stringify({ success: false, error: "Order not found" }),
        { status: 404, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    if (!validTransition(order.status, newStatus)) {
      return new Response(
        JSON.stringify({ success: false, error: `Invalid transition: ${order.status} → ${newStatus}` }),
        { status: 400, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    const { data: updated, error: updateErr } = await supabase
      .from("orders")
      .update({ status: newStatus, updated_at: new Date().toISOString() })
      .eq("id", orderId).select().single();

    if (updateErr) throw new Error(updateErr.message);

    // Outbox event → Render sync worker handles Firestore
    await writeOutboxEvent(supabase, "order_status_changed", orderId, { orderId, newStatus, order: updated });

    return new Response(
      JSON.stringify({ success: true, data: updated }),
      { headers: { ...CORS, "Content-Type": "application/json" } }
    );
  }

  // ── verify-otp ────────────────────────────────────────────
  if (action === "verify-otp" || action === "/verify-otp") {
    const { orderId, otp } = body as { orderId: string; otp: string };

    const encoder = new TextEncoder();
    const hashBuf = await crypto.subtle.digest("SHA-256", encoder.encode(otp + orderId));
    const hashed = Array.from(new Uint8Array(hashBuf))
      .map(b => b.toString(16).padStart(2, "0")).join("");

    const { data: order, error: fetchErr } = await supabase
      .from("orders").select("delivery_otp_hash, status").eq("id", orderId).single();

    if (fetchErr || !order) {
      return new Response(
        JSON.stringify({ success: false, error: "Order not found" }),
        { status: 404, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    if (order.delivery_otp_hash !== hashed) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid OTP" }),
        { status: 400, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    if (!validTransition(order.status, "delivered")) {
      return new Response(
        JSON.stringify({ success: false, error: "Cannot mark as delivered from current status" }),
        { status: 400, headers: { ...CORS, "Content-Type": "application/json" } }
      );
    }

    const { data: updated, error: updateErr } = await supabase
      .from("orders")
      .update({ status: "delivered", otp_verified: true, delivered_at: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq("id", orderId).select().single();

    if (updateErr) throw new Error(updateErr.message);

    await writeOutboxEvent(supabase, "order_delivered", orderId, { orderId, order: updated });

    return new Response(
      JSON.stringify({ success: true, data: updated }),
      { headers: { ...CORS, "Content-Type": "application/json" } }
    );
  }

  return new Response(
    JSON.stringify({ success: false, error: `Unknown action: ${action}` }),
    { status: 400, headers: { ...CORS, "Content-Type": "application/json" } }
  );
});
