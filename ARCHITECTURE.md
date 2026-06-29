# Fufaji Store — Enterprise Architecture Design

**Status:** Production-Ready | **Last Updated:** 2026-06-28

---

## 1. System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     FUFAJI STORE — SYSTEM DESIGN                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  CLIENT LAYER (Android App + Web Dashboard)                     │
│  ├─ Fufaji Store App (Flutter)                                  │
│  └─ Shop Owner Dashboard (React/Next.js)                        │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTPS + JWT
┌────────────────────────┴────────────────────────────────────────┐
│  API LAYER — SUPABASE EDGE FUNCTIONS (Deno)                    │
│  ├─ Auth Middleware (withSupabase)                              │
│  ├─ Order Service                                               │
│  ├─ Payment Service (Razorpay)                                  │
│  ├─ Delivery Service                                            │
│  ├─ Notification Service (FCM)                                  │
│  ├─ Search Service (Vector)                                     │
│  └─ Analytics Service                                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────────────┐
│  DATA LAYER — SUPABASE POSTGRES + REALTIME                      │
│  ├─ PostgreSQL (12 tables, 50+ indexes)                         │
│  ├─ RLS Policies (row-level security)                           │
│  ├─ Realtime Subscriptions (orders, deliveries)                 │
│  ├─ pgvector (embeddings for recommendations)                   │
│  ├─ Vector Storage (S3 buckets)                                 │
│  └─ Audit Logging (compliance)                                  │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────────────┐
│  EXTERNAL INTEGRATIONS                                          │
│  ├─ Razorpay (Payments)                                         │
│  ├─ SendGrid (Email)                                            │
│  ├─ Firebase Cloud Messaging (Notifications)                    │
│  ├─ OpenAI/Gemini (Embeddings for recommendations)              │
│  └─ WhatsApp Business API (Customer support)                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Flow Architecture

### Order Lifecycle Flow

```
Customer Orders → Order Created (DB) 
  ↓
Payment Processing (Razorpay webhook)
  ↓
Order Confirmed (Email + Notification)
  ↓
Inventory Deduction (Atomic transaction)
  ↓
Shop Preparation (Realtime update)
  ↓
Delivery Assignment (Rider allocation algorithm)
  ↓
Route Optimization (Low-latency geospatial query)
  ↓
Live Location Tracking (Realtime channel)
  ↓
Delivery Confirmation (Photo + signature)
  ↓
Wallet Credit (Refund if applicable)
  ↓
Review & Rating (Product recommendations trained)
```

### Recommendation Engine Flow

```
Product View → Embedding Generated (OpenAI) → pgvector stored
      ↓
User Behavior Tracked → Vector similarity search
      ↓
Top 5 Similar Products Returned (millisecond latency)
      ↓
Personalized Homepage Feed (ML-ranked)
      ↓
Customer Conversion Optimized
```

---

## 3. Latency Optimization Strategy

### 3.1 Database Level
- **Query Optimization:** All frequent queries have indexes (B-tree, GiST, BRIN)
- **Connection Pooling:** PgBouncer (1000 concurrent connections)
- **Caching:** Redis for hot data (product catalog, user profiles)
- **Read Replicas:** Analytics queries on separate replica

### 3.2 Application Level
- **Edge Functions:** Deno deploys globally (edge locations)
- **Middleware Caching:** Cache RLS computations
- **Batch Operations:** Combine multiple updates into single transaction
- **Async Jobs:** Heavy operations (email, embeddings) queued

### 3.3 Network Level
- **CDN:** Images/assets via Supabase Storage (CloudFront)
- **Compression:** Gzip/Brotli for responses
- **HTTP/2:** Multiplexing for multiple requests
- **Keep-alive:** Connection reuse

### 3.4 Monitoring
```
Target Latencies:
├─ API response: <100ms (p95)
├─ Search/recommendations: <200ms (p95)
├─ Payment processing: <500ms (webhook)
├─ Real-time updates: <50ms broadcast
└─ Image loading: <300ms (via CDN)
```

---

## 4. Recommendation Engine Architecture

### Vector Embedding Pipeline

```
Product Data (name, description, category, tags)
      ↓
OpenAI Embedding Model (text-embedding-3-small)
      ↓
1536-dimensional Vector
      ↓
pgvector Storage (IVFFLAT index)
      ↓
Cosine Similarity Search
      ↓
Top-K Similar Products (K=5)
      ↓
ML Ranking (CTR, conversion, freshness)
      ↓
Personalized Feed
```

### High-Accuracy Mechanism

```
1. Collaborative Filtering
   ├─ User-Product interactions
   ├─ Similar users' purchases
   └─ Cross-shop patterns

2. Content-Based Filtering
   ├─ Product embeddings (semantic similarity)
   ├─ Category affinity
   └─ Price range preference

3. Contextual Ranking
   ├─ Time of day (breakfast items at 8am)
   ├─ User location (local shops first)
   ├─ Weather (umbrellas in monsoon)
   └─ Trending (popular in user's area)

4. Cold Start Handling
   ├─ Category-based for new users
   ├─ Location-based fallback
   └─ Trending products default
```

---

## 5. Security Architecture

### Authentication & Authorization
```
Mobile App
  ↓
Supabase Auth (Email/Google/Phone)
  ↓
JWT Token (issued)
  ↓
Edge Function (validate JWT)
  ↓
Row-Level Security (automatic field-level access)
  ↓
Service Role (for complex operations, backend-only)
```

### RLS Implementation
```
Every table has policies:
├─ Customers see only own data
├─ Shop owners see own shop + orders
├─ Riders see assigned deliveries
├─ Admins see all data
└─ Service role bypasses for batch operations
```

### Secret Management
```
Secrets stored in Supabase Secrets/Environment:
├─ RAZORPAY_KEY_SECRET (never expose)
├─ SENDGRID_API_KEY
├─ OPENAI_API_KEY
├─ FCM_SERVER_KEY
└─ Database encryption keys (AWS KMS)
```

---

## 6. Scalability Plan

### Current Target
- **Users:** 10,000 concurrent
- **Orders/day:** 50,000
- **API calls/sec:** 2,000

### Scaling Triggers

| Metric | Trigger | Action |
|--------|---------|--------|
| DB CPU | >70% | Read replica activation |
| Connection pool | >80% | PgBouncer scaling |
| API latency | >100ms p95 | Function optimization |
| Storage | >100GB | Archive old data |
| Embeddings | >1M vectors | Separate vector DB |

### Growth Timeline
```
Phase 1 (Now): Single region, PostgreSQL + Redis
Phase 2 (10k users): Multi-region, read replicas
Phase 3 (100k users): Sharding by geography
Phase 4 (1M users): Dedicated search cluster (Elasticsearch)
```

---

## 7. Deployment Architecture

### Environments
```
Development (Local)
  ├─ supabase start (local Postgres)
  └─ Edge Functions (local)

Staging (Pre-prod)
  ├─ Separate Supabase project
  ├─ Production config replicas
  └─ Full test data

Production
  ├─ Supabase cloud (mxjtgpunctckovtuyfmz)
  ├─ Daily backups (point-in-time recovery)
  ├─ Multi-region failover
  └─ Monitoring (Sentry, Datadog)
```

### CI/CD Pipeline
```
Git commit
  ↓
GitHub Actions trigger
  ↓
Run tests (Jest, Cypress)
  ↓
Build Edge Functions (Deno check)
  ↓
Database migrations (test first)
  ↓
Deploy to staging
  ↓
Smoke tests
  ↓
Manual approval
  ↓
Deploy to production
```

---

## 8. Monitoring & Observability

### Key Metrics
```
Application:
├─ API response time (p50, p95, p99)
├─ Error rate (4xx, 5xx by endpoint)
├─ Database query performance
├─ Vector search latency
└─ Payment success rate

Business:
├─ Order conversion rate
├─ Average order value
├─ Recommendation CTR
├─ User retention
└─ NPS score

Infrastructure:
├─ Database CPU/memory
├─ Connection pool usage
├─ Storage growth
├─ Backup success rate
└─ Edge Function executions
```

### Alerting
```
PagerDuty alerts for:
├─ Error rate > 1%
├─ API latency p95 > 500ms
├─ Database CPU > 85%
├─ Payment failure > 5%
└─ Backup failure
```

---

## 9. Cost Optimization

### Supabase Pricing Strategy
```
Database:
├─ Shared CPU ($25/mo) → Dedicated ($350/mo) at 1M queries/day
├─ Storage overage: $0.10/GB ($25/mo for 250GB)
└─ Transfer: $0.09/GB outbound

Edge Functions:
├─ 2M invocations included ($25/mo)
├─ $0.15/M invocations after
└─ 512MB RAM execution

Storage:
├─ 5GB included ($25/mo)
├─ $6/100GB after
└─ Image transformation (+$50/mo)

Realtime:
├─ Included in Pro plan
└─ Per-concurrent-user after free tier
```

### Cost Targets
```
Monthly Cost by Scale:
├─ 1,000 users: $150/mo
├─ 10,000 users: $500/mo
├─ 100,000 users: $2,000/mo
└─ 1,000,000 users: $10,000/mo
```

---

## 10. Architecture Decision Records (ADRs)

### ADR-1: Why Supabase over Firebase?
```
✅ PostgreSQL (relational data, RLS, advanced queries)
✅ Edge Functions (Deno, lower latency)
✅ pgvector (ML embeddings natively)
✅ Row-level security (automatic)
✅ Open source (Postgres, not vendor-locked)
❌ Firebase: Firestore limitations, expensive after scale, no SQL
```

### ADR-2: Why Deno for Edge Functions?
```
✅ Native TypeScript (no transpile)
✅ Permissions model (explicit imports)
✅ Standard library (no npm chaos)
✅ Low cold start (<10ms)
❌ Node.js: Slower cold start, legacy ecosystem
```

### ADR-3: Why pgvector for Recommendations?
```
✅ Native Postgres (no separate DB)
✅ IVFFLAT indexing (fast similarity search)
✅ Cosine distance (industry standard)
✅ Scalable to millions (with partitioning)
❌ Pinecone: Vendor lock-in, $600+/mo
❌ Weaviate: Operational overhead
```

---

## 11. High-Level Implementation Roadmap

```
Week 1:
├─ Database schema + RLS policies
├─ Supabase project link + migrations
└─ Basic auth middleware

Week 2:
├─ Order service (create, status updates)
├─ Payment webhook (Razorpay)
└─ Real-time subscriptions

Week 3:
├─ Email templates + SendGrid integration
├─ Storage bucket configuration
└─ Notification service (FCM)

Week 4:
├─ Vector embeddings + recommendation engine
├─ Search optimization
└─ Background job queue

Week 5:
├─ Security audit + RLS validation
├─ Performance testing (load, latency)
└─ Monitoring setup (Sentry, Datadog)

Week 6:
├─ Mobile app integration
├─ Dashboard integration
└─ Production deployment

Week 7:
├─ Load testing (scale to 1000 concurrent users)
├─ Failover testing
└─ Documentation finalization
```

---

## 12. Success Criteria

```
✅ All API endpoints respond in <100ms p95
✅ Recommendations load in <200ms with >85% accuracy
✅ Payment webhook processes in <500ms
✅ Real-time updates broadcast in <50ms
✅ RLS policies prevent all unauthorized access
✅ 99.9% uptime (excluding maintenance)
✅ Zero unhandled errors in production
✅ Database backups run daily with verified recovery
✅ Cost < $1000/month at 100k users
✅ Team can deploy with zero-downtime
```

---

**Next:** Database Architect will build the schema with these principles in mind.
