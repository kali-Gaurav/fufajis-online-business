# Supabase Edge Functions Migration Guide

## Overview
You're migrating from the old Supabase project to a new one (`mxjtgpunctckovtuyfmz`) using **Supabase Edge Functions** instead of Express.js on AWS Lambda.

**Project:** `mxjtgpunctckovtuyfmz`

---

## Step 1: Update Environment Variables

### 1.1 Update Root `.env`
Edit `C:\Projects\fufaji-online-business\.env` and replace the old Supabase keys with the new project's credentials:

```env
# OLD (remove these)
SUPABASE_URL=https://orfikmmpbboesbxdiwzb.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...

# NEW (add these)
SUPABASE_URL=https://mxjtgpunctckovtuyfmz.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_pb_YOUR_KEY_HERE
SUPABASE_SECRET_KEY=sb_secret_YOUR_KEY_HERE
```

Get these from: **Supabase Dashboard > Settings > API**

### 1.2 Update Supabase Functions Environment
Edit `supabase/.env.local` and add your credentials:

```env
SUPABASE_URL=https://mxjtgpunctckovtuyfmz.supabase.co
SUPABASE_SECRET_KEY=sb_secret_YOUR_KEY_HERE
SUPABASE_PUBLISHABLE_KEY=sb_pb_YOUR_KEY_HERE
SUPABASE_JWKS_URL=https://mxjtgpunctckovtuyfmz.supabase.co/auth/v1/jwks
```

---

## Step 2: Link to New Project

```bash
cd supabase
supabase link --project-ref mxjtgpunctckovtuyfmz
```

You'll be prompted for your database password. Enter it.

---

## Step 3: Push Migrations

```bash
cd supabase
supabase db push
```

This will:
1. Create all tables defined in `supabase/migrations/`
2. Set up RLS policies
3. Initialize the schema in your new project

---

## Step 4: Deploy Edge Functions

### 4.1 Install Deno (if not already installed)
```bash
# macOS/Linux
curl -fsSL https://deno.land/x/install/install.sh | sh

# Windows (via Scoop)
scoop install deno
```

### 4.2 Deploy to Supabase
```bash
cd supabase
supabase functions deploy hello
```

Each function in `supabase/functions/` gets deployed as a separate Edge Function.

---

## Step 5: Test Edge Functions

```bash
# Get your project URL
SUPABASE_URL=https://mxjtgpunctckovtuyfmz.supabase.co

# Call the function (without auth)
curl https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/hello

# Call with auth token
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/hello
```

---

## Step 6: Migrate API Endpoints to Edge Functions

### Pattern: `withSupabase` Middleware

All Edge Functions use the `_shared/withSupabase.ts` middleware for:
- JWT authentication
- Supabase client injection
- User ID extraction

**Example function:**

```typescript
// supabase/functions/my-endpoint/index.ts
import { withSupabase, FunctionRequest } from "../_shared/withSupabase.ts";

const handler = async (req: FunctionRequest): Promise<Response> => {
  // req.supabase = Supabase client
  // req.userId = Authenticated user ID (if token was valid)
  
  if (!req.userId) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Your logic here...
  return new Response(JSON.stringify({ message: "Success" }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};

export default withSupabase(handler);
```

---

## Step 7: Update Backend Dependencies

If you still need the backend for other services, install `@supabase/server`:

```bash
cd backend
npm install @supabase/server
npm install -D @types/node
```

**Note:** The `@supabase/server` SDK is primarily for Edge Functions. For Express, you may continue using `@supabase/supabase-js`.

---

## Key Files

| File | Purpose |
|------|---------|
| `supabase/functions/_shared/withSupabase.ts` | Shared auth middleware |
| `supabase/functions/hello/index.ts` | Sample Edge Function |
| `supabase/migrations/` | Database schema migrations |
| `supabase/config.toml` | Local dev & deployment config |
| `supabase/.env.local` | Edge Function secrets |

---

## Local Development

Run Supabase locally:

```bash
cd supabase
supabase start
```

This starts:
- PostgreSQL on `localhost:54322`
- API on `localhost:54321`
- Studio on `localhost:54323`
- Edge Functions on `localhost:54321/functions/v1/`

---

## Deployment to Cloud

Once tested locally, deploy to your Supabase project:

```bash
supabase functions deploy hello
```

Your function is live at:
```
https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/hello
```

---

## Next Steps

1. ✅ Add new Supabase keys to `.env`
2. ✅ Link to new project: `supabase link --project-ref mxjtgpunctckovtuyfmz`
3. ✅ Push migrations: `supabase db push`
4. 🔄 **Migrate your API endpoints** from `backend/src/routes/` to `supabase/functions/`
5. 🔄 **Update frontend** to call new Edge Function URLs
6. 🔄 **Test thoroughly** in local dev before shipping to production

---

## Questions?

- **Supabase Docs:** https://supabase.com/docs/guides/functions
- **Edge Functions Guide:** https://supabase.com/docs/guides/functions/overview
- **Deno Docs:** https://deno.land/manual/
