import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

interface DataWriteRequest {
  tableName: string; // 'orders', 'products', 'users', 'wallet_balance', etc
  entityId: string; // UUID of the entity
  operation: "CREATE" | "UPDATE" | "DELETE"; // operation type
  data: Record<string, any>; // the data to write
  changedBy?: string; // who is making this change (user_id or system)
  changeReason?: string; // why this change is happening
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
    const body: DataWriteRequest = await req.json();

    // VALIDATION
    if (!body.tableName || !body.entityId || !body.operation || !body.data) {
      return new Response(
        JSON.stringify({
          error: "INVALID_INPUT",
          message: "tableName, entityId, operation, and data are required",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!["CREATE", "UPDATE", "DELETE"].includes(body.operation)) {
      return new Response(
        JSON.stringify({
          error: "INVALID_OPERATION",
          message: "operation must be CREATE, UPDATE, or DELETE",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // MODULE 5 FIX: WIRING - Call PostgreSQL function (server-side)
    // All data writes go through server validation and sync tracking
    // Firestore becomes read-only cache synced FROM PostgreSQL

    const { data: result, error: mutationError } = await supabase
      .rpc("apply_mutation_atomic", {
        p_table_name: body.tableName,
        p_entity_id: body.entityId,
        p_operation: body.operation,
        p_data: body.data,
        p_changed_by: body.changedBy || null,
      })
      .single();

    if (mutationError || !result?.success) {
      console.error(`Failed to write data: ${result?.error_message}`);

      return new Response(
        JSON.stringify({
          error: "DATA_WRITE_FAILED",
          message: result?.error_message || "Failed to write data",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // AUDIT LOG
    await supabase.from("audit_log").insert({
      action: `DATA_${body.operation}`,
      table_name: body.tableName,
      entity_id: body.entityId,
      changed_by: body.changedBy || "system",
      change_reason: body.changeReason || null,
      timestamp: new Date(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: "Data written successfully",
        tableName: body.tableName,
        entityId: body.entityId,
        operation: body.operation,
        mutationId: result.mutation_id,
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
