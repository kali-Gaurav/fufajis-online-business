/// ============================================================================
/// FUFAJI RAZORPAY PAYMENT COMPLETE REQUEST/RESPONSE LOGIC
/// ============================================================================
///
/// This file documents the complete payment flow from order creation through
/// payment verification, webhook handling, and refunds. This serves as the
/// definitive specification for the payment system.
///
/// Architecture:
/// - Mobile App: Initiates order, collects payment, submits verification
/// - Backend API: Creates orders, manages inventory, verifies payments
/// - Razorpay API: Processes payments, returns payment ID + signature
/// - PostgreSQL: Stores orders, payments, refunds (source of truth)
/// - Firestore: Real-time order sync (read-only, PostgreSQL is primary)
/// - Redis: Caching, rate limiting, order reservations
///
/// ============================================================================
library;

// ignore_for_file: unused_element, empty_function_body

/// ============================================================================
/// SECTION 1: CREATE ORDER (MOBILE APP → BACKEND)
/// ============================================================================
///
/// REQUEST: POST /api/orders/create
///
/// REQUEST FORMAT:
/// {
///   "items": [
///     {
///       "productId": "prod-123",
///       "quantity": 2,
///       "price": 199.99
///     },
///     {
///       "productId": "prod-456",
///       "quantity": 1,
///       "price": 49.99
///     }
///   ],
///   "deliveryAddress": {
///     "line": "123 Main St, Apt 4B",
///     "city": "Delhi",
///     "state": "Delhi",
///     "postalCode": "110001",
///     "lat": 28.7041,
///     "lng": 77.1025
///   },
///   "couponCode": "SAVE20",
///   "paymentMethod": "razorpay",
///   "deviceId": "device-uuid-123"
/// }
///
/// VALIDATION LOGIC:
/// 1. Authentication:
///    - JWT token valid
///    - User not suspended
///    - User exists in system
///
/// 2. Items:
///    - Not empty (at least 1 item)
///    - Each item has: productId, quantity > 0, price > 0
///    - Product IDs exist in PostgreSQL products table
///    - Prices match current product prices (prevent tampering)
///    - Quantities don't exceed limits (e.g., max 100 per item)
///
/// 3. Delivery Address:
///    - All required fields present (line, city, state, postalCode)
///    - Coordinates valid (lat -90 to 90, lng -180 to 180)
///    - Coordinates within service area (calculated from lat/lng)
///    - Address string not too long (max 500 chars)
///
/// 4. Coupon (if provided):
///    - Coupon code exists in coupons table
///    - Coupon not expired
///    - Coupon active (not deleted/disabled)
///    - User meets coupon criteria (min order value, specific categories, etc.)
///    - User hasn't exceeded coupon usage limit (per-user usage)
///    - Coupon globally hasn't exceeded usage limit
///
/// 5. Payment Method:
///    - Must be "razorpay" (only option currently)
///    - Not empty
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "items": "Must include at least 1 item",
///       "deliveryAddress.lat": "Invalid latitude",
///       "couponCode": "Coupon not found or expired",
///       "paymentMethod": "Invalid payment method"
///     }
///   }
/// - 401 Unauthorized: {
///     "success": false,
///     "code": "INVALID_TOKEN",
///     "message": "Please log in to create an order"
///   }
/// - 403 Forbidden: {
///     "success": false,
///     "code": "ACCOUNT_SUSPENDED",
///     "message": "Cannot place orders with suspended account"
///   }
/// - 404 Not Found: {
///     "success": false,
///     "errors": {
///       "productId": "Product prod-123 not found"
///     }
///   }
/// - 409 Conflict: {
///     "success": false,
///     "code": "INSUFFICIENT_STOCK",
///     "message": "Requested quantity not available for prod-123",
///     "availableQuantity": 1
///   }
/// - 422 Unprocessable Entity: {
///     "success": false,
///     "code": "OUT_OF_SERVICE_AREA",
///     "message": "Delivery not available at this location",
///     "nearestServiceArea": "5km away"
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Verify JWT Token
///   - Extract token from Authorization header
///   - Verify signature with SECRET_KEY
///   - Extract uid, email, role from claims
///   - Check token not expired
///   - Check token not blacklisted
///   - If invalid: return 401
///
/// Step 2: Verify User Exists and Active
///   - Query PostgreSQL: SELECT * FROM users WHERE id = $1
///   - If not found: return 401 (data integrity issue)
///   - If status != 'active': return 403 "Account suspended"
///   - Extract user_id for later use
///
/// Step 3: Validate Items List
///   - Check items array not empty
///   - If empty: return 400 "Must include at least 1 item"
///   - For each item:
///     - Check productId not empty
///     - Check quantity > 0 and <= 100
///     - Check price > 0
///     - If invalid: return 400 with field errors
///
/// Step 4: Verify Products Exist and Prices Match
///   - For each item:
///     - Query: SELECT id, name, price, stock FROM products WHERE id = $1
///     - If not found: return 404 "Product not found"
///     - If price != request.price:
///       - This indicates price tampering attempt
///       - Log security event: "price_mismatch_attempt"
///       - Return 400 "Product price changed, please retry"
///     - Store product data for later calculation
///
/// Step 5: Check Inventory Availability
///   - For each item:
///     - Query: SELECT available_quantity FROM inventory WHERE product_id = $1
///     - If available_quantity < requested_quantity:
///       - return 409 with availableQuantity
///     - All items must have sufficient stock
///
/// Step 6: Validate Delivery Address
///   - Check all required fields present
///   - Validate latitude: -90 <= lat <= 90
///   - Validate longitude: -180 <= lng <= 180
///   - Validate coordinates format (decimal numbers)
///   - If any validation fails: return 400
///
/// Step 7: Check Service Area
///   - Query service_areas table (e.g., polygon or radius-based)
///   - Check if (lat, lng) falls within service area
///   - Use point-in-polygon algorithm if service areas are polygons
///   - If not in service area: return 422 "Out of service area"
///   - Extract delivery zone/area for pricing
///
/// Step 8: Validate Coupon (if provided)
///   - If couponCode not provided: skip this step
///   - Query: SELECT * FROM coupons WHERE code = UPPER($1)
///   - If not found: return 400 "Coupon not found"
///   - Check coupon.active = true
///   - Check coupon.expires_at > NOW()
///   - Check coupon.disabled = false
///   - If checks fail: return 400 with appropriate message
///
/// Step 9: Check Coupon Eligibility
///   - Check minimum order value:
///     - If subtotal < coupon.min_order_value:
///       - return 400 "Minimum order value for this coupon is ₹X"
///   - Check usage limits (per user):
///     - Query: COUNT(*) FROM order_coupons WHERE coupon_id = ? AND user_id = ?
///     - If count >= coupon.max_uses_per_user:
///       - return 400 "You've reached the usage limit for this coupon"
///   - Check global usage limits:
///     - Query: COUNT(*) FROM order_coupons WHERE coupon_id = ?
///     - If count >= coupon.max_uses_global:
///       - return 400 "Coupon reached maximum usage"
///   - If all checks pass: extract discount_type and discount_value
///
/// Step 10: Calculate Order Totals
///   - Calculate subtotal: sum(item.price * item.quantity)
///   - Calculate tax: subtotal * 0.05 (5% GST)
///   - Calculate delivery fee:
///     - Based on delivery zone from Step 7
///     - Typically: base_fee + (distance * per_km_rate)
///     - For MVP: fixed fee (e.g., 50 rupees)
///   - Calculate discount:
///     - If coupon provided:
///       - If discount_type == 'flat': discount = discount_value
///       - If discount_type == 'percentage': discount = subtotal * (discount_value / 100)
///       - Cap discount: cannot exceed (subtotal + tax)
///     - If no coupon: discount = 0
///   - Calculate final total:
///     - total = subtotal + tax + delivery - discount
///     - Round to 2 decimal places
///   - Ensure total > 0 (shouldn't happen, but check)
///
/// Step 11: Reserve Inventory
///   - For each item:
///     - INSERT INTO inventory_reservations (
///         product_id,
///         customer_id,
///         quantity,
///         order_id (null for now),
///         reserved_at,
///         expires_at  // NOW() + 30 minutes
///       ) VALUES (...)
///     - This ensures inventory is held for 30 minutes
///     - If customer doesn't complete payment, reservation expires
///
/// Step 12: Create Order in PostgreSQL
///   - INSERT INTO orders (
///       id,                              // UUID
///       customer_id,                     // from JWT
///       shop_id,                         // 1 (single shop for MVP)
///       delivery_address_line,
///       delivery_address_city,
///       delivery_address_state,
///       delivery_address_postal_code,
///       delivery_latitude,
///       delivery_longitude,
///       delivery_zone,                   // from Step 7
///       items,                           // JSON array
///       subtotal,                        // from Step 10
///       tax,                             // from Step 10
///       delivery_fee,                    // from Step 10
///       discount_amount,                 // from Step 10
///       coupon_id,                       // if coupon provided
///       total_amount,                    // from Step 10
///       payment_method,                  // 'razorpay'
///       payment_status,                  // 'pending'
///       order_status,                    // 'pending_payment'
///       notes,                           // nullable
///       created_at,
///       updated_at,
///       razorpay_order_id                // will be filled in next step
///     ) VALUES (...)
///   - Get order_id from INSERT RETURNING
///   - If INSERT fails: return 500 with error
///
/// Step 13: Update Inventory Reservations
///   - UPDATE inventory_reservations SET order_id = $1 WHERE customer_id = $2 AND order_id IS NULL
///   - Link reservations to the newly created order
///
/// Step 14: Create Razorpay Order
///   - Call Razorpay API:
///     POST https://api.razorpay.com/v1/orders
///     Headers:
///       Authorization: Basic base64(key_id:key_secret)
///       Content-Type: application/json
///     Body: {
///       "amount": total_amount_in_paise,  // Convert rupees to paise (* 100)
///       "currency": "INR",
///       "receipt": "order_{order_id}",    // Unique receipt ID
///       "payment_capture": 1,              // Auto-capture payment
///       "notes": {
///         "orderId": order_id,
///         "customerId": customer_id,
///         "shopId": 1
///       }
///     }
///   - Parse response:
///     {
///       "id": "order_7Oy8OMjw3bqnIZ",
///       "amount": 25000,
///       "currency": "INR",
///       "status": "created",
///       "attempts": 0
///     }
///   - Extract razorpay_order_id
///   - If API call fails:
///     - Log error with order details
///     - Delete order from PostgreSQL (rollback)
///     - Delete inventory reservations
///     - return 500 "Failed to create payment order"
///
/// Step 15: Update Order with Razorpay Order ID
///   - UPDATE orders SET razorpay_order_id = $1 WHERE id = $2
///   - If update fails: log error (payment order was created but not linked)
///
/// Step 16: Create Firestore Order Document (Non-blocking)
///   - In background/async:
///     - Create firestore doc: orders/{order_id}
///     - Fields:
///       {
///         "customerId": customer_id,
///         "items": items,
///         "subtotal": subtotal,
///         "tax": tax,
///         "deliveryFee": delivery_fee,
///         "discount": discount_amount,
///         "total": total_amount,
///         "paymentMethod": "razorpay",
///         "paymentStatus": "pending",
///         "status": "pending_payment",
///         "deliveryAddress": {lat, lng, ...},
///         "createdAt": FieldValue.serverTimestamp(),
///         "updatedAt": FieldValue.serverTimestamp()
///       }
///     - Enable real-time sync
///   - If Firestore fails: log but don't fail response (PostgreSQL is source of truth)
///
/// Step 17: Log Audit Event
///   - INSERT INTO audit_logs (
///       user_id: customer_id,
///       event_type: 'order',
///       event_name: 'order_created',
///       details: {order_id, total_amount, item_count},
///       ip_address: client_ip,
///       created_at: NOW()
///     )
///
/// Step 18: Return Success Response
///
/// SUCCESS RESPONSE (201 Created):
/// {
///   "success": true,
///   "order": {
///     "orderId": "order-123-abc",
///     "razorpayOrderId": "order_7Oy8OMjw3bqnIZ",
///     "amount": 25000,
///     "amountInRupees": 250.00,
///     "currency": "INR",
///     "items": [
///       {
///         "productId": "prod-123",
///         "name": "Product Name",
///         "quantity": 2,
///         "price": 199.99,
///         "subtotal": 399.98
///       }
///     ],
///     "subtotal": 449.97,
///     "tax": 22.50,
///     "deliveryFee": 50.00,
///     "discount": 0,
///     "total": 522.47,
///     "status": "pending_payment",
///     "paymentMethod": "razorpay",
///     "createdAt": "2026-06-28T10:30:00Z"
///   },
///   "razorpayKey": "rzp_live_xxxxx",
///   "message": "Order created. Proceed to payment."
/// }
///

Future<CreateOrderResponse> createOrder({
  required String jwt,
  required List<OrderItem> items,
  required DeliveryAddress deliveryAddress,
  String? couponCode,
  required String paymentMethod,
  String? deviceId,
  String? clientIp,
}) async {
  // VERIFY JWT TOKEN
  // Extract from Authorization header
  // Verify signature with SECRET_KEY
  // Extract uid, email, role
  // Check not expired, not blacklisted
  // If invalid: return 401

  // VERIFY USER EXISTS AND ACTIVE
  // Query: SELECT * FROM users WHERE id = uid
  // If not found: return 401
  // If status != 'active': return 403

  // VALIDATE ITEMS LIST
  // Check not empty
  // Check each item has productId, quantity > 0, price > 0
  // If invalid: return 400

  // VERIFY PRODUCTS EXIST AND PRICES MATCH
  // For each item:
  //   - Query: SELECT price FROM products WHERE id = productId
  //   - If not found: return 404
  //   - If price != request.price: return 400 (price tampering)

  // CHECK INVENTORY AVAILABILITY
  // For each item:
  //   - Query: SELECT available_quantity FROM inventory WHERE product_id = productId
  //   - If available < requested: return 409 with availableQuantity

  // VALIDATE DELIVERY ADDRESS
  // Check all required fields
  // Validate lat (-90 to 90), lng (-180 to 180)
  // If invalid: return 400

  // CHECK SERVICE AREA
  // Query service_areas table
  // Check if (lat, lng) in service area
  // If not: return 422 "Out of service area"

  // VALIDATE COUPON (if provided)
  // Query: SELECT * FROM coupons WHERE code = UPPER(couponCode)
  // If not found: return 400
  // Check: active, not expired, not disabled

  // CHECK COUPON ELIGIBILITY
  // Check min_order_value
  // Check per-user usage limit
  // Check global usage limit
  // If checks fail: return 400

  // CALCULATE ORDER TOTALS
  // subtotal = sum(price * quantity)
  // tax = subtotal * 0.05
  // delivery_fee = based on zone
  // discount = apply coupon if valid
  // total = subtotal + tax + delivery - discount

  // RESERVE INVENTORY
  // For each item:
  //   - INSERT into inventory_reservations
  //   - Expires in 30 minutes

  // CREATE ORDER IN POSTGRESQL
  // INSERT into orders table
  // Get order_id from INSERT RETURNING

  // UPDATE INVENTORY RESERVATIONS
  // Link reservations to order_id

  // CREATE RAZORPAY ORDER
  // Call Razorpay API: POST /v1/orders
  // amount in paise, currency INR, receipt unique
  // Extract razorpay_order_id
  // If fails: rollback order, delete reservations, return 500

  // UPDATE ORDER WITH RAZORPAY ORDER ID
  // UPDATE orders SET razorpay_order_id = razorpay_order_id

  // CREATE FIRESTORE DOCUMENT (async)
  // Create orders/{order_id} in Firestore
  // Enable real-time sync

  // LOG AUDIT EVENT
  // INSERT audit_logs: order_created

  // RETURN SUCCESS RESPONSE
  return CreateOrderResponse(
    success: true,
    order: OrderData(
      orderId: 'order-123-abc',
      razorpayOrderId: 'order_7Oy8OMjw3bqnIZ',
      amount: 25000,
      amountInRupees: 250.00,
      currency: 'INR',
      items: items,
      subtotal: 449.97,
      tax: 22.50,
      deliveryFee: 50.00,
      discount: 0,
      total: 522.47,
      status: 'pending_payment',
      paymentMethod: 'razorpay',
      createdAt: DateTime.now(),
    ),
    razorpayKey: 'rzp_live_xxxxx',
    message: 'Order created. Proceed to payment.',
  );
}

/// ============================================================================
/// SECTION 2: PAYMENT SUBMISSION (MOBILE APP → RAZORPAY)
/// ============================================================================
///
/// Note: This step happens entirely on the mobile app and at Razorpay.
/// Backend doesn't participate.
///
/// FLOW:
/// 1. App receives order details + razorpayOrderId from Step 1
/// 2. App extracts razorpayKey (public key) from response
/// 3. App opens Razorpay payment modal:
///    ```
///    Razorpay.open({
///      key: razorpayKey,
///      amount: order.amount (in paise),
///      currency: 'INR',
///      name: 'Fufaji Store',
///      description: 'Order #order-123',
///      order_id: razorpayOrderId,
///      prefill: {
///        email: user.email,
///        contact: user.phone
///      },
///      theme: {
///        color: '#FF5733'
///      }
///    })
///    ```
/// 4. User selects payment method:
///    - Credit/Debit card
///    - UPI
///    - Net Banking
///    - Wallet (Paytm, Amazon Pay, etc.)
///    - EMI (if available)
///
/// 5. User completes payment at Razorpay gateway
/// 6. Razorpay processes payment with payment processor (Visa, MasterCard, etc.)
/// 7. Payment succeeds or fails
/// 8. Razorpay returns payment details to app:
///    - razorpay_payment_id
///    - razorpay_order_id
///    - razorpay_signature
///    - method (payment method used)
///    - status
///
/// 9. App receives these details in callback
/// 10. App submits to backend for verification (see Section 3)
///

/// ============================================================================
/// SECTION 3: VERIFY PAYMENT (MOBILE APP → BACKEND)
/// ============================================================================
///
/// REQUEST: POST /api/payments/verify
///
/// REQUEST FORMAT:
/// {
///   "orderId": "order-123-abc",
///   "razorpayPaymentId": "pay_7Oy8OMjw3bqnIZ",
///   "razorpayOrderId": "order_7Oy8OMjw3bqnIZ",
///   "razorpaySignature": "9ef4dffbfd84f1318f6739a3ce19f9d85851857ae648f114332d8401e0949a3d"
/// }
///
/// VALIDATION LOGIC:
/// 1. All fields required and not empty
/// 2. Signature format: 64-character hex string
/// 3. Order exists in PostgreSQL
/// 4. Order not already paid
/// 5. Razorpay signature valid (HMAC-SHA256)
///
/// ERROR RESPONSES:
/// - 400 Bad Request: {
///     "success": false,
///     "errors": {
///       "razorpaySignature": "Invalid signature format (must be 64 hex chars)"
///     }
///   }
/// - 401 Unauthorized: {
///     "success": false,
///     "code": "INVALID_SIGNATURE",
///     "message": "Payment verification failed. This transaction is suspicious.",
///     "action": "contact_support"
///   }
/// - 404 Not Found: {
///     "success": false,
///     "code": "ORDER_NOT_FOUND",
///     "message": "Order not found"
///   }
/// - 409 Conflict: {
///     "success": false,
///     "code": "PAYMENT_ALREADY_PROCESSED",
///     "message": "Payment already processed for this order",
///     "order": {...}
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Verify JWT Token
///   - Extract and verify JWT
///   - Extract customer_id from claims
///   - If invalid: return 401
///
/// Step 2: Validate Input Fields
///   - Check orderId not empty
///   - Check razorpayPaymentId not empty
///   - Check razorpayOrderId not empty
///   - Check razorpaySignature not empty
///   - Check razorpaySignature is 64-char hex string: /^[0-9a-f]{64}$/i
///   - If any validation fails: return 400
///
/// Step 3: Get Order from PostgreSQL
///   - Query: SELECT * FROM orders WHERE id = $1
///   - If not found: return 404 "Order not found"
///   - Extract: customer_id, total_amount, payment_status, razorpay_order_id
///   - Verify order.customer_id == JWT.customer_id (user can only verify own orders)
///   - If mismatch: return 403 "Unauthorized access to order"
///
/// Step 4: Check Payment Status
///   - If order.payment_status = 'completed':
///     - return 409 "Payment already processed"
///     - Include existing order data
///   - If order.payment_status = 'failed':
///     - Allow retry (continue)
///   - If order.payment_status != 'pending':
///     - return 409 "Invalid order state for payment"
///
/// Step 5: Verify Razorpay Order ID Matches
///   - If order.razorpay_order_id != razorpayOrderId:
///     - This indicates tampering or wrong order
///     - Log security event: "payment_order_mismatch"
///     - return 401 "Order mismatch"
///
/// Step 6: Verify Payment Signature (CRITICAL SECURITY)
///   - This is the most important verification to prevent fraud
///   - Build body string: razorpay_order_id + "|" + razorpay_payment_id
///     - Example: "order_7Oy8OMjw3bqnIZ|pay_7Oy8OMjw3bqnIZ"
///   - Get Razorpay key_secret from environment:
///     - RAZORPAY_KEY_SECRET from encrypted env vars
///     - NEVER log this secret
///     - NEVER commit to repo
///   - Compute HMAC-SHA256:
///     ```
///     import crypto
///     hmac = crypto.createHmac('sha256', key_secret)
///     computed_signature = hmac.update(body).digest('hex')
///     ```
///   - Compare with provided signature (constant-time comparison):
///     ```
///     if (!isConstantTimeEqual(computed_signature, razorpaySignature)) {
///       // FRAUD ATTEMPT
///       log security event
///       return 401
///     }
///     ```
///   - Use constant-time comparison to prevent timing attacks:
///     - Convert both to byte arrays
///     - Compare byte-by-byte
///     - Don't short-circuit on first mismatch
///   - If signature invalid:
///     - Log: "payment_signature_verification_failed"
///     - Log: order details, payment details
///     - return 401 "Invalid signature"
///     - DO NOT provide details to help attacker debug
///
/// Step 7: Check for Duplicate Payment (Idempotency)
///   - Query: SELECT * FROM payment_transactions WHERE razorpay_payment_id = $1
///   - If found:
///     - This payment was already processed
///     - Return 200 with order data (idempotent - same result)
///     - Log: "payment_duplicate_request"
///     - Don't process again (avoid double-charging)
///
/// Step 8: Create Payment Transaction Record
///   - INSERT INTO payment_transactions (
///       id,                              // UUID
///       order_id,
///       customer_id,
///       razorpay_payment_id,
///       razorpay_order_id,
///       amount,                          // from order
///       currency,                        // 'INR'
///       payment_status,                  // 'authorized'
///       payment_method,                  // from Razorpay (card/upi/etc)
///       verified_at,                     // NOW()
///       webhook_received_at,             // NULL (will be updated by webhook)
///       signature_verified,              // true
///       created_at
///     ) VALUES (...)
///   - If INSERT fails: return 500 (log error)
///
/// Step 9: Deduct Inventory (ATOMIC)
///   - For each item in order:
///     - Call ATOMIC stored procedure to avoid race conditions:
///       ```
///       CALL process_order_deduct_inventory(
///         order_id => order_id,
///         product_id => item.product_id,
///         quantity => item.quantity
///       )
///       ```
///     - Stored procedure should:
///       1. DELETE FROM inventory_reservations WHERE order_id = $1
///       2. UPDATE inventory SET available_quantity -= quantity
///       3. Check: available_quantity >= 0 (still available)
///       4. If failed: throw error, transaction rolls back
///     - In transaction (SERIALIZABLE isolation level for maximum safety)
///   - If any item fails:
///     - All items rolled back
///     - Payment not marked as complete
///     - Return 409 "Insufficient inventory"
///
/// Step 10: Update Order Status
///   - UPDATE orders SET
///       payment_status = 'completed',
///       razorpay_payment_id = $1,
///       order_status = 'confirmed',
///       paid_at = NOW()
///     WHERE id = $2
///   - If update fails: return 500 (log error)
///
/// Step 11: Clear Inventory Reservations
///   - DELETE FROM inventory_reservations WHERE order_id = $1
///   - (Should already be deleted by stored procedure in Step 9)
///
/// Step 12: Sync to Firestore (Non-blocking, Async)
///   - In background task/queue:
///     - Update firestore doc: orders/{order_id}
///       - Set: status = 'confirmed', paymentStatus = 'completed'
///     - Create firestore doc: payment_transactions/{transaction_id}
///     - If Firestore fails: log but don't fail response
///       - PostgreSQL is source of truth
///       - Data will sync eventually
///
/// Step 13: Create Wallet Entry (for refunds)
///   - INSERT INTO wallet_transactions (
///       customer_id,
///       amount,                         // negative (debit)
///       type,                           // 'order_payment'
///       reference_id,                   // order_id
///       created_at
///     )
///   - This tracks payments for wallet/balance audit trail
///
/// Step 14: Send Push Notification
///   - Query: SELECT device_tokens FROM user_devices WHERE user_id = $1
///   - For each device token:
///     - Send push notification via FCM:
///       - Title: "Order Confirmed!"
///       - Body: "Your order #order-123 has been confirmed. Estimated delivery: 30-45 min"
///       - Payload: {orderId, type: 'order_confirmed'}
///   - If FCM fails: log but don't fail response
///
/// Step 15: Send Confirmation Email
///   - Query customer email
///   - Send via Sendgrid:
///     - Template: order_confirmation_email
///     - Subject: "Order Confirmed - #order-123"
///     - Include: order details, estimated delivery, tracking link
///   - If email fails: log but don't fail response
///
/// Step 16: Log Audit Event
///   - INSERT INTO audit_logs (
///       user_id: customer_id,
///       event_type: 'payment',
///       event_name: 'payment_verified',
///       details: {order_id, payment_id, amount},
///       ip_address: client_ip,
///       created_at: NOW()
///     )
///
/// SUCCESS RESPONSE (200 OK):
/// {
///   "success": true,
///   "order": {
///     "orderId": "order-123-abc",
///     "status": "confirmed",
///     "paymentStatus": "completed",
///     "total": 522.47,
///     "estimatedDelivery": "30-45 minutes"
///   },
///   "message": "Payment successful! Your order is confirmed."
/// }
///

Future<VerifyPaymentResponse> verifyPayment({
  required String jwt,
  required String orderId,
  required String razorpayPaymentId,
  required String razorpayOrderId,
  required String razorpaySignature,
  String? clientIp,
}) async {
  // VERIFY JWT TOKEN
  // Extract and verify JWT
  // Extract customer_id from claims
  // If invalid: return 401

  // VALIDATE INPUT FIELDS
  // Check orderId, razorpayPaymentId, razorpayOrderId not empty
  // Check razorpaySignature is 64-char hex: /^[0-9a-f]{64}$/i
  // If invalid: return 400

  // GET ORDER FROM POSTGRESQL
  // Query: SELECT * FROM orders WHERE id = orderId
  // If not found: return 404
  // Verify order.customer_id == JWT.customer_id
  // Extract: customer_id, total_amount, payment_status, razorpay_order_id

  // CHECK PAYMENT STATUS
  // If payment_status = 'completed': return 409 "Payment already processed"
  // If payment_status != 'pending': return 409

  // VERIFY RAZORPAY ORDER ID MATCHES
  // If order.razorpay_order_id != razorpayOrderId: return 401

  // VERIFY PAYMENT SIGNATURE (CRITICAL)
  // Build body: razorpay_order_id + "|" + razorpay_payment_id
  // Get RAZORPAY_KEY_SECRET from env
  // Compute HMAC-SHA256(body, key_secret)
  // Compare with constant-time comparison
  // If invalid: log security event, return 401

  // CHECK FOR DUPLICATE PAYMENT (Idempotency)
  // Query: SELECT * FROM payment_transactions WHERE razorpay_payment_id = razorpayPaymentId
  // If found: return 200 with existing order data

  // CREATE PAYMENT TRANSACTION RECORD
  // INSERT into payment_transactions table
  // If fails: return 500

  // DEDUCT INVENTORY (ATOMIC)
  // For each item in order:
  //   - Call stored procedure: process_order_deduct_inventory()
  //   - Check available_quantity >= 0
  // If any fails: return 409 "Insufficient inventory"

  // UPDATE ORDER STATUS
  // UPDATE orders SET
  //   payment_status = 'completed',
  //   razorpay_payment_id = razorpayPaymentId,
  //   order_status = 'confirmed',
  //   paid_at = NOW()

  // CLEAR INVENTORY RESERVATIONS
  // DELETE FROM inventory_reservations WHERE order_id = orderId

  // SYNC TO FIRESTORE (async)
  // Update orders/{order_id}
  // Create payment_transactions doc
  // If fails: log but continue

  // CREATE WALLET ENTRY
  // INSERT into wallet_transactions (debit entry)

  // SEND PUSH NOTIFICATION
  // Query device_tokens
  // Send via FCM
  // If fails: log but continue

  // SEND CONFIRMATION EMAIL
  // Send via Sendgrid
  // If fails: log but continue

  // LOG AUDIT EVENT
  // INSERT audit_logs: payment_verified

  // RETURN SUCCESS RESPONSE
  return VerifyPaymentResponse(
    success: true,
    order: OrderData(
      orderId: orderId,
      status: 'confirmed',
      total: 522.47,
      estimatedDelivery: '30-45 minutes',
    ),
    message: 'Payment successful! Your order is confirmed.',
  );
}

/// ============================================================================
/// SECTION 4: PAYMENT WEBHOOK (RAZORPAY → BACKEND)
/// ============================================================================
///
/// REQUEST: POST /functions/razorpay-webhook-dual-write
///
/// REQUEST FORMAT (from Razorpay):
/// {
///   "event": "payment.authorized",
///   "created_at": 1687951234,
///   "payload": {
///     "payment": {
///       "entity": {
///         "id": "pay_7Oy8OMjw3bqnIZ",
///         "order_id": "order_7Oy8OMjw3bqnIZ",
///         "amount": 25000,
///         "amount_paid": 25000,
///         "amount_due": 0,
///         "currency": "INR",
///         "receipt": "order_123",
///         "status": "authorized",
///         "method": "card",
///         "description": "Order #order-123",
///         "bank": null,
///         "wallet": null,
///         "email": "user@example.com",
///         "contact": "+919876543210",
///         "fee": null,
///         "tax": null,
///         "error_code": null,
///         "error_description": null,
///         "error_source": null,
///         "acquirer_data": {...},
///         "created_at": 1687951234
///       }
///     }
///   }
/// }
///
/// HEADERS:
/// - X-Razorpay-Signature: {webhook_signature}
///
/// VALIDATION LOGIC:
/// 1. Signature header present
/// 2. Signature valid (HMAC-SHA256 with webhook secret)
/// 3. Request body not modified
///
/// ERROR RESPONSES:
/// Webhooks should ALWAYS return 200, even on error
/// Razorpay will retry if not 200 within 60 seconds
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Extract Signature from Header
///   - Get X-Razorpay-Signature header value
///   - If not present: return 401 "Signature not provided"
///
/// Step 2: Get Webhook Secret
///   - Load RAZORPAY_WEBHOOK_SECRET from encrypted env vars
///   - NEVER log this secret
///   - NEVER commit to repo
///
/// Step 3: Verify Webhook Signature
///   - Read raw request body (before JSON parsing)
///   - Compute HMAC-SHA256:
///     ```
///     hmac = crypto.createHmac('sha256', webhook_secret)
///     computed_signature = hmac.update(raw_body).digest('hex')
///     ```
///   - Compare with provided signature (constant-time comparison)
///   - If signature invalid:
///     - Log: "webhook_signature_verification_failed"
///     - return 400 "Signature verification failed"
///     - Razorpay will retry later
///
/// Step 4: Parse Webhook Body
///   - Parse JSON body
///   - Extract: event, payload.payment.entity
///   - Extract payment details:
///     - payment_id (entity.id)
///     - order_id (entity.order_id)
///     - amount (entity.amount)
///     - status (entity.status)
///     - error_code (entity.error_code)
///
/// Step 5: Handle Different Events
///   - If event == 'payment.authorized':
///     - Payment successful (see Step 6)
///   - If event == 'payment.failed':
///     - Payment failed (see error handling)
///   - If event == 'payment.captured':
///     - Payment captured (usually happens auto with capture: 1)
///   - If event == 'payment.refunded':
///     - Refund processed (see refund handling)
///   - Other events: log and return 200 (ignore)
///
/// Step 6: Get Order from PostgreSQL
///   - Query: SELECT * FROM orders WHERE razorpay_order_id = $1
///   - If not found:
///     - Log: "webhook_order_not_found"
///     - return 200 OK (don't fail webhook)
///     - Webhook signature was valid, but order unknown
///     - Return 200 to prevent Razorpay retry
///   - Extract: customer_id, total_amount, payment_status
///
/// Step 7: Check for Idempotency (Duplicate Webhook)
///   - Query: SELECT * FROM payment_transactions WHERE razorpay_payment_id = $1
///   - If found:
///     - Payment already processed
///     - Log: "webhook_duplicate"
///     - return 200 OK (idempotent - don't process again)
///     - This prevents double-charging if Razorpay sends webhook twice
///
/// Step 8: Verify Amount Matches
///   - If webhook.amount != order.total_amount:
///     - This indicates tampering or mismatch
///     - Log: "webhook_amount_mismatch"
///     - return 400 (don't process)
///     - Razorpay will retry
///
/// Step 9: Handle Success (event == 'payment.authorized')
///   - Status should be 'authorized'
///   - error_code should be null
///   - Create payment_transactions record:
///     INSERT INTO payment_transactions (
///       order_id, customer_id,
///       razorpay_payment_id, razorpay_order_id,
///       amount, currency, payment_status,
///       payment_method, verified_at,
///       webhook_received_at,  // NOW()
///       signature_verified,
///       created_at
///     )
///   - Update orders status:
///     UPDATE orders SET
///       payment_status = 'completed',
///       order_status = 'confirmed',
///       razorpay_payment_id = payment_id,
///       paid_at = NOW()
///   - Rest is same as Step 9-14 of verify payment
///     (deduct inventory, sync Firestore, etc.)
///
/// Step 10: Handle Failure (event == 'payment.failed')
///   - Error indicated: error_code is not null
///   - Examples: 'BAD_REQUEST_ERROR', 'GATEWAY_ERROR', 'TIMEOUT', etc.
///   - Delete inventory reservations:
///     DELETE FROM inventory_reservations WHERE order_id = $1
///   - Update order status:
///     UPDATE orders SET
///       payment_status = 'failed',
///       order_status = 'payment_failed',
///       error_code = $1,
///       error_description = $2
///   - Create failed payment record:
///     INSERT INTO payment_transactions (
///       order_id, customer_id,
///       razorpay_payment_id, razorpay_order_id,
///       amount, currency,
///       payment_status = 'failed',
///       error_code, error_description,
///       webhook_received_at = NOW()
///     )
///   - Send notification to user:
///     - "Your payment failed: {error_description}"
///     - "Retry payment or contact support"
///   - return 200 OK
///
/// Step 11: Log Webhook Event
///   - INSERT INTO audit_logs (
///       user_id: customer_id,
///       event_type: 'payment',
///       event_name: 'webhook_received',
///       details: {event, payment_id, amount, status},
///       created_at: NOW()
///     )
///
/// SUCCESS RESPONSE (200 OK):
/// {
///   "status": "ok",
///   "message": "Webhook processed successfully"
/// }
///

Future<WebhookResponse> handleRazorpayWebhook({
  required String signatureHeader,
  required String rawBody,
  String? clientIp,
}) async {
  // EXTRACT SIGNATURE FROM HEADER
  // Get X-Razorpay-Signature
  // If not present: return 401

  // GET WEBHOOK SECRET
  // Load RAZORPAY_WEBHOOK_SECRET from env

  // VERIFY WEBHOOK SIGNATURE
  // Compute HMAC-SHA256(raw_body, webhook_secret)
  // Compare with constant-time comparison
  // If invalid: return 400

  // PARSE WEBHOOK BODY
  // Parse JSON
  // Extract: event, payment_id, order_id, amount, status, error_code

  // HANDLE DIFFERENT EVENTS
  // If event == 'payment.authorized': process success
  // If event == 'payment.failed': process failure
  // If event == 'payment.captured': process capture
  // If event == 'payment.refunded': process refund
  // Other events: ignore, return 200

  // GET ORDER FROM POSTGRESQL
  // Query: SELECT * FROM orders WHERE razorpay_order_id = razorpay_order_id
  // If not found: log, return 200

  // CHECK FOR IDEMPOTENCY (Duplicate Webhook)
  // Query: SELECT * FROM payment_transactions WHERE razorpay_payment_id = payment_id
  // If found: return 200 (already processed)

  // VERIFY AMOUNT MATCHES
  // If webhook.amount != order.total_amount: return 400

  // HANDLE SUCCESS
  // Create payment_transactions record
  // Update orders status to 'confirmed'
  // Deduct inventory
  // Sync to Firestore
  // Send notifications

  // HANDLE FAILURE
  // Delete inventory reservations
  // Update orders status to 'payment_failed'
  // Create failed payment record
  // Send user notification

  // LOG WEBHOOK EVENT
  // INSERT audit_logs: webhook_received

  // RETURN 200 OK
  return WebhookResponse(status: 'ok', message: 'Webhook processed successfully');
}

/// ============================================================================
/// SECTION 5: REFUND FLOW
/// ============================================================================
///
/// REQUEST: POST /api/refunds/create
///
/// REQUEST FORMAT:
/// {
///   "orderId": "order-123-abc",
///   "reason": "customer_request",
///   "reasonDetails": "Product quality issue",
///   "amount": 522.47
/// }
///
/// VALIDATION LOGIC:
/// 1. Order exists and belongs to user
/// 2. Order can be refunded (delivery status allows)
/// 3. Refund amount <= order total
/// 4. Reason provided and valid
///
/// ERROR RESPONSES:
/// - 404 Not Found: {
///     "success": false,
///     "code": "ORDER_NOT_FOUND",
///     "message": "Order not found"
///   }
/// - 409 Conflict: {
///     "success": false,
///     "code": "CANNOT_REFUND",
///     "message": "This order cannot be refunded",
///     "reason": "Delivery already completed more than 7 days ago"
///   }
///
/// BACKEND LOGIC STEPS:
///
/// Step 1: Verify JWT Token
///   - Extract and verify JWT
///   - Extract customer_id from claims
///   - If invalid: return 401
///
/// Step 2: Get Order from PostgreSQL
///   - Query: SELECT * FROM orders WHERE id = $1
///   - If not found: return 404
///   - Verify order.customer_id == JWT.customer_id
///   - Extract: payment_status, order_status, total_amount, paid_at
///
/// Step 3: Check Order Can Be Refunded
///   - If payment_status != 'completed':
///     - return 409 "Order not paid yet"
///   - Allow refund for most statuses except:
///     - If order_status = 'delivered' AND (now - delivered_at) > 7 days:
///       - return 409 "Refund window expired (7 days)"
///     - If order_status = 'cancelled_by_system':
///       - return 409 "Cannot refund system-cancelled order"
///   - Otherwise: allow refund
///
/// Step 4: Get Payment from PostgreSQL
///   - Query: SELECT * FROM payment_transactions WHERE order_id = $1
///   - If not found: return 500 (data integrity error)
///   - Extract: razorpay_payment_id, amount, payment_method
///
/// Step 5: Validate Refund Amount
///   - Check amount provided <= order.total_amount
///   - Typically: amount = order.total_amount (full refund)
///   - Can also do partial refund (e.g., exclude tax)
///   - If amount invalid: return 400
///
/// Step 6: Validate Reason
///   - Allowed reasons: 'customer_request', 'order_quality', 'not_received',
///     'damaged', 'seller_initiated', 'admin_approved', etc.
///   - If reason not in allowlist: return 400
///   - reasonDetails optional (additional info)
///
/// Step 7: Check for Duplicate Refund
///   - Query: SELECT * FROM refunds WHERE order_id = $1 AND status = 'completed'
///   - If found:
///     - return 409 "Refund already processed for this order"
///   - Query: SELECT * FROM refunds WHERE order_id = $1 AND status = 'pending'
///   - If found:
///     - return 409 "Refund already in progress"
///
/// Step 8: Create Refund Record in PostgreSQL
///   - INSERT INTO refunds (
///       id,                       // UUID
///       order_id,
///       customer_id,
///       payment_transaction_id,
///       razorpay_payment_id,
///       amount,
///       currency,                 // 'INR'
///       reason,
///       reason_details,
///       refund_status,            // 'pending'
///       razorpay_refund_id,       // null (will be filled by API)
///       initiated_at,             // NOW()
///       initiated_by              // 'customer' or 'admin'
///     )
///   - Get refund_id from INSERT RETURNING
///
/// Step 9: Call Razorpay Refund API
///   - POST https://api.razorpay.com/v1/payments/{payment_id}/refund
///     Headers:
///       Authorization: Basic base64(key_id:key_secret)
///       Content-Type: application/json
///     Body: {
///       "amount": amount_in_paise,  // Leave empty/null for full refund
///       "speed": "optimum",         // Can be "optimum", "normal", or "instant"
///       "notes": {
///         "orderId": order_id,
///         "reason": reason,
///         "refundId": refund_id
///       }
///     }
///   - Parse response:
///     {
///       "id": "rfnd_7Oy8OMjw3bqnIZ",
///       "entity": "refund",
///       "payment_id": "pay_7Oy8OMjw3bqnIZ",
///       "amount": 25000,
///       "receipt": null,
///       "currency": "INR",
///       "notes": {...},
///       "receipt": null,
///       "status": "pending",
///       "speed_processed": "normal",
///       "speed_requested": "optimum",
///       "created_at": 1687951234
///     }
///   - Extract razorpay_refund_id (id)
///   - If API call fails:
///     - Log error
///     - Update refund status = 'failed'
///     - return 500 "Failed to initiate refund"
///
/// Step 10: Update Refund with Razorpay ID
///   - UPDATE refunds SET
///       razorpay_refund_id = $1,
///       updated_at = NOW()
///     WHERE id = refund_id
///
/// Step 11: Restore Inventory (if order not delivered)
///   - If order.order_status != 'delivered':
///     - For each item in order:
///       - UPDATE inventory SET available_quantity += quantity
///         WHERE product_id = item.product_id
///   - This makes inventory available again for other customers
///
/// Step 12: Add Credit to Wallet
///   - INSERT INTO wallet_transactions (
///       customer_id,
///       amount,                   // positive (credit)
///       type,                     // 'refund'
///       reference_id,             // order_id
///       details,                  // {reason, refund_id}
///       created_at
///     )
///   - UPDATE wallets SET
///       balance = balance + amount
///     WHERE customer_id = customer_id
///   - This credit can be used for future purchases
///
/// Step 13: Update Order Status (if full refund)
///   - If amount == order.total_amount:
///     - UPDATE orders SET
///         order_status = 'refunded',
///         updated_at = NOW()
///   - If partial refund: don't change order_status
///
/// Step 14: Sync to Firestore (async)
///   - Update orders/{order_id}: refundStatus = 'pending'
///   - Create refunds/{refund_id}: with refund details
///
/// Step 15: Send Notification to User
///   - Send push notification:
///     - "Refund initiated for order #order-123"
///     - "Amount: ₹522.47"
///     - "Will appear in your wallet in 3-5 business days"
///   - Send email:
///     - Template: refund_initiated_email
///     - Include: refund amount, expected timeline, order details
///
/// Step 16: Log Audit Event
///   - INSERT INTO audit_logs (
///       user_id: customer_id,
///       event_type: 'refund',
///       event_name: 'refund_initiated',
///       details: {order_id, amount, reason, refund_id},
///       ip_address: client_ip,
///       created_at: NOW()
///     )
///
/// SUCCESS RESPONSE (201 Created):
/// {
///   "success": true,
///   "refund": {
///     "refundId": "rfnd_7Oy8OMjw3bqnIZ",
///     "orderId": "order-123-abc",
///     "amount": 522.47,
///     "currency": "INR",
///     "status": "pending",
///     "reason": "customer_request",
///     "initiatedAt": "2026-06-28T10:30:00Z",
///     "expectedInWallet": "3-5 business days"
///   },
///   "message": "Refund initiated. Amount will appear in your wallet in 3-5 business days."
/// }
///

Future<CreateRefundResponse> createRefund({
  required String jwt,
  required String orderId,
  required String reason,
  String? reasonDetails,
  required double amount,
  String? clientIp,
}) async {
  // VERIFY JWT TOKEN
  // Extract and verify JWT
  // Extract customer_id
  // If invalid: return 401

  // GET ORDER FROM POSTGRESQL
  // Query: SELECT * FROM orders WHERE id = orderId
  // If not found: return 404
  // Verify order.customer_id == JWT.customer_id

  // CHECK ORDER CAN BE REFUNDED
  // If payment_status != 'completed': return 409
  // Check refund window (7 days for delivered orders)
  // If outside window: return 409

  // GET PAYMENT FROM POSTGRESQL
  // Query: SELECT * FROM payment_transactions WHERE order_id = orderId
  // If not found: return 500

  // VALIDATE REFUND AMOUNT
  // Check amount <= order.total_amount
  // If invalid: return 400

  // VALIDATE REASON
  // Check reason in allowlist
  // If invalid: return 400

  // CHECK FOR DUPLICATE REFUND
  // Query completed refunds
  // Query pending refunds
  // If found: return 409

  // CREATE REFUND RECORD IN POSTGRESQL
  // INSERT into refunds table
  // Get refund_id

  // CALL RAZORPAY REFUND API
  // POST /v1/payments/{payment_id}/refund
  // amount in paise, speed optimum
  // Include notes with order/refund IDs
  // Extract razorpay_refund_id
  // If fails: update status to failed, return 500

  // UPDATE REFUND WITH RAZORPAY ID
  // UPDATE refunds SET razorpay_refund_id

  // RESTORE INVENTORY (if not delivered)
  // If order_status != 'delivered':
  //   For each item:
  //     - UPDATE inventory SET available_quantity += quantity

  // ADD CREDIT TO WALLET
  // INSERT into wallet_transactions (credit entry)
  // UPDATE wallets SET balance += amount

  // UPDATE ORDER STATUS (if full refund)
  // If amount == order.total_amount:
  //   - UPDATE orders SET order_status = 'refunded'

  // SYNC TO FIRESTORE (async)
  // Update orders/{order_id}
  // Create refunds/{refund_id}

  // SEND NOTIFICATION TO USER
  // Push notification via FCM
  // Email via Sendgrid

  // LOG AUDIT EVENT
  // INSERT audit_logs: refund_initiated

  // RETURN SUCCESS RESPONSE
  return CreateRefundResponse(
    success: true,
    refund: RefundData(
      refundId: 'rfnd_7Oy8OMjw3bqnIZ',
      orderId: orderId,
      amount: amount,
      currency: 'INR',
      status: 'pending',
      reason: reason,
      initiatedAt: DateTime.now(),
      expectedInWallet: '3-5 business days',
    ),
    message: 'Refund initiated. Amount will appear in your wallet in 3-5 business days.',
  );
}

/// ============================================================================
/// SECTION 6: WEBHOOK REFUND STATUS UPDATE (RAZORPAY → BACKEND)
/// ============================================================================
///
/// REQUEST: Same webhook endpoint as payment
/// EVENT: "refund.created", "refund.failed", "refund.processed"
///
/// LOGIC (Similar to payment webhook):
/// 1. Verify webhook signature (same as payment webhook)
/// 2. Extract refund details: refund_id, payment_id, amount, status
/// 3. Query refunds table by razorpay_refund_id
/// 4. Update refund status based on event:
///    - "refund.created": status = 'processing'
///    - "refund.processed": status = 'completed', processed_at = now
///    - "refund.failed": status = 'failed', error_code, error_description
/// 5. If "refund.processed":
///    - Credit already added in Step 12 of createRefund
///    - Send user notification: "Refund completed"
/// 6. If "refund.failed":
///    - Reverse wallet credit
///    - Send user notification: "Refund failed, will retry"
/// 7. Update Firestore: refunds/{refund_id} sync
/// 8. Return 200 OK
///

/// ============================================================================
/// SECTION 7: SECURITY SUMMARY
/// ============================================================================
///
/// RAZORPAY SIGNATURE VERIFICATION (Most Critical):
///   1. Build body: razorpay_order_id + "|" + razorpay_payment_id
///   2. Compute: HMAC-SHA256(body, key_secret)
///   3. Compare with constant-time comparison
///   4. If mismatch: FRAUD attempt, return 401
///   5. NEVER reveal details to attacker
///
/// WEBHOOK SIGNATURE VERIFICATION:
///   1. Use raw request body (before JSON parsing)
///   2. Compute: HMAC-SHA256(body, webhook_secret)
///   3. Compare with X-Razorpay-Signature header
///   4. If mismatch: return 400, webhook will retry
///
/// ADDITIONAL SECURITY:
///   1. Idempotency: Check for duplicate payments before processing
///   2. Atomic operations: Inventory deduction in transaction
///   3. Amount verification: Webhook amount must match order amount
///   4. Customer verification: Order must belong to authenticated user
///   5. Constant-time comparison: Prevent timing attacks on signatures
///   6. Secrets management: NEVER log or commit secrets
///   7. Rate limiting: Prevent rapid-fire refund/payment attempts
///   8. Audit logging: Log all payment transactions for compliance
///
/// ============================================================================

// Model classes for requests/responses
class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
  });
}

class DeliveryAddress {
  final String line;
  final String city;
  final String state;
  final String postalCode;
  final double lat;
  final double lng;

  DeliveryAddress({
    required this.line,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.lat,
    required this.lng,
  });
}

class CreateOrderResponse {
  final bool success;
  final OrderData order;
  final String razorpayKey;
  final String message;

  CreateOrderResponse({
    required this.success,
    required this.order,
    required this.razorpayKey,
    required this.message,
  });
}

class OrderData {
  final String orderId;
  final String? razorpayOrderId;
  final int? amount;
  final double? amountInRupees;
  final String currency;
  final List<OrderItem>? items;
  final double? subtotal;
  final double? tax;
  final double? deliveryFee;
  final double? discount;
  final double total;
  final String status;
  final String? paymentMethod;
  final DateTime? createdAt;
  final String? estimatedDelivery;

  OrderData({
    required this.orderId,
    this.razorpayOrderId,
    this.amount,
    this.amountInRupees,
    this.currency = 'INR',
    this.items,
    this.subtotal,
    this.tax,
    this.deliveryFee,
    this.discount,
    required this.total,
    required this.status,
    this.paymentMethod,
    this.createdAt,
    this.estimatedDelivery,
  });
}

class VerifyPaymentResponse {
  final bool success;
  final OrderData order;
  final String message;

  VerifyPaymentResponse({required this.success, required this.order, required this.message});
}

class WebhookResponse {
  final String status;
  final String message;

  WebhookResponse({required this.status, required this.message});
}

class CreateRefundResponse {
  final bool success;
  final RefundData refund;
  final String message;

  CreateRefundResponse({required this.success, required this.refund, required this.message});
}

class RefundData {
  final String refundId;
  final String orderId;
  final double amount;
  final String currency;
  final String status;
  final String reason;
  final DateTime initiatedAt;
  final String expectedInWallet;

  RefundData({
    required this.refundId,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.reason,
    required this.initiatedAt,
    required this.expectedInWallet,
  });
}
