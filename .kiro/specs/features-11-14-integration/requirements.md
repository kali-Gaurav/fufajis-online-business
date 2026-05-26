# Features 11-14 Integration Requirements Document

## 1. Overview

This document outlines the requirements for end-to-end integration of Features 11-14 into the Fufaji's Online platform. The goal is to take the existing service layer implementations and fully integrate them into the app UI, other services, and backend systems.

### 1.1 Features Covered

- **Feature 11**: WhatsApp Sync Service - Bulk upload via WhatsApp bot
- **Feature 12**: Inventory Alert Service - Smart low-stock predictive alerts
- **Feature 13**: Expiry Checker Service - Auto-expiry tracking and dynamic markdown
- **Feature 14**: Pricing Engine Service - Dynamic price adjuster and competitor matching

### 1.2 Current State

All four services have been implemented at the service layer but are NOT integrated into:
- App UI (AddProductScreen, Owner Dashboard, Settings)
- ProductProvider (for sales recording and inventory updates)
- Firebase Functions (for webhook and cron job handling)
- User notification system

---

## 2. Feature 11: WhatsApp Sync Service Integration

### 2.1 User Stories

| ID | User Story | Priority |
|----|------------|----------|
| WS-11.1 | As a shop owner, I want to send a photo of my inventory bill to WhatsApp so that products are automatically added to my store | Must Have |
| WS-11.2 | As a shop owner, I want to send a text list of items to WhatsApp so that I can quickly update inventory without opening the app | Must Have |
| WS-11.3 | As a shop owner, I want to receive WhatsApp notifications when products are successfully added so that I know the sync worked | Should Have |
| WS-11.4 | As a shop owner, I want to view all WhatsApp-synced items in my product list so that I can verify and edit them | Should Have |
| WS-11.5 | As a shop owner, I want to configure my WhatsApp Business number in settings so that I can receive updates | Could Have |

### 2.2 Functional Requirements

#### 11.1 WhatsApp Webhook Handler
- **REQ-11.1.1**: System must accept incoming WhatsApp messages via webhook endpoint
- **REQ-11.1.2**: System must verify webhook using verifyToken
- **REQ-11.1.3**: System must process text, image, and document messages
- **REQ-11.1.4**: System must handle message deduplication to prevent duplicate processing

#### 11.2 Text Message Processing
- **REQ-11.2.1**: System must parse item lists from text messages using Gemini AI
- **REQ-11.2.2**: System must extract item name, quantity, price, and unit from text
- **REQ-11.2.3**: System must validate extracted data before adding to inventory
- **REQ-11.2.4**: System must send confirmation message with summary of added items

#### 11.3 Image Message Processing
- **REQ-11.3.1**: System must download and process bill images from WhatsApp
- **REQ-11.3.2**: System must enhance image quality for better OCR
- **REQ-11.3.3**: System must extract text from images using Gemini Vision API
- **REQ-11.3.4**: System must parse extracted text into structured item data
- **REQ-11.3.5**: System must handle multiple items in a single bill

#### 11.4 Shop Identification
- **REQ-11.4.1**: System must identify shop owner by phone number
- **REQ-11.4.2**: System must create new shop profile if phone number is new
- **REQ-11.4.3**: System must link items to correct shop ID
- **REQ-11.4.4**: System must reject messages from unregistered numbers

#### 11.5 Notification System
- **REQ-11.5.1**: System must send WhatsApp confirmation after successful sync
- **REQ-11.5.2**: System must send push notification to shop owner app
- **REQ-11.5.3**: System must report errors to shop owner via WhatsApp
- **REQ-11.5.4**: System must include item count and any parsing errors in notification

### 2.3 Integration Requirements

#### 11.6 Firebase Functions Integration
- **REQ-11.6.1**: Create WhatsApp webhook function in Firebase Functions
- **REQ-11.6.2**: Configure CORS for WhatsApp API callbacks
- **REQ-11.6.3**: Implement message queuing for rate limiting
- **REQ-11.6.4**: Set up error logging and monitoring

#### 11.7 App UI Integration
- **REQ-11.7.1**: Add WhatsApp configuration screen in Owner Settings
- **REQ-11.7.2**: Display WhatsApp sync status on dashboard
- **REQ-11.7.3**: Show recent WhatsApp-synced items in product list
- **REQ-11.7.4**: Add "Sync via WhatsApp" quick action button

#### 11.8 Data Flow
```
WhatsApp Message → Firebase Functions Webhook → Gemini AI Processing → Firestore Products → Push Notification → App UI Update
```

### 2.4 Non-Functional Requirements

- **NF-11.1**: Message processing must complete within 30 seconds
- **NF-11.2**: OCR accuracy must be at least 85% for clear images
- **NF-11.3**: System must handle at least 100 messages per minute
- **NF-11.4**: WhatsApp API calls must follow rate limits (60 RPM)

### 2.5 Acceptance Criteria

| Criterion | Test Method |
|-----------|-------------|
| Text message with "Add 20 apples at 150" creates product with name="Apples", price=150, stock=20 | Manual Test |
| Bill photo of 10 items creates 10 products with correct data | Manual Test |
| Duplicate message does not create duplicate products | Automated Test |
| Unregistered phone number receives rejection message | Manual Test |
| Processing time for 10-item bill is under 30 seconds | Performance Test |

---

## 3. Feature 12: Inventory Alert Service Integration

### 3.1 User Stories

| ID | User Story | Priority |
|----|------------|----------|
| WS-12.1 | As a shop owner, I want to receive notifications when products are running low so that I can reorder before stockout | Must Have |
| WS-12.2 | As a shop owner, I want to see a health score for my inventory so that I know my overall stock status | Should Have |
| WS-12.3 | As a shop owner, I want to see predicted days until stockout so that I can plan reordering | Should Have |
| WS-12.4 | As a shop owner, I want to see recommended reorder quantities so that I know how much to order | Could Have |
| WS-12.5 | As a shop owner, I want to see sales trends so that I can anticipate demand | Could Have |

### 3.2 Functional Requirements

#### 12.1 Sales Velocity Calculation
- **REQ-12.1.1**: System must calculate average daily sales for each product
- **REQ-12.1.2**: System must analyze sales data for the last 30 days
- **REQ-12.1.3**: System must detect sales trend (increasing/decreasing/stable)
- **REQ-12.1.4**: System must calculate confidence level based on data points

#### 12.2 Stockout Prediction
- **REQ-12.2.1**: System must predict days until stockout for each product
- **REQ-12.2.2**: System must consider sales trend in prediction
- **REQ-12.2.3**: System must update predictions in real-time as sales occur
- **REQ-12.2.4**: System must flag products with less than 7 days stock

#### 12.3 Reorder Recommendations
- **REQ-12.3.1**: System must calculate recommended reorder quantity
- **REQ-12.3.2**: System must consider lead time (default 3 days)
- **REQ-12.3.3**: System must calculate safety stock (default 2 days)
- **REQ-12.3.4**: System must recommend minimum 1 week of stock

#### 12.4 Alert Generation
- **REQ-12.4.1**: System must generate alerts for products with ≤7 days stock
- **REQ-12.4.2**: System must categorize alerts by severity (Critical/High/Medium/Low)
- **REQ-12.4.3**: System must save alerts to Firestore
- **REQ-12.4.4**: System must dismiss alerts when stock is replenished

#### 12.5 Notification System
- **REQ-12.5.1**: System must send push notification for critical alerts
- **REQ-12.5.2**: System must send WhatsApp message for critical alerts
- **REQ-12.5.3**: System must batch warning alerts to reduce notification spam
- **REQ-12.5.4**: System must allow users to configure notification preferences

### 3.3 Integration Requirements

#### 12.6 ProductProvider Integration
- **REQ-12.6.1**: ProductProvider must call `recordSale()` when order is completed
- **REQ-12.6.2**: ProductProvider must include sales data in product updates
- **REQ-12.6.3**: ProductProvider must subscribe to real-time alerts
- **REQ-12.6.4**: ProductProvider must expose low stock products in API

#### 12.7 Owner Dashboard Integration
- **REQ-12.7.1**: Dashboard must show low stock alert count
- **REQ-12.7.2**: Dashboard must display inventory health score (0-100)
- **REQ-12.7.3**: Dashboard must show critical items list
- **REQ-12.7.4**: Dashboard must link to full inventory alerts screen

#### 12.8 Firebase Functions Integration
- **REQ-12.8.1**: Create scheduled function to check inventory every hour
- **REQ-12.8.2**: Create function to clean up old sales data (>90 days)
- **REQ-12.8.3**: Create function to send batch notifications
- **REQ-12.8.4**: Set up monitoring for alert generation rate

#### 12.9 Data Flow
```
Order Completed → ProductProvider.recordSale() → Firestore Sales History → InventoryAlertService.checkLowStock() → Alert Generated → Push/WhatsApp Notification → Dashboard Update
```

### 3.4 Non-Functional Requirements

- **NF-12.1**: Sales velocity calculation must complete within 2 seconds
- **NF-12.2**: Stockout prediction accuracy must be at least 80%
- **NF-12.3**: System must handle at least 1000 products per shop
- **NF-12.4**: Alert generation must complete within 5 seconds for 1000 products

### 3.5 Acceptance Criteria

| Criterion | Test Method |
|-----------|-------------|
| Product with 10 daily sales and 50 stock shows 5 days until stockout | Unit Test |
| Product with increasing trend adjusts stockout prediction down | Unit Test |
| Shop with 80% healthy products shows health score of 80 | Integration Test |
| Critical alert sends push notification within 10 seconds | Performance Test |
| Sales recording adds entry to sales_history collection | Manual Test |

---

## 4. Feature 13: Expiry Checker Service Integration

### 4.1 User Stories

| ID | User Story | Priority |
|----|------------|----------|
| WS-13.1 | As a shop owner, I want to set expiry dates for products so that the system can track them | Must Have |
| WS-13.2 | As a shop owner, I want products nearing expiry to be automatically discounted so that I can clear stock | Must Have |
| WS-13.3 | As a shop owner, I want to receive notifications about expiring products so that I can take action | Should Have |
| WS-13.4 | As a customer, I want to see discounted prices on products nearing expiry so that I can save money | Should Have |
| WS-13.5 | As a shop owner, I want to see analytics on expiry waste so that I can improve my inventory | Could Have |

### 4.2 Functional Requirements

#### 13.1 Expiry Date Management
- **REQ-13.1.1**: System must allow setting expiry date when adding products
- **REQ-13.1.2**: System must validate expiry date is in the future
- **REQ-13.1.3**: System must allow updating expiry date for existing products
- **REQ-13.1.4**: System must mark products as expired when date passes

#### 13.2 Dynamic Discount Calculation
- **REQ-13.2.1**: System must calculate discount based on hours until expiry
- **REQ-13.2.2**: System must apply 10-20% discount for 3+ days remaining
- **REQ-13.2.3**: System must apply 20-30% discount for 2-3 days remaining
- **REQ-13.2.4**: System must apply 30-40% discount for 1-2 days remaining
- **REQ-13.2.5**: System must apply 40-50% discount for <24 hours remaining
- **REQ-13.2.6**: System must not decrease existing discounts
- **REQ-13.2.7**: System must cap maximum discount at 50%

#### 13.3 Automatic Discount Application
- **REQ-13.3.1**: System must check products for expiry every hour
- **REQ-13.3.2**: System must apply new discounts automatically
- **REQ-13.3.3**: System must log all discount changes
- **REQ-13.3.4**: System must update product availability for expired items

#### 13.4 Expiry Notifications
- **REQ-13.4.1**: System must send notification for products expiring in 24 hours
- **REQ-13.4.2**: System must send notification for products expiring in 72 hours
- **REQ-13.4.3**: System must send notification when products are marked expired
- **REQ-13.4.4**: System must include discount status in notifications

### 4.3 Integration Requirements

#### 13.5 AddProductScreen Integration
- **REQ-13.5.1**: AddProductScreen must include expiry date picker
- **REQ-13.5.2**: Expiry date picker must show only future dates
- **REQ-13.5.3**: Expiry date must be optional (not all products have expiry)
- **REQ-13.5.4**: Selected date must be saved to product document

#### 13.6 ProductCard Integration
- **REQ-13.6.1**: ProductCard must show discount badge if dynamically discounted
- **REQ-13.6.2**: ProductCard must show original price and discounted price
- **REQ-13.6.3**: ProductCard must show "Expires in X hours" if applicable
- **REQ-13.6.4**: ProductCard must hide expired products from customer view

#### 13.7 Owner Dashboard Integration
- **REQ-13.7.1**: Dashboard must show count of products expiring soon
- **REQ-13.7.2**: Dashboard must show count of expired products
- **REQ-13.7.3**: Dashboard must show potential waste value
- **REQ-13.7.4**: Dashboard must link to expiry management screen

#### 13.8 Firebase Functions Integration
- **REQ-13.8.1**: Create scheduled function to check expiry every hour
- **REQ-13.8.2**: Create function to apply dynamic discounts
- **REQ-13.8.3**: Create function to mark expired products
- **REQ-13.8.4**: Create function to send expiry notifications

#### 13.9 Data Flow
```
Scheduled Function (Hourly) → ExpiryCheckerService.checkAndApplyDiscounts() → Firestore Product Update → Discount Badge Update → Customer Notification
```

### 4.4 Non-Functional Requirements

- **NF-13.1**: Expiry check must complete within 10 seconds for 1000 products
- **NF-13.2**: Discount application must maintain data consistency
- **NF-13.3**: System must handle concurrent discount updates
- **NF-13.4**: Expiry notifications must be delivered within 5 minutes

### 4.5 Acceptance Criteria

| Criterion | Test Method |
|-----------|-------------|
| Product with expiry in 48 hours shows 30% discount | Unit Test |
| Product with expiry in 12 hours shows 45% discount | Unit Test |
| Product with expiry in 7 days shows no discount | Unit Test |
| Expired product is marked unavailable | Integration Test |
| Expiry date picker only shows future dates | UI Test |
| ProductCard shows dynamic discount badge | UI Test |

---

## 5. Feature 14: Pricing Engine Service Integration

### 5.1 User Stories

| ID | User Story | Priority |
|----|------------|----------|
| WS-14.1 | As a shop owner, I want to input competitor prices so that the system can compare | Must Have |
| WS-14.2 | As a shop owner, I want the system to recommend price changes based on competitors so that I stay competitive | Must Have |
| WS-14.3 | As a shop owner, I want to approve or reject price changes so that I maintain control | Should Have |
| WS-14.4 | As a shop owner, I want to set pricing rules (beat/match/premium) so that I can control my pricing strategy | Should Have |
| WS-14.5 | As a shop owner, I want to see price comparison analytics so that I understand my market position | Could Have |

### 5.2 Functional Requirements

#### 14.1 Competitor Price Management
- **REQ-14.1.1**: System must allow adding competitor prices for products
- **REQ-14.1.2**: System must support multiple competitors per product
- **REQ-14.1.3**: System must track price history for competitors
- **REQ-14.1.4**: System must update competitor prices via bulk import

#### 14.2 Pricing Strategies
- **REQ-14.2.1**: System must support "Beat" strategy (price below lowest competitor)
- **REQ-14.2.2**: System must support "Match" strategy (match lowest competitor)
- **REQ-14.2.3**: System must support "Premium" strategy (price above competitors)
- **REQ-14.2.4**: System must support "Cost Plus" strategy (cost + margin)
- **REQ-14.2.5**: System must allow category-specific pricing rules

#### 14.3 Price Calculation
- **REQ-14.3.1**: System must calculate optimal price based on strategy
- **REQ-14.3.2**: System must ensure price is above cost (minimum 1% margin)
- **REQ-14.3.3**: System must round prices to nearest rupee
- **REQ-14.3.4**: System must trigger price change when difference > 2%

#### 14.4 Price Change Workflow
- **REQ-14.4.1**: System must save pending price changes for review
- **REQ-14.4.2**: System must notify shop owner of pending changes
- **REQ-14.4.3**: System must allow approval of individual price changes
- **REQ-14.4.4**: System must allow rejection with reason
- **REQ-14.4.5**: System must auto-apply changes if configured

#### 14.5 Price History
- **REQ-14.5.1**: System must track all price changes with timestamps
- **REQ-14.5.2**: System must keep 90 days of price history
- **REQ-14.5.3**: System must show price trend over time
- **REQ-14.5.4**: System must allow export of price history

### 5.3 Integration Requirements

#### 14.6 AddProductScreen Integration
- **REQ-14.6.1**: AddProductScreen must include cost price field
- **REQ-14.6.2**: AddProductScreen must include competitor price fields
- **REQ-14.6.3**: AddProductScreen must include pricing strategy selector
- **REQ-14.6.4**: AddProductScreen must show calculated optimal price

#### 14.7 Pricing Rules Screen
- **REQ-14.7.1**: Create PricingRulesScreen in Owner Dashboard
- **REQ-14.7.2**: Screen must show current pricing rules
- **REQ-14.7.3**: Screen must allow adding/editing rules
- **REQ-14.7.4**: Screen must allow setting default strategy
- **REQ-14.7.5**: Screen must allow setting margin percentage

#### 14.8 Pending Price Changes Screen
- **REQ-14.8.1**: Create PendingPriceChangesScreen in Owner Dashboard
- **REQ-14.8.2**: Screen must list all pending price changes
- **REQ-14.8.3**: Screen must show current vs new price
- **REQ-14.8.4**: Screen must allow bulk approval/rejection
- **REQ-14.8.5**: Screen must show change reason

#### 14.9 Analytics Integration
- **REQ-14.9.1**: Analytics must show price comparison report
- **REQ-14.9.2**: Analytics must show market position (lowest/middle/highest)
- **REQ-14.9.3**: Analytics must show competitor coverage
- **REQ-14.9.4**: Analytics must show price change history

#### 14.10 Firebase Functions Integration
- **REQ-14.10.1**: Create scheduled function for daily price analysis
- **REQ-14.10.2**: Create function to send price recommendations
- **REQ-14.10.3**: Create function for bulk competitor price import
- **REQ-14.10.4**: Set up monitoring for price change frequency

#### 14.11 Data Flow
```
Scheduled Function (Daily) → PricingEngineService.adjustPrices() → Pending Changes → Shop Owner Approval → Price Update → Product Update → Customer Notification
```

### 5.4 Non-Functional Requirements

- **NF-14.1**: Price calculation must complete within 1 second
- **NF-14.2**: System must handle 1000 competitor prices per shop
- **NF-14.3**: Price changes must maintain data consistency
- **NF-14.4**: Price history query must complete within 2 seconds

### 5.5 Acceptance Criteria

| Criterion | Test Method |
|-----------|-------------|
| Product with cost 100 and "Cost Plus 20%" shows price 120 | Unit Test |
| Product with lowest competitor 150 and "Beat" strategy shows price 147 | Unit Test |
| Product with 2% price difference triggers pending change | Unit Test |
| Pending change appears in PendingPriceChangesScreen | UI Test |
| Approval of pending change updates product price | Integration Test |
| Pricing rule applies to correct product category | Integration Test |

---

## 6. Cross-Feature Integration Requirements

### 6.1 Shared Dependencies

#### 6.1.1 Firebase Functions
All four features require Firebase Functions for:
- Webhook handling (Feature 11)
- Scheduled jobs (Features 12, 13, 14)
- Background processing

#### 6.1.2 Firestore Collections
| Collection | Features | Purpose |
|------------|----------|---------|
| `whatsapp_processed` | 11 | Message deduplication |
| `inventory_alerts` | 12 | Low stock alerts |
| `sales_history` | 12 | Sales velocity tracking |
| `expiry_logs` | 13 | Expiry tracking logs |
| `discount_history` | 13 | Discount changes |
| `competitor_prices` | 14 | Competitor prices |
| `price_history` | 14 | Price changes |
| `pricing_rules` | 14 | Pricing strategies |
| `price_alerts` | 14 | Pending changes |

#### 6.1.3 Notification Service
All features use NotificationService for:
- Push notifications (Features 11, 12, 13, 14)
- WhatsApp messages (Features 11, 12)

### 6.2 UI Component Sharing

#### 6.2.1 Dashboard Widgets
- LowStockAlertWidget (Feature 12)
- ExpiringSoonWidget (Feature 13)
- PendingPriceChangesWidget (Feature 14)
- InventoryHealthScoreWidget (Feature 12)

#### 6.2.2 Shared Components
- DatePickerField (Feature 13)
- PriceInputField (Features 12, 14)
- CompetitorPriceInput (Feature 14)
- AlertListView (Features 12, 13, 14)

### 6.3 Error Handling

#### 6.3.1 Common Error Scenarios
| Error | Features | Handling |
|-------|----------|----------|
| WhatsApp API rate limit | 11 | Queue and retry |
| Gemini API timeout | 11, 13 | Fallback to manual |
| Firestore transaction conflict | All | Retry with backoff |
| Invalid data format | 11, 14 | Log and notify user |

---

## 7. Testing Requirements

### 7.1 Unit Tests

Each service must have unit tests for:
- Core calculation functions
- Data validation
- Error handling
- Edge cases

### 7.2 Integration Tests

Integration tests must verify:
- Service to Firestore communication
- Firebase Functions triggers
- Notification delivery
- UI component rendering

### 7.3 End-to-End Tests

E2E tests must verify:
- Complete user workflows
- Data consistency across features
- Performance under load

### 7.4 Test Coverage Requirements

| Metric | Target |
|--------|--------|
| Unit test coverage | 80% |
| Integration test coverage | 60% |
| Critical path coverage | 100% |

---

## 8. Security Requirements

### 8.1 Authentication & Authorization

- **SEC-8.1.1**: WhatsApp webhook must verify request authenticity
- **SEC-8.1.2**: Only shop owners can view their inventory alerts
- **SEC-8.1.3**: Only shop owners can approve price changes
- **SEC-8.1.4**: Competitor prices must be isolated per shop

### 8.2 Data Protection

- **SEC-8.2.1**: WhatsApp messages must be processed securely
- **SEC-8.2.2**: Sales history must be retained for 90 days only
- **SEC-8.2.3**: Price history must be retained for 90 days only
- **SEC-8.2.4**: Sensitive data must not be logged

### 8.3 API Security

- **SEC-8.3.1**: WhatsApp webhook must use HTTPS
- **SEC-8.3.2**: Firebase Functions must validate requests
- **SEC-8.3.3**: Rate limiting must prevent abuse
- **SEC-8.3.4**: Input validation must prevent injection

---

## 9. Performance Requirements

### 9.1 Response Time

| Operation | Target |
|-----------|--------|
| WhatsApp message processing | < 30s |
| Sales velocity calculation | < 2s |
| Expiry check (1000 products) | < 10s |
| Price calculation | < 1s |
| Dashboard load | < 3s |

### 9.2 Scalability

| Metric | Target |
|--------|--------|
| Products per shop | 10,000 |
| Messages per minute | 100 |
| Concurrent users | 1,000 |
| Firebase Functions invocations | 10,000/day |

---

## 10. Documentation Requirements

### 10.1 User Documentation

- [ ] WhatsApp sync user guide
- [ ] Inventory alerts user guide
- [ ] Expiry tracking user guide
- [ ] Pricing engine user guide
- [ ] Video tutorials for each feature

### 10.2 Technical Documentation

- [ ] API documentation for webhook
- [ ] Firestore schema documentation
- [ ] Firebase Functions deployment guide
- [ ] Testing guide
- [ ] Troubleshooting guide

---

## 11. Implementation Phases

### Phase 1: Core Integration (Week 1-2)
1. AddProductScreen enhancement (Features 12, 13, 14)
2. ProductProvider integration (Feature 12)
3. Owner Dashboard widgets (Features 12, 13, 14)

### Phase 2: Service Integration (Week 3-4)
1. Firebase Functions webhook (Feature 11)
2. Scheduled functions (Features 12, 13, 14)
3. Notification integration (All features)

### Phase 3: UI Completion (Week 5-6)
1. Pricing Rules Screen (Feature 14)
2. Pending Price Changes Screen (Feature 14)
3. Expiry Management Screen (Feature 13)
4. Inventory Alerts Screen (Feature 12)

### Phase 4: Testing & Polish (Week 7-8)
1. Unit and integration tests
2. Performance optimization
3. Bug fixes and refinements
4. Documentation completion

---

## 12. Risks and Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| WhatsApp API changes | High | Low | Use official Meta SDK |
| Firebase Functions cold starts | Medium | Medium | Set minimum instances |
| OCR accuracy issues | Medium | Medium | Fallback to manual entry |
| Shop owner adoption | High | Medium | Training and support |
| Price war escalation | Medium | Low | Set minimum margin |

---

## 13. Success Metrics

### Feature 11: WhatsApp Sync
- [ ] 50% of shop owners use WhatsApp for inventory
- [ ] Average sync time < 30 seconds
- [ ] OCR accuracy > 85%

### Feature 12: Inventory Alerts
- [ ] 80% reduction in stockouts
- [ ] 50% faster reorder cycle
- [ ] Inventory health score > 80

### Feature 13: Expiry Tracking
- [ ] 90% of expiring products discounted
- [ ] 30% reduction in waste
- [ ] Customer awareness > 70%

### Feature 14: Dynamic Pricing
- [ ] Price competitiveness within 2% of market
- [ ] 50% price recommendations approved
- [ ] 5% revenue increase

---

## 14. Appendix

### A. Firestore Schema

See `design.md` for detailed Firestore schema.

### B. API Specifications

See `design.md` for API endpoint specifications.

### C. UI Mockups

See `design.md` for UI wireframes.

### D. Test Cases

See `tasks.md` for detailed test cases.

---

**Document Version**: 1.0  
**Last Updated**: 2026-05-20  
**Status**: Draft - Pending Review
---

## 15. Detailed Acceptance Criteria

### 15.1 Feature 11: WhatsApp Sync Service

#### 15.1.1 Text Message Processing

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-11.1.1 | Simple item addition | "Add 20 apples at 150" | Product created: name="Apples", price=150, stock=20, unit="piece" | Must Have |
| TC-11.1.2 | Multiple items | "Add 10 bananas at 50, 5 oranges at 100" | 2 products created with correct data | Must Have |
| TC-11.1.3 | Item with unit | "Add 2kg rice at 80 per kg" | Product with unit="kg", price=80, stock=2 | Should Have |
| TC-11.1.4 | Invalid format | "I want to add some fruits" | Error message asking for clearer format | Must Have |
| TC-11.1.5 | Unregistered phone | Message from unknown number | "Phone not registered" message | Must Have |
| TC-11.1.6 | Duplicate message | Same message sent twice | Only one product created | Must Have |

#### 15.1.2 Image Message Processing

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-11.2.1 | Clear bill image | Image of 5-item bill | 5 products created with correct data | Must Have |
| TC-11.2.2 | Blurry image | Low quality image | Error message asking for clearer image | Should Have |
| TC-11.2.3 | Multiple page bill | Multi-page document | First page processed, warning for others | Could Have |
| TC-11.2.4 | Handwritten bill | Handwritten list | Partial recognition with confidence score | Could Have |
| TC-11.2.5 | Empty image | Blank image | "No items found" message | Should Have |

#### 15.1.3 Notification Delivery

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-11.3.1 | Success notification | 5 items added | WhatsApp message with "Added 5 items" | Must Have |
| TC-11.3.2 | Partial success | 10 items, 2 failed | Message with success count and error details | Should Have |
| TC-11.3.3 | Push notification | Items added | Push notification to owner's device | Should Have |
| TC-11.3.4 | Error notification | Invalid image | Error details sent via WhatsApp | Should Have |

### 15.2 Feature 12: Inventory Alert Service

#### 15.2.1 Sales Velocity Calculation

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-12.1.1 | Consistent sales | 30 days data, 10 units/day | Velocity = 10, trend = "stable" | Must Have |
| TC-12.1.2 | Increasing trend | 2nd half 20% more than 1st | Trend = "increasing", +20% | Must Have |
| TC-12.1.3 | Decreasing trend | 2nd half 20% less than 1st | Trend = "decreasing", -20% | Must Have |
| TC-12.1.4 | No sales data | New product | Velocity = 0, confidence = 0.3 | Must Have |
| TC-12.1.5 | Low data points | 5 sales records | Confidence = 0.5 | Should Have |
| TC-12.1.6 | High data points | 100+ sales records | Confidence = 1.0 | Should Have |

#### 15.2.2 Stockout Prediction

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-12.2.1 | Normal prediction | 50 stock, 10/day velocity | 5 days until stockout | Must Have |
| TC-12.2.2 | Increasing trend | 50 stock, 10→15/day | 4 days until stockout (adjusted) | Must Have |
| TC-12.2.3 | Decreasing trend | 50 stock, 10→5/day | 6 days until stockout (adjusted) | Must Have |
| TC-12.2.4 | No sales | 50 stock, 0 velocity | 999 days (infinite) | Must Have |
| TC-12.2.5 | Critical stock | 5 stock, 10/day | 0 days (immediate stockout) | Must Have |

#### 15.2.3 Reorder Recommendations

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-12.3.1 | Basic calculation | 20 stock, 10/day velocity | Reorder quantity ≥ 70 | Must Have |
| TC-12.3.2 | Custom lead time | 20 stock, 10/day, 5-day lead | Reorder quantity ≥ 85 | Should Have |
| TC-12.3.3 | Safety stock | 20 stock, 10/day, 2-day safety | Reorder quantity ≥ 60 | Should Have |
| TC-12.3.4 | Minimum order | 50 stock, 2/day velocity | Minimum order = 14 | Should Have |
| TC-12.3.5 | No sales data | 20 stock, 0 velocity | Reorder = current stock | Must Have |

#### 15.2.4 Alert Generation

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-12.4.1 | Critical alert | 1 day until stockout | Severity = 5, notification sent | Must Have |
| TC-12.4.2 | High alert | 2 days until stockout | Severity = 4, notification sent | Must Have |
| TC-12.4.3 | Medium alert | 3 days until stockout | Severity = 3, logged only | Should Have |
| TC-12.4.4 | Low alert | 5 days until stockout | Severity = 2, logged only | Could Have |
| TC-12.4.5 | Warning alert | 7 days until stockout | Severity = 1, logged only | Could Have |
| TC-12.4.6 | Alert dismissal | Stock replenished | Alert removed from active list | Should Have |

### 15.3 Feature 13: Expiry Checker Service

#### 15.3.1 Dynamic Discount Calculation

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-13.1.1 | 7 days remaining | expiryDate = now + 7 days | Discount = 10% | Must Have |
| TC-13.1.2 | 3 days remaining | expiryDate = now + 3 days | Discount = 20% | Must Have |
| TC-13.1.3 | 2 days remaining | expiryDate = now + 2 days | Discount = 30% | Must Have |
| TC-13.1.4 | 1 day remaining | expiryDate = now + 1 day | Discount = 40% | Must Have |
| TC-13.1.5 | 12 hours remaining | expiryDate = now + 12 hours | Discount = 45% | Must Have |
| TC-13.1.6 | 6 hours remaining | expiryDate = now + 6 hours | Discount = 48% | Should Have |
| TC-13.1.7 | Maximum discount | < 24 hours | Discount capped at 50% | Must Have |
| TC-13.1.8 | No decrease | Existing 30%, now 25% | Discount stays at 30% | Must Have |

#### 15.3.2 Expiry Date Management

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-13.2.1 | Set future date | Expiry = now + 30 days | Date saved correctly | Must Have |
| TC-13.2.2 | Set past date | Expiry = now - 1 day | Validation error | Must Have |
| TC-13.2.3 | Update existing | Change expiry date | Old date replaced | Should Have |
| TC-13.2.4 | Remove expiry | Clear expiry field | Field set to null | Should Have |
| TC-13.2.5 | Expired product | expiryDate < now | isAvailable = false | Must Have |

#### 15.3.3 Discount Application

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-13.3.1 | Apply new discount | 30% discount | Price reduced by 30% | Must Have |
| TC-13.3.2 | Log discount change | Discount change | Entry added to discount_history | Must Have |
| TC-13.3.3 | Original price preserved | Discount applied | originalPrice = old price | Must Have |
| TC-13.3.4 | isOnSale flag | Discount > 0 | isOnSale = true | Must Have |
| TC-13.3.5 | Reset discount | Remove discount | Price restored to original | Should Have |

### 15.4 Feature 14: Pricing Engine Service

#### 15.4.1 Price Calculation

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-14.1.1 | Beat strategy | Cost=100, lowest competitor=150 | Price = 147 (2% below) | Must Have |
| TC-14.1.2 | Match strategy | Cost=100, lowest competitor=150 | Price = 150 | Must Have |
| TC-14.1.3 | Premium strategy | Cost=100, lowest competitor=150 | Price = 158 (5% above) | Must Have |
| TC-14.1.4 | Cost plus strategy | Cost=100, margin=20% | Price = 120 | Must Have |
| TC-14.1.5 | No competitor data | Cost=100, no competitors | Price = 105 (5% margin) | Must Have |
| TC-14.1.6 | Below cost protection | Cost=100, calculated=98 | Price = 101 (1% above cost) | Must Have |
| TC-14.1.7 | Rounding | Calculated=123.45 | Price = 123 | Must Have |

#### 15.4.2 Pricing Rules

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-14.2.1 | Category rule | Groceries category | Category-specific margin applied | Should Have |
| TC-14.2.2 | Default rule | No category match | Default margin applied | Must Have |
| TC-14.2.3 | Rule priority | Multiple matching rules | Higher priority rule applied | Should Have |
| TC-14.2.4 | Update rule | Change margin from 5% to 10% | New margin used for calculations | Should Have |
| TC-14.2.5 | Delete rule | Remove category rule | Fallback to default rule | Should Have |

#### 15.4.3 Price Change Workflow

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-14.3.1 | Create pending change | Price diff > 2% | Pending change saved | Must Have |
| TC-14.3.2 | Approve change | Approve pending change | Price updated, change logged | Must Have |
| TC-14.3.3 | Reject change | Reject with reason | Change rejected, reason logged | Should Have |
| TC-14.3.4 | Auto-apply | Auto-apply enabled | Price updated without approval | Should Have |
| TC-14.3.5 | Bulk approval | Select multiple changes | All selected changes applied | Could Have |

#### 15.4.4 Price History

| Test ID | Description | Input | Expected Output | Priority |
|---------|-------------|-------|-----------------|----------|
| TC-14.4.1 | Log price change | Price updated | Entry added to history | Must Have |
| TC-14.4.2 | 90-day retention | Old entries | Entries > 90 days deleted | Should Have |
| TC-14.4.3 | Query history | Get last 30 changes | Returns 30 most recent entries | Should Have |
| TC-14.4.4 | Trend calculation | Price history | Shows price trend over time | Could Have |

---

## 16. Technical Specifications

### 16.1 Firestore Schema

#### 16.1.1 Products Collection

```javascript
// products/{productId}
{
  // Existing fields...
  expiryDate: Timestamp,              // Feature 13
  discountPercentage: Number,         // Feature 13
  originalPrice: Number,              // Feature 13
  isOnSale: Boolean,                  // Feature 13
  costPrice: Number,                  // Feature 14
  competitorPrices: Map,              // Feature 14
  pricingStrategy: String,            // Feature 14
  lastPriceUpdate: Timestamp,         // Feature 14
  // Subcollections...
  sales_history: subcollection        // Feature 12
  discount_history: subcollection     // Feature 13
  price_history: subcollection       // Feature 14
}
```

#### 16.1.2 Sales History Subcollection

```javascript
// products/{productId}/sales_history/{historyId}
{
  quantity: Number,                   // Units sold
  createdAt: Timestamp,              // Sale timestamp
  orderId: String,                   // Reference to order
  shopId: String                     // Shop identifier
}
```

#### 16.1.3 Discount History Subcollection

```javascript
// products/{productId}/discount_history/{historyId}
{
  previousDiscount: Number,          // Old discount percentage
  newDiscount: Number,               // New discount percentage
  reason: String,                    // 'expiry_dynamic' or 'manual_override'
  hoursUntilExpiry: Number,          // Feature 13
  createdAt: Timestamp
}
```

#### 16.1.4 Price History Subcollection

```javascript
// products/{productId}/price_history/{historyId}
{
  oldPrice: Number,                  // Previous price
  newPrice: Number,                  // New price
  reason: String,                    // 'competitor_price_match' or 'manual'
  createdAt: Timestamp
}
```

#### 16.1.5 Inventory Alerts Collection

```javascript
// shops/{shopId}/inventory_alerts/{productId}
{
  productId: String,
  productName: String,
  currentStock: Number,
  dailyVelocity: Number,
  daysUntilStockout: Number,
  trend: String,                     // 'increasing', 'decreasing', 'stable'
  confidence: Number,
  reorderQuantity: Number,
  severity: Number,                  // 1-5
  createdAt: Timestamp,
  status: String                     // 'active', 'actioned', 'dismissed'
}
```

#### 16.1.6 Competitor Prices Collection

```javascript
// shops/{shopId}/competitor_prices/{docId}
{
  productName: String,
  competitorName: String,
  price: Number,
  category: String,
  updatedAt: Timestamp
}
```

#### 16.1.7 Pricing Rules Collection

```javascript
// shops/{shopId}/pricing_rules/{ruleId}
{
  name: String,
  strategy: String,                  // 'beat', 'match', 'premium', 'cost_plus'
  margin: Number,                    // Percentage
  category: String,                  // Optional, null for default
  isDefault: Boolean,
  priority: Number,
  updatedAt: Timestamp
}
```

#### 16.1.8 Price Alerts Collection

```javascript
// shops/{shopId}/price_alerts/{productId}
{
  productId: String,
  productName: String,
  currentPrice: Number,
  newPrice: Number,
  changePercentage: Number,
  reason: String,
  status: String,                    // 'pending', 'approved', 'rejected'
  createdAt: Timestamp
}
```

#### 16.1.9 WhatsApp Processed Collection

```javascript
// whatsapp_processed/{messageId}
{
  from: String,                      // Phone number
  processedAt: Timestamp
}
```

#### 16.1.10 Expiry Logs Collection

```javascript
// shops/{shopId}/expiry_logs/{logId}
{
  productId: String,
  action: String,                    // 'expiry_date_set', 'marked_expired', 'discount_applied'
  expiryDate: Timestamp,             // Optional
  timestamp: Timestamp
}
```

### 16.2 Firebase Functions

#### 16.2.1 WhatsApp Webhook Function

```javascript
// functions/index.js
exports.whatsappWebhook = functions.https.onRequest(async (req, res) => {
  // Verify webhook
  // Process incoming messages
  // Call WhatsAppSyncService
  // Send responses
});
```

#### 16.2.2 Scheduled Functions

```javascript
// Hourly inventory check (Feature 12)
exports.hourlyInventoryCheck = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async (context) => {
    // Check all shops for low stock
    // Send notifications
  });

// Hourly expiry check (Feature 13)
exports.hourlyExpiryCheck = functions.pubsub
  .schedule('every 60 minutes')
  .onRun(async (context) => {
    // Check products for expiry
    // Apply dynamic discounts
    // Send notifications
  });

// Daily price analysis (Feature 14)
exports.dailyPriceAnalysis = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    // Analyze competitor prices
    // Generate price recommendations
    // Send notifications
  });
```

### 16.3 API Endpoints

#### 16.3.1 WhatsApp Webhook

```
POST /whatsapp-webhook
Headers:
  Content-Type: application/json
Body:
{
  "entry": [{
    "changes": [{
      "value": {
        "messages": [{
          "from": "919999999999",
          "id": "message_id",
          "timestamp": "1234567890",
          "type": "text" | "image" | "document",
          "text": { "body": "message text" },
          "image": { "id": "media_id" },
          "document": { "id": "media_id", "mime_type": "type" }
        }]
      }
    }]
  }]
}
Response: 200 OK
```

#### 16.3.2 Inventory Alerts API

```
GET /api/shops/{shopId}/alerts
Response:
{
  "alerts": [{
    "productId": "string",
    "productName": "string",
    "currentStock": number,
    "daysUntilStockout": number,
    "severity": number,
    "reorderQuantity": number
  }],
  "healthScore": number
}

POST /api/shops/{shopId}/alerts/{productId}/dismiss
Response: 200 OK

POST /api/shops/{shopId}/alerts/{productId}/actioned
Response: 200 OK
```

#### 16.3.3 Pricing API

```
GET /api/shops/{shopId}/pricing-rules
Response:
{
  "rules": [{
    "id": "string",
    "name": "string",
    "strategy": "string",
    "margin": number,
    "category": "string"
  }]
}

POST /api/shops/{shopId}/pricing-rules
Body:
{
  "name": "string",
  "strategy": "string",
  "margin": number,
  "category": "string"
}
Response: 200 OK with rule ID

GET /api/shops/{shopId}/price-changes/pending
Response:
{
  "changes": [{
    "productId": "string",
    "productName": "string",
    "currentPrice": number,
    "newPrice": number,
    "changePercentage": number
  }]
}

POST /api/shops/{shopId}/price-changes/{productId}/approve
Response: 200 OK

POST /api/shops/{shopId}/price-changes/{productId}/reject
Body: { "reason": "string" }
Response: 200 OK
```

### 16.4 Data Models

#### 16.4.1 Competitor Price Model

```dart
class CompetitorPrice {
  final String productName;
  final String competitorName;
  final double price;
  final String? category;
  final DateTime updatedAt;

  CompetitorPrice({
    required this.productName,
    required this.competitorName,
    required this.price,
    this.category,
    required this.updatedAt,
  });

  factory CompetitorPrice.fromMap(Map<String, dynamic> map) {
    return CompetitorPrice(
      productName: map['productName'] ?? '',
      competitorName: map['competitorName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'],
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'competitorName': competitorName,
      'price': price,
      'category': category,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
```

#### 16.4.2 Pricing Rule Model

```dart
class PricingRule {
  final String id;
  final String name;
  final PricingStrategy strategy;
  final double margin;
  final String? category;
  final bool isDefault;
  final int priority;
  final DateTime updatedAt;

  PricingRule({
    required this.id,
    required this.name,
    required this.strategy,
    required this.margin,
    this.category,
    this.isDefault = false,
    this.priority = 0,
    required this.updatedAt,
  });

  factory PricingRule.fromMap(String id, Map<String, dynamic> map) {
    return PricingRule(
      id: id,
      name: map['name'] ?? '',
      strategy: PricingStrategy.values.firstWhere(
        (e) => e.toString() == 'PricingStrategy.${map['strategy']}',
        orElse: () => PricingStrategy.match,
      ),
      margin: (map['margin'] ?? 0.05).toDouble(),
      category: map['category'],
      isDefault: map['isDefault'] ?? false,
      priority: map['priority'] ?? 0,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}

enum PricingStrategy {
  beat,      // Price below lowest competitor
  match,     // Match lowest competitor
  premium,   // Price above competitors
  costPlus,  // Cost + margin
}
```

#### 16.4.3 Inventory Alert Model

```dart
class InventoryAlert {
  final String productId;
  final String productName;
  final int currentStock;
  final int dailyVelocity;
  final int daysUntilStockout;
  final SalesTrend trend;
  final double confidence;
  final int reorderQuantity;
  final int severity;
  final DateTime createdAt;
  final AlertStatus status;

  InventoryAlert({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.dailyVelocity,
    required this.daysUntilStockout,
    required this.trend,
    required this.confidence,
    required this.reorderQuantity,
    required this.severity,
    required this.createdAt,
    this.status = AlertStatus.active,
  });

  factory InventoryAlert.fromMap(String id, Map<String, dynamic> map) {
    return InventoryAlert(
      productId: id,
      productName: map['productName'] ?? '',
      currentStock: map['currentStock'] ?? 0,
      dailyVelocity: map['dailyVelocity'] ?? 0,
      daysUntilStockout: map['daysUntilStockout'] ?? 999,
      trend: SalesTrend.values.firstWhere(
        (e) => e.toString() == 'SalesTrend.${map['trend']}',
        orElse: () => SalesTrend.stable,
      ),
      confidence: (map['confidence'] ?? 0.5).toDouble(),
      reorderQuantity: map['reorderQuantity'] ?? 0,
      severity: map['severity'] ?? 1,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: AlertStatus.values.firstWhere(
        (e) => e.toString() == 'AlertStatus.${map['status']}',
        orElse: () => AlertStatus.active,
      ),
    );
  }
}

enum SalesTrend {
  increasing,
  decreasing,
  stable,
}

enum AlertStatus {
  active,
  actioned,
  dismissed,
}
```

---

## 17. Implementation Checklist

### 17.1 Feature 11: WhatsApp Sync

- [ ] 11.1 Create Firebase Functions webhook
  - [ ] Set up Express.js server
  - [ ] Implement webhook verification
  - [ ] Handle message parsing
  - [ ] Implement error handling
  - [ ] Add logging

- [ ] 11.2 Implement text message processing
  - [ ] Integrate Gemini AI for parsing
  - [ ] Handle item extraction
  - [ ] Validate extracted data
  - [ ] Send confirmation messages

- [ ] 11.3 Implement image processing
  - [ ] Download media from WhatsApp
  - [ ] Enhance image quality
  - [ ] Integrate OCR (Gemini Vision)
  - [ ] Parse bill items

- [ ] 11.4 Implement shop identification
  - [ ] Phone number normalization
  - [ ] Firestore lookup
  - [ ] New shop creation flow

- [ ] 11.5 Add WhatsApp configuration UI
  - [ ] Settings screen
  - [ ] Phone number input
  - [ ] Connection status display

- [ ] 11.6 Add notification integration
  - [ ] Push notification on new items
  - [ ] WhatsApp confirmation messages
  - [ ] Error notification flow

### 17.2 Feature 12: Inventory Alerts

- [ ] 12.1 Integrate with ProductProvider
  - [ ] Add recordSale() method
  - [ ] Call on order completion
  - [ ] Update sales history

- [ ] 12.2 Implement sales velocity calculation
  - [ ] Query 30-day sales history
  - [ ] Calculate average daily sales
  - [ ] Implement trend detection
  - [ ] Calculate confidence score

- [ ] 12.3 Implement stockout prediction
  - [ ] Calculate days until stockout
  - [ ] Apply trend adjustment
  - [ ] Generate reorder recommendations

- [ ] 12.4 Create alert generation system
  - [ ] Check all products
  - [ ] Categorize by severity
  - [ ] Save alerts to Firestore

- [ ] 12.5 Add Owner Dashboard widgets
  - [ ] Low stock alert count
  - [ ] Inventory health score
  - [ ] Critical items list
  - [ ] Health trend indicator

- [ ] 12.6 Create scheduled function
  - [ ] Hourly cron job
  - [ ] Process all shops
  - [ ] Send notifications

- [ ] 12.7 Create Inventory Alerts screen
  - [ ] List all alerts
  - [ ] Filter by severity
  - [ ] Dismiss/action buttons
  - [ ] Reorder quantity display

### 17.3 Feature 13: Expiry Checker

- [ ] 13.1 Add expiry date picker to AddProductScreen
  - [ ] Date picker component
  - [ ] Validation (future dates only)
  - [ ] Optional field handling
  - [ ] Save to Firestore

- [ ] 13.2 Implement dynamic discount calculation
  - [ ] Calculate based on hours remaining
  - [ ] Apply minimum/maximum limits
  - [ ] Prevent discount decrease

- [ ] 13.3 Implement discount application
  - [ ] Update product price
  - [ ] Set isOnSale flag
  - [ ] Log discount history
  - [ ] Preserve original price

- [ ] 13.4 Update ProductCard display
  - [ ] Show discount badge
  - [ ] Display original and discounted price
  - [ ] Show "Expires in X hours"
  - [ ] Handle expired products

- [ ] 13.5 Create scheduled function
  - [ ] Hourly cron job
  - [ ] Check all products
  - [ ] Apply discounts
  - [ ] Mark expired products

- [ ] 13.6 Add expiry notifications
  - [ ] 24-hour warning
  - [ ] 72-hour warning
  - [ ] Expired product alert

- [ ] 13.7 Create Expiry Management screen
  - [ ] List expiring products
  - [ ] Show discount history
  - [ ] Manual discount override
  - [ ] Reset discount option

### 17.4 Feature 14: Pricing Engine

- [ ] 14.1 Add cost price field to AddProductScreen
  - [ ] Input field
  - [ ] Validation
  - [ ] Save to Firestore

- [ ] 14.2 Add competitor price input
  - [ ] Competitor name field
  - [ ] Price field
  - [ ] Add/remove competitors
  - [ ] Save to Firestore

- [ ] 14.3 Add pricing strategy selector
  - [ ] Dropdown with options
  - [ ] Margin percentage input
  - [ ] Category-specific rules

- [ ] 14.4 Implement price calculation
  - [ ] Get competitor prices
  - [ ] Apply pricing strategy
  - [ ] Ensure minimum margin
  - [ ] Round to nearest rupee

- [ ] 14.5 Implement price change workflow
  - [ ] Detect price difference
  - [ ] Create pending change
  - [ ] Send notification
  - [ ] Handle approval/rejection

- [ ] 14.6 Create Pricing Rules screen
  - [ ] List current rules
  - [ ] Add new rule
  - [ ] Edit existing rule
  - [ ] Delete rule
  - [ ] Set default rule

- [ ] 14.7 Create Pending Price Changes screen
  - [ ] List pending changes
  - [ ] Show current vs new price
  - [ ] Approve button
  - [ ] Reject with reason
  - [ ] Bulk actions

- [ ] 14.8 Create scheduled function
  - [ ] Daily price analysis
  - [ ] Generate recommendations
  - [ ] Send notifications

- [ ] 14.9 Add price analytics
  - [ ] Price comparison report
  - [ ] Market position display
  - [ ] Competitor coverage
  - [ ] Price trend chart

---

## 18. Resource Requirements

### 18.1 Development Resources

| Resource | Quantity | Duration |
|----------|----------|----------|
| Senior Flutter Developer | 1 | 8 weeks |
| Firebase Developer | 1 | 4 weeks |
| UI/UX Designer | 1 (part-time) | 2 weeks |
| QA Engineer | 1 (part-time) | 4 weeks |
| Project Manager | 1 (part-time) | 8 weeks |

### 18.2 Infrastructure Requirements

| Resource | Specification | Quantity |
|----------|---------------|----------|
| Firebase Functions | 2nd gen, 2GB memory | 10,000 invocations/day |
| Firestore | Read/write capacity | 100,000 ops/day |
| Firebase Storage | Image storage | 10GB |
| Gemini API | Vision and Text | 10,000 calls/day |
| WhatsApp Business API | Meta Business subscription | 1 account |

### 18.3 External Services

| Service | Purpose | Cost Estimate |
|---------|---------|---------------|
| WhatsApp Business API | Message processing | $0.01/message |
| Gemini API | AI processing | $0.001/1K tokens |
| Google Maps API | Location services (optional) | $0.005/call |

---

## 19. Training and Support Plan

### 19.1 Shop Owner Training

| Topic | Format | Duration |
|-------|--------|----------|
| WhatsApp Sync Basics | Video tutorial | 10 min |
| Inventory Alerts Overview | Video tutorial | 8 min |
| Expiry Tracking Guide | Video tutorial | 12 min |
| Pricing Strategy Guide | Video tutorial | 15 min |
| Full Platform Training | Live webinar | 60 min |

### 19.2 Support Channels

- In-app chat support
- WhatsApp support line
- Email support (24-hour response)
- FAQ documentation
- Video tutorial library

### 19.3 Onboarding Timeline

| Day | Activity |
|-----|----------|
| Day 1 | Account setup and verification |
| Day 2 | Product catalog import |
| Day 3 | WhatsApp sync configuration |
| Day 4 | Inventory alerts setup |
| Day 5 | Pricing rules configuration |
| Day 6 | Staff training |
| Day 7 | Go-live and monitoring |

---

**Document Version**: 1.1  
**Last Updated**: 2026-05-20  
**Status**: Complete - Ready for Design Phase**

---

## Next Steps

1. **Review Requirements**: Stakeholder review of requirements document
2. **Create Design Document**: Technical design with system diagrams and data models
3. **Create invoke_sub_agent List**: Detailed implementation tasks with dependencies
4. **Begin Implementation**: Start with Phase 1 (Core Integration)