import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: "user" }, async (_req, ctx) => {
    // This uses the RLS-scoped client to fetch users
    // (Ensure you have a users table, or modify the query as needed)
    const { data, error } = await ctx.supabase.from("users").select().limit(5);
    
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    return new Response(JSON.stringify({ users: data }), {
      headers: { "Content-Type": "application/json" }
    });
  }),
};
