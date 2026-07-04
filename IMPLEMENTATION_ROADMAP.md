# FUFAJI STORE — IMPLEMENTATION ROADMAP & CODE TEMPLATES

## Quick Summary

**Status**: 45/119 endpoints (38%)
**Production Ready**: NO (Missing delivery + admin)
**Recommendation**: Launch with manual delivery, build delivery system in Phase 1

---

## PHASE 0: Pre-Launch Fixes (This Week)

### Task 1: Fix Remaining Wiring Issues
**Status**: 70% complete

**Remaining fixes**:
1. ✅ Supabase service wrapper - DONE
2. ✅ Firebase integration - DONE
3. ✅ Sync queue - DONE
4. ✅ Payment webhook - DONE
5. ⏳ Add Firestore trigger functions (optional, can use sync queue)
6. ⏳ Test complete checkout flow end-to-end

**Estimate**: 2 hours

---

### Task 2: Create Delivery Database Schema
**Status**: Not started

**Database migrations needed**:
```sql
-- Migration: 08_add_delivery_system.sql

CREATE TABLE delivery_riders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  vehicle_type TEXT,
  vehicle_number TEXT,
  status TEXT DEFAULT 'inactive', -- inactive, active, on_delivery, break
  current_latitude FLOAT,
  current_longitude FLOAT,
  rating FLOAT DEFAULT 5.0,
  total_deliveries INT DEFAULT 0,
  earnings DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE delivery_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  rider_id UUID REFERENCES delivery_riders(id),
  assigned_at TIMESTAMP DEFAULT NOW(),
  pickup_at TIMESTAMP,
  delivered_at TIMESTAMP,
  status TEXT DEFAULT 'pending', -- pending, assigned, picked_up, in_transit, delivered, cancelled
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE delivery_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id UUID NOT NULL REFERENCES delivery_assignments(id),
  latitude FLOAT NOT NULL,
  longitude FLOAT NOT NULL,
  timestamp TIMESTAMP DEFAULT NOW(),
  status TEXT
);

CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id),
  user_id UUID NOT NULL REFERENCES users(id),
  rating INT CHECK (rating >= 1 AND rating <= 5),
  title TEXT,
  comment TEXT,
  helpful_count INT DEFAULT 0,
  unhelpful_count INT DEFAULT 0,
  verified_purchase BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE ratings_summary (
  product_id UUID PRIMARY KEY REFERENCES products(id),
  average_rating FLOAT,
  total_reviews INT DEFAULT 0,
  rating_1_count INT DEFAULT 0,
  rating_2_count INT DEFAULT 0,
  rating_3_count INT DEFAULT 0,
  rating_4_count INT DEFAULT 0,
  rating_5_count INT DEFAULT 0,
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  type TEXT, -- percentage, fixed_amount
  discount_value DECIMAL(10,2),
  max_usage INT,
  used_count INT DEFAULT 0,
  valid_from TIMESTAMP,
  valid_to TIMESTAMP,
  min_order_value DECIMAL(10,2),
  max_discount DECIMAL(10,2),
  created_by UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE order_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  event_type TEXT, -- created, confirmed, packed, shipped, delivered, cancelled
  timestamp TIMESTAMP DEFAULT NOW(),
  details JSONB
);

-- Indexes for performance
CREATE INDEX idx_delivery_riders_status ON delivery_riders(status);
CREATE INDEX idx_delivery_assignments_order ON delivery_assignments(order_id);
CREATE INDEX idx_delivery_assignments_rider ON delivery_assignments(rider_id);
CREATE INDEX idx_reviews_product ON reviews(product_id);
CREATE INDEX idx_reviews_user ON reviews(user_id);
CREATE INDEX idx_order_events_order ON order_events(order_id);
```

**Estimate**: 1 hour

---

### Task 3: Create Reviews Service
**Status**: Not started

**File**: `backend/src/services/ReviewService.js`

```javascript
const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');

class ReviewService {
  /**
   * Post a review for a product
   */
  static async postReview({
    productId,
    userId,
    rating,
    title,
    comment,
    verifiedPurchase = false
  }) {
    if (rating < 1 || rating > 5) {
      throw new Error('Rating must be between 1 and 5');
    }

    const reviewId = uuidv4();
    
    return await pool.transaction(async (client) => {
      // Insert review
      const review = await client.query(
        `INSERT INTO reviews (id, product_id, user_id, rating, title, comment, verified_purchase)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [reviewId, productId, userId, rating, title, comment, verifiedPurchase]
      );

      // Update ratings summary
      await this.updateRatingSummary(client, productId);

      return review.rows[0];
    });
  }

  /**
   * Get product reviews
   */
  static async getProductReviews(productId, { limit = 10, offset = 0 }) {
    const result = await pool.query(
      `SELECT r.*, u.name, u.avatar_url
       FROM reviews r
       LEFT JOIN users u ON r.user_id = u.id
       WHERE r.product_id = $1
       ORDER BY r.created_at DESC
       LIMIT $2 OFFSET $3`,
      [productId, limit, offset]
    );

    return result.rows;
  }

  /**
   * Update ratings summary after new review
   */
  static async updateRatingSummary(client, productId) {
    const stats = await client.query(
      `SELECT 
         COUNT(*) as total_reviews,
         AVG(rating) as average_rating,
         SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1_count,
         SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2_count,
         SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3_count,
         SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4_count,
         SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5_count
       FROM reviews
       WHERE product_id = $1`,
      [productId]
    );

    const data = stats.rows[0];

    await client.query(
      `INSERT INTO ratings_summary (product_id, total_reviews, average_rating, rating_1_count, rating_2_count, rating_3_count, rating_4_count, rating_5_count)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (product_id) DO UPDATE SET
         total_reviews = $2,
         average_rating = $3,
         rating_1_count = $4,
         rating_2_count = $5,
         rating_3_count = $6,
         rating_4_count = $7,
         rating_5_count = $8,
         updated_at = NOW()`,
      [productId, data.total_reviews, data.average_rating, data.rating_1_count, data.rating_2_count, data.rating_3_count, data.rating_4_count, data.rating_5_count]
    );
  }
}

module.exports = ReviewService;
```

**Routes file**: `backend/src/routes/reviews.js`

```javascript
const express = require('express');
const router = express.Router();
const ReviewService = require('../services/ReviewService');
const { authMiddleware } = require('../middleware/validation');

// GET product reviews
router.get('/product/:productId', async (req, res) => {
  try {
    const { productId } = req.params;
    const { limit = 10, offset = 0 } = req.query;

    const reviews = await ReviewService.getProductReviews(productId, { limit, offset });
    res.json({ success: true, data: reviews });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST review
router.post('/product/:productId', authMiddleware, async (req, res) => {
  try {
    const { productId } = req.params;
    const { rating, title, comment } = req.body;
    const userId = req.user.id;

    const review = await ReviewService.postReview({
      productId, userId, rating, title, comment, verifiedPurchase: true
    });

    res.json({ success: true, data: review });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

module.exports = router;
```

**Estimate**: 3 hours

---

### Task 4: Create Delivery Service (Basic)
**Status**: Not started

**File**: `backend/src/services/DeliveryService.js`

```javascript
const pool = require('../db/pool');
const { v4: uuidv4 } = require('uuid');
const firebaseAdmin = require('./firebaseAdmin');

class DeliveryService {
  /**
   * Assign order to rider
   */
  static async assignRider(orderId, riderId) {
    const assignmentId = uuidv4();

    return await pool.transaction(async (client) => {
      const assignment = await client.query(
        `INSERT INTO delivery_assignments (id, order_id, rider_id, status)
         VALUES ($1, $2, $3, 'assigned')
         RETURNING *`,
        [assignmentId, orderId, riderId]
      );

      // Update order status
      await client.query(
        `UPDATE orders SET status = 'assigned' WHERE id = $1`,
        [orderId]
      );

      // Emit event for notifications
      await EventBus.publishEvent({
        event_type: 'DELIVERY_ASSIGNED',
        aggregate_id: orderId,
        payload: { riderId, assignmentId }
      });

      return assignment.rows[0];
    });
  }

  /**
   * Update rider location (from GPS)
   */
  static async updateRiderLocation(riderId, latitude, longitude) {
    // Update rider current location
    await pool.query(
      `UPDATE delivery_riders 
       SET current_latitude = $2, current_longitude = $3, updated_at = NOW()
       WHERE id = $1`,
      [riderId, latitude, longitude]
    );

    // Find active assignment for this rider
    const assignment = await pool.query(
      `SELECT id FROM delivery_assignments 
       WHERE rider_id = $1 AND status IN ('assigned', 'picked_up', 'in_transit')
       ORDER BY created_at DESC LIMIT 1`,
      [riderId]
    );

    if (assignment.rows.length > 0) {
      // Log tracking point
      await pool.query(
        `INSERT INTO delivery_tracking (assignment_id, latitude, longitude)
         VALUES ($1, $2, $3)`,
        [assignment.rows[0].id, latitude, longitude]
      );

      // Broadcast location to Firestore (real-time)
      const db = firebaseAdmin.db();
      await db.collection('delivery_tracking').doc(assignment.rows[0].id).set({
        riderId,
        latitude,
        longitude,
        timestamp: new Date(),
        assignmentId: assignment.rows[0].id
      });
    }
  }

  /**
   * Mark delivery as completed
   */
  static async markDelivered(assignmentId) {
    return await pool.transaction(async (client) => {
      const result = await client.query(
        `UPDATE delivery_assignments 
         SET status = 'delivered', delivered_at = NOW()
         WHERE id = $1
         RETURNING order_id`,
        [assignmentId]
      );

      const orderId = result.rows[0].order_id;

      // Update order
      await client.query(
        `UPDATE orders SET status = 'delivered', delivered_at = NOW()
         WHERE id = $1`,
        [orderId]
      );

      // Emit event
      await EventBus.publishEvent({
        event_type: 'ORDER_DELIVERED',
        aggregate_id: orderId,
        payload: { assignmentId }
      });
    });
  }
}

module.exports = DeliveryService;
```

**Routes file**: `backend/src/routes/delivery.js`

```javascript
const express = require('express');
const router = express.Router();
const DeliveryService = require('../services/DeliveryService');
const { authMiddleware } = require('../middleware/validation');

// POST assign rider to order (admin only)
router.post('/:orderId/assign', authMiddleware, async (req, res) => {
  try {
    const { orderId } = req.params;
    const { riderId } = req.body;

    const assignment = await DeliveryService.assignRider(orderId, riderId);
    res.json({ success: true, data: assignment });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

// PUT update rider location (from mobile app)
router.put('/update-location', authMiddleware, async (req, res) => {
  try {
    const { latitude, longitude } = req.body;
    const riderId = req.user.id;

    await DeliveryService.updateRiderLocation(riderId, latitude, longitude);
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

// POST mark delivered
router.post('/:assignmentId/mark-delivered', authMiddleware, async (req, res) => {
  try {
    const { assignmentId } = req.params;
    await DeliveryService.markDelivered(assignmentId);
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

module.exports = router;
```

**Estimate**: 5 hours

---

## PHASE 1: Post-Launch (Next 2 Weeks)

### 1. Complete Delivery System
- GPS tracking dashboard
- Route optimization
- Rider earnings calculation
- Multi-rider assignment

**Estimate**: 12 hours

### 2. Admin Dashboard
- Sales metrics
- Order analytics
- Delivery reports
- System settings

**Estimate**: 8 hours

### 3. Enhanced Notifications
- Template system
- Scheduled sends
- Broadcast to users

**Estimate**: 4 hours

### 4. Coupons & Discounts
- Coupon validation
- Discount calculation
- Usage tracking

**Estimate**: 3 hours

---

## PHASE 2: Advanced Features (Week 3-4)

### 1. Shipping Calculation
- Distance-based pricing
- Weight-based pricing
- Service area validation

**Estimate**: 4 hours

### 2. Multi-Location Inventory
- Stock transfers
- Location-specific pricing
- Fulfillment from nearest warehouse

**Estimate**: 6 hours

### 3. Loyalty Program
- Points tracking
- Redemption
- Tier benefits

**Estimate**: 5 hours

### 4. Referral System
- Referral links
- Reward tracking
- Payout management

**Estimate**: 4 hours

---

## Testing & QA Checklist

### Unit Tests Needed
- [ ] ReviewService
- [ ] DeliveryService
- [ ] CouponService
- [ ] AdminService

### Integration Tests
- [ ] Complete checkout → delivery assignment flow
- [ ] Payment webhook → order → delivery
- [ ] Firestore sync after each step

### E2E Tests
- [ ] Full customer journey (signup → checkout → delivery → rating)
- [ ] Admin operations (create, update, delete products/orders)
- [ ] Rider mobile app (location updates, delivery completion)

---

## Deployment Checklist

Before going live:
- [ ] All 119 endpoints implemented
- [ ] Database migrations applied
- [ ] Firestore security rules updated
- [ ] Error handling tested
- [ ] Rate limiting configured
- [ ] Monitoring/alerts set up
- [ ] Backup strategy in place
- [ ] Rollback plan documented
- [ ] Customer support trained

