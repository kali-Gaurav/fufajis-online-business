# Fufaji Online - Shop Owner Complete Guide

## Table of Contents
1. [Getting Started](#getting-started)
2. [Account Setup](#account-setup)
3. [Product Management](#product-management)
4. [Order Management](#order-management)
5. [Delivery Management](#delivery-management)
6. [Payment & Settlement](#payment--settlement)
7. [Analytics & Reports](#analytics--reports)
8. [Grow Your Business](#grow-your-business)
9. [Troubleshooting](#troubleshooting)
10. [Support](#support)

---

## Getting Started

### Prerequisites

Before registering, prepare:
- **Government ID** (Aadhaar, PAN, Passport, or Driver's License)
- **Shop registration/license** (if applicable)
- **Bank account details** (for settlements)
- **Shop address** with latitude/longitude
- **Contact phone number** (with OTP capability)

### Registration Process

#### Step 1: Download & Install
- Download Fufaji Online from Play Store or App Store
- Install and open the app

#### Step 2: Select Role
- Tap "Join as Shop Owner"
- Read terms and conditions
- Accept to proceed

#### Step 3: Verify Phone Number
- Enter shop contact phone number
- Receive 6-digit OTP via SMS
- Enter OTP to verify

#### Step 4: Add Shop Details
- Shop name (as you want it displayed)
- Owner name
- Contact phone number
- Shop address (complete with landmark)
- Select address on map or pin drop
- Confirm location

#### Step 5: Upload Documents
- Government ID (clear photo)
- Shop registration/license (if available)
- Utility bill (proof of address)
- Bank passbook/statement (first page)
- Tap "Submit for Verification"

#### Step 6: Wait for Approval
- Verification takes 24-48 hours
- You'll receive SMS notification
- Check "My Shop" → "Status" for updates
- Approved! Now set up products

### Dashboard Overview

**Main Dashboard shows:**
```
Today's Summary
├─ Total Orders: 15
├─ Completed: 12
├─ Cancelled: 2
├─ Pending: 1
└─ Earnings: ₹2,340

Quick Actions
├─ View Orders
├─ Add Products
├─ View Ratings
├─ Manage Offers
└─ Contact Support

Statistics
├─ Monthly Revenue
├─ Customer Ratings (4.8★)
├─ On-Time Delivery: 98%
└─ Customer Satisfaction: 95%
```

---

## Account Setup

### Shop Profile

#### Edit Shop Information
1. Go to **Settings** → **Shop Profile**
2. Update shop name, description, phone
3. Change shop address if needed
4. Upload/update shop logo
5. Save changes

#### Operating Hours

1. Go to **Settings** → **Operating Hours**
2. Set opening and closing times
3. Select days of operation (M-Sun)
4. Add holidays/special closures
5. Save

**Example:**
```
Monday-Friday:     9:00 AM - 9:00 PM
Saturday-Sunday:  10:00 AM - 10:00 PM
Closed: Republic Day (26 Jan)
```

### Delivery Area

#### Define Delivery Coverage
1. Go to **Settings** → **Delivery Area**
2. Option 1: Draw on map (drag radius)
3. Option 2: Enter pin codes
4. Set delivery fee (optional)
5. Save

**Tip:** Start with smaller area for better delivery times

### Bank Account Management

#### Add/Update Bank Details
1. Go to **Settings** → **Bank Account**
2. Enter:
   - Account holder name
   - Account number
   - IFSC code
   - Bank name
   - Account type (Savings/Current)
3. Verify with bank statement
4. Save

**Note:** Used for daily settlements (T+1)

---

## Product Management

### Adding Products

#### Single Product Entry
1. Go to **Inventory** → **Add Product**
2. Fill details:
   - **Product Name** (e.g., "Fresh Milk - 1L")
   - **Category** (Grocery, Fruits, Dairy, Bakery, etc.)
   - **Price** (₹)
   - **Unit** (1L, 500g, etc.)
   - **Stock Quantity**
   - **SKU** (optional, for your tracking)

3. Add product details:
   - Description (50-200 words)
   - Manufacturer name
   - Expiry date (if applicable)
   - Nutritional info (if applicable)

4. Upload product image:
   - Clear photo from front angle
   - 1024x1024px recommended
   - JPG/PNG format

5. Tap **Save** → Product live in 5 minutes

#### Bulk Upload from CSV
1. Go to **Inventory** → **Bulk Upload**
2. Download CSV template
3. Fill in spreadsheet:
   ```
   product_name,category,price,unit,stock,description
   Fresh Milk,Dairy,45,1L,100,Pure fresh milk
   Apple,Fruits,80,1kg,50,Red apples
   ```
4. Upload file
5. System validates and imports (5-10 mins)

### Product Variations

#### Create Size/Color Options
1. Go to **Inventory** → **Edit Product**
2. Tap **Add Variants**
3. Enter variant details:
   - Name (e.g., "Size")
   - Options (e.g., "500ml, 1L, 2L")
   - Price for each variant
   - Stock for each variant
4. Save

**Example - Milk:**
```
500ml:  ₹25, Stock: 50
1L:     ₹45, Stock: 100
2L:     ₹85, Stock: 75
```

### Inventory Management

#### Monitor Stock Levels
1. Dashboard shows low-stock alerts
2. Go to **Inventory** → View all products
3. Red = Out of stock, Yellow = Low stock

#### Set Reorder Alerts
1. Go to **Settings** → **Inventory Alerts**
2. Set minimum stock level per category
3. Get notification when stock falls below

#### Update Stock Manually
1. **Inventory** → Tap product
2. Tap "Update Stock"
3. Enter new quantity
4. Reason (sold, damaged, returned, etc.)
5. Save

**Note:** System auto-deducts stock as orders placed

### Product Offers

#### Create Discount Offers
1. Go to **Offers** → **Create Offer**
2. Select products (single or multiple)
3. Discount type:
   - Fixed (₹50 off)
   - Percentage (10% off)
4. Valid from/to dates
5. Minimum cart value (optional)
6. Save and publish

#### Bundle Deals
1. Go to **Offers** → **Create Bundle**
2. Select 2-5 products
3. Set bundle price
4. Set validity period
5. Publish

**Example Bundle:**
```
Milk (1L) + Bread + Butter
Regular: ₹150
Bundle: ₹125 (Save ₹25)
```

#### Loyalty Discounts
1. Go to **Offers** → **Loyalty Rewards**
2. Create tier-based discounts:
   - Silver: 2% off
   - Gold: 5% off
3. Set activation date
4. Monitor uptake

---

## Order Management

### Receiving Orders

#### Order Notifications
- Real-time SMS/in-app notification
- 5-minute acceptance window
- After 5 mins, order auto-cancels

#### Accept/Reject Orders
1. **Pending Orders** tab shows incoming orders
2. Review:
   - Customer name
   - Items (with quantity)
   - Total amount
   - Delivery address
   - Special instructions

3. **Accept Order:**
   - Tap "Confirm"
   - System locks inventory
   - Notifies customer + rider
   - Order moves to "Preparing"

4. **Reject Order:**
   - Tap "Reject"
   - Choose reason (out of stock, too late, etc.)
   - Customer auto-refunded
   - No cancellation fee

### Packing & Fulfillment

#### Pack Orders
1. Go to **Orders** → **Preparing**
2. Tap order to view items
3. Pick items from shelf/store
4. Verify quantity and quality
5. Pack items securely
6. Add invoice/receipt (optional)

#### Mark Ready for Pickup
1. Once packed, tap **Ready for Pickup**
2. System notifies assigned rider
3. Rider arrives within 10 minutes
4. Verify items with rider
5. Rider scans QR code
6. Order moves to "Picked Up"

#### Handle Special Requests
- Customer notes appear in order
- Example: "Please pick fresh milk only"
- Confirm with customer via chat if unsure
- Get approval before fulfilling differently

### Order History & Details

#### View Order Details
1. Go to **Orders** → Tap any order
2. See:
   - Order ID
   - Customer details
   - Items list
   - Prices and discounts
   - Delivery address
   - Timeline (placed → packed → picked → delivered)
   - Payment status

#### Export Order Data
1. Go to **Reports** → **Orders**
2. Select date range
3. Tap "Export CSV"
4. Use for accounting/inventory

---

## Delivery Management

### Delivery Settings

#### Set Delivery Fee
1. Go to **Settings** → **Delivery**
2. Option 1: Fixed fee (₹30 all deliveries)
3. Option 2: Distance-based (₹1/km after 2km)
4. Option 3: Free delivery
5. Save

#### Assign Riders

**Automatic Assignment:**
- Fufaji automatically assigns nearest available rider
- Rider notified instantly
- Average pickup time: 5-10 minutes

**Manual Assignment:**
1. Go to **Orders** → Tap order
2. Tap **Assign Rider**
3. Select from available riders
4. Confirm and notify

#### Track Deliveries
1. Go to **Deliveries** → **In Transit**
2. See real-time location on map
3. See estimated delivery time
4. Click rider info for phone/chat

### Delivery Issues

#### Order Delayed?
1. Check rider location on map
2. Chat with rider to confirm
3. Check traffic/weather conditions
4. Communicate ETA update to customer

#### Item Rejected at Delivery?
1. Customer can reject if item damaged
2. You'll be notified
3. Refund customer from your balance
4. Investigate quality control

#### Lost Item During Delivery?
1. Contact rider immediately
2. Check if item can be recovered
3. Refund customer if lost
4. Log incident for rider performance

---

## Payment & Settlement

### Understanding Earnings

#### Earnings Calculation

```
Customer Payment:        ₹500
- Fufaji Commission:     ₹50 (10%)
- Platform Fees:         ₹0
- Taxes (GST 5%):        ₹22.50
─────────────────────────────
Net to You:              ₹427.50
```

**Commission Rates:**
- Standard: 8-12% (based on category)
- Premium (Fresh produce): 5%
- Bulk orders (>₹2000): 6%
- After 100 orders: Tier-based discounts

#### View Earnings Dashboard

1. Go to **Earnings** tab
2. Today's summary:
   - Orders completed
   - Total sales
   - Net earnings
   - Pending orders value

3. Breakdown by:
   - Date
   - Category
   - Product
   - Customer

### Daily Settlements

#### How Settlements Work

```
Timeline for Order Placed at 2:00 PM:
2:00 PM  - Order placed, payment from customer
8:00 PM  - Order delivered
10:00 PM - Settlement initiated
10:00 AM Next Day (T+1) - Money in your account
```

**Settlement Rules:**
- Processed daily at 10:00 PM
- Deposited by 10:00 AM next day
- Automatically to registered bank account
- No manual action needed
- Instant view in "Settlement History"

#### Settlement Statement

1. Go to **Settlements**
2. Select date or date range
3. View:
   - Order-wise breakdown
   - Total orders
   - Total amount
   - Commission deducted
   - Taxes paid
   - Net amount transferred

4. Download PDF for accounting

### Handling Refunds

#### Customer Initiates Return

1. Notification: "Customer requested return for order #123"
2. Review return reason
3. Review items condition (from photos)
4. **Approve/Reject:**
   - Approve: Customer sends back, refund initiated
   - Reject: Provide reason, customer notified

#### Refund Deduction
- When approved, refund amount deducted from your balance
- Deduction appears in next settlement
- You have 48 hours to process return

#### Dispute Handling
- Customer disputes return rejection
- Escalated to Fufaji support team
- Team mediates and decides
- Result within 24 hours

### Payment Method Management

#### Update Bank Account
1. **Settings** → **Bank Account**
2. Current account shown
3. Tap **Change Bank Account**
4. Enter new details
5. Verify with bank statement
6. Future settlements go to new account

#### View Transaction History
1. Go to **Earnings** → **Transactions**
2. Filter by date, amount, status
3. Export as CSV for records

#### Tax Compliance
- GST automatically deducted if registered
- Invoice generated for every order
- Download monthly tax summary
- Ready for income tax filing

---

## Analytics & Reports

### Dashboard Metrics

#### Daily Metrics
- Orders received
- Orders completed
- Orders cancelled
- Total sales
- Average order value
- On-time delivery %
- Customer rating

#### View Analytics
1. Go to **Reports** → **Analytics**
2. Select time period (day, week, month, year)
3. View:
   - Revenue trend
   - Order volume
   - Customer acquisition
   - Category performance
   - Peak hours

### Performance Metrics

#### Shop Rating Factors
- On-time delivery (40%)
- Order accuracy (30%)
- Food quality/freshness (20%)
- Cleanliness & packaging (10%)

**Target: Maintain 4.5+ rating**

#### Key Performance Indicators
```
Metric              Target    Current
─────────────────────────────────────
On-time %           > 95%     98%
Cancellation %      < 5%      2%
Return/Refund %     < 2%      1%
Rating              > 4.5     4.8
Customer Feedback   > 90%     Positive
```

### Export Reports

#### Generate Reports
1. Go to **Reports** → Select type:
   - Sales Report
   - Order Report
   - Customer Report
   - Product Performance
   - Tax Report

2. Select date range
3. Choose format (PDF, CSV, Excel)
4. Download

#### Use for:
- Accounting and bookkeeping
- Tax filing
- Business analysis
- Inventory planning
- Identifying trends

---

## Grow Your Business

### Increasing Visibility

#### Product Optimization
1. **Use clear product names:**
   - Bad: "Milk"
   - Good: "Amul Fresh Milk - 1L Packet"

2. **Write detailed descriptions:**
   - Include ingredients/benefits
   - Mention origin/brand
   - Add nutritional info if applicable

3. **High-quality images:**
   - Clear, well-lit photos
   - Show product from multiple angles
   - Include packaging

4. **Proper categorization:**
   - Select correct category
   - Add relevant tags
   - Use keywords customers search

#### Promotional Strategies

1. **Flash Sales:**
   - Create limited-time offers
   - 20-30% discount for volume
   - Advertise via push notifications

2. **Bundle Deals:**
   - Combine complementary products
   - Increase average order value
   - Reduce per-item cost perception

3. **Loyalty Rewards:**
   - Offer 5-10% to repeat customers
   - Create loyalty program
   - Special birthday offers

### Building Customer Relationships

#### Communicate Effectively
- Respond to customer chat quickly (< 5 mins)
- Address complaints professionally
- Thank customers for positive reviews
- Ask for feedback on products

#### Quality Assurance
1. **Fresh & Quality Products:**
   - Source from reliable suppliers
   - Check expiry dates regularly
   - Remove damaged items before dispatch
   - Store items at correct temperature

2. **Packaging Standards:**
   - Use clean containers
   - Protect fragile items
   - Include desiccants for moisture-prone items
   - Add thank-you notes

3. **On-Time Delivery:**
   - Prioritize orders arriving early
   - Pack efficiently
   - Communicate delays proactively
   - Follow customer delivery instructions

### Customer Engagement

#### Respond to Reviews
- Positive review: Thank customer, offer loyalty discount
- Negative review: Apologize, offer solution, ask for resolution
- Average response: Within 1 hour

#### Feature Special Products
- Create seasonal collections
- Highlight best-sellers
- Introduce new products monthly
- Get feedback from customers

### Promotional Calendar

**Monthly Promotions:**
```
January    - New Year Specials, Healthy Eating
February   - Valentine's, Home Delivery Deals
March      - Spring Fresh Produce, Ramadan (if applicable)
April      - Summer Specials, Hydration Focus
May        - Pre-Summer Deals
June       - Monsoon Necessities
July-Aug   - Back to School, Holiday Prep
September  - Festival Season Prep
October    - Diwali Specials
November   - Winter Specials, Black Friday
December   - Holiday Season, Year-End Offers
```

---

## Troubleshooting

### Common Issues & Solutions

#### Orders Not Appearing
**Problem:** No orders showing despite being online

**Solutions:**
1. Check shop status: Settings → Shop Status → Should be "Active"
2. Verify delivery area covers customer locations
3. Check operating hours are current
4. Confirm all products have stock > 0
5. Restart app and try again

#### Payment Not Received
**Problem:** Order completed but money not in account

**Solutions:**
1. Check settlement status: Earnings → Settlements
2. Verify bank account details are correct
3. Check if amount is in "Pending" state
4. Settlements process daily at 10 PM
5. Contact support if still missing after 24 hours

#### Customer Complaint
**Problem:** Customer claims order items missing/damaged

**Solutions:**
1. Review order photo taken at pickup
2. Check customer chat for evidence
3. If valid, approve return and refund
4. If disputed, escalate to Fufaji support
5. Review quality control process

#### Low Ratings
**Problem:** Rating dropped below 4.5

**Solutions:**
1. Review recent negative comments
2. Identify patterns (late delivery, quality, accuracy)
3. Create action plan to improve
4. Communicate improvements to team
5. Reach out to customers who gave low ratings

#### Cannot Update Stock
**Problem:** Stock update option disabled

**Solutions:**
1. Verify you're logged in as shop owner
2. Check order is not in "Preparing" state
3. Ensure product is not in active promotion
4. Try logout and login again
5. Contact support if issue persists

---

## Support

### Getting Help

#### In-App Support
1. Go to **Settings** → **Help & Support**
2. Browse FAQ or search issue
3. Tap "Chat with Support"
4. Average response: 10-15 minutes
5. Available 24/7

#### Contact Methods

**Email:** shop-support@fufaji.com  
**Phone:** 1800-FUFAJI-2 (9am-9pm)  
**WhatsApp:** +91-9876543222

#### Support Ticket System
1. Go to **Help & Support** → **Report Issue**
2. Select category (product, payment, delivery, etc.)
3. Attach screenshots/evidence
4. Submit
5. Track status and chat with agent

### Common Questions

**Q: How long until my shop goes live?**
A: 24-48 hours after document verification

**Q: Can I sell from multiple locations?**
A: Yes! Register each location as separate shop

**Q: What's the commission rate?**
A: 8-12% depending on category and order volume

**Q: How often do I get paid?**
A: Daily settlements (T+1 to bank account)

**Q: Can I offer cash payment?**
A: Yes! Cash on Delivery (COD) available in select areas

**Q: What if an order gets damaged during delivery?**
A: Refund from your balance, investigate with rider

**Q: How do I increase my sales?**
A: Optimize products, run promotions, maintain quality, get good ratings

**Q: Can I close my shop temporarily?**
A: Yes! Settings → Shop Status → "On Break". Reactivate anytime

---

## Success Tips

1. **Stock Fresh Products Daily** - Quality is your competitive advantage
2. **Respond Quickly to Customers** - Chat < 5 minutes, call < 2 minutes
3. **Maintain Cleanliness** - Package items with care
4. **Update Inventory Regularly** - Don't keep popular items out of stock
5. **Monitor Your Rating** - 4.8+ gives you 20% more orders
6. **Run Strategic Promotions** - Weekly or monthly specials
7. **Gather Customer Feedback** - Improve based on reviews
8. **Stay Active in App** - Regular updates = better visibility
9. **Follow Delivery Times** - On-time delivery = happy customers
10. **Be Professional** - Building brand reputation takes time

---

## Resources

- **Blog:** blog.fufaji.com/shop-owners
- **Video Tutorials:** youtube.com/@fufaji-shops
- **Community Forum:** forum.fufaji.com
- **Knowledge Base:** help.fufaji.com

---

**Thank you for partnering with Fufaji!**

*Together, we're bringing local shops to customers everywhere.*
