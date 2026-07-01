// Shared Supabase middleware for Edge Functions
import { createServerClient } from "npm:@supabase/supabase-js";

export interface FunctionRequest extends Request {
  supabase?: ReturnType<typeof createServerClient>;
  userId?: string;
}

export function withSupabase(
  handler: (req: FunctionRequest) => Promise<Response>
) {
  return async (req: Request): Promise<Response> => {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SECRET_KEY");

    if (!supabaseUrl || !supabaseKey) {
      return new Response(
        JSON.stringify({ error: "Missing Supabase credentials" }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // Extract JWT from Authorization header
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace("Bearer ", "");

    const supabase = createServerClient(supabaseUrl, supabaseKey, {
      auth: {
        persistSession: false,
      },
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    // Verify JWT and get user
    let userId: string | undefined;
    if (token) {
      const { data, error } = await supabase.auth.getUser(token);
      if (!error && data.user) {
        userId = data.user.id;
      }
    }

    // Add supabase client and userId to request
    const enhancedReq: FunctionRequest = Object.assign(req, {
      supabase,
      userId,
    });

    return handler(enhancedReq);
  };
}
