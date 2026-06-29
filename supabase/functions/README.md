# Supabase Edge Functions

This directory contains your API endpoints as Supabase Edge Functions.

## Structure

```
functions/
├── _shared/               # Shared utilities & middleware
│   └── withSupabase.ts   # Auth middleware for all functions
├── hello/                 # Sample function (DELETE this after understanding)
│   └── index.ts
└── deno.json             # Deno configuration
```

## Quick Start

### 1. Create a New Edge Function

```bash
# Create function folder
mkdir supabase/functions/my-api-endpoint

# Create index.ts
cat > supabase/functions/my-api-endpoint/index.ts << 'EOF'
import { withSupabase, FunctionRequest } from "../_shared/withSupabase.ts";

const handler = async (req: FunctionRequest): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    // Your logic here
    return new Response(
      JSON.stringify({ message: "Success" }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
};

export default withSupabase(handler);
EOF
```

### 2. Local Testing

```bash
# Start local Supabase
supabase start

# Deploy function locally
supabase functions deploy my-api-endpoint

# Call it
curl http://localhost:54321/functions/v1/my-api-endpoint
```

### 3. Deploy to Cloud

```bash
supabase functions deploy my-api-endpoint
```

Function is live at:
```
https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/my-api-endpoint
```

---

## Middleware: `withSupabase`

Every function uses the `withSupabase` middleware to:
- ✅ Extract JWT from Authorization header
- ✅ Verify token with Supabase Auth
- ✅ Inject Supabase client (`req.supabase`)
- ✅ Inject authenticated user ID (`req.userId`)

### Usage

```typescript
import { withSupabase, FunctionRequest } from "../_shared/withSupabase.ts";

const handler = async (req: FunctionRequest): Promise<Response> => {
  // req.supabase = Supabase client (authenticated with service role)
  // req.userId = User ID from JWT (undefined if no token or invalid token)

  if (!req.userId) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Query user data
  const { data, error } = await req.supabase
    .from("customers")
    .select("*")
    .eq("id", req.userId)
    .single();

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export default withSupabase(handler);
```

---

## CORS Headers

Always include CORS headers for OPTIONS requests:

```typescript
if (req.method === "OPTIONS") {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
```

---

## Environment Variables

Set secrets in `supabase/.env.local`:

```env
SUPABASE_URL=https://mxjtgpunctckovtuyfmz.supabase.co
SUPABASE_SECRET_KEY=sb_secret_...
```

Access in functions:
```typescript
const secret = Deno.env.get("MY_SECRET");
```

---

## Debugging

### View Logs
```bash
supabase functions list
supabase functions delete hello  # Remove a function
```

### Local Logs
```bash
supabase functions deploy hello --debug
```

---

## Function Naming

Use kebab-case and descriptive names:
- ✅ `supabase/functions/get-customer/`
- ✅ `supabase/functions/place-order/`
- ✅ `supabase/functions/verify-payment/`
- ❌ `supabase/functions/api/` (too vague)
- ❌ `supabase/functions/test/` (too generic)

---

## What's NOT Included

- Database migrations (see `supabase/migrations/`)
- RLS policies (see `supabase/migrations/`)
- Storage buckets (configure in Supabase Dashboard)
- Auth settings (configure in Supabase Dashboard)

---

## Resources

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Deno Docs](https://deno.land/manual/)
- [Deno Standard Library](https://deno.land/std/)

---

## Next: Migrate from Express Routes

Convert your `backend/src/routes/` endpoints to Edge Functions:

| Old Path | New Function |
|----------|-------------|
| `POST /api/auth/login` | `functions/auth-login/` |
| `POST /api/orders` | `functions/create-order/` |
| `GET /api/products` | `functions/list-products/` |

Then update frontend API calls to point to the new Edge Function URLs.
