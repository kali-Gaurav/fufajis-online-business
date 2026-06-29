# Supabase Edge Functions Migration Checklist

## ✅ Setup Complete

The following files have been created:

### New Files Created
- ✅ `supabase/functions/_shared/withSupabase.ts` — Shared auth middleware
- ✅ `supabase/functions/hello/index.ts` — Sample Edge Function
- ✅ `supabase/functions/deno.json` — Deno configuration
- ✅ `supabase/functions/README.md` — Functions guide
- ✅ `supabase/migrations/20260628_init_tables.sql` — Sample migration
- ✅ `supabase/.env.local` — Environment template
- ✅ `EDGE_FUNCTIONS_SETUP.md` — Complete setup guide (READ THIS FIRST)
- ✅ `SUPABASE_MIGRATION_CHECKLIST.md` — This file

### Files Modified
- ✅ `backend/package.json` — Added `@supabase/server` dependency
- ✅ `supabase/config.toml` — Updated migration path

---

## 🔄 Next Steps (In Order)

### Phase 1: Get Credentials (TODAY)
- [ ] Go to Supabase Dashboard
- [ ] Navigate to: **Settings > API**
- [ ] Copy: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`
- [ ] Update `.env` in project root
- [ ] Update `supabase/.env.local`

### Phase 2: Link & Migrate (TODAY)
```bash
cd supabase
supabase link --project-ref mxjtgpunctckovtuyfmz
supabase db push
```

### Phase 3: Test Locally (TODAY/TOMORROW)
```bash
cd supabase
supabase start
supabase functions deploy hello
curl http://localhost:54321/functions/v1/hello
```

### Phase 4: Migrate API Endpoints (NEXT DAYS)
For each endpoint in `backend/src/routes/`:
1. Create new function in `supabase/functions/endpoint-name/`
2. Copy logic and adapt to Deno/TypeScript
3. Test locally
4. Deploy: `supabase functions deploy endpoint-name`

### Phase 5: Update Frontend (NEXT DAYS)
Change all API calls from:
```javascript
// Old
fetch('https://fufaji-api.render.com/api/products')

// New
fetch('https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/list-products')
```

### Phase 6: Cleanup (LATER)
- [ ] Delete `hello` function (sample only)
- [ ] Remove old Express routes from `backend/src/routes/`
- [ ] Decommission old API on Render
- [ ] Delete old Supabase project (if no other projects use it)

---

## 📋 Credentials Needed

You'll be prompted for these. Get them from Supabase Dashboard > Settings > API:

```
SUPABASE_URL=https://mxjtgpunctckovtuyfmz.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_pb_[your_key]
SUPABASE_SECRET_KEY=sb_secret_[your_key]
SUPABASE_JWKS_URL=https://mxjtgpunctckovtuyfmz.supabase.co/auth/v1/jwks
```

---

## 📚 Key Documentation

| Document | Purpose |
|----------|---------|
| `EDGE_FUNCTIONS_SETUP.md` | Complete step-by-step setup guide (READ FIRST) |
| `supabase/functions/README.md` | Functions development guide |
| `supabase/config.toml` | Supabase local dev config |

---

## ⚙️ Commands Reference

```bash
# Local development
cd supabase
supabase start                          # Start local Supabase
supabase stop                           # Stop local Supabase

# Link to cloud project
supabase link --project-ref mxjtgpunctckovtuyfmz

# Database management
supabase db push                        # Push migrations to cloud
supabase db pull                        # Pull latest schema from cloud
supabase db reset                       # Reset local database

# Edge Functions (local)
supabase functions deploy hello         # Deploy to local
supabase functions list                 # List deployed functions

# Edge Functions (cloud)
supabase functions deploy hello --no-verify-jwt  # Deploy to cloud (skip JWT check)

# Testing
curl http://localhost:54321/functions/v1/hello
curl https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/hello
```

---

## 🚨 Important Notes

1. **JWT Tokens**: Edge Functions need valid JWT tokens. Generate them via Supabase Auth.
2. **CORS**: Always handle OPTIONS requests with proper CORS headers.
3. **Environment Variables**: Use `Deno.env.get()`, NOT `process.env`.
4. **Database**: Use RLS policies to secure data access.
5. **Secrets**: Never commit `.env` files. Use `.env.local` (already in `.gitignore`).

---

## 🎯 End Goal

Your entire API moves from Express.js on AWS Lambda to Supabase Edge Functions:

| Component | Before | After |
|-----------|--------|-------|
| API Runtime | AWS Lambda | Supabase Edge Functions (Deno) |
| Database | RDS PostgreSQL | Supabase PostgreSQL |
| Storage | AWS S3 | Supabase Storage (S3-compatible) |
| Auth | Firebase + Custom | Supabase Auth |
| Deployments | Manual SAM/AWS CLI | Auto via Supabase CLI |

---

## ❓ Questions?

Refer to:
- `EDGE_FUNCTIONS_SETUP.md` for step-by-step instructions
- `supabase/functions/README.md` for function development
- [Supabase Docs](https://supabase.com/docs)
- [Deno Docs](https://deno.land/manual/)

---

**Status:** ✅ Setup complete. Awaiting your Supabase credentials.
