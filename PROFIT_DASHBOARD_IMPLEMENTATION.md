# Profit Calculation Dashboard Implementation

## Overview

This document describes the implementation of the **Profit Calculation Dashboard** for Fufaji Store shopkeepers. This feature provides critical financial insights by calculating and displaying comprehensive profit metrics in real-time.

## Files Created

### 1. **profit_service.dart** (`lib/services/profit_service.dart`)
Core service for profit calculation logic.

#### Key Classes:

**ProfitMetrics** - Data class containing calculated profit metrics:
- `grossRevenue` - Total revenue from all orders in the date range
- `cogs` - Cost of Goods Sold (calculated from product costPrice)
- `refunds` - Total refund amount for returned/refunded orders
- `commissions` - Platform commission (10% of gross revenue)
- `netProfit` - Final profit: Gross Revenue - COGS - Commission - Refunds
- `profitMarginPercentage` - Profit margin %: (Net Profit / Gross Revenue) * 100
- `ordersProcessed` - Number of delivered orders in the range
- `startDate` / `endDate` - Date range for the calculation

**ProfitService** - Main service class with the following methods:

#### `calculateProfitMetrics(shopId, {startDate, endDate, platformCommissionPercent})`
Calculates comprehensive profit metrics for a shop within a date range.

**Parameters:**
- `shopId` (String) - The shop to calculate profit for
- `startDate` (DateTime) - Start of date range (inclusive)
- `endDate` (DateTime) - End of date range (inclusive)
- `platformCommissionPercent` (double) - Default: 10%

**Returns:** `Future<ProfitMetrics>`

**Process:**
1. Fetches all delivered orders from Firestore for the shop in the date range
2. Calculates gross revenue from order totalAmount
3. Calculates total COGS by:
   - Fetching product documents for each item
   - Summing: `quantity × costPrice` for all items
4. Calculates refunds from orders with `refunded` status
5. Calculates platform commission: `grossRevenue × (10 / 100)`
6. Calculates net profit: `grossRevenue - cogs - commissions - refunds`
7. Calculates profit margin %: `(netProfit / grossRevenue) × 100`

#### `getProfitMetricsForRange(shopId, range)`
Convenience method for common date ranges.

**Parameters:**
- `shopId` (String)
- `range` (String) - One of: 'today', 'week', 'month', 'year', 'all'

**Returns:** `Future<ProfitMetrics>`

### 2. **profit_dashboard_screen.dart** (`lib/screens/owner/profit_dashboard_screen.dart`)
UI screen displaying profit metrics to the shopkeeper.

#### Features:
- **Date Range Selector** - Dropdown to select: Today, This Week, This Month, This Year, All Time
- **Responsive Layout** - Works on all screen sizes
- **Real-time Calculations** - Refreshes on demand
- **Error Handling** - Graceful error messages and retry options
- **Pull-to-Refresh** - Users can refresh metrics
- **Loading States** - Clear loading indicators

#### Display Sections:

1. **Gross Revenue Card**
   - Shows total revenue earned
   - Display: "₹X" formatted in Indian rupees
   - Icon: trending_up
   - Color: Info (blue)

2. **Cost of Goods Sold (COGS) Card**
   - Shows total product cost
   - Display: "-₹Y" (shown as negative deduction)
   - Icon: production_quantity_limits
   - Color: Warning (amber)

3. **Platform Commission Card**
   - Shows 10% platform commission deducted
   - Explains: "10% of gross revenue"
   - Display: "-₹Z"
   - Icon: percent
   - Color: Grey

4. **Refunds Card** (conditional - only shown if refunds > 0)
   - Shows total refund amount
   - Display: "-₹W"
   - Icon: undo
   - Color: Error (red)

5. **NET PROFIT Card** (highlighted)
   - Central display of profit
   - Large, bold text
   - Color-coded:
     - GREEN if positive (profit)
     - RED if negative (loss)
   - Includes status: "Profitable" or "Loss"

6. **Profit Margin Card**
   - Shows profit margin percentage
   - Display: "X.XX%"
   - Calculation: `(Net Profit / Gross Revenue) × 100`
   - Color-coded like net profit

7. **Date Range Info Footer**
   - Shows exact date range
   - Shows number of orders processed

#### Data Retrieval:
1. Gets current Firebase user
2. Retrieves shopId from:
   - Custom claims (preferred)
   - owners collection (fallback)
   - shops collection (final fallback)
3. Queries orders based on selected date range

#### Error Handling:
- No logged-in user → "You are not logged in. Please login again."
- No shop found → "Unable to find your shop. Please contact support."
- Data fetch errors → Shows error message with retry button

---

## Calculation Logic

### Example: Basic Test Case (from Requirements)

**Input:**
- Order revenue: ₹100
- Product cost: ₹30 (30% of selling price)
- Refund: ₹10
- Platform commission: 10%

**Calculation:**
```
Gross Revenue:       ₹100
Less: COGS          -₹30   (cost to acquire product)
Less: Commission    -₹10   (10% of ₹100)
Less: Refunds       -₹10   (customer refund)
────────────────────────
NET PROFIT:          ₹50

Profit Margin = (50 / 100) × 100 = 50%
```

### Multiple Orders Example

**Orders:**
1. Order A: ₹100 revenue, ₹30 COGS → Profit: ₹70
2. Order B: ₹200 revenue, ₹60 COGS → Profit: ₹140
3. Order C: ₹200 revenue (refunded), ₹60 COGS

**Calculation:**
```
Gross Revenue (A+B+C): ₹500
COGS (30+60+60):       -₹150
Commission (10%):      -₹50
Refunds (Order C):     -₹200
────────────────────────
NET PROFIT:            ₹100

Profit Margin = (100 / 500) × 100 = 20%
```

---

## Firestore Data Structure

### Orders Collection
```firestore
orders/{orderId}
├── id: string
├── orderNumber: string
├── shopId: string
├── totalAmount: number (₹)
├── refundAmount: number
├── status: enum (OrderStatus.delivered, .refunded, etc.)
├── items: array
│   └── [0]
│       ├── productId: string
│       └── quantity: number
└── createdAt: timestamp
```

### Products Collection
```firestore
products/{productId}
├── id: string
├── name: string
├── price: number
├── costPrice: number ← Used for COGS calculation
├── shopId: string
└── ...other fields
```

---

## Feature Highlights

### 1. **Comprehensive Financial View**
- All profit-related metrics on one screen
- Clear breakdown of revenue sources and deductions
- No hidden calculations

### 2. **Accurate COGS Calculation**
- Fetches actual product cost from Firestore
- Multiplies by quantity for each order
- Handles missing cost prices gracefully (defaults to 0)

### 3. **Real-time Updates**
- Pull-to-refresh capability
- Fresh data on date range change
- Loading states during calculation

### 4. **Date Range Flexibility**
- Today's profit
- Weekly performance
- Monthly analysis
- Yearly trend
- All-time statistics

### 5. **Profit Margin Analysis**
- Automatic percentage calculation
- Visual indication of profitability
- Helps identify pricing strategy effectiveness

---

## Usage

### Navigate to Profit Dashboard

From Owner Dashboard, add a navigation link:
```dart
ListTile(
  title: const Text('Profit Dashboard'),
  subtitle: const Text('View profit analytics'),
  leading: const Icon(Icons.analytics),
  onTap: () => context.push('/owner/profit-dashboard'),
)
```

### Integrate with Go Router

```dart
GoRoute(
  path: 'profit-dashboard',
  name: 'profitDashboard',
  builder: (context, state) => const ProfitDashboardScreen(),
)
```

### Programmatic Access

```dart
final profitService = ProfitService();

// Get monthly profit
final metrics = await profitService.getProfitMetricsForRange(
  'shop_123',
  'month',
);

print('Net Profit: ₹${metrics.netProfit}');
print('Profit Margin: ${metrics.profitMarginPercentage}%');
```

---

## Testing

### Test Data File
See `profit_service_test_data.dart` for predefined test cases:

1. **Basic Test Case**
   - Expected: ₹50 profit, 50% margin
   - Single order with refund

2. **Multi-Item Complex Case**
   - Expected: ₹250 profit, 50% margin
   - Multiple items, multiple orders, one refund

3. **Zero Revenue Case**
   - No orders in range
   - All metrics: 0

4. **Negative Profit Case (Loss)**
   - High COGS (80%) with commission
   - Expected: ₹10 profit, 10% margin

5. **High Margin Case**
   - Low COGS (10%)
   - Expected: ₹800 profit, 80% margin

### Running Tests

```dart
void testProfitCalculation() {
  final service = ProfitService();
  
  // Test with basicTestCase
  final result = await service.calculateProfitMetrics(
    'shop_test_001',
    startDate: DateTime.now().subtract(Duration(days: 30)),
    endDate: DateTime.now(),
  );
  
  assert(result.netProfit == 50.0);
  assert(result.profitMarginPercentage == 50.0);
}
```

---

## Key Design Decisions

### 1. **Only Delivered Orders Count**
- Only `OrderStatus.delivered` orders are included in calculations
- This ensures we only count actual revenue
- Pending/processing orders are excluded

### 2. **Separate Refund Handling**
- Refunds are tracked separately from COGS
- Shows visibility of returns and their impact
- Helps identify problematic products/categories

### 3. **Platform Commission at 10%**
- Configurable via parameter
- Deducted before net profit
- Standard e-commerce platform practice

### 4. **Cost Price Required**
- Each product should have a costPrice field
- If missing, defaults to 0 (conservative estimate)
- Better than guessing or using markup-based estimate

### 5. **Date Range Flexibility**
- Not limited to fixed periods
- Custom date ranges possible via `calculateProfitMetrics()`
- Convenience methods for common ranges

---

## Future Enhancements

### 1. **Category-wise Breakdown**
```
Vegetables: ₹300 profit (40% margin)
Dairy:      ₹150 profit (30% margin)
Bakery:     ₹50 profit  (20% margin)
```

### 2. **Payment Method Analysis**
```
COD:     ₹250 profit
UPI:     ₹200 profit
Wallet:  ₹100 profit
```

### 3. **Customer Profiling**
- Top 10 customers by order value
- Repeat customer profit contribution
- Customer lifetime value

### 4. **Inventory Health Metrics**
- Stock turnover ratio
- Slow-moving products
- Dead stock value

### 5. **Predictive Analytics**
- Projected monthly profit
- Seasonal trends
- Growth forecasting

### 6. **Export to PDF/CSV**
- Generate profit reports
- Share with accountant
- Audit trail

### 7. **Notifications & Alerts**
- Profit target milestones
- Loss alerts
- Refund spike notifications

---

## Troubleshooting

### Issue: "Unable to find your shop"
**Solution:**
1. Ensure shopId is stored in Firestore owners collection
2. Check that ownerId matches current user.uid in shops collection
3. Verify custom claims are set on Firebase user

### Issue: COGS calculation shows 0
**Solution:**
1. Verify products have costPrice field populated
2. Check that product documents exist in Firestore
3. Ensure productId in order items matches product IDs in Firestore

### Issue: Refunds not showing
**Solution:**
1. Verify refunded orders have status: OrderStatus.refunded
2. Check that refundAmount or totalAmount is correctly stored
3. Ensure order creation date is in selected date range

---

## Performance Considerations

### Query Optimization
- **Indexed fields needed:**
  - orders.shopId
  - orders.createdAt
  - orders.status

- **Batch processing for COGS:**
  - Product fetches are done one-by-one
  - For optimization, consider batch reads in future versions

### Caching Strategy
- Consider caching profit metrics for 5-10 minutes
- Helpful for high-frequency dashboard views
- Clear cache on manual refresh

---

## Security Considerations

### Authorization
- Only owners can view their shop's profit data
- Orders are filtered by shopId
- No cross-shop data leakage

### Data Validation
- Order status must be valid enum
- Amounts are validated as positive doubles
- Date ranges are validated

---

## Code Quality

### Dependencies
- No external packages beyond existing app dependencies
- Uses Firestore transaction patterns
- Follows existing code style and conventions

### Error Handling
- Try-catch blocks for all Firestore operations
- Graceful fallbacks for missing data
- User-friendly error messages

### Documentation
- Comprehensive inline comments
- Class and method documentation
- Parameter descriptions

---

## Summary

The Profit Calculation Dashboard provides shopkeepers with essential financial insights:

1. **Gross Revenue** - Total money earned
2. **COGS** - What products cost them
3. **Commissions** - Platform fees
4. **Refunds** - Customer returns impact
5. **Net Profit** - Bottom line
6. **Profit Margin %** - Efficiency metric

This enables data-driven decision-making for pricing, inventory, and business strategy.
