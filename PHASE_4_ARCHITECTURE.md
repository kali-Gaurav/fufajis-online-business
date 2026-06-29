# PHASE 4: ADMIN ANALYTICS - ARCHITECTURE OVERVIEW

**Purpose**: Complete system design for Phase 4 implementation
**Audience**: Architects, developers planning implementation
**Format**: ASCII diagrams + descriptions

---

## SYSTEM ARCHITECTURE DIAGRAM

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FLUTTER FRONTEND                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │  Admin Dashboard │  │  Order Analytics │  │ Delivery Analytics│  │
│  │   Metrics (8)    │  │   Trends (4)     │  │   Perf (4 KPI)   │  │
│  │                  │  │   Breakdown (4)  │  │   Riders (10)    │  │
│  │ • Today's Orders │  │   Metrics (6)    │  │   Quality (4)    │  │
│  │ • Pending        │  │   Forecast       │  │   Bottleneck     │  │
│  │ • In-Delivery    │  │                  │  │   Heatmap        │  │
│  │ • Rating         │  │                  │  │   Alerts         │  │
│  │ • Top Product    │  │                  │  │                  │  │
│  │ • Peak Hour      │  │                  │  │                  │  │
│  │ • Avg AOV        │  │                  │  │                  │  │
│  │ • Satisfaction   │  │                  │  │                  │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│           ▲                     ▲                      ▲              │
│           │                     │                      │              │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              Business Insights Screen                       │    │
│  │  • Recommendations (Inventory, Pricing, Timing, etc.)      │    │
│  │  • Forecasting (Peak day, Low day, Risks)                 │    │
│  │  • Customer Insights (LTV, Churn, VIP)                    │    │
│  │  • Competitive Analysis                                    │    │
│  └─────────────────────────────────────────────────────────────┘    │
│           ▲                                                           │
│           │                                                           │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              Supporting Widgets                             │    │
│  │  • DateRangePickerWidget   • FilterChipGroup               │    │
│  │  • ComparisonToggle        • ExportButton                  │    │
│  │  • QuickActionButtons      • ActivityStream                │    │
│  └─────────────────────────────────────────────────────────────┘    │
│           ▲                                                           │
└───────────┼───────────────────────────────────────────────────────────┘
            │
            │ HTTP/HTTPS (REST API)
            │
┌───────────┼───────────────────────────────────────────────────────────┐
│ BACKEND (Node.js + Firebase Functions)                                │
├───────────┼───────────────────────────────────────────────────────────┤
│           │                                                             │
│  ┌────────▼─────────┐   ┌──────────────┐   ┌──────────────────┐      │
│  │  Analytics APIs  │   │  Insights API│   │   Export API     │      │
│  │                  │   │              │   │                  │      │
│  │ GET /metrics     │   │ POST /gen    │   │ POST /pdf        │      │
│  │ GET /trend       │   │ GET /recs    │   │ POST /csv        │      │
│  │ GET /breakdown   │   │ POST /mark   │   │                  │      │
│  │ GET /forecast    │   │ GET /forecast│   │ [Generate Files] │      │
│  │ GET /riders      │   │ GET /health  │   │                  │      │
│  │ GET /quality     │   │              │   │                  │      │
│  │ GET /bottleneck  │   │              │   │                  │      │
│  │ GET /heatmap     │   │              │   │                  │      │
│  │ GET /anomalies   │   │              │   │                  │      │
│  └────────┬─────────┘   └──────┬───────┘   └────────┬─────────┘      │
│           │                    │                    │                  │
│  ┌────────▼────────────────────▼────────────────────▼──────────┐     │
│  │              Analytics Service                             │     │
│  │  • getOrderTrend()        • getDeliveryMetrics()           │     │
│  │  • getOrderBreakdown()    • getRiderPerformance()          │     │
│  │  • getOrderMetrics()      • getDeliveryQuality()           │     │
│  │  • forecastOrders()       • getBottleneckAnalysis()        │     │
│  │  • getDeliveryHeatmap()   • getAnomalies()                 │     │
│  └────────┬─────────────────────────────────────────────────────┘    │
│           │                                                             │
│  ┌────────▼─────────────────────────────────────────────────────┐    │
│  │              Insights Engine                                │    │
│  │  • generateInsights()     • findChurnRiskCustomers()        │    │
│  │  • generateRecommendations()  • identifyVIPs()             │    │
│  │  • runMLModels()          • analyzeBottlenecks()           │    │
│  └────────┬─────────────────────────────────────────────────────┘    │
│           │                                                             │
│  ┌────────▼─────────────────────────────────────────────────────┐    │
│  │              ML Models                                      │    │
│  │                                                              │    │
│  │ ┌─────────────────┐  ┌──────────────────┐ ┌─────────────┐  │    │
│  │ │DemandForecast   │  │PriceElasticity   │ │Segmentation │  │    │
│  │ │(ARIMA/Prophet)  │  │(Linear Regression)│ │(K-means)    │  │    │
│  │ │                 │  │                  │ │             │  │    │
│  │ │Input: Orders    │  │Input: Price+Qty  │ │Input: RFM   │  │    │
│  │ │Output: 7-day    │  │Output: Elasticity│ │Output: Segs │  │    │
│  │ │forecast ±5      │  │Recommend price   │ │New/Loyal/  │  │    │
│  │ │Accuracy: 80%+   │  │changes           │ │At-Risk     │  │    │
│  │ └─────────────────┘  └──────────────────┘ └─────────────┘  │    │
│  │                                                              │    │
│  │ ┌──────────────────┐  ┌────────────────────┐               │    │
│  │ │ChurnPrediction   │  │RecommendationEngine│               │    │
│  │ │(Logistic Reg)    │  │(Rule-based + ML)   │               │    │
│  │ │                  │  │                    │               │    │
│  │ │Input: Behavior   │  │Input: Metrics      │               │    │
│  │ │Output: Churn     │  │Output: Actions     │               │    │
│  │ │probability (0-1) │  │• Reorder           │               │    │
│  │ │Target: 85%+      │  │• Raise price       │               │    │
│  │ │accuracy          │  │• Discount          │               │    │
│  │ │                  │  │• Hire staff        │               │    │
│  │ └──────────────────┘  └────────────────────┘               │    │
│  └──────────────────────────────────────────────────────────┘    │
│           │                                                      │    │
└───────────┼──────────────────────────────────────────────────────┘
            │
            │ Read/Write
            │
┌───────────▼──────────────────────────────────────────────────────┐
│ FIRESTORE DATABASE                                                │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────┐   ┌──────────────────────┐              │
│  │  analytics_daily     │   │  insights            │              │
│  │  /{shopId}/metrics   │   │  /{shopId}/{insId}   │              │
│  │                      │   │                      │              │
│  │ • date               │   │ • id                 │              │
│  │ • ordersCount        │   │ • title              │              │
│  │ • revenue            │   │ • description        │              │
│  │ • avgOrderValue      │   │ • category           │              │
│  │ • peakHour           │   │ • confidence         │              │
│  │ • customersCount     │   │ • actionItems        │              │
│  │ • avgDeliveryTime    │   │ • status             │              │
│  │ • onTimePercentage   │   │ • generatedAt        │              │
│  │ • customerRating     │   │ • actionsHistory     │              │
│  │ • reviewCount        │   │                      │              │
│  └──────────────────────┘   └──────────────────────┘              │
│                                                                     │
│  ┌──────────────────────┐   ┌──────────────────────┐              │
│  │  insights_history    │   │  delivery_zones      │              │
│  │  /{shopId}/{date}    │   │  /{shopId}/{zoneId}  │              │
│  │                      │   │                      │              │
│  │ • totalInsights      │   │ • zoneName           │              │
│  │ • insights[]         │   │ • coordinates        │              │
│  │                      │   │ • deliveryCount      │              │
│  │                      │   │ • avgDeliveryTime    │              │
│  │                      │   │ • cancellationRate   │              │
│  │                      │   │ • peakHours[]        │              │
│  └──────────────────────┘   └──────────────────────┘              │
│                                                                     │
│  Plus existing collections:                                       │
│  • orders, orders_items, deliveries, reviews, products, etc.     │
│  • New indexes on {shopId, createdAt} for analytics               │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

---

## DATA FLOW DIAGRAM

### Flow 1: Dashboard Metrics (Real-time)
```
User opens dashboard
        │
        ▼
AdminProvider.fetchDashboardMetrics()
        │
        ├─→ Query: orders.where(status in [pending, accepted, out_for_delivery])
        │          orders.where(status == delivered)
        │          reviews.where(shopId == X)
        │
        ├─→ Calculate: count, sum(totalAmount), avg(rating)
        │
        ├─→ Store in provider state
        │
        ├─→ notifyListeners()
        │
        ▼
UI rebuilds with fresh metrics
        │
        ├─→ Display 8 metric cards
        ├─→ Show loading skeleton while fetching
        ├─→ Auto-refresh every 10 seconds (Timer)
        │
        ▼
User sees real-time data: "42 orders | ₹15,000 revenue"
```

**Optimization**: Cache in analytics_daily collection, refresh at 2 AM UTC

---

### Flow 2: Order Trend Analysis
```
User opens Order Analytics screen
        │
        ▼
Selects date range: Last 7 days
        │
        ▼
AdminProvider.fetchOrderTrend(startDate, endDate, granularity='daily')
        │
        ├─→ HTTP GET /api/admin/analytics/orders/trend
        │   ├─→ Query orders with date filter
        │   ├─→ Group by date/hour
        │   ├─→ Calculate count, revenue, avg AOV
        │   ├─→ Return [{date, orderCount, revenue, avgOrderValue}]
        │
        ├─→ Provider stores data
        ├─→ notifyListeners()
        │
        ▼
LineChart renders
        │
        ├─→ X-axis: dates (Last 7 days)
        ├─→ Y-axis: order count
        ├─→ Interactive touch for details
        │
        ▼
User sees trend: "Orders trending up, peak on Friday"

User clicks comparison toggle: "vs Last Week"
        │
        ▼
New query with previous period
        │
        ▼
Chart shows side-by-side: "Week 2 up 5% vs Week 1"
```

---

### Flow 3: Insight Generation (Daily)
```
Scheduled job runs at 2 AM UTC
        │
        ├─→ POST /api/admin/insights/generate {shopId: X}
        │
        ▼
InsightsEngine.generateInsights(shopId)
        │
        ├─→ Load shop metrics from analytics_daily
        ├─→ Run ML models:
        │   ├─→ DemandForecast: Predict next 7 days
        │   ├─→ PriceElasticity: Identify optimization opportunities
        │   ├─→ CustomerSegmentation: New/Loyal/At-Risk
        │   ├─→ ChurnPrediction: Identify churn risk customers
        │
        ├─→ Generate recommendations:
        │   ├─→ Inventory insights
        │   │   └─→ "Buy 50 Tomatoes (2 days stock left, +3x sales)"
        │   ├─→ Pricing insights
        │   │   └─→ "Raise Biryani to ₹450 (inelastic, +15% revenue)"
        │   ├─→ Timing insights
        │   │   └─→ "Best time: Friday 1-2 PM (peak demand)"
        │   ├─→ Promotion insights
        │   │   └─→ "Discount Samosa 15% (high inventory, slow)"
        │   ├─→ Operations insights
        │   │   └─→ "Hire 2 riders (avg delivery 28→20 min goal)"
        │   ├─→ Customer insights
        │   │   └─→ "5 customers churning (no order in 30 days)"
        │
        ├─→ Calculate confidence score for each
        ├─→ Store in insights/{shopId}
        │
        ▼
User opens Insights screen next day
        │
        ├─→ UI fetches insights
        ├─→ Displays as cards sorted by confidence
        ├─→ User can "Mark as Actioned" or "Dismiss"
        │
        ▼
User sees: "6 recommendations (87% avg confidence)"
```

---

### Flow 4: Export to PDF
```
User clicks "Export as PDF"
        │
        ▼
ExportButton shows dropdown:
        ├─→ PDF
        ├─→ CSV
        ├─→ Excel
        │
User selects: PDF
        │
        ▼
POST /api/admin/export/pdf
{
  dataType: "order_analytics",
  dateRange: { start, end },
  filters: { category: "all" }
}
        │
        ▼
Backend:
        ├─→ Query data from Firestore
        ├─→ Generate PDF with:
        │   ├─→ Charts (line, pie, bar)
        │   ├─→ Tables (metrics)
        │   ├─→ Headers/Footer with date range
        │   └─→ Shop name + branding
        ├─→ Upload to Firebase Storage
        ├─→ Generate signed URL
        │
        ▼
Return: { fileUrl: "https://..." }
        │
        ▼
Frontend:
        ├─→ Show "PDF ready!" toast
        ├─→ Open in browser or download
        │
        ▼
User saves "Fufaji_OrderAnalytics_2026-06-23.pdf"
```

---

## STATE MANAGEMENT ARCHITECTURE

```
┌─────────────────────────────────────────────────┐
│         Admin Dashboard State (Provider)         │
├─────────────────────────────────────────────────┤
│                                                  │
│  Metrics State:                                 │
│  ├─ ordersToday: int                            │
│  ├─ revenueToday: double                        │
│  ├─ pendingOrders: int                          │
│  ├─ inDeliveryOrders: int                       │
│  ├─ todayRating: double                         │
│  ├─ reviewCount: int                            │
│  └─ lastRefresh: DateTime                       │
│                                                  │
│  Analytics State:                               │
│  ├─ selectedDateRange: DateTimeRange            │
│  ├─ orderTrend: List<DailyMetric>              │
│  ├─ orderBreakdown: Map<String, List>          │
│  ├─ deliveryMetrics: DeliveryMetricsModel      │
│  └─ riderPerformance: List<RiderModel>         │
│                                                  │
│  Insights State:                                │
│  ├─ insights: List<InsightCard>                │
│  ├─ selectedCategory: String                    │
│  ├─ actedInsights: List<String>                │
│  └─ lastGenerated: DateTime                     │
│                                                  │
│  UI State:                                      │
│  ├─ isLoading: bool                             │
│  ├─ error: String                               │
│  ├─ selectedTab: int                            │
│  └─ isExporting: bool                           │
│                                                  │
└─────────────────────────────────────────────────┘

Methods:
├─ fetchDashboardMetrics()
├─ fetchOrderTrend(range, granularity)
├─ fetchDeliveryMetrics(range)
├─ fetchInsights()
├─ generateInsights()
├─ markInsightActioned(id)
├─ exportToPDF(dataType, params)
├─ exportToCSV(dataType, params)
└─ updateDateRange(range)
```

---

## API RESPONSE SCHEMAS

### GET /api/admin/dashboard/metrics
```javascript
{
  "ordersToday": 42,
  "revenueToday": 15000,
  "pendingOrders": 8,
  "inDeliveryOrders": 5,
  "todayRating": 4.8,
  "reviewCount": 124,
  "topProduct": {
    "name": "Biryani",
    "count": 28
  },
  "peakHour": "13:00-14:00",
  "avgOrderValue": 357.14,
  "satisfactionScore": 87
}
```

### GET /api/admin/analytics/orders/forecast
```javascript
{
  "forecast": [
    {
      "date": "2026-06-24",
      "expectedOrders": 48,
      "expectedRevenue": 16800,
      "confidence": 0.92,
      "interval": { "min": 43, "max": 53 }
    },
    ...
  ],
  "trend": "up",
  "trendPercentage": 5.2,
  "modelAccuracy": 0.85
}
```

### GET /api/admin/insights/recommendations
```javascript
{
  "insights": [
    {
      "id": "insight_123",
      "title": "Reorder Tomatoes",
      "description": "Stock: 2 days remaining, Sales: 3x normal rate",
      "category": "inventory",
      "confidence": 0.95,
      "actionItems": [
        "Order 50 kg from supplier",
        "Update delivery schedule"
      ],
      "status": "pending",
      "generatedAt": "2026-06-23T10:30:00Z"
    },
    ...
  ]
}
```

---

## PERFORMANCE TARGETS

```
Metric                      Target      Actual      Status
─────────────────────────────────────────────────────────
Dashboard load time         < 2s        TBD         ⏳
Metric refresh time         < 200ms     TBD         ⏳
Chart render time           < 1s        TBD         ⏳
Analytics API response      < 500ms     TBD         ⏳
Forecast API response       < 1s        TBD         ⏳
Insight generation time     < 30s       TBD         ⏳
PDF export time             < 5s        TBD         ⏳
CSV export time             < 3s        TBD         ⏳

Firestore queries           < 10        TBD         ⏳
Cloud Functions calls       < 100       TBD         ⏳
Cache hit rate              > 80%       TBD         ⏳
ML model accuracy           > 80%       TBD         ⏳
```

---

## SECURITY ARCHITECTURE

```
┌──────────────────────────────────────────────┐
│ Frontend (Flutter App)                        │
├──────────────────────────────────────────────┤
│ • Firebase Auth required for access           │
│ • Admin role check in AuthProvider            │
│ • All API calls through authenticated client  │
└───────────────────┬──────────────────────────┘
                    │
                    ▼
          HTTPS Only (TLS 1.3)
                    │
                    ▼
┌──────────────────────────────────────────────┐
│ Backend (Firebase Functions)                  │
├──────────────────────────────────────────────┤
│ • Verify Firebase Auth token                  │
│ • Check admin role in custom claims           │
│ • Validate shopId ownership                   │
│ • Rate limiting (100 req/min per user)        │
│ • Input validation (dates, filters)           │
│ • SQL injection prevention (no raw SQL)       │
│ • Firestore rules enforce access              │
└───────────────────┬──────────────────────────┘
                    │
                    ▼
        Firestore Security Rules
                    │
            ┌───────┴──────┐
            ▼              ▼
    analytics_daily  insights
    
    Rules:
    ├─ Only shop owner can read own data
    ├─ Analytics_daily is read-only from functions
    ├─ Insights can only be written by functions
    ├─ No direct write from frontend
    └─ TTL deletes old data automatically

```

---

## SCALABILITY CONSIDERATIONS

### Firestore Collections Size Estimate
```
Collection          Docs/Year/Shop    Storage/Year    Index Cost
──────────────────────────────────────────────────────────────────
analytics_daily     365               ~5 MB           1 index
insights            3,650             ~10 MB          1 index
insights_history    365               ~50 MB          0 indexes
delivery_zones      10                ~1 MB           0 indexes
──────────────────────────────────────────────────────────────────
TOTAL              4,390              ~66 MB          2 indexes
```

### API Rate Limits
```
Endpoint                          Limit           TTL
────────────────────────────────────────────────────────
GET /api/admin/dashboard/*        1000 req/day    -
GET /api/admin/analytics/*        100 req/day     5 min (cached)
POST /api/admin/insights/generate 1 req/day       -
GET /api/admin/insights/*         1000 req/day    -
POST /api/admin/export/*          50 req/day      -
```

### Caching Strategy
```
Cache Layer              TTL         Hit Rate Target
─────────────────────────────────────────────────────
analytics_daily (DB)    24 hours    85%
API response cache      5 minutes   80%
Frontend provider cache in-memory   70%
Chart data cache        10 minutes  75%
```

---

## ERROR HANDLING FLOW

```
User Action
    │
    ▼
Provider API Call
    │
    ├─→ Try
    │   ├─→ Validate input
    │   ├─→ Call Firestore/HTTP
    │   ├─→ Transform data
    │   └─→ Update state
    │
    ├─→ Catch (Firestore Error)
    │   ├─→ Permission denied → Show "Access denied" toast
    │   ├─→ Not found → Show "No data" message
    │   ├─→ Timeout → Show "Retry" button
    │   └─→ Network error → Show offline mode message
    │
    ├─→ Catch (HTTP Error)
    │   ├─→ 401 → Logout user
    │   ├─→ 403 → Show "Admin role required"
    │   ├─→ 429 → Show "Rate limited, try later"
    │   ├─→ 500 → Show "Server error, contact support"
    │   └─→ 503 → Show "Service temporarily unavailable"
    │
    └─→ Finally
        └─→ Stop loading state
            └─→ Refresh UI
```

---

## DEPLOYMENT PIPELINE

```
Developer
    │
    ├─→ Create feature branch: feature/phase4-dashboard
    │
    ├─→ Implement code
    │   ├─→ Frontend: lib/screens/admin/
    │   ├─→ Backend: backend/services/
    │   └─→ Tests: test/ + integration_test/
    │
    ├─→ Run tests locally
    │   ├─→ flutter test          # Unit + widget tests
    │   ├─→ integration_test      # Integration tests
    │   └─→ npm test              # Backend tests
    │
    ├─→ Commit + Push to GitHub
    │
    ▼
GitHub Actions CI
    │
    ├─→ Lint checks
    │   ├─→ flutter analyze
    │   └─→ eslint (backend)
    │
    ├─→ Run all tests
    │   ├─→ 45 tests must pass
    │   └─→ Code coverage > 80%
    │
    ├─→ Build APK
    │   └─→ flutter build apk --release
    │
    ├─→ Build backend
    │   └─→ npm run build
    │
    ▼
Pull Request Review
    │
    ├─→ Code review by senior dev
    ├─→ Performance review
    ├─→ Security review
    │
    ▼
Merge to main
    │
    ├─→ Auto-deploy to staging
    │   ├─→ Deploy APK to Firebase App Distribution
    │   ├─→ Deploy backend to Firebase Functions
    │   └─→ Deploy Firestore rules
    │
    ├─→ Staging tests
    │   ├─→ Manual QA (2 hours)
    │   ├─→ Smoke tests on real device
    │   └─→ Performance profiling
    │
    ▼
Release tag: v4.0.0-analytics
    │
    ├─→ Auto-deploy to production
    │   ├─→ Firebase Functions deploy
    │   ├─→ Firestore rules update
    │   ├─→ APK available for manual install
    │
    ├─→ Monitor
    │   ├─→ Crashlytics errors
    │   ├─→ Performance monitoring
    │   ├─→ API response times
    │
    ▼
Completed ✓
```

---

## MONITORING & ALERTING

```
Metric                          Alert Threshold
──────────────────────────────────────────────────
API Response Time               > 500ms
Firestore Error Rate            > 1%
Cloud Functions Timeout         > 5 times/hour
Insight Generation Failure      Any failure
ML Model Accuracy               < 75%
Cache Hit Rate                  < 70%
Firestore Write Latency         > 100ms

Alert Actions:
├─→ Email to admin@fufaji.com
├─→ Slack notification
├─→ PagerDuty (critical only)
└─→ Auto-log in Firestore
```

---

## TESTING PYRAMID

```
       ▲
       │
    1  │  █████  Integration Tests (10)
       │  ███████  • End-to-end flows
       │  █████████  • Real Firestore
       │              • Real APIs
       │
    2  │  ████████████████  Widget Tests (10)
       │  ████████████████████  • UI components
       │  ██████████████████████  • Mock data
       │                          • Responsive layout
       │
    3  │  ██████████████████████████████  Unit Tests (15)
       │  ████████████████████████████████████  • Business logic
       │  ████████████████████████████████████████  • Calculations
       │                                         • Transformations
       │
       └─────────────────────────────────────
          45 tests total
```

---

## TECHNOLOGY STACK

```
Frontend:
├─ Flutter 3.16+
├─ Provider (state management)
├─ go_router (navigation)
├─ fl_chart (charting)
├─ Firebase SDK (Firestore, Auth, Storage)
├─ intl (date formatting)
├─ csv (export)
└─ pdf (export)

Backend:
├─ Node.js 18+
├─ Firebase Functions (serverless)
├─ Firebase Admin SDK
├─ Express.js (optional, for local dev)
├─ ml.js or simple-statistics (ML models)
├─ pdf-lib (PDF generation)
└─ papaparse (CSV generation)

Database:
├─ Firebase Firestore (primary)
├─ Firebase Storage (exports)
└─ Cloud Scheduler (jobs)

DevOps:
├─ GitHub Actions (CI/CD)
├─ Firebase CLI (deployment)
├─ Docker (optional, for testing)
└─ Postman (API testing)

Monitoring:
├─ Firebase Performance Monitoring
├─ Firebase Crashlytics
├─ Custom Firestore logging
└─ Cloud Logging
```

---

## DEPENDENCIES DIAGRAM

```
PHASE 4 depends on:
├─ Phase 1-3 (Complete)
│  ├─ Auth system
│  ├─ Order system
│  ├─ Delivery system
│  └─ Firestore collections
│
├─ AdminProvider (exists, enhance)
├─ Firestore rules (update)
└─ Backend infrastructure (Firebase Functions)

Phase 4 enables:
├─ Phase 5 (Marketing insights)
├─ Phase 6 (Loyalty programs)
├─ Phase 7 (Scaling & multi-shop)
└─ Phase 8+ (Advanced features)
```

---

## VERSION CONTROL STRATEGY

```
Branch naming:
├─ feature/phase4-dashboard
├─ feature/phase4-analytics-orders
├─ feature/phase4-analytics-delivery
├─ feature/phase4-insights
├─ feature/phase4-backend-apis
└─ feature/phase4-ml-models

Commit message format:
├─ [Phase 4] Add admin dashboard metrics (8 cards)
├─ [Phase 4] Implement order trend analysis
├─ [Phase 4] Add delivery performance leaderboard
├─ [Phase 4] Create insights recommendation engine
└─ [Phase 4] Deploy analytics APIs to production

Tag format:
├─ v4.0.0-beta (after first complete build)
├─ v4.0.0-rc1 (after testing)
└─ v4.0.0 (production release)
```

---

**Document Version**: 1.0
**Last Updated**: June 23, 2026
**Status**: Ready for Implementation
