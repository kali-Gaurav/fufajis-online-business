# PHASE 4: ADMIN ANALYTICS - EXECUTION CHECKLIST

**Status**: Ready to Start
**Total Checkpoints**: 87
**Categories**: Frontend (45), Backend (20), Testing (15), DevOps (7)

---

## SECTION 1: ADMIN DASHBOARD ENHANCEMENT (25 hours)

### 1.1 Provider Enhancement - AdminProvider

- [ ] **1.1.1** Add method: `fetchOrderTrend(DateTimeRange range, String granularity)`
  - Query orders collection with date filtering
  - Group by date/hour based on granularity
  - Calculate count, revenue, avg order value
  - Return List<DailyMetric>
  - Files: `lib/providers/admin_provider.dart`

- [ ] **1.1.2** Add method: `fetchDeliveryMetrics(DateTimeRange range)`
  - Query delivery_tasks collection
  - Calculate on_time%, avg_time, cancellation_rate, failed_rate
  - Return DeliveryMetricsModel
  - Files: `lib/providers/admin_provider.dart`

- [ ] **1.1.3** Add method: `fetchInsightRecommendations(String? category)`
  - Query insights collection
  - Filter by category if provided
  - Sort by confidence (descending)
  - Return List<InsightCard>
  - Files: `lib/providers/admin_provider.dart`

- [ ] **1.1.4** Add method: `markInsightAsActioned(String insightId)`
  - Update insights document with status='actioned'
  - Update local list
  - Notify listeners
  - Files: `lib/providers/admin_provider.dart`

- [ ] **1.1.5** Add method: `exportToPDF(String dataType, Map params)`
  - Generate PDF from data
  - Include charts, tables, metrics
  - Return file path
  - Files: `lib/providers/admin_provider.dart`

- [ ] **1.1.6** Add method: `exportToCSV(String dataType, Map params)`
  - Convert data to CSV format
  - Include headers and formatting
  - Return file path
  - Files: `lib/providers/admin_provider.dart`

- [ ] **1.1.7** Add state properties to AdminProvider
  - `List<DailyMetric> orderTrend`
  - `DeliveryMetricsModel deliveryMetrics`
  - `List<InsightCard> insights`
  - `bool isExporting`
  - Files: `lib/providers/admin_provider.dart`

### 1.2 Dashboard Metrics Widget

- [ ] **1.2.1** Create file: `lib/screens/admin/admin_dashboard_metrics.dart`
  - Stateful widget with auto-refresh timer
  - Start refresh every 10 seconds
  - Cancel timer on dispose
  - Files: Create new file

- [ ] **1.2.2** Build 8 metric cards
  - Today's Orders card (orders + revenue)
  - Pending Fulfillment card (count)
  - In Delivery card (count)
  - Today's Rating card (stars + review count)
  - Top Product card (name + count)
  - Peak Hour card (time + orders)
  - Avg Order Value card (₹)
  - Satisfaction Score card (%)
  - Files: `lib/screens/admin/admin_dashboard_metrics.dart`

- [ ] **1.2.3** Implement metric card styling
  - White background with shadow
  - Icon + color per metric
  - Responsive layout (2 columns on mobile, 4 on desktop)
  - Tap-to-drill-down functionality
  - Files: `lib/screens/admin/admin_dashboard_metrics.dart`

- [ ] **1.2.4** Add loading skeleton state
  - Show shimmer effect while loading
  - Replace with real data on success
  - Show error state with retry button
  - Files: `lib/screens/admin/admin_dashboard_metrics.dart`

### 1.3 Dashboard Charts

- [ ] **1.3.1** Create file: `lib/screens/admin/admin_dashboard_charts.dart`
  - 3 chart widgets
  - Import fl_chart package
  - Files: Create new file

- [ ] **1.3.2** Implement Orders Over Time chart (LineChart)
  - X-axis: Time (hourly or daily)
  - Y-axis: Order count
  - Touch interaction to see exact values
  - 2-color gradient
  - Files: `lib/screens/admin/admin_dashboard_charts.dart`

- [ ] **1.3.3** Implement Revenue by Payment Method chart (PieChart)
  - 4 segments: Cash, Card, UPI, Wallet
  - Show percentage labels
  - Distinct colors per method
  - Legend below chart
  - Files: `lib/screens/admin/admin_dashboard_charts.dart`

- [ ] **1.3.4** Implement Top Products chart (BarChart)
  - Top 5 products sorted descending
  - X-axis: Product names
  - Y-axis: Order count
  - Colors gradient from primary to accent
  - Files: `lib/screens/admin/admin_dashboard_charts.dart`

### 1.4 Quick Actions Widget

- [ ] **1.4.1** Create file: `lib/screens/admin/admin_dashboard_quick_actions.dart`
  - 4 action buttons in a grid
  - Files: Create new file

- [ ] **1.4.2** Implement buttons
  - "View Pending Orders" → Navigate to orders screen with filter
  - "View In-Delivery Orders" → Navigate with delivery filter
  - "Create Promo" → Navigate to coupon creation
  - "View Inventory" → Navigate to inventory management
  - Files: `lib/screens/admin/admin_dashboard_quick_actions.dart`

### 1.5 Activity Stream Widget

- [ ] **1.5.1** Create file: `lib/screens/admin/admin_dashboard_activity.dart`
  - Activity model with type enum
  - Activity items list
  - Files: Create new file

- [ ] **1.5.2** Design ActivityItem model
  - id, type, title, description, timestamp, relatedId
  - Types: order_placed, delivered, inventory_alert, new_review, cancellation
  - Files: `lib/screens/admin/admin_dashboard_activity.dart`

- [ ] **1.5.3** Implement activity feed UI
  - Timeline-style list
  - Icons per activity type
  - Timestamps (relative: "5 mins ago")
  - Tap to navigate to related entity
  - Files: `lib/screens/admin/admin_dashboard_activity.dart`

---

## SECTION 2: ORDER ANALYTICS SCREEN (20 hours)

### 2.1 Create Order Analytics Screen

- [ ] **2.1.1** Create file: `lib/screens/admin/analytics_orders_screen.dart`
  - Stateful widget
  - Call fetchOrderTrend on init
  - Files: Create new file

- [ ] **2.1.2** Build date range picker section
  - Default: Last 7 days
  - Preset buttons: Today, 7 days, 30 days, 90 days, Custom
  - Trigger refresh on range change
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

### 2.2 Trend Section (Line Charts)

- [ ] **2.2.1** Build Orders Over Time chart
  - Use existing provider data
  - Show hourly/daily based on granularity
  - Interactive touch for values
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

- [ ] **2.2.2** Build Average Order Value trend chart
  - Line chart showing daily average
  - Highlight peak and low days
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

- [ ] **2.2.3** Build Conversion Rate chart
  - Show: Browse → Add to Cart → Checkout → Success rates
  - Funnel visualization or line chart
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

- [ ] **2.2.4** Build Cancellation Rate trend
  - Line chart showing daily cancellation %
  - Alert if > 5%
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

### 2.3 Breakdown Section (Pie/Bar Charts)

- [ ] **2.3.1** Build payment method breakdown
  - Pie chart: Cash vs Card vs UPI vs Wallet
  - Show counts and percentages
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

- [ ] **2.3.2** Build time-of-day breakdown
  - Bar chart: Breakfast (6-9) vs Lunch (12-2) vs Dinner (7-10) vs Late (10+)
  - Show order counts per period
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

- [ ] **2.3.3** Build category breakdown
  - Pie chart: Orders by product category
  - Top 5 categories
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

- [ ] **2.3.4** Build customer segment breakdown
  - Pie chart: New vs Returning vs Loyal
  - Show percentages
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

### 2.4 Key Metrics Section

- [ ] **2.4.1** Display 6 key metrics
  - Avg order value: ₹350
  - Orders per day: 45
  - Peak hour: "1-2 PM - 12 orders"
  - Repeat customer rate: 42%
  - Customer lifetime value: ₹2,500
  - Churn rate: 5% monthly
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

- [ ] **2.4.2** Implement metric cards
  - Grid layout (2 or 3 columns)
  - Icon + color per metric
  - Display in easy-to-read format
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

### 2.5 Forecasting Section

- [ ] **2.5.1** Display 4-week forecast
  - Expected orders tomorrow with ±5 confidence interval
  - Expected revenue with ±₹1,500 interval
  - Confidence score (%)
  - Trending indicator (↑ ↓ →)
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

- [ ] **2.5.2** Implement forecast visualization
  - Bar chart or area chart
  - Show actual vs predicted
  - Confidence interval as shaded area
  - Files: `lib/screens/admin/analytics_orders_screen.dart`

---

## SECTION 3: DELIVERY ANALYTICS SCREEN (20 hours)

### 3.1 Create Delivery Analytics Screen

- [ ] **3.1.1** Create file: `lib/screens/admin/analytics_delivery_screen.dart`
  - Stateful widget
  - Call fetchDeliveryMetrics on init
  - Files: Create new file

### 3.2 Performance Metrics Section

- [ ] **3.2.1** Display 4 KPI cards
  - On-time delivery %: 94% (green if ≥90%)
  - Avg delivery time: 28 minutes
  - Cancellation rate: 2% (red if >5%)
  - Failed deliveries: 1.5% (red if >3%)
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

- [ ] **3.2.2** Implement KPI card styling
  - Large font for number
  - Color coding (green/yellow/red)
  - Trend indicator
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

### 3.3 Rider Leaderboard Section

- [ ] **3.3.1** Create RiderPerformanceItem model
  - riderId, riderName, completedDeliveries, rating, onTimePercentage, earnings, lastDelivery
  - Files: `lib/models/rider_performance_model.dart`

- [ ] **3.3.2** Build rider leaderboard table
  - Sortable by: Rating, On-Time %, Deliveries
  - Show top 10 riders
  - Include earnings to date
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

- [ ] **3.3.3** Implement rider detail tap
  - Show individual rider stats
  - Delivery history
  - Customer feedback
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

### 3.4 Quality Metrics Section

- [ ] **3.4.1** Display quality KPIs
  - Customer satisfaction: 4.8/5.0
  - Complaint rate: 1.2%
  - Positive feedback %: 87%
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

- [ ] **3.4.2** Build issue breakdown chart
  - Pie chart: Photo damage (40%) vs Late (35%) vs Other (25%)
  - Show counts and percentages
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

### 3.5 Bottleneck Analysis Section

- [ ] **3.5.1** Display 3 time metrics
  - Avg time at shop: 5 min
  - Avg time to customer: 23 min
  - Avg time between deliveries: 3 min
  - Identify slowest step
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

- [ ] **3.5.2** Implement waterfall chart
  - Show delivery journey stages
  - Time spent at each step
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

### 3.6 Geographic Heatmap Section

- [ ] **3.6.1** Display delivery zones
  - Zone list with metrics
  - Delivery count per zone
  - Cancellation rate per zone
  - Avg delivery time per zone
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

- [ ] **3.6.2** Build zone selector and stats
  - Tap zone to see details
  - Peak hours for that zone
  - Problem indicators
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

### 3.7 Anomaly Alerts Section

- [ ] **3.7.1** Display alerts
  - Red alert if on-time % < 90%
  - Yellow alert if complaint rate > 2%
  - Yellow alert if avg time > +10%
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

- [ ] **3.7.2** Implement alert styling
  - Color-coded by severity
  - Icon + message
  - Metric name + current value
  - Files: `lib/screens/admin/analytics_delivery_screen.dart`

---

## SECTION 4: BUSINESS INSIGHTS SCREEN (20 hours)

### 4.1 Create Insights Screen

- [ ] **4.1.1** Create file: `lib/screens/admin/analytics_insights_screen.dart`
  - Stateful widget
  - Call generateInsights on init
  - Files: Create new file

### 4.2 Recommendations Section

- [ ] **4.2.1** Create InsightCard model
  - id, title, description, category, confidence, actionItems, isActioned, generatedAt
  - Categories: inventory, pricing, timing, promotion, operations, customer
  - Files: `lib/models/insight_card_model.dart`

- [ ] **4.2.2** Build recommendation cards
  - Display 6-8 recommendations
  - Sort by confidence (descending)
  - Color per category
  - Files: `lib/screens/admin/analytics_insights_screen.dart`

- [ ] **4.2.3** Implement action button
  - "Mark as Actioned" button on each card
  - Show checkmark when actioned
  - Dim/hide completed recommendations
  - Files: `lib/screens/admin/analytics_insights_screen.dart`

- [ ] **4.2.4** Add category filter
  - Filter buttons: All, Inventory, Pricing, Timing, Promotion, Operations, Customer
  - Update list on filter change
  - Files: `lib/screens/admin/analytics_insights_screen.dart`

### 4.3 Forecasting Panel

- [ ] **4.3.1** Display forecast insights
  - Expected peak order day: "Friday 1-2 PM"
  - Expected low day: "Wednesday 3-4 PM"
  - Inventory shortage risk: Medium/Low/High with date
  - Weather impact: Show rainy/sunny forecast effect on orders
  - Files: `lib/screens/admin/analytics_insights_screen.dart`

- [ ] **4.3.2** Implement forecast cards
  - Visual cards with icons
  - Trend indicators
  - Actionable recommendations
  - Files: `lib/screens/admin/analytics_insights_screen.dart`

### 4.4 Customer Insights Section

- [ ] **4.4.1** Display 4 customer metrics
  - Customer lifetime value: ₹2,500 avg
  - Churn risk: 5 customers (list with names)
  - VIP customers: 20 (top spenders)
  - New customer rate: 8%
  - Files: `lib/screens/admin/analytics_insights_screen.dart`

- [ ] **4.4.2** Implement customer cards
  - Metric cards with navigation
  - Click to see customer list
  - Contact/outreach options
  - Files: `lib/screens/admin/analytics_insights_screen.dart`

### 4.5 Competitive Analysis Section (Optional)

- [ ] **4.5.1** Display competitive insights
  - Price comparison: "12% more expensive than competitor X"
  - Delivery advantage: "5 min faster delivery"
  - Review position: "You're #2 in your area"
  - Files: `lib/screens/admin/analytics_insights_screen.dart`

---

## SECTION 5: SUPPORTING WIDGETS

### 5.1 Date Range Picker Widget

- [ ] **5.1.1** Create file: `lib/screens/admin/widgets/date_range_picker_widget.dart`
  - Stateful widget
  - Preset buttons: Today, Last 7 days, Last 30 days, Last 90 days, Custom
  - Show selected range
  - Callback on range change
  - Files: Create new file

- [ ] **5.1.2** Implement custom date range picker
  - Use showDateRangePicker()
  - Format dates nicely
  - Files: `lib/screens/admin/widgets/date_range_picker_widget.dart`

### 5.2 Filter Chip Group Widget

- [ ] **5.2.1** Create file: `lib/screens/admin/widgets/filter_chip_group.dart`
  - Stateful widget
  - Multiple chip options
  - Multi-select capability
  - Callback on change
  - Files: Create new file

- [ ] **5.2.2** Implement chip styling
  - Selected vs unselected state
  - Color per filter type
  - Wrapping layout
  - Files: `lib/screens/admin/widgets/filter_chip_group.dart`

### 5.3 Comparison Toggle Widget

- [ ] **5.3.1** Create file: `lib/screens/admin/widgets/comparison_toggle.dart`
  - Stateful widget
  - Options: vs Last Week, vs Last Month, vs Last Year, Off
  - Show comparison side-by-side
  - Callback on toggle
  - Files: Create new file

### 5.4 Export Button Widget

- [ ] **5.4.1** Create file: `lib/screens/admin/widgets/export_button.dart`
  - Stateless widget
  - Dropdown: PDF, CSV, Excel
  - Show "Exporting..." state
  - Success/error feedback
  - Share options
  - Files: Create new file

- [ ] **5.4.2** Implement export logic
  - Call provider.exportToPDF()
  - Call provider.exportToCSV()
  - Show file saved notification
  - Files: `lib/screens/admin/widgets/export_button.dart`

---

## SECTION 6: BACKEND API ENDPOINTS (20 hours)

### 6.1 Setup Backend Structure

- [ ] **6.1.1** Create file: `backend/services/AnalyticsService.js`
  - Class with Firestore instance
  - Methods for all analytics queries
  - Caching layer for performance
  - Files: Create new file

- [ ] **6.1.2** Create file: `backend/services/InsightsEngine.js`
  - Class with analytics service dependency
  - Methods for insight generation
  - ML model integrations
  - Files: Create new file

### 6.2 Dashboard Metrics Endpoint

- [ ] **6.2.1** Implement `GET /api/admin/dashboard/metrics`
  - Query parameters: shopId (optional), startDate, endDate
  - Return 8 metrics
  - Response time: < 200ms
  - Files: `backend/routes/admin-analytics.js`

### 6.3 Order Analytics Endpoints

- [ ] **6.3.1** Implement `GET /api/admin/analytics/orders/trend`
  - Parameters: shopId, startDate, endDate, granularity
  - Return: list of {date, orderCount, revenue, avgOrderValue}
  - Response time: < 500ms
  - Files: `backend/routes/admin-analytics.js`

- [ ] **6.3.2** Implement `GET /api/admin/analytics/orders/breakdown`
  - Parameters: shopId, startDate, endDate
  - Return: 4 breakdowns (payment, time, category, segment)
  - Response time: < 500ms
  - Files: `backend/routes/admin-analytics.js`

- [ ] **6.3.3** Implement `GET /api/admin/analytics/orders/metrics`
  - Parameters: shopId, startDate, endDate
  - Return: 6 key metrics
  - Response time: < 200ms
  - Files: `backend/routes/admin-analytics.js`

- [ ] **6.3.4** Implement `GET /api/admin/analytics/orders/forecast`
  - Parameters: shopId, days (default 7)
  - Return: list of {date, expectedOrders, expectedRevenue, confidence}
  - Response time: < 1000ms
  - Files: `backend/routes/admin-analytics.js`

### 6.4 Delivery Analytics Endpoints

- [ ] **6.4.1** Implement `GET /api/admin/analytics/delivery/performance`
  - Parameters: shopId, startDate, endDate
  - Return: 4 KPIs
  - Files: `backend/routes/admin-analytics.js`

- [ ] **6.4.2** Implement `GET /api/admin/analytics/delivery/riders`
  - Parameters: shopId, sortBy
  - Return: sorted rider list
  - Files: `backend/routes/admin-analytics.js`

- [ ] **6.4.3** Implement `GET /api/admin/analytics/delivery/quality`
  - Parameters: shopId, startDate, endDate
  - Return: quality metrics
  - Files: `backend/routes/admin-analytics.js`

- [ ] **6.4.4** Implement `GET /api/admin/analytics/delivery/bottleneck`
  - Parameters: shopId
  - Return: 3 time metrics
  - Files: `backend/routes/admin-analytics.js`

- [ ] **6.4.5** Implement `GET /api/admin/analytics/delivery/heatmap`
  - Parameters: shopId
  - Return: zones with metrics
  - Files: `backend/routes/admin-analytics.js`

- [ ] **6.4.6** Implement `GET /api/admin/analytics/delivery/anomalies`
  - Parameters: shopId
  - Return: alerts list
  - Files: `backend/routes/admin-analytics.js`

### 6.5 Insights Endpoints

- [ ] **6.5.1** Implement `POST /api/admin/insights/generate`
  - Parameters: shopId (body)
  - Call InsightsEngine.generateInsights()
  - Store in Firestore
  - Return: insights list
  - Files: `backend/routes/admin-insights.js`

- [ ] **6.5.2** Implement `GET /api/admin/insights/recommendations`
  - Parameters: shopId, category (optional)
  - Return: filtered insights
  - Files: `backend/routes/admin-insights.js`

- [ ] **6.5.3** Implement `POST /api/admin/insights/{id}/mark-addressed`
  - Parameters: shopId, insightId (body)
  - Update status to 'actioned'
  - Return: success
  - Files: `backend/routes/admin-insights.js`

- [ ] **6.5.4** Implement `GET /api/admin/insights/forecast`
  - Parameters: shopId, days (default 7)
  - Return: forecast insights
  - Files: `backend/routes/admin-insights.js`

- [ ] **6.5.5** Implement `GET /api/admin/insights/customer-health`
  - Parameters: shopId
  - Return: customer metrics
  - Files: `backend/routes/admin-insights.js`

### 6.6 Export Endpoints

- [ ] **6.6.1** Implement `POST /api/admin/export/pdf`
  - Parameters: dataType, dateRange, filters (body)
  - Generate PDF file
  - Return: file URL
  - Files: `backend/routes/admin-export.js`

- [ ] **6.6.2** Implement `POST /api/admin/export/csv`
  - Parameters: dataType, dateRange, filters (body)
  - Generate CSV file
  - Return: file URL
  - Files: `backend/routes/admin-export.js`

---

## SECTION 7: ML MODEL IMPLEMENTATION (15 hours)

### 7.1 Demand Forecasting Model

- [ ] **7.1.1** Create file: `backend/ml-models/DemandForecastModel.js`
  - Input: Historical daily orders
  - Output: 7-day forecast with confidence intervals
  - Method: ARIMA or Prophet
  - Files: Create new file

- [ ] **7.1.2** Train demand model
  - Use last 90 days of data
  - Validate on last 2 weeks
  - Accuracy: 80%+
  - Files: `backend/ml-models/DemandForecastModel.js`

### 7.2 Price Elasticity Model

- [ ] **7.2.1** Create file: `backend/ml-models/PriceElasticityModel.js`
  - Input: Product price history + sales
  - Output: Elasticity coefficient
  - Formula: % change in quantity / % change in price
  - Files: Create new file

- [ ] **7.2.2** Implement price recommendation
  - Calculate elasticity per product
  - If elasticity < -0.5: recommend price increase
  - Files: `backend/ml-models/PriceElasticityModel.js`

### 7.3 Customer Segmentation Model

- [ ] **7.3.1** Create file: `backend/ml-models/CustomerSegmentationModel.js`
  - Input: Customer purchase history
  - Output: Segments (new, returning, loyal, at_risk)
  - Method: K-means on RFM metrics
  - Files: Create new file

- [ ] **7.3.2** Define RFM metrics
  - Recency: Days since last purchase
  - Frequency: Number of orders
  - Monetary: Total spent
  - Files: `backend/ml-models/CustomerSegmentationModel.js`

### 7.4 Churn Prediction Model

- [ ] **7.4.1** Create file: `backend/ml-models/ChurnPredictionModel.js`
  - Input: Customer behavior
  - Output: Churn probability (0-1)
  - Method: Logistic regression
  - Files: Create new file

- [ ] **7.4.2** Define churn features
  - Days since last order
  - Order frequency trend
  - Avg order value trend
  - Review count trend
  - Files: `backend/ml-models/ChurnPredictionModel.js`

### 7.5 Recommendation Engine

- [ ] **7.5.1** Create file: `backend/ml-models/RecommendationEngine.js`
  - Input: Shop metrics
  - Output: List of recommended actions
  - Methods: Rule-based + ML predictions
  - Files: Create new file

- [ ] **7.5.2** Implement rule-based insights
  - Low stock + increasing sales → Reorder
  - High stock + decreasing sales → Discount
  - Peak hour identified → Staffing recommendation
  - Files: `backend/ml-models/RecommendationEngine.js`

---

## SECTION 8: FIRESTORE COLLECTIONS (7 hours)

### 8.1 Create Analytics Collections

- [ ] **8.1.1** Create `analytics_daily/{shopId}/metrics` collection
  - Document per day
  - Fields: date, ordersCount, revenue, avgOrderValue, etc.
  - TTL: 2 years
  - Files: Firestore console

- [ ] **8.1.2** Create `insights/{shopId}/{insightId}` collection
  - Document per insight
  - Fields: id, title, description, category, confidence, etc.
  - TTL: 90 days
  - Files: Firestore console

- [ ] **8.1.3** Create `insights_history/{shopId}/{date}` collection
  - Daily snapshot of all insights
  - For historical tracking
  - TTL: 1 year
  - Files: Firestore console

- [ ] **8.1.4** Create `delivery_zones/{shopId}/{zoneId}` collection
  - Zone metadata
  - Fields: zoneName, coordinates, metrics
  - Files: Firestore console

### 8.2 Add Indexes

- [ ] **8.2.1** Create index: `orders(shopId, createdAt)`
  - For efficient date-range queries
  - Files: Firestore console

- [ ] **8.2.2** Create index: `delivery_tasks(shopId, status, createdAt)`
  - For delivery analytics queries
  - Files: Firestore console

- [ ] **8.2.3** Create index: `reviews(shopId, rating)`
  - For rating aggregation
  - Files: Firestore console

---

## SECTION 9: TESTING (15 hours)

### 9.1 Unit Tests

- [ ] **9.1.1** Test `AdminProvider.fetchOrderTrend()`
  - Mocks Firestore
  - Verifies correct grouping by date
  - File: `test/providers/admin_provider_test.dart`

- [ ] **9.1.2** Test `AdminProvider.fetchDeliveryMetrics()`
  - Mocks Firestore
  - Verifies correct calculations
  - File: `test/providers/admin_provider_test.dart`

- [ ] **9.1.3** Test `AIInsightsProvider.generateInsights()`
  - Verifies insights generation logic
  - File: `test/providers/ai_insights_provider_test.dart`

- [ ] **9.1.4** Test `ForecastProvider.forecastOrders()`
  - Verifies forecast accuracy > 80%
  - File: `test/providers/forecast_provider_test.dart`

- [ ] **9.1.5** Test ML models (5 tests)
  - DemandForecast accuracy
  - PriceElasticity calculation
  - CustomerSegmentation clustering
  - ChurnPrediction classification
  - RecommendationEngine rule execution
  - File: `test/backend/ml-models-test.js`

- [ ] **9.1.6** Additional unit tests (5 more)
  - Total: 15 unit tests
  - Files: `test/` directory

### 9.2 Widget Tests

- [ ] **9.2.1** Test `AdminDashboardMetrics` widget
  - Verifies 8 cards render
  - Verifies tap navigation
  - File: `test/widgets/admin_dashboard_metrics_test.dart`

- [ ] **9.2.2** Test chart widgets
  - Orders over time chart renders
  - Revenue pie chart renders
  - Top products bar chart renders
  - File: `test/widgets/admin_dashboard_charts_test.dart`

- [ ] **9.2.3** Test `DateRangePickerWidget`
  - Opens date picker
  - Applies preset ranges
  - Notifies on change
  - File: `test/widgets/date_range_picker_widget_test.dart`

- [ ] **9.2.4** Test `FilterChipGroup`
  - Selects/deselects chips
  - Notifies on change
  - File: `test/widgets/filter_chip_group_test.dart`

- [ ] **9.2.5** Test `ExportButton`
  - Triggers export
  - Shows progress
  - Shows success message
  - File: `test/widgets/export_button_test.dart`

- [ ] **9.2.6** Test screens (5 more)
  - Total: 10 widget tests
  - Files: `test/widgets/` directory

### 9.3 Integration Tests

- [ ] **9.3.1** Test admin dashboard flow
  - Load metrics → Display cards → Refresh every 10 seconds
  - File: `integration_test/admin_dashboard_flow_test.dart`

- [ ] **9.3.2** Test order analytics flow
  - Open screen → Change date range → Charts update
  - File: `integration_test/order_analytics_flow_test.dart`

- [ ] **9.3.3** Test delivery analytics flow
  - Open screen → Filter riders → See leaderboard
  - File: `integration_test/delivery_analytics_flow_test.dart`

- [ ] **9.3.4** Test insights flow
  - Generate insights → Mark as actioned → Dismiss
  - File: `integration_test/insights_flow_test.dart`

- [ ] **9.3.5** Test export flow
  - Select data → Export to PDF → Download succeeds
  - File: `integration_test/export_flow_test.dart`

- [ ] **9.3.6** Additional integration tests (5 more)
  - Total: 10 integration tests
  - Files: `integration_test/` directory

### 9.4 API Tests

- [ ] **9.4.1** Test `GET /api/admin/dashboard/metrics`
  - Returns 8 metrics
  - Response < 200ms
  - File: `backend/tests/api.test.js`

- [ ] **9.4.2** Test `GET /api/admin/analytics/orders/trend`
  - Respects date range
  - Returns correct granularity
  - Response < 500ms
  - File: `backend/tests/api.test.js`

- [ ] **9.4.3** Test `POST /api/admin/insights/generate`
  - Creates new insights
  - Stores in Firestore
  - Returns insights list
  - File: `backend/tests/api.test.js`

- [ ] **9.4.4** Test `GET /api/admin/analytics/delivery/riders`
  - Sorts correctly
  - Returns rider list
  - File: `backend/tests/api.test.js`

- [ ] **9.4.5** Test `POST /api/admin/export/pdf`
  - Generates PDF file
  - Returns file URL
  - File: `backend/tests/api.test.js`

- [ ] **9.4.6** Performance test
  - All analytics endpoints < 500ms
  - Dashboard metrics < 200ms
  - File: `backend/tests/performance.test.js`

- [ ] **9.4.7-9.4.10** Additional API tests (4 more)
  - Total: 10 API tests
  - Files: `backend/tests/` directory

---

## SECTION 10: DOCUMENTATION (5 hours)

### 10.1 Code Documentation

- [ ] **10.1.1** Document AdminProvider methods
  - JSDoc comments
  - Parameter descriptions
  - Return type documentation
  - Files: `lib/providers/admin_provider.dart`

- [ ] **10.1.2** Document screen widgets
  - Class descriptions
  - Widget purpose and usage
  - Files: `lib/screens/admin/*.dart`

- [ ] **10.1.3** Document backend services
  - Method descriptions
  - Database queries explained
  - Files: `backend/services/*.js`

### 10.2 API Documentation

- [ ] **10.2.1** Create Postman collection
  - Import all 18 endpoints
  - Set up variables (shopId, dates)
  - Create example requests/responses
  - Files: `docs/Fufaji-Analytics-API.postman_collection.json`

- [ ] **10.2.2** Create API markdown docs
  - Endpoint descriptions
  - Query parameters
  - Response schemas
  - Example payloads
  - Files: `docs/ADMIN_ANALYTICS_API.md`

### 10.3 User Guide

- [ ] **10.3.1** Create admin dashboard user guide
  - How to read metrics
  - How to drill down
  - How to export
  - Files: `docs/ADMIN_DASHBOARD_USER_GUIDE.md`

- [ ] **10.3.2** Create analytics user guide
  - How to filter by date range
  - How to interpret charts
  - How to use insights
  - Files: `docs/ANALYTICS_USER_GUIDE.md`

---

## SECTION 11: DEPLOYMENT & DEVOPS (7 hours)

### 11.1 Frontend Deployment

- [ ] **11.1.1** Build APK for testing
  - `flutter build apk --release`
  - Verify all screens render correctly
  - Files: `build/app/outputs/apk/`

- [ ] **11.1.2** Test on multiple devices
  - Phone (mobile view)
  - Tablet (responsive view)
  - Verify all features work
  - Files: Android devices

### 11.2 Backend Deployment

- [ ] **11.2.1** Deploy AnalyticsService
  - Firebase Functions deployment
  - `firebase deploy --only functions`
  - Verify endpoints working
  - Files: `backend/`

- [ ] **11.2.2** Deploy InsightsEngine
  - Firebase Functions deployment
  - Scheduled function for daily generation
  - Verify insights created daily
  - Files: `backend/`

### 11.3 Database Deployment

- [ ] **11.3.1** Create Firestore indexes
  - Deploy via Firebase CLI
  - Verify indexes created
  - Files: `firestore.indexes.json`

- [ ] **11.3.2** Deploy Firestore rules
  - Update security rules for analytics collections
  - Test rule sets before deploying
  - Files: `firestore.rules`

### 11.4 Monitoring Setup

- [ ] **11.4.1** Setup analytics monitoring
  - Firebase Performance Monitoring
  - Custom metrics for API response times
  - Files: `monitoring/`

- [ ] **11.4.2** Setup error tracking
  - Firebase Crashlytics
  - Backend error logging
  - Files: `monitoring/`

- [ ] **11.4.3** Create alerts
  - Alert if API response time > 500ms
  - Alert if error rate > 5%
  - Alert if insights generation fails
  - Files: `monitoring/alerts-config.json`

---

## FINAL VERIFICATION CHECKLIST

### Before Marking Complete

- [ ] **Final Check 1**: All 45 frontend files created/modified
- [ ] **Final Check 2**: All 20 backend endpoints implemented
- [ ] **Final Check 3**: All 15 test files created and passing
- [ ] **Final Check 4**: All 7 ML models implemented
- [ ] **Final Check 5**: All 4 Firestore collections created
- [ ] **Final Check 6**: Documentation complete
- [ ] **Final Check 7**: Deployed to production Firebase
- [ ] **Final Check 8**: APK tested on real devices
- [ ] **Final Check 9**: All 8 dashboard metrics displaying correctly
- [ ] **Final Check 10**: Real-time refresh working (10-second intervals)

---

## NOTES

- **Dependencies**: Ensure pubspec.yaml has latest fl_chart, provider, go_router
- **Backend**: Node.js + Firebase Functions required
- **Testing**: Use Firestore emulator for local testing
- **Performance**: Analytics queries should be cached for < 500ms response time
- **ML Models**: Start with rule-based, upgrade to ML iteratively
- **Mobile**: Test on both phone and tablet for responsive layout

---

**Total Checkpoints**: 87
**Completed**: 0
**Remaining**: 87

**Estimated Time**: 85 hours
**Start Date**: (To be filled)
**End Date**: (To be filled)

---

**Version**: 1.0
**Last Updated**: June 23, 2026
**Status**: Ready for Execution
