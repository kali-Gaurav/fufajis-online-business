# Complete Supabase Setup for Fufaji Store

**Goal:** Fully leverage Supabase features that Firebase Spark doesn't support.

---

## 🎯 Features Being Implemented

| # | Feature | Status | Priority |
|---|---------|--------|----------|
| 1 | PostgreSQL + RLS | 📋 Planned | P0 |
| 2 | File Storage (S3) | 📋 Planned | P0 |
| 3 | Real-time Updates | 📋 Planned | P0 |
| 4 | Email Service | 📋 Planned | P1 |
| 5 | Vector/AI Search | 📋 Planned | P1 |
| 6 | Webhooks & Jobs | 📋 Planned | P1 |
| 7 | Backups & Replication | 📋 Planned | P2 |

---

## Phase 1: Database Schema + RLS (Task #2)

### Why It Matters
- PostgreSQL is way better than Firestore for relational data
- RLS = automatic security at the database level
- Each user only sees their own data without extra code

### What We'll Build

```sql
-- Example tables structure
customers (id, email, phone, wallet_balance, created_at)
  ├─ RLS: Users see only their own profile
  
orders (id, customer_id, status, total, created_at)
  ├─ RLS: Users see only their own orders
  
products (id, shop_id, name, price, embeddings)
  ├─ RLS: Public read, shop owner can edit
  
inventory (id, product_id, quantity, reserved)
  ├─ RLS: Shop owners see their own
  
payments (id, order_id, method, status, amount)
  ├─ RLS: Secure payment records
  
wallets (id, customer_id, balance, transactions)
  ├─ RLS: Users see only their wallet
  
deliveries (id, order_id, rider_id, status, location)
  ├─ RLS: Riders see assigned, customers see their own
  
audit_log (id, table_name, action, user_id, changes, created_at)
  └─ Track all changes automatically
```

### Files to Create
- `supabase/migrations/01_init_schema.sql` — Tables
- `supabase/migrations/02_rls_policies.sql` — Security policies
- `supabase/migrations/03_functions.sql` — Helper functions
- `supabase/migrations/04_triggers.sql` — Audit logging, auto-updates

### Key RLS Patterns

```sql
-- Pattern 1: User sees only their own data
CREATE POLICY "Users see own profile"
  ON customers FOR SELECT
  USING (auth.uid() = id);

-- Pattern 2: Public read, authenticated write
CREATE POLICY "Products are public"
  ON products FOR SELECT
  USING (true);

CREATE POLICY "Shop owner can edit"
  ON products FOR UPDATE
  USING (auth.uid() = shop_id);

-- Pattern 3: Service role bypass
-- Functions run as service_role, bypass RLS for complex logic
CREATE OR REPLACE FUNCTION process_order(order_id UUID)
RETURNS void AS $$
  -- This function can see/modify all data
  -- Called from Edge Functions with service role
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## Phase 2: File Storage (Task #3)

### Why It Matters
- Product images, order receipts, delivery proofs
- Signed URLs = secure, temporary access
- S3-compatible = easy integration

### Buckets We'll Create

```
product-images/
├─ {product_id}/
│  ├─ main.jpg
│  ├─ thumb.jpg
│  └─ gallery_*.jpg

order-receipts/
├─ {order_id}/
│  └─ receipt.pdf

customer-documents/
├─ {customer_id}/
│  ├─ id_proof.jpg
│  └─ address_proof.jpg

delivery-proofs/
└─ {delivery_id}/
   ├─ photo_before.jpg
   └─ photo_delivery.jpg
```

### Storage Policies (RLS for Files)

```sql
-- Customers can upload to their own folder
CREATE POLICY "Customers upload own images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'customer-documents'
    AND auth.uid()::text = (storage.foldername(name))[1]);

-- Products are public read
CREATE POLICY "Products are public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images');
```

### Edge Function for Signed URLs

```typescript
// supabase/functions/get-signed-url/index.ts
import { createServerClient } from "@supabase/supabase-js";

export default async (req) => {
  const supabase = createServerClient(url, key);
  
  const { data, error } = await supabase
    .storage
    .from('product-images')
    .createSignedUrl('path/to/file', 3600); // 1 hour
  
  return new Response(JSON.stringify(data));
};
```

---

## Phase 3: Real-time Updates (Task #4)

### Why It Matters
- Live order status updates
- Push notifications
- Rider location tracking (via Realtime)

### Realtime Channels

```typescript
// Listen to order changes
const channel = supabase
  .channel('orders')
  .on('postgres_changes', 
    { 
      event: 'UPDATE', 
      schema: 'public', 
      table: 'orders',
      filter: `customer_id=eq.${userId}`
    },
    (payload) => {
      console.log('Order updated:', payload.new);
      // Update UI, send push notification, etc.
    }
  )
  .subscribe();
```

### Push Notifications

```typescript
// supabase/functions/send-notification/index.ts
// Triggered by order updates via Edge Function
// Sends FCM (Firebase Cloud Messaging) to mobile app

const handler = async (req: FunctionRequest) => {
  const { userId, title, body } = await req.json();
  
  // Get user's FCM token from database
  const { data: user } = await req.supabase
    .from('customers')
    .select('fcm_token')
    .eq('id', userId)
    .single();
  
  // Send via FCM API
  await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Authorization': `key=${FCM_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      to: user.fcm_token,
      notification: { title, body },
    }),
  });
};
```

---

## Phase 4: Email Service (Task #5)

### Why It Matters
- Order confirmations
- Payment receipts
- Password resets
- Marketing campaigns

### Setup: SendGrid or Resend

```bash
# Install SendGrid package
npm install @sendgrid/mail
```

### Edge Function Template

```typescript
// supabase/functions/send-order-confirmation/index.ts
import { sendEmail } from "../_shared/emailService.ts";

const handler = async (req: FunctionRequest) => {
  const { orderId } = await req.json();
  
  // Get order details
  const { data: order } = await req.supabase
    .from('orders')
    .select(`*, customers(email, name)`)
    .eq('id', orderId)
    .single();
  
  // Send email
  await sendEmail({
    to: order.customers.email,
    subject: `Order Confirmation #${orderId}`,
    template: 'order-confirmation',
    data: order,
  });
  
  return new Response(JSON.stringify({ success: true }));
};
```

### Email Templates
- `order-confirmation.html`
- `payment-receipt.html`
- `password-reset.html`
- `promotional.html`

---

## Phase 5: Vector/AI (Task #6)

### Why It Matters
- Product recommendations
- Semantic search (search by meaning, not keywords)
- Fraud detection

### Setup: pgvector Extension

```sql
-- Enable pgvector
CREATE EXTENSION vector;

-- Create embeddings table
CREATE TABLE product_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES products(id),
  embedding vector(1536), -- OpenAI embeddings dimension
  created_at TIMESTAMP DEFAULT now()
);

-- Index for fast similarity search
CREATE INDEX ON product_embeddings USING ivfflat (embedding vector_cosine_ops);
```

### Embedding Generation

```typescript
// supabase/functions/generate-embeddings/index.ts
import { OpenAI } from "https://esm.sh/openai@4.0.0";

const handler = async (req: FunctionRequest) => {
  const openai = new OpenAI({
    apiKey: Deno.env.get('OPENAI_API_KEY'),
  });
  
  // Get product description
  const { data: product } = await req.supabase
    .from('products')
    .select('id, name, description')
    .single();
  
  // Generate embedding
  const response = await openai.embeddings.create({
    model: "text-embedding-3-small",
    input: `${product.name}. ${product.description}`,
  });
  
  const embedding = response.data[0].embedding;
  
  // Store in database
  await req.supabase
    .from('product_embeddings')
    .insert({ product_id: product.id, embedding });
};
```

### Semantic Search

```sql
-- Find similar products
SELECT id, product_id, 1 - (embedding <=> query_embedding) AS similarity
FROM product_embeddings
ORDER BY embedding <=> query_embedding
LIMIT 5;
```

---

## Phase 6: Webhooks & Background Jobs (Task #7)

### Why It Matters
- Payment verification (Razorpay webhook)
- Order processing jobs
- Inventory reconciliation
- Delivery route optimization

### Webhook: Razorpay Payment

```typescript
// supabase/functions/razorpay-webhook/index.ts
import { createHmac } from "https://deno.land/std/crypto/mod.ts";

const handler = async (req: FunctionRequest) => {
  const body = await req.text();
  const signature = req.headers.get('x-razorpay-signature');
  
  // Verify webhook signature
  const expectedSignature = createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
    .update(body)
    .digest('hex');
  
  if (signature !== expectedSignature) {
    return new Response(JSON.stringify({ error: 'Invalid signature' }), {
      status: 401,
    });
  }
  
  const payload = JSON.parse(body);
  
  if (payload.event === 'payment.authorized') {
    const { order_id, amount } = payload.payload.payment.entity;
    
    // Update order in database
    await req.supabase
      .from('orders')
      .update({ 
        payment_status: 'completed',
        paid_amount: amount,
      })
      .eq('razorpay_order_id', order_id);
    
    // Trigger fulfillment
    await triggerOrderFulfillment(order_id);
  }
  
  return new Response(JSON.stringify({ success: true }));
};
```

### Background Job: Order Processing

```typescript
// supabase/functions/process-order/index.ts
const handler = async (req: FunctionRequest) => {
  const { orderId } = await req.json();
  
  // 1. Deduct inventory
  await req.supabase
    .rpc('deduct_inventory', { order_id: orderId });
  
  // 2. Create delivery
  await req.supabase
    .from('deliveries')
    .insert({
      order_id: orderId,
      status: 'pending_assignment',
    });
  
  // 3. Send notification
  await fetch(
    `https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/send-notification`,
    {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` },
      body: JSON.stringify({
        orderId,
        message: 'Your order has been confirmed!',
      }),
    }
  );
  
  return new Response(JSON.stringify({ success: true }));
};
```

### Job Queue (Using pg_cron)

```sql
-- Process all pending orders every minute
SELECT cron.schedule(
  'process-pending-orders',
  '* * * * *',
  $$SELECT process_order(id) FROM orders WHERE status = 'pending'$$
);
```

---

## Phase 7: Backups & Replication (Task #8)

### Why It Matters
- Data safety (point-in-time recovery)
- Analytics (read replicas)
- Disaster recovery

### Backup Strategy

```
Daily automated backups (Supabase handles)
├─ 7-day retention (free tier)
└─ 30-day retention (paid)

Point-in-time recovery: Any time in last 7 days
```

### Verification Script

```typescript
// supabase/functions/verify-backup/index.ts
const handler = async (req: FunctionRequest) => {
  // Count records in each table
  const stats = {
    customers: await req.supabase.from('customers').select('count').count,
    orders: await req.supabase.from('orders').select('count').count,
    products: await req.supabase.from('products').select('count').count,
  };
  
  // Log to monitoring system
  console.log('Backup stats:', stats);
  
  return new Response(JSON.stringify(stats));
};
```

### Recovery Procedure

```bash
# If disaster happens:
1. Contact Supabase support
2. Request point-in-time restore to specific time
3. Test on staging environment
4. Promote to production
```

---

## 📦 Implementation Order

1. **Today:** Get credentials, link project (`supabase link`)
2. **Day 1:** Create database schema + RLS (Task #2) → `supabase db push`
3. **Day 2:** Configure storage buckets (Task #3)
4. **Day 2-3:** Realtime + notifications (Task #4)
5. **Day 3:** Email service (Task #5)
6. **Day 4:** Vector/embeddings (Task #6)
7. **Day 4-5:** Webhooks (Task #7)
8. **Day 5:** Verify backups (Task #8)

---

## 🔑 Key Configuration Files

```
supabase/
├── config.toml                 # Local dev config
├── .env.local                  # Secrets
├── migrations/
│   ├── 01_init_schema.sql
│   ├── 02_rls_policies.sql
│   ├── 03_functions.sql
│   └── 04_triggers.sql
├── functions/
│   ├── _shared/
│   │   ├── withSupabase.ts
│   │   ├── emailService.ts
│   │   ├── notificationService.ts
│   │   └── storageService.ts
│   ├── send-order-confirmation/
│   ├── send-notification/
│   ├── process-order/
│   ├── razorpay-webhook/
│   ├── generate-embeddings/
│   ├── semantic-search/
│   └── verify-backup/
└── seed.sql                    # Sample data for testing
```

---

## 🚀 Deploy Checklist

- [ ] Credentials added to `.env`
- [ ] Project linked: `supabase link --project-ref mxjtgpunctckovtuyfmz`
- [ ] Migrations pushed: `supabase db push`
- [ ] Storage buckets created
- [ ] RLS policies tested
- [ ] Realtime subscriptions working
- [ ] Email service tested
- [ ] Vector search tested
- [ ] Webhooks receiving data
- [ ] Backups verified
- [ ] Frontend updated to use Supabase
- [ ] Mobile app updated (FCM, realtime)

---

## 📚 Resources

- [Supabase Docs](https://supabase.com/docs)
- [PostgreSQL RLS Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Storage Guide](https://supabase.com/docs/guides/storage)
- [Realtime Guide](https://supabase.com/docs/guides/realtime)
- [Edge Functions](https://supabase.com/docs/guides/functions)
- [pgvector Docs](https://github.com/pgvector/pgvector)

---

**Next:** Share your Supabase credentials and we'll start with Task #2!
