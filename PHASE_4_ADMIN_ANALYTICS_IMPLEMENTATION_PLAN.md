# PHASE 4: ADMIN DASHBOARD & ANALYTICS - DETAILED IMPLEMENTATION PLAN

**Date**: June 23, 2026
**Priority**: High (Post Phase 3)
**Scope**: Enhanced business intelligence system with real-time metrics, analytics dashboards, and AI-powered insights
**Total Effort**: 85 hours
**Success Criteria**: 4 dashboards, 20+ metrics, 35+ tests, 5 ML models, production-ready

---

## CURRENT STATE ANALYSIS

### Existing Infrastructure (Already Present)
✅ **AdminProvider** (lib/providers/admin_provider.dart)
- Basic dashboard metrics fetching
- User/shop/order management
- Revenue calculation

✅ **AnalyticsScreen** (lib/screens/admin/analytics_screen.dart)
- Global system analytics
- Basic charts using fl_chart
- Metrics display (revenue, shops, users)

✅ **Supporting Providers**
- `ai_insights_provider.dart` - AI insights generation (partial)
- `forecast_provider.dart` - Forecasting logic (partial)
- `owner_analytics_provider.dart` - Owner-specific analytics
- `operational_intelligence_provider.dart` - Operations analytics

✅ **UI Components**
- Admin dashboard scaffold with navigation
- Responsive design utilities
- Theme system (AppTheme)

### Gaps to Fill
- ❌ Shop owner dashboard (different from global admin)
- ❌ Order analytics with trends & forecasting
- ❌ Delivery analytics with rider performance
- ❌ Business insights with ML recommendations
- ❌ Real-time metric updates
- ❌ Advanced filtering & date range pickers
- ❌ PDF/CSV export functionality
- ❌ Backend analytics APIs
- ❌ ML model implementation

---

## DELIVERABLE 1: ADMIN DASHBOARD ENHANCEMENT (25 hours)

### File: `lib/screens/admin/admin_dashboard_metrics.dart`
**Purpose**: Real-time metrics display with auto-refresh

```dart
class AdminDashboardMetrics extends StatefulWidget {
  final String shopId;  // null for global admin, set for shop owner
  const AdminDashboardMetrics({super.key, this.shopId});

  @override
  State<AdminDashboardMetrics> createState() => _AdminDashboardMetricsState();
}

class _AdminDashboardMetricsState extends State<AdminDashboardMetrics> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();  // Refresh every 10 seconds
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        context.read<AdminProvider>().fetchDashboardMetrics();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
```

**Metrics to Display** (8 cards):
1. **Today's Orders**: Count + revenue (e.g., "42 orders | ₹15,000")
2. **Pending Fulfillment**: Orders waiting to ship (e.g., "8 orders")
3. **In Delivery**: Orders on the way (e.g., "5 orders")
4. **Today's Rating**: Star rating + review count (e.g., "4.8★ | 124 reviews")
5. **Top Product**: Best-selling item (e.g., "Biryani - 28 orders")
6. **Peak Hour**: When most orders received (e.g., "1-2 PM - 12 orders")
7. **Avg Order Value**: Daily average (e.g., "₹350")
8. **Customer Satisfaction**: NPS or CSAT score (e.g., "87% positive")

**Features**:
- Real-time updates (10-second refresh)
- Tap to drill-down to details screen
- Loading skeleton while fetching
- Error handling with retry button
- Responsive layout (grid on desktop, stack on mobile)

**Backend Requirement**:
```
GET /api/admin/dashboard/metrics
Query params: shopId (optional), startDate, endDate
Response: {
  ordersToday: 42,
  revenueToday: 15000,
  pendingOrders: 8,
  inDeliveryOrders: 5,
  todayRating: 4.8,
  reviewCount: 124,
  topProduct: { name: "Biryani", count: 28 },
  peakHour: "1-2 PM",
  avgOrderValue: 350,
  satisfactionScore: 87
}
```

---

### File: `lib/screens/admin/admin_dashboard_charts.dart`
**Purpose**: Visualizations for key metrics

**Chart 1: Orders Over Time (Hourly/Daily Line Chart)**
- X-axis: Time (hourly or daily)
- Y-axis: Order count
- Interactive: Tap to see exact count

**Chart 2: Revenue by Payment Method (Pie Chart)**
- Segments: Cash, Card, UPI, Wallet
- Show: Count + percentage
- Colors: Distinct colors per method

**Chart 3: Top Products (Bar Chart)**
- Top 5 products by order count
- X-axis: Product name
- Y-axis: Order count
- Sorting: Descending

**Implementation Pattern**:
```dart
class _OrdersOverTimeChart extends StatelessWidget {
  final List<FlSpot> dataPoints;  // from provider
  final List<String> hourLabels;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        spots: dataPoints,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: ...),
          ),
        ),
        lineTouchData: LineTouchData(enabled: true),
      ),
    );
  }
}
```

---

### File: `lib/screens/admin/admin_dashboard_quick_actions.dart`
**Purpose**: Quick navigation buttons

**4 Main Actions**:
1. **View Pending Orders** → Navigate to orders screen with status filter
2. **View In-Delivery Orders** → Navigate to orders screen with delivery filter
3. **Create Promo** → Navigate to coupon creation screen
4. **View Inventory** → Navigate to inventory management screen

```dart
class QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [...],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
```

---

### File: `lib/screens/admin/admin_dashboard_activity.dart`
**Purpose**: Recent activity stream

**Activity Items**:
- Order placed: "Order #123 placed by Customer X"
- Order delivered: "Order #121 delivered (5★ review added)"
- Inventory alert: "Tomatoes low - 5 units remaining"
- New review: "Customer Y left 4★ review"
- Cancellation: "Order #120 cancelled - refund issued"

```dart
class ActivityItem {
  final String id;
  final ActivityType type;  // enum: order_placed, delivered, inventory_alert, etc.
  final String title;
  final String description;
  final DateTime timestamp;
  final String? relatedId;  // orderId, productId, etc.

  ActivityItem({required this.id, ...});
}
```

---

## DELIVERABLE 2: ORDER ANALYTICS SCREEN (20 hours)

### File: `lib/screens/admin/analytics_orders_screen.dart`
**Purpose**: Comprehensive order analytics and trends

### Section A: Trend Analysis
```dart
class OrderTrendSection extends StatefulWidget {
  // Line charts showing:
  // 1. Orders over time (daily/hourly)
  // 2. Average order value trend
  // 3. Conversion rate (browse → add-to-cart → checkout)
  // 4. Cancellation rate trend
}
```

**Data Required**:
- Date range picker (default: last 7 days)
- Granularity selector: Daily / Hourly / Weekly / Monthly
- Compare with previous period toggle

### Section B: Breakdown Analysis
```dart
class OrderBreakdownSection extends StatelessWidget {
  // 4 pie/bar charts:
  // 1. Orders by payment method
  // 2. Orders by time of day (breakfast 6-9, lunch 12-2, dinner 7-10, late night)
  // 3. Orders by product category
  // 4. Orders by customer segment (new, returning, loyal)
}
```

### Section C: Key Metrics
- Avg order value: ₹350
- Orders per day: 45
- Peak hour: 1-2 PM (12 orders)
- Repeat customer rate: 42%
- Customer lifetime value: ₹2,500 avg
- Churn rate: 5% monthly

### Section D: Forecasting
- Expected orders tomorrow: 48 ± 5
- Expected revenue: ₹16,800 ± ₹1,500
- Confidence: 92%
- Trending: ↑ (up 5% vs last week)

**Backend Requirement**:
```
GET /api/admin/analytics/orders/trend
Query: shopId, startDate, endDate, granularity
Response: {
  trendData: [{date, orderCount, revenue, avgOrderValue}, ...],
  conversionRate: [{stage, rate}, ...],
  cancellationTrend: [{date, rate}, ...]
}

GET /api/admin/analytics/orders/breakdown
Response: {
  byPaymentMethod: [{method, count, percentage}, ...],
  byTimeOfDay: [{period, count}, ...],
  byCategory: [{category, count}, ...],
  bySegment: [{segment, count}, ...]
}

GET /api/admin/analytics/orders/metrics
Response: {
  avgOrderValue: 350,
  ordersPerDay: 45,
  peakHour: "1-2 PM",
  peakHourCount: 12,
  repeatCustomerRate: 0.42,
  customerLifetimeValue: 2500,
  churnRateMonthly: 0.05
}

GET /api/admin/analytics/orders/forecast
Query: shopId, days=7
Response: {
  forecast: [{date, expectedOrders, expectedRevenue, confidence}, ...],
  trend: "up|down|stable",
  trendPercentage: 5.2
}
```

---

## DELIVERABLE 3: DELIVERY ANALYTICS SCREEN (20 hours)

### File: `lib/screens/admin/analytics_delivery_screen.dart`
**Purpose**: Fulfillment and delivery performance tracking

### Section A: Performance Metrics (4 KPIs)
- On-time delivery %: 94% (green if ≥90%)
- Avg delivery time: 28 minutes
- Cancellation rate: 2%
- Failed deliveries: 1.5%

### Section B: Rider Leaderboard
```dart
class RiderPerformanceItem {
  String riderId;
  String riderName;
  int completedDeliveries;
  double rating;  // 1-5
  double onTimePercentage;
  double earnings;
  DateTime lastDelivery;
}
```

Sort by: Rating (desc) / On-Time % (desc) / Deliveries (desc)

### Section C: Quality Metrics
- Customer satisfaction: 4.8/5.0
- Complaint rate: 1.2%
- Positive feedback %: 87%
- Issue breakdown:
  - Photo damage: 40%
  - Late delivery: 35%
  - Other: 25%

### Section D: Bottleneck Analysis
- Avg time at shop: 5 min
- Avg time to customer: 23 min
- Avg time between deliveries: 3 min
- Slowest step: Identify and highlight

### Section E: Geographic Heatmap
- Delivery density by zone
- Problem zones (high cancellation rate)
- Peak delivery hours by location

### Section F: Anomaly Alerts
- If on-time % drops below 90% → Red alert
- If complaint rate exceeds 2% → Yellow alert
- If avg delivery time increases > 10% → Yellow alert

**Backend Requirements**:
```
GET /api/admin/analytics/delivery/performance
Response: {
  onTimePercentage: 0.94,
  avgDeliveryTimeMinutes: 28,
  cancellationRate: 0.02,
  failedDeliveryRate: 0.015
}

GET /api/admin/analytics/delivery/riders
Query: sortBy (rating|onTime|deliveries)
Response: {
  riders: [{
    riderId, riderName, completedDeliveries, rating,
    onTimePercentage, earnings, lastDelivery
  }, ...]
}

GET /api/admin/analytics/delivery/quality
Response: {
  customerSatisfaction: 4.8,
  complaintRate: 0.012,
  positiveFeedbackPercentage: 0.87,
  issueBreakdown: {
    photoDamage: 0.40,
    lateDelivery: 0.35,
    other: 0.25
  }
}

GET /api/admin/analytics/delivery/bottleneck
Response: {
  avgTimeAtShop: 5,
  avgTimeToCustomer: 23,
  avgTimeBetweenDeliveries: 3,
  slowestStep: "time_to_customer"
}

GET /api/admin/analytics/delivery/heatmap
Response: {
  zones: [{
    zoneId, zoneName, deliveryDensity, cancellationRate,
    peakHours: [{ hour, count }]
  }, ...]
}

GET /api/admin/analytics/delivery/anomalies
Response: {
  alerts: [{
    severity: "red|yellow",
    message: "...",
    metric: "onTime|complaint|avgTime",
    currentValue: 0.88,
    threshold: 0.90
  }, ...]
}
```

---

## DELIVERABLE 4: BUSINESS INSIGHTS SCREEN (20 hours)

### File: `lib/screens/admin/analytics_insights_screen.dart`
**Purpose**: AI-generated recommendations and insights

### Section A: Automated Recommendations (Priority-ordered)
```dart
class InsightCard {
  String id;
  String title;
  String description;
  String category;  // inventory|pricing|timing|promotion|operations
  double confidence;  // 0-1
  List<String> actionItems;  // Steps to implement
  bool isActioned;  // User marked as done
  DateTime generatedAt;
}
```

**Example Recommendations**:
1. **Inventory**: "Buy 50 more Tomatoes (selling 3x normal rate, 2 days stock left)"
2. **Pricing**: "Consider raising Biryani price to ₹450 (inelastic demand, +15% revenue)"
3. **Timing**: "Best sales window: Friday 1-2 PM (12 orders avg, peak day)"
4. **Promotion**: "Launch 15% discount on Samosa (inventory high, slow sales)"
5. **Operations**: "Reduce delivery time: Hire 2 more riders (avg 28 min → target 20 min)"
6. **Customer**: "Reach out to 5 churning customers (hadn't ordered in 30 days)"

**Recommendation Generation Logic**:
```dart
class InsightEngine {
  List<InsightCard> generateInsights(ShopMetrics metrics) {
    final insights = <InsightCard>[];

    // Inventory insights
    for (var product in metrics.products) {
      final daysOfStock = product.quantity / product.dailySalesAvg;
      if (daysOfStock < 3) {
        insights.add(InsightCard(
          title: "Reorder ${product.name}",
          description: "Only ${daysOfStock.toStringAsFixed(1)} days of stock left",
          actionItems: ["Increase order quantity by 50%"],
        ));
      }
    }

    // Pricing insights
    for (var product in metrics.products) {
      if (product.elasticity < -0.5) {  // Inelastic demand
        final newPrice = product.currentPrice * 1.15;
        insights.add(InsightCard(
          title: "Raise ${product.name} price",
          description: "Demand is inelastic, can increase to ₹${newPrice.toInt()}",
          actionItems: ["Update price in inventory", "Monitor sales for 3 days"],
        ));
      }
    }

    return insights;
  }
}
```

### Section B: Forecasting Panel
- Expected peak order day: Friday 1-2 PM
- Expected low day: Wednesday 3-4 PM
- Inventory shortage risk: Medium (Monday)
- Weather impact: Rainy Sunday → expect 20% drop in orders

### Section C: Customer Insights
- Customer lifetime value: ₹2,500 avg (Segment: Loyal)
- Churn risk: 5 customers at risk this week (no order in 30 days)
- VIP customers: 20 (spend > ₹5,000/month)
- New customer rate: 8% (acquisition healthy)

### Section D: Competitive Analysis (if available)
- You're 12% more expensive than competitor X
- Your delivery is 5 min faster (competitive advantage!)
- Customer reviews: You're #2 in your area (after X)

**Backend Requirement**:
```
POST /api/admin/insights/generate
Query: shopId
Body: { metrics: ShopMetrics }
Response: {
  insights: [{
    id, title, description, category, confidence,
    actionItems, isActioned, generatedAt
  }, ...],
  refreshedAt: timestamp
}

GET /api/admin/insights/recommendations
Query: shopId, category (optional)
Response: {
  insights: [InsightCard, ...]
}

POST /api/admin/insights/{id}/mark-addressed
Response: { success: true }

GET /api/admin/insights/forecast
Query: shopId, days=7
Response: {
  peakDay: { dayOfWeek, timeRange, expectedOrders },
  lowDay: { dayOfWeek, timeRange },
  riskFactors: [{ factor, impact, date }, ...],
  weatherImpact: { condition, expectedOrderChange }
}

GET /api/admin/insights/customer-health
Response: {
  customerLifetimeValue: 2500,
  churnRiskCustomers: [{ customerId, name, riskScore, lastOrder }, ...],
  vipCustomers: [{ customerId, name, totalSpent, orderCount }, ...],
  newCustomerRate: 0.08,
  retentionRate: 0.92
}
```

---

## SUPPORTING COMPONENTS

### File: `lib/screens/admin/widgets/date_range_picker_widget.dart`
```dart
class DateRangePickerWidget extends StatefulWidget {
  final DateTimeRange initialRange;
  final ValueChanged<DateTimeRange> onRangeChanged;

  const DateRangePickerWidget({
    required this.initialRange,
    required this.onRangeChanged,
  });

  // Preset buttons: Today, Last 7 days, Last 30 days, Last 90 days, Custom
}
```

### File: `lib/screens/admin/widgets/filter_chip_group.dart`
```dart
class FilterChipGroup extends StatefulWidget {
  final List<String> options;
  final List<String> selectedValues;
  final ValueChanged<List<String>> onChanged;

  // For filtering by: category, payment method, customer segment, etc.
}
```

### File: `lib/screens/admin/widgets/comparison_toggle.dart`
```dart
class ComparisonToggle extends StatefulWidget {
  final String currentPeriod;
  final ValueChanged<String> onPeriodChanged;

  // Options: vs Last Week, vs Last Month, vs Last Year, Off
}
```

### File: `lib/screens/admin/widgets/export_button.dart`
```dart
class ExportButton extends StatelessWidget {
  final String data;  // JSON
  final String filename;

  // Export formats: PDF, CSV, Excel
  // Share: Email, Download, Print
}
```

---

## PROVIDER ENHANCEMENTS

### File: `lib/providers/admin_provider.dart` (Enhance)
**Add Methods**:
```dart
class AdminProvider with ChangeNotifier {
  // Existing methods...

  // NEW: Order analytics
  Future<void> fetchOrderTrend(DateTimeRange range, String granularity) async {}
  Future<void> fetchOrderBreakdown(DateTimeRange range) async {}
  Future<void> fetchOrderMetrics(DateTimeRange range) async {}
  Future<void> fetchOrderForecast(int days) async {}

  // NEW: Delivery analytics
  Future<void> fetchDeliveryMetrics(DateTimeRange range) async {}
  Future<void> fetchRiderPerformance(String sortBy) async {}
  Future<void> fetchDeliveryQuality(DateTimeRange range) async {}
  Future<void> fetchBottleneckAnalysis() async {}
  Future<void> fetchDeliveryHeatmap() async {}

  // NEW: Insights
  Future<void> generateInsights() async {}
  Future<void> fetchInsightRecommendations({String? category}) async {}
  Future<void> markInsightAsActioned(String insightId) async {}
  Future<void> fetchCustomerInsights() async {}

  // NEW: Export
  Future<String> exportToPDF(String dataType, Map<String, dynamic> params) async {}
  Future<String> exportToCSV(String dataType, Map<String, dynamic> params) async {}
}
```

### File: `lib/providers/ai_insights_provider.dart` (Enhance)
**Existing partial implementation** - Complete with:
```dart
class AIInsightsProvider with ChangeNotifier {
  // ML Models
  DemandForecastModel? _demandModel;
  PriceElasticityModel? _pricingModel;
  CustomerSegmentationModel? _segmentationModel;
  ChurnPredictionModel? _churnModel;
  RecommendationEngine? _recommendationEngine;

  // Generate insights using ML
  Future<List<InsightCard>> generateInsights(ShopMetrics metrics) async {}
  Future<Map<String, dynamic>> predictDemand(String productId, int days) async {}
  Future<double> recommendPrice(String productId) async {}
  Future<List<String>> findChurnRiskCustomers() async {}
}
```

### File: `lib/providers/forecast_provider.dart` (Enhance)
**Existing partial implementation** - Complete with:
```dart
class ForecastProvider with ChangeNotifier {
  // Time series forecasting
  Future<List<ForecastPoint>> forecastOrders(int days) async {}
  Future<List<ForecastPoint>> forecastRevenue(int days) async {}
  Future<List<ForecastPoint>> forecastInventory(String productId, int days) async {}

  // Model selection (ARIMA vs Prophet vs ML)
  String selectedModel = 'auto';  // Automatically chooses best
}
```

---

## BACKEND SERVICES (Node.js/Firebase Functions)

### File: `backend/services/AnalyticsService.js` (Create)
**~500 lines**

```javascript
class AnalyticsService {
  constructor(firestore) {
    this.db = firestore;
  }

  // Order analytics
  async getOrderTrend(shopId, startDate, endDate, granularity) {
    // Query orders collection
    // Group by date/hour
    // Calculate: count, revenue, avg_order_value
    // Return time series
  }

  async getOrderBreakdown(shopId, startDate, endDate) {
    // 4 breakdowns: by payment method, time of day, category, customer segment
  }

  async getOrderMetrics(shopId, startDate, endDate) {
    // Calculate: avg order value, orders per day, peak hour, repeat customer rate
  }

  async forecastOrders(shopId, days = 7) {
    // Use Prophet or ARIMA
    // Return: daily forecast with confidence interval
  }

  // Delivery analytics
  async getDeliveryMetrics(shopId, startDate, endDate) {
    // Calculate: on_time%, avg_time, cancellation_rate, failed_rate
  }

  async getRiderPerformance(shopId, sortBy = 'rating') {
    // Query all riders for shop
    // Calculate: deliveries_completed, rating, on_time%, earnings
    // Sort by field
  }

  async getDeliveryQuality(shopId, startDate, endDate) {
    // Calculate: customer satisfaction, complaint rate, issue breakdown
  }

  async getBottleneckAnalysis(shopId) {
    // Break down delivery steps: at_shop → to_customer → next_delivery
  }

  async getDeliveryHeatmap(shopId) {
    // Geographic distribution of deliveries
    // Identify problem zones
  }

  // Helper
  async getAnalyticsCollection(collectionName) {
    // Check if pre-calculated analytics_daily exists
    // If not, calculate on-demand and cache
  }
}
```

### File: `backend/services/InsightsEngine.js` (Create)
**~400 lines**

```javascript
class InsightsEngine {
  constructor(analyticsService) {
    this.analytics = analyticsService;
    this.models = {
      demandForecast: new DemandForecastModel(),
      priceElasticity: new PriceElasticityModel(),
      customerSegmentation: new CustomerSegmentationModel(),
      churnPrediction: new ChurnPredictionModel(),
    };
  }

  async generateInsights(shopId) {
    const metrics = await this.getShopMetrics(shopId);
    const insights = [];

    // Inventory insights
    insights.push(...this.generateInventoryInsights(metrics));

    // Pricing insights
    insights.push(...this.generatePricingInsights(metrics));

    // Timing insights
    insights.push(...this.generateTimingInsights(metrics));

    // Promotion insights
    insights.push(...this.generatePromotionInsights(metrics));

    // Operations insights
    insights.push(...this.generateOperationsInsights(metrics));

    // Customer insights
    insights.push(...this.generateCustomerInsights(metrics));

    // Store in Firestore
    await this.storeInsights(shopId, insights);
    return insights;
  }

  generateInventoryInsights(metrics) {
    // For each product: calculate days of stock, sales trend
    // If stock low AND sales increasing: recommend reorder
    // If stock high AND sales low: recommend discount
  }

  generatePricingInsights(metrics) {
    // For each product: estimate price elasticity
    // If inelastic (low sensitivity): recommend price increase
    // If elastic (high sensitivity): recommend price stability
  }

  generateTimingInsights(metrics) {
    // Identify peak hours/days
    // Recommend promotion timing
  }

  generatePromotionInsights(metrics) {
    // Find slow-moving products
    // Recommend discounts/bundles
  }

  generateOperationsInsights(metrics) {
    // Analyze delivery times, rider utilization
    // Recommend hiring, staffing changes
  }

  generateCustomerInsights(metrics) {
    // Identify churn risk, VIP customers
    // Recommend retention campaigns
  }

  // ML Model wrappers
  async forecastDemand(productId, days = 7) {
    // Time series prediction using trained model
  }

  async recommendPrice(productId) {
    // Price elasticity analysis
  }

  async segmentCustomers(shopId) {
    // K-means clustering
  }

  async predictChurn(shopId) {
    // Logistic regression
  }
}
```

### File: `backend/models/ml-models.js` (Create)
**ML Model implementations**

```javascript
// 1. Demand Forecasting (Time Series)
class DemandForecastModel {
  // Input: historical daily orders
  // Output: predicted orders for next N days
  // Method: ARIMA, Prophet, or custom LSTM
  predict(historicalData, days) { }
}

// 2. Price Elasticity
class PriceElasticityModel {
  // Input: product price history + sales
  // Output: elasticity coefficient
  // Formula: % change in quantity / % change in price
  calculateElasticity(priceHistory, quantityHistory) { }
}

// 3. Customer Segmentation
class CustomerSegmentationModel {
  // Input: customer purchase history
  // Output: segments (new, returning, loyal, at_risk)
  // Method: K-means clustering on RFM metrics
  segment(customers) { }
}

// 4. Churn Prediction
class ChurnPredictionModel {
  // Input: customer behavior
  // Output: churn probability (0-1)
  // Method: Logistic regression on features
  predictChurn(customer) { }
}

// 5. Recommendation Engine
class RecommendationEngine {
  // Input: order history
  // Output: recommended actions
  // Method: Rule-based or collaborative filtering
  recommend(shopMetrics) { }
}
```

---

## FIRESTORE COLLECTIONS

**New Collections Required**:

### `analytics_daily/{shopId}/metrics`
```
{
  date: "2026-06-23",
  shopId: "shop_123",
  ordersCount: 42,
  revenue: 15000,
  avgOrderValue: 357,
  cancelledOrders: 2,
  customerCount: 35,
  repeatCustomerCount: 8,
  peakHour: "13:00",
  peakHourOrders: 12,
  avgDeliveryTime: 28,
  onTimePercentage: 0.94,
  customerRating: 4.8,
  reviewCount: 124,
  topProduct: "biryani",
  topProductCount: 28
}
```

### `insights/{shopId}/{insightId}`
```
{
  id: "insight_123",
  shopId: "shop_123",
  title: "Reorder Tomatoes",
  description: "Only 2 days of stock remaining",
  category: "inventory",
  confidence: 0.92,
  actionItems: ["Increase order by 50%"],
  status: "pending|actioned|dismissed",
  generatedAt: timestamp,
  actionsHistory: [{
    action: "actioned|dismissed",
    at: timestamp,
    note: "..."
  }]
}
```

### `insights_history/{shopId}/{date}`
```
{
  date: "2026-06-23",
  shopId: "shop_123",
  totalInsights: 12,
  insights: [InsightCard, ...]
}
```

### `delivery_zones/{shopId}/{zoneId}`
```
{
  zoneId: "zone_downtown",
  zoneName: "Downtown Area",
  coordinates: { lat, lng, radius },
  deliveryCount: 156,
  avgDeliveryTime: 25,
  cancellationRate: 0.015,
  customerSatisfaction: 4.85,
  peakHours: [
    { hour: 13, orders: 15 },
    { hour: 19, orders: 18 }
  ]
}
```

---

## API ENDPOINTS SUMMARY

**Dashboard Metrics**:
- GET /api/admin/dashboard/metrics

**Order Analytics**:
- GET /api/admin/analytics/orders/trend
- GET /api/admin/analytics/orders/breakdown
- GET /api/admin/analytics/orders/metrics
- GET /api/admin/analytics/orders/forecast

**Delivery Analytics**:
- GET /api/admin/analytics/delivery/performance
- GET /api/admin/analytics/delivery/riders
- GET /api/admin/analytics/delivery/quality
- GET /api/admin/analytics/delivery/bottleneck
- GET /api/admin/analytics/delivery/heatmap
- GET /api/admin/analytics/delivery/anomalies

**Insights**:
- POST /api/admin/insights/generate
- GET /api/admin/insights/recommendations
- POST /api/admin/insights/{id}/mark-addressed
- GET /api/admin/insights/forecast
- GET /api/admin/insights/customer-health

**Export**:
- POST /api/admin/export/pdf
- POST /api/admin/export/csv

---

## TESTING STRATEGY

### Unit Tests (~15 tests)
```dart
test('AdminProvider: fetchDashboardMetrics returns correct metrics', () async {});
test('AnalyticsService: calculatePeakHour returns correct hour', () async {});
test('InsightEngine: generateInventoryInsights identifies low stock', () async {});
test('ForecastProvider: forecastOrders returns 7-day forecast', () async {});
test('AIInsightsProvider: calculateElasticity correctly measures price sensitivity', () async {});
// ... 10 more
```

### Widget Tests (~10 tests)
```dart
testWidgets('AdminDashboardMetrics displays 8 cards', (WidgetTester tester) async {});
testWidgets('OrderTrendChart renders line chart correctly', (WidgetTester tester) async {});
testWidgets('DateRangePickerWidget opens date picker', (WidgetTester tester) async {});
testWidgets('InsightCard shows correct recommendation', (WidgetTester tester) async {});
testWidgets('ExportButton triggers PDF export', (WidgetTester tester) async {});
// ... 5 more
```

### Integration Tests (~10 tests)
```dart
testWidgets('Admin Dashboard flow: load metrics → view trends → export', (WidgetTester tester) async {});
testWidgets('Order Analytics: date range change triggers refresh', (WidgetTester tester) async {});
testWidgets('Delivery Analytics: rider filter works', (WidgetTester tester) async {});
testWidgets('Insights: mark recommendation as actioned', (WidgetTester tester) async {});
testWidgets('Real-time metrics: auto-refresh every 10 seconds', (WidgetTester tester) async {});
// ... 5 more
```

### API Tests (~10 tests via Postman/Jest)
```javascript
test('GET /api/admin/dashboard/metrics returns 8 metrics', async () => {});
test('GET /api/admin/analytics/orders/trend respects date range', async () => {});
test('POST /api/admin/insights/generate creates new insights', async () => {});
test('GET /api/admin/analytics/delivery/riders sorted correctly', async () => {});
test('Performance: /api/admin/analytics/* responds in < 500ms', async () => {});
// ... 5 more
```

---

## SUCCESS CRITERIA

✅ **Performance**
- Dashboard loads in < 2 seconds
- Metrics update every 10 seconds (real-time feel)
- All charts render without lag
- Analytics queries < 500ms

✅ **Functionality**
- 8 dashboard metrics displayed correctly
- 3 chart types working (line, pie, bar)
- Date range picker functional
- All 4 analytics screens operational
- Insights generated daily
- Export to PDF/CSV working

✅ **Quality**
- 35+ tests passing (unit + widget + integration)
- ML models predicting with 80%+ accuracy
- Zero critical bugs
- Error handling for all API calls
- Offline mode gracefully degrades

✅ **UX**
- Mobile-responsive (works on tablet)
- Intuitive navigation
- Clear data visualization
- Quick action buttons functional
- Export UI polished

---

## BUILD ORDER & TIMELINE

### Week 1 (Days 1-5): Foundation
1. Enhance AdminProvider (fetchOrderTrend, fetchDeliveryMetrics, etc.)
2. Create admin_dashboard_metrics.dart with 8 cards
3. Create supporting widgets (date picker, filters, export)
4. Backend: AnalyticsService basic methods
5. Unit tests for provider methods

**Deliverable**: Working dashboard with static data

### Week 2 (Days 6-10): Charts & Analytics
6. Create order analytics screen with 4 charts
7. Create delivery analytics screen with 6 sections
8. Backend: Complete AnalyticsService
9. API endpoints (18 total)
10. Widget + integration tests

**Deliverable**: 2 analytics screens with live data

### Week 3 (Days 11-15): Insights & ML
11. Create insights screen UI
12. Backend: InsightsEngine basic (rule-based)
13. Backend: ML models (demand forecast, price elasticity)
14. AIInsightsProvider implementation
15. Insights API endpoints

**Deliverable**: Insights generation (initial)

### Week 4 (Days 16-20): Refinement & Testing
16. Export functionality (PDF/CSV)
17. Real-time refresh logic
18. Performance optimization
19. Comprehensive testing (all 35+ tests)
20. Documentation + bugfixes

**Deliverable**: Production-ready Phase 4 complete

---

## CRITICAL DEPENDENCIES

⚠️ **Must Be Completed Before Phase 4**:
1. Unified Order Service (Phase 3)
2. Firestore security rules
3. Backend authentication

⚠️ **Optional Enhancements** (Post Phase 4):
- Weather API integration for forecasting
- Competitor price monitoring
- Multi-location analytics aggregation
- Custom metric builder
- Scheduled report generation

---

## ROLLBACK PLAN

If issues arise:
1. **Metrics fail to load**: Revert to AdminProvider.fetchDashboardMetrics()
2. **Charts render incorrectly**: Check fl_chart version in pubspec.yaml
3. **Export hangs**: Implement pagination for large datasets
4. **ML predictions inaccurate**: Fall back to rule-based insights
5. **Performance issues**: Add caching layer for analytics_daily

---

## NOTES FOR DEVELOPER

1. **Use existing providers**: AIInsightsProvider and ForecastProvider are partially implemented
2. **Charts library**: Flutter uses `fl_chart` - ensure version is compatible
3. **Real-time updates**: Use Timer.periodic for 10-second refresh
4. **Mobile first**: Responsive.useRailNav() checks for rail/drawer nav
5. **Error handling**: All API calls must have try-catch with user-friendly messages
6. **Testing**: Firestore emulator should be running for integration tests
7. **Backend**: Node.js/Firebase Functions - ensure proper error handling
8. **ML models**: Start with simple rules, upgrade to ML models iteratively

---

## ESTIMATED EFFORT BREAKDOWN

| Component | Hours | Status |
|-----------|-------|--------|
| Admin Dashboard Enhancement | 25 | Not Started |
| Order Analytics Screen | 20 | Not Started |
| Delivery Analytics Screen | 20 | Not Started |
| Business Insights Screen | 20 | Not Started |
| Backend Services | 20 | Not Started |
| ML Model Implementation | 15 | Not Started |
| Testing (unit + widget + integration) | 15 | Not Started |
| Documentation & Polish | 10 | Not Started |
| **TOTAL** | **145 hours** | |

**Note**: Total is higher than spec due to backend work breakdown. Frontend only = 85 hours.

---

## NEXT STEPS

1. Review this plan with team
2. Prioritize: Which screens first? (Recommend: Dashboard → Order Analytics → Delivery Analytics → Insights)
3. Setup backend environment (Node.js, Firebase Functions)
4. Create feature branches for parallel work
5. Establish daily standup for progress tracking

---

**Document Version**: 1.0
**Last Updated**: June 23, 2026
**Status**: Ready for Implementation
