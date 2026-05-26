# Implementation Plan: Fully Functional Hyperlocal E-Commerce App

## Overview

This implementation plan follows a phased approach, starting with core MVP features (authentication, product browsing, cart, checkout, and order management) and progressing to advanced features (wallet, rewards, delivery agent module, admin panel). The plan builds on the existing Flutter codebase which already includes models, providers, and screen scaffolds.

## Architecture Notes

- **Language**: Dart (Flutter)
- **State Management**: Provider pattern with ChangeNotifier
- **Backend**: Firebase (Auth, Firestore, Storage, FCM)
- **Navigation**: GoRouter with role-based shells
- **Local Storage**: Hive for offline caching

## Tasks

---

## Phase 1: Foundation and Authentication

### Objective

Establish core authentication infrastructure with phone OTP verification, session management, and role-based access control. This phase ensures secure user onboarding and proper data isolation.

---

- [x] 1.1 Complete AuthProvider implementation
  - Implement sendOTP with Firebase Auth rate limiting (max 5 OTPs/hour)
  - Implement verifyOTP with 3-attempt limit before requiring new OTP
  - Implement logout with session clearing
  - Add biometric authentication integration with LocalAuth
  - _Requirements: 1.2, 1.8, 1.9, 17.1, 17.3_

- [x] 1.2 Implement UserModel with all required fields
  - Add membershipTier, walletBalance, rewardPoints fields
  - Add district, village, savedAddresses fields
  - Add isVerified, isActive flags for user management
  - Add createdAt, lastLogin timestamps
  - _Requirements: 1.5, 11.5, 13.8_

- [x] 1.3 Complete LoginScreen UI
  - Add country code picker with phone number input
  - Add validation for phone number format
  - Add loading state and error display
  - Add "Send OTP" button with Firebase integration
  - _Requirements: 1.1_

- [x] 1.4 Complete OTPScreen UI
  - Create 6-digit OTP input field
  - Add auto-advance between digits
  - Add resend OTP functionality with countdown timer
  - Add error display for invalid OTP
  - _Requirements: 1.3, 1.9_

- [x] 1.5 Complete RoleSelectScreen UI
  - Display role options: Customer, Shop Owner, Delivery Agent
  - Add role selection with icons and descriptions
  - Save selected role to user profile in Firestore
  - Navigate to appropriate dashboard based on role
  - _Requirements: 1.4_

- [x] 1.6 Implement Firestore security rules
  - Users can only read/write their own profile
  - Products readable by all, writable only by shop owners for their products
  - Orders readable by customer, shop owner, and assigned delivery agent
  - _Requirements: 17.4_

- [x] 1.7 Checkpoint - Authentication flow validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 2: Product Catalog and Browsing

### Objective

Build complete product catalog with category browsing, search, filtering, and product detail views. Focus on performance with pagination and caching.

---

- [x] 2.1 Complete ProductModel implementation
  - Add all fields: name, description, price, originalPrice, discountPercentage
  - Add category, subCategory, shopId, shopName fields
  - Add rating, reviewCount, stockQuantity, isAvailable
  - Add specifications, tags, barcode, brand, origin
  - Add delivery area restrictions (district, village)
  - _Requirements: 2.5, 2.8_

- [x] 2.2 Complete ProductProvider implementation
  - Implement fetchProductsByCategory with pagination (20 items/page)
  - Implement search with debounce (300ms) and Firestore text search
  - Implement filtering by price range, rating, availability, discount
  - Implement sorting by price, rating, newest
  - Add featured, trending, new arrivals queries
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 8.2, 8.3_

- [x] 2.3 Implement ProductCategory enum
  - Define all categories: groceries, vegetables, fruits, dairy, bakery, snacks, beverages, household, personalCare, electronics, clothing, footwear, homeDecor, kitchenware, stationery, toys, medicines, agricultural, other
  - Add category icons and display names
  - _Requirements: 2.2_

- [x] 2.4 Complete HomeScreen UI
  - Implement category horizontal scroll with chips
  - Add featured products carousel section
  - Add trending items and new arrivals sections
  - Implement flash deals section with countdown
  - Add location indicator for hyperlocal area
  - _Requirements: 2.1, 8.7_

- [x] 2.5 Complete ProductDetailScreen UI
  - Implement image carousel with dot indicators and swipe navigation
  - Display product name, price, original price, discount percentage
  - Add rating display with star icons and review count
  - Add description, specifications, stock quantity sections
  - Implement variant selection (size, color, weight) with price update
  - Add "Out of Stock" badge when applicable
  - Add related products section
  - _Requirements: 2.5, 2.6, 2.7, 2.8_

- [x] 2.6 Implement SearchScreen UI
  - Add search bar with recent searches history
  - Implement real-time search results with debounce
  - Add barcode scanner integration for product lookup
  - Display "no results" state with related categories
  - Add "Notify when available" option for out-of-stock items
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 2.7 Implement RecommendationEngine basics
  - Add "You May Also Like" section on product detail
  - Implement basic recommendation based on category
  - _Requirements: 8.6_

- [x] 2.8 Checkpoint - Product browsing validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 3: Shopping Cart and Wishlist

### Objective

Implement shopping cart with quantity management, coupon validation, and wishlist functionality. Ensure offline support for cart operations.

---

- [x] 3.1 Complete CartItem and Cart models
  - Define CartItem with productId, quantity, selected variants
  - Add Cart with items list, subtotal, discount, delivery charge, total
  - Add couponCode, walletAmountUsed fields
  - _Requirements: 3.1, 3.5_

- [x] 3.2 Complete CartProvider implementation
  - Implement addItem with default quantity 1 and stock validation
  - Implement updateQuantity with stock cap and warning display
  - Implement removeItem with cart total update
  - Implement applyCoupon with CouponValidator integration
  - Implement setWalletAmount (max 50% of order value)
  - Add Hive persistence for offline access
  - Add Firestore sync when online
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.7, 3.8, 3.9, 11.4_

- [x] 3.3 Complete CartScreen UI
  - Display cart items with image, name, unit, quantity, price, total
  - Add quantity increment/decrement buttons with stock limits
  - Add remove item action
  - Implement empty state with illustration and "Continue Shopping" button
  - Show subtotal, delivery charge, discount, wallet amount, final total
  - Add coupon code input field with apply button
  - Add "Checkout" button
  - _Requirements: 3.5, 3.6, 3.7_

- [x] 3.4 Implement Coupon model and validation
  - Define Coupon with code, discountType, discountValue, minOrderAmount
  - Add usageLimit, usageCount, startDate, endDate fields
  - Implement CouponValidator with validity checks
  - _Requirements: 3.7, 3.8_

- [x] 3.5 Implement WishlistManager
  - Add wishlist to UserModel with product references
  - Implement addToWishlist and removeFromWishlist
  - Add Hive persistence and Firestore sync
  - Add heart icon toggle on product cards
  - _Requirements: 9.1, 9.2, 9.3, 9.6, 9.7_

- [x] 3.6 Implement WishlistScreen UI
  - Display saved products with current price, discount percentage
  - Add "Out of Stock" badge for unavailable items
  - Add navigation to product detail on tap
  - Add price drop notification indicator
  - _Requirements: 9.2, 9.3, 9.5_

- [x] 3.7 Implement price drop notifications
  - Track wishlist item prices
  - Send FCM notification when price drops >10%
  - _Requirements: 9.4_

- [x] 3.8 Checkpoint - Cart and wishlist validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 4: Checkout and Order Placement

### Objective

Build complete checkout flow with address selection, payment integration, and order creation. Implement order number generation and confirmation.

---

- [x] 4.1 Complete AddressModel implementation
  - Define Address with label, fullAddress, landmark, pincode
  - Add latitude, longitude for geocoding
  - Add isDefault, deliveryInstructions fields
  - _Requirements: 4.3_

- [x] 4.2 Complete LocationProvider implementation
  - Implement current location detection with permission handling
  - Implement geocoding for address-to-coordinates conversion
  - Implement saved addresses CRUD operations
  - Add Google Maps location picker integration
  - _Requirements: 4.2, 4.3, 13.1_

- [x] 4.3 Implement DeliveryAreaValidator
  - Check if location is within configured district boundaries
  - Support village delivery area validation
  - Display service area map for out-of-area locations
  - _Requirements: 13.2, 13.3, 13.4_

- [x] 4.4 Complete AddressScreen UI
  - Display saved addresses with map preview
  - Add "Add New Address" button with Google Maps picker
  - Capture label (Home/Office/Other), full address, landmark, pincode
  - Add delivery instructions field
  - Allow setting default address
  - _Requirements: 4.2, 4.3_

- [x] 4.5 Implement delivery type selection
  - Standard Delivery (free for >₹500, ₹20 for ₹200-500, ₹40 for <₹200)
  - Express Delivery (₹50, next day)
  - Same Day Delivery (₹100, within 8 hours)
  - Village Delivery (₹30, 3-5 days based on distance)
  - Show estimated delivery date for each option
  - _Requirements: 4.4_

- [x] 4.6 Implement payment method selection
  - Cash on Delivery
  - UPI (Google Pay, PhonePe, Paytm)
  - Credit/Debit Cards
  - Net Banking
  - Wallet Balance
  - Pay Later (BNPL)
  - _Requirements: 4.5_

- [x] 4.7 Implement Razorpay payment integration
  - Initialize Razorpay checkout with order amount
  - Handle success callback with payment ID
  - Handle failure callback with error display
  - Verify payment status before order creation
  - _Requirements: 4.6_

- [x] 4.8 Complete OrderModel and OrderItem models
  - Define OrderModel with orderNumber (HLM-YYYYMMDD-XXXX format)
  - Add customerId, customerName, customerPhone, customerEmail
  - Add items list (OrderItem objects), subtotal, deliveryCharge, discount, tax, totalAmount
  - Add walletAmountUsed, cashbackEarned, rewardPointsUsed, rewardPointsEarned
  - Add paymentMethod, paymentId, paymentStatus
  - Add status enum: pending, confirmed, processing, packed, outForDelivery, delivered, cancelled, returned, refunded
  - Add deliveryAddress, deliveryType, deliveryAgentId, deliveryAgentName, deliveryAgentPhone
  - Add otp for delivery verification, otpVerified flag
  - Add timestamps: createdAt, updatedAt, statusHistory
  - _Requirements: 4.8, 5.2_

- [x] 4.9 Implement OrderProvider
  - Implement createOrder with unique order number generation
  - Implement order status updates with timeline
  - Implement order history retrieval with pagination (10 orders/page)
  - Implement cancellation with wallet refund and stock restoration
  - Implement return request creation
  - _Requirements: 4.8, 5.1, 5.7, 5.8_

- [x] 4.10 Complete CheckoutScreen UI
  - Step 1: Delivery address selection with saved addresses
  - Step 2: Payment method selection
  - Step 3: Order review with items summary, address, charges breakdown
  - Step 4: Order confirmation with order number display
  - Add progress indicator between steps
  - _Requirements: 4.1, 4.7_

- [x] 4.11 Implement OrderConfirmationScreen
  - Display order number, estimated delivery date
  - Show order summary and payment method
  - Add "Track Order" button
  - Send confirmation SMS/notification
  - _Requirements: 4.8, 4.9_
  - **Implementation**: Created SMSService for SMS sending, updated Firebase Functions with Twilio integration, enhanced OrderConfirmationScreen with SMS sending on order confirmation

- [x] 4.12 Checkpoint - Checkout flow validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 5: Order Management and Tracking

### Objective

Build order history, tracking, and delivery management features for customers. Implement OTP verification and delivery agent coordination.

---

- [x] 5.1 Complete OrdersScreen UI
  - Display order history sorted by createdAt (newest first)
  - Show order cards with order number, status, items summary, total
  - Add pagination (10 orders per page with load more)
  - Add tabs for order status filtering (Active, Completed, Cancelled)
  - _Requirements: 5.1_

- [x] 5.2 Complete OrderDetailScreen UI
  - Display order number, status, payment method
  - Show items list with images, names, quantities, prices
  - Display shop details (name, phone)
  - Show delivery address and instructions
  - Add "Cancel Order" button for cancellable orders
  - Add "Return" button for delivered orders within 7 days
  - _Requirements: 5.2_

- [x] 5.3 Implement OrderTimeline
  - Show status progression: Pending → Confirmed → Processing → Packed → Out for Delivery → Delivered
  - Display timestamps for each status transition
  - Highlight current status
  - _Requirements: 5.3_

- [x] 5.4 Implement live delivery tracking
  - When order is out for delivery, show delivery agent info
  - Display agent name and phone number
  - Show agent live location on map
  - Add "Call Agent" button
  - _Requirements: 5.4_

- [x] 5.5 Implement OTP delivery verification
  - Generate 4-digit OTP for order delivery
  - Require customer OTP for delivery completion
  - Display OTP to delivery agent
  - Mark otpVerified when confirmed
  - _Requirements: 5.5_

- [x] 5.6 Implement order cancellation flow
  - Check if order is cancellable (before processing)
  - Update status to Cancelled
  - Refund wallet amount if used
  - Restore stock quantities
  - Send notification to customer and shop owner
  - _Requirements: 5.7_

- [x] 5.7 Implement return request flow
  - Allow return within 7 days of delivery
  - Capture return reason from customer
  - Notify shop owner of return request
  - Track return status
  - _Requirements: 5.8_

- [x] 5.8 Implement customer support features
  - Add in-app chat with shop owner
  - Add "Call Agent" button for delivery inquiries
  - _Requirements: 5.9_

- [x] 5.9 Checkpoint - Order management validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 6: Reviews and Ratings

### Objective

Implement product review and rating system with moderation and shop owner responses.

---

- [x] 6.1 Complete ProductReview model
  - Define Review with productId, userId, userName, userImage
  - Add rating (1-5), review text, images (up to 3)
  - Add createdAt timestamp
  - _Requirements: 10.2_

- [x] 6.2 Implement ReviewSection on ProductDetailScreen
  - Display average rating and rating distribution (5-star to 1-star)
  - Show review count
  - List up to 10 most recent reviews with pagination
  - Add sort options: Most Recent, Highest Rating, Lowest Rating, Most Helpful
  - _Requirements: 10.5_

- [x] 6.3 Implement rating prompt
  - Show rating prompt after order delivery
  - Allow rating within 7 days of delivery
  - Limit to one review per product per order
  - _Requirements: 10.1_

- [x] 6.4 Implement ReviewForm
  - Create 1-5 star rating selector
  - Add optional text review (min 3 characters)
  - Add optional image upload (up to 3 images)
  - Implement profanity filter
  - _Requirements: 10.2, 10.3_

- [x] 6.5 Implement ProductRatingCalculator
  - Calculate average rating from all reviews
  - Update product rating and review count within 1 hour
  - _Requirements: 10.4_

- [x] 6.6 Implement shop owner response
  - Allow shop owner to respond to reviews
  - Display response below original review
  - _Requirements: 10.6_

- [x] 6.7 Implement ReviewModerationSystem
  - Flag inappropriate reviews for admin review
  - Add admin interface to approve/hide reviews
  - _Requirements: 10.7_

- [x] 6.8 Checkpoint - Reviews validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 7: Wallet and Rewards

### Objective

Build wallet balance system with cashback, reward points, and membership tiers.

---

- [x] 7.1 Implement WalletService
  - Add walletBalance field to UserModel
  - Implement wallet balance updates with Firestore sync
  - Implement wallet history tracking (transaction type, amount, order reference, timestamp)
  - _Requirements: 11.1, 11.6, 11.7_

- [x] 7.2 Implement cashback calculation
  - Calculate 1% cashback on order completion
  - Add cashback to wallet balance
  - _Requirements: 11.1_

- [x] 7.3 Implement RewardSystem
  - Award 1 point per ₹10 spent
  - Award 100 points for first order
  - Award 20 points for reviews
  - Award 50 points for referrals
  - Implement points-to-currency conversion (100 points = ₹1)
  - _Requirements: 11.2, 11.3_

- [x] 7.4 Implement MembershipTierCalculator
  - Bronze tier: ₹0-999 lifetime spending
  - Silver tier: ₹1000-4999 lifetime spending
  - Gold tier: ₹5000-19999 lifetime spending
  - Platinum tier: ₹20000+ lifetime spending
  - Update tier on order completion
  - _Requirements: 11.5_

- [x] 7.5 Integrate wallet at checkout
  - Display wallet balance on checkout screen
  - Allow using up to 50% of order value from wallet
  - Deduct wallet balance on order placement
  - Refund to wallet on cancellation
  - _Requirements: 11.4_

- [x] 7.6 Implement WalletHistoryScreen UI
  - Display transaction history with pagination
  - Show transaction type, amount, order reference, timestamp
  - Add filter by transaction type
  - _Requirements: 11.7_

- [x] 7.7 Checkpoint - Wallet validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 8: Notifications and Messaging

### Objective

Implement FCM push notifications for orders, promotions, and system messages with user-configurable settings.

---

- [x] 8.1 Complete NotificationProvider
  - Request FCM permission on app start
  - Subscribe to user-specific topics (userId, role-based)
  - Handle notification tap to navigate to relevant screen
  - Implement notification display with action buttons
  - _Requirements: 12.1, 12.7_

- [x] 8.2 Implement notification types
  - Order Updates: status changes, delivery agent assigned, OTP
  - Promotions: flash sales, bundle offers, BOGO
  - Price Drops: wishlist item price reduction
  - Shop Updates: new products from followed shops
  - System Messages: app updates, maintenance notices
  - _Requirements: 12.2, 12.3, 12.4_

- [x] 8.3 Implement NotificationCenter
  - Create in-app notification list
  - Mark notifications as read
  - Delete notifications
  - Add deep link handling
  - _Requirements: 12.2_

- [x] 8.4 Implement NotificationSettingsScreen
  - Enable/disable each notification type
  - Set quiet hours (10 PM - 8 AM)
  - Set frequency limits
  - Save preferences to Firestore
  - _Requirements: 12.6_

- [x] 8.5 Implement offline notification queue
  - Queue notifications when offline
  - Deliver when connectivity restored
  - _Requirements: 12.5_

- [x] 8.6 Checkpoint - Notifications validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 9: Delivery Agent Module

### Objective

Build complete delivery agent dashboard with order assignment, navigation, and earnings tracking.

---

- [x] 9.1 Complete DeliveryDashboard UI
  - Display assigned deliveries count
  - Show completed deliveries today
  - Display today's earnings
  - Show current location on map
  - Add quick actions for common tasks
  - _Requirements: 7.1_

- [x] 9.2 Implement DeliveryOrdersScreen
  - List all assigned deliveries with status
  - Show pickup and delivery addresses on map
  - Display order details, items list, customer phone
  - Show OTP for delivery verification
  - _Requirements: 7.2, 7.3_

- [x] 9.3 Implement delivery status updates
  - "Accept Delivery" - assign to agent
  - "Picked Up" - update status to Out for Delivery
  - "Delivered" - verify OTP and complete delivery
  - "Failed" - select reason and reschedule/return
  - _Requirements: 7.4, 7.7, 7.8_

- [x] 9.4 Implement Google Maps navigation
  - Integrate turn-by-turn navigation to pickup/delivery locations
  - Calculate route and ETA
  - _Requirements: 7.5_

- [x] 9.5 Implement delivery fee calculation
  - Calculate delivery fee based on distance and order value
  - Add fee to agent earnings on delivery completion
  - _Requirements: 7.7_

- [x] 9.6 Implement DeliveryEarningsScreen
  - Display earnings history with pagination
  - Show delivery statistics (total deliveries, successful, failed)
  - Display customer ratings
  - _Requirements: 7.9_

- [x] 9.7 Checkpoint - Delivery agent validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 10: Shop Owner Dashboard

### Objective

Complete shop owner features for product management, order processing, and analytics.

---

- [x] 10.1 Complete OwnerDashboard UI
  - Display today's orders count
  - Show pending orders count
  - Display total revenue (daily/weekly/monthly)
  - Add quick actions: Add Product, View Orders, Update Inventory
  - _Requirements: 6.1_

- [x] 10.2 Complete ProductsManagementScreen
  - List products filtered by shopId
  - Add "Add New Product" button
  - Implement product form with all fields: name, description, price, original price, unit, category, stock quantity, images (up to 5), specifications, tags, barcode, brand, origin, expiry date, weight
  - Implement image upload via camera or gallery
  - Add edit and delete functionality
  - _Requirements: 6.2, 6.3, 6.4_

- [x] 10.3 Complete OrdersManagementScreen
  - Display incoming orders with customer details
  - Show items, delivery address, payment method
  - Add action buttons based on status: Confirm, Process, Pack
  - _Requirements: 6.7, 6.8, 6.9_

- [x] 10.4 Implement InventoryScreen
  - Show stock levels for all products
  - Add low-stock alerts
  - Allow quick stock updates
  - Auto-mark products as unavailable when stock reaches zero
  - _Requirements: 6.5_

- [x] 10.5 Implement AnalyticsScreen
  - Display revenue charts (daily/weekly/monthly)
  - Show top selling products
  - Display order trends
  - Show customer ratings
  - _Requirements: 6.10_

- [x] 10.6 Implement shop owner notifications
  - Send push notification for new orders
  - Display badge on orders tab
  - _Requirements: 6.6_

- [x] 10.7 Checkpoint - Shop owner validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 11: Admin Panel

### Objective

Build admin capabilities for platform management, user moderation, and analytics.

---

- [x] 11.1 Complete AdminDashboard UI
  - Display total users, active shops, today's orders, revenue
  - Show platform health metrics
  - Add quick navigation to management modules
  - _Requirements: 14.1_

- [x] 11.2 Implement UserManagementModule
  - View user list with pagination
  - Disable/enable users
  - Reset passwords
  - View transaction history
  - _Requirements: 14.2_

- [x] 11.3 Implement ShopManagementModule
  - Approve new shop registrations
  - Verify documents
  - Suspend/unsuspend shops
  - Manage shop categories
  - _Requirements: 14.3_

- [x] 11.4 Implement ProductModerationModule
  - Flag inappropriate products
  - Hide/delete products with reason
  - View reported products
  - _Requirements: 14.4_

- [x] 11.5 Implement OrderManagementModule
  - View all orders with filters
  - Manually update order status
  - Process refunds
  - Handle disputes
  - _Requirements: 14.5_

- [x] 11.6 Implement CouponManagementModule
  - Create new coupons with configurable parameters
  - Edit existing coupons
  - Delete or deactivate coupons
  - Set usage limits and expiration
  - _Requirements: 14.6_

- [x] 11.7 Implement AnalyticsModule
  - Revenue charts (daily/weekly/monthly)
  - User growth tracking
  - Top products, top shops
  - Delivery performance metrics
  - _Requirements: 14.7_

- [x] 11.8 Implement SystemSettingsModule
  - Configure delivery charges
  - Set service areas
  - Configure commission rates
  - Manage promotional banners
  - _Requirements: 14.8_

- [x] 11.9 Checkpoint - Admin panel validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 12: Offline Support and Performance

### Objective

Implement offline functionality, caching, and performance optimizations.

---

- [x] 12.1 Implement OfflineManager
  - Cache product catalog on first load
  - Cache categories and user profile
  - Store cached data in Hive
  - _Requirements: 15.1_

- [x] 12.2 Implement offline cart operations
  - Add items to cart when offline
  - Save to local storage
  - Sync with Firestore when online
  - Show "Offline" indicator
  - _Requirements: 15.3_

- [x] 12.3 Implement order queue for offline placement
  - Queue orders when offline
  - Attempt submission when connectivity restored
  - Show queue status to user
  - _Requirements: 15.4_

- [x] 12.4 Implement NetworkMonitor
  - Detect connectivity changes
  - Show online/offline banner
  - Update UI accordingly
  - _Requirements: 15.7_

- [x] 12.5 Optimize app startup time
  - Target under 3 seconds first launch
  - Target under 1 second subsequent launches
  - Implement lazy loading for non-critical data
  - _Requirements: 15.5_

- [x] 12.6 Optimize image loading
  - Implement lazy loading with placeholder
  - Cache images using cached_network_image
  - Optimize image quality for mobile
  - _Requirements: 15.6_

- [x] 12.7 Optimize list performance
  - Implement pagination with 20 items per batch
  - Minimize widget rebuilds
  - Cache Firestore queries with indexes
  - _Requirements: 15.2_

- [x] 12.8 Checkpoint - Offline support validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 13: Accessibility and Localization

### Objective

Ensure app is accessible to users with disabilities and available in Hindi language.

---

- [x] 13.1 Implement screen reader support
  - Add proper labels for all interactive elements (TalkBack/VoiceOver)
  - Ensure logical focus order
  - Add content descriptions for images
  - _Requirements: 16.1_

- [x] 13.2 Implement accessibility compliance
  - Ensure minimum contrast ratio 4.5:1 for text, 3:1 for large text
  - Ensure touch target size at least 44x44 pixels
  - Support keyboard navigation
  - _Requirements: 16.2, 16.3, 16.4_

- [x] 13.3 Implement Hindi localization
  - Add Hindi translations for all strings
  - Support proper font rendering
  - Implement RTL layout for Hindi
  - _Requirements: 16.5, 16.8_

- [x] 13.4 Implement Indian localization formatting
  - CurrencyFormatter for ₹ display
  - DateTimeFormatter for DD/MM/YYYY format
  - Time formatter for 12-hour format with AM/PM
  - _Requirements: 16.6, 16.7_

- [x] 13.5 Checkpoint - Accessibility validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 14: Analytics and Crash Reporting

### Objective

Implement analytics tracking and crash reporting for monitoring and improvement.

---

- [x] 14.1 Implement AnalyticsService
  - Track screen views
  - Track user actions (product_view, add_to_cart, checkout_started, purchase_completed, search_performed)
  - Track search queries
  - Track conversion funnels
  - Track session duration
  - _Requirements: 18.1, 18.5_

- [x] 14.2 Implement CrashReporter
  - Capture stack traces with Firebase Crashlytics
  - Add custom logs for debugging
  - _Requirements: 18.2_

- [x] 14.3 Implement PerformanceMonitor
  - Track app startup time
  - Track screen rendering time
  - Track API response times
  - _Requirements: 18.3_

- [x] 14.4 Implement user properties tracking
  - Track user role, membership tier
  - Track total orders, location district
  - _Requirements: 18.4_

- [x] 14.5 Checkpoint - Analytics validation
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Phase 15: Final Integration and Polish

### Objective

Complete integration testing, bug fixes, and final polish before release.

---

- [x] 15.1 End-to-end testing - Customer purchase flow
  - Product browsing to order confirmation
  - Verify all status transitions
  - Test offline scenarios
  - _Requirements: All customer-facing_

- [x] 15.2 End-to-end testing - Shop owner flow
  - Product management
  - Order processing
  - _Requirements: All shop owner_

- [x] 15.3 End-to-end testing - Delivery agent flow
  - Delivery assignment to completion
  - Earnings tracking
  - _Requirements: All delivery agent_

- [x] 15.4 Security audit
  - Verify Firestore security rules
  - Test authentication edge cases
  - Verify data encryption
  - _Requirements: 17.x_

- [x] 15.5 Performance testing
  - Measure app startup time
  - Test with large product catalog
  - Test with many concurrent orders
  - _Requirements: 15.x_

- [x] 15.6 Accessibility audit
  - Test with screen reader
  - Verify contrast ratios
  - Test keyboard navigation
  - _Requirements: 16.x_

- [x] 15.7 Final checkpoint - Release readiness
  - Ensure all tests pass
  - Ask the user if questions arise

---

## Summary

This implementation plan is organized into 15 phases, starting with core MVP features and progressing to advanced functionality:

**MVP Core (Phases 1-5)**: Authentication, product catalog, cart, checkout, order management - enables basic shopping flow

**Enhanced Shopping (Phases 6-8)**: Reviews, wallet/rewards, notifications - improves user engagement and retention

**Business Features (Phases 9-11)**: Delivery agent module, shop owner dashboard, admin panel - enables multi-role platform operations

**Infrastructure (Phases 12-14)**: Offline support, accessibility, analytics - ensures reliability and inclusivity

**Final (Phase 15)**: Integration testing and release preparation

Each phase includes a checkpoint task to validate progress before proceeding. Test-related sub-tasks are marked with `*` and can be skipped for faster MVP delivery.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- The existing codebase provides models, providers, and screen scaffolds that these tasks build upon
- Firestore security rules should be deployed before production launch
- FCM notifications require proper notification channel configuration for Android