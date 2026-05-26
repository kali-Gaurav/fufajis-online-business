# Requirements Document: Fully Functional Hyperlocal E-Commerce App

## Introduction

This document defines the requirements for completing the Hyperlocal Market e-commerce application. The app is a Flutter-based hyperlocal marketplace connecting local shop owners with customers in their district and villages. The system supports three primary user roles: Customers, Shop Owners, and Delivery Agents, with an Admin panel for platform management.

## Glossary

- **App**: The Hyperlocal Market mobile application
- **System**: The complete software ecosystem including mobile app and backend services
- **Customer**: End user who purchases products from local shops
- **Shop Owner**: Local business owner who lists and sells products
- **Delivery Agent**: Person responsible for picking up and delivering orders
- **Admin**: Platform administrator who manages users, shops, and operations
- **Hyperlocal**: Service area limited ato a specific district and its surrounding villages
- **Cart**: Temporary storage for items selected for purchase
- **Order**: Confirmed purchase transaction with unique order number
- **FCM**: Firebase Cloud Messaging for push notifications

## Requirements

### Requirement 1: User Authentication and Profile Management

**User Story:** As a user, I want to authenticate using my phone number and manage my profile, so that I can securely access the app and maintain my personal information.

#### Acceptance Criteria

1. WHEN a new user opens the App, THE System SHALL display a phone number input screen with country code picker.
2. WHEN a user enters a valid phone number and taps "Send OTP", THE AuthProvider SHALL send an OTP via Firebase Auth within 5 seconds.
3. WHEN the user enters the correct OTP, THE System SHALL create or retrieve the user account and navigate to the role selection screen.
4. WHEN a user selects a role (Customer, Shop Owner, Delivery Agent), THE System SHALL save the role to the user profile and navigate to the appropriate home screen.
5. WHEN a user accesses their profile, THE System SHALL display: name, phone number, email, profile image, membership tier, wallet balance, and reward points.
6. WHEN a user updates their profile information, THE System SHALL save the changes to Firestore and update the local cache within 2 seconds.
7. WHEN a user enables biometric authentication, THE System SHALL use LocalAuth to verify identity before allowing access.
8. IF Firebase Auth fails to send OTP, THEN THE System SHALL display an error message and offer retry options.
9. IF the user enters an incorrect OTP 3 times, THEN THE System SHALL require a new OTP request.

---

### Requirement 2: Product Catalog and Browsing

**User Story:** As a customer, I want to browse products by category, search for items, and view product details, so that I can find and learn about products I want to purchase.

#### Acceptance Criteria

1. WHEN the customer opens the home screen, THE ProductProvider SHALL load and display featured products, trending items, and new arrivals within 3 seconds.
2. WHEN the customer taps a category, THE System SHALL display products filtered by that category with infinite scroll pagination (20 items per page).
3. WHEN the customer enters a search query, THE System SHALL display matching products from all categories within 500ms, supporting partial matches on product name, brand, and description.
4. WHEN the customer filters products, THE System SHALL support filtering by: price range, rating (4+ stars), availability (in stock), discount percentage, and sort by price (low-high/high-low), rating, or newest.
5. WHEN the customer taps a product, THE System SHALL navigate to the product detail screen displaying: images (carousel), name, price, original price, discount percentage, rating, review count, description, specifications, stock quantity, and available variants.
6. WHEN the product has multiple images, THE ImageCarousel SHALL allow swiping through images with dot indicators.
7. WHEN the product is out of stock, THE System SHALL display "Out of Stock" badge and disable the "Add to Cart" button.
8. WHEN the product has variants (size, color, weight), THE System SHALL allow selection and update price accordingly.
9. WHEN the customer scrolls to product reviews, THE ReviewSection SHALL display: average rating, rating distribution (5-star to 1-star), and up to 10 most recent reviews with pagination.

---

### Requirement 3: Shopping Cart Management

**User Story:** As a customer, I want to add products to a cart, adjust quantities, and remove items, so that I can prepare my order before checkout.

#### Acceptance Criteria

1. WHEN a customer taps "Add to Cart" on a product, THE CartProvider SHALL add the item with default quantity 1 and display a success snackbar.
2. WHEN a customer increases quantity beyond available stock, THE System SHALL cap the quantity at stockQuantity and display a warning.
3. WHEN a customer updates cart item quantity, THE CartProvider SHALL recalculate subtotal, item total, and update Firestore within 1 second.
4. WHEN a customer removes an item from cart, THE System SHALL delete the item and update the cart total.
5. WHEN a customer views the cart, THE System SHALL display: list of items with image, name, unit, quantity, price, total price, and action to remove or adjust quantity.
6. WHEN cart is empty, THE System SHALL display an empty state with illustration and "Continue Shopping" button.
7. WHEN a customer applies a coupon code, THE CouponValidator SHALL verify validity and apply discount to the subtotal.
8. WHEN an invalid or expired coupon is applied, THE System SHALL display an appropriate error message.
9. THE CartProvider SHALL persist cart items locally using Hive for offline access and sync with Firestore when online.

---

### Requirement 4: Checkout and Order Placement

**User Story:** As a customer, I want to select a delivery address, choose payment method, and place my order, so that I can complete my purchase.

#### Acceptance Criteria

1. WHEN a customer taps "Checkout" from cart, THE System SHALL navigate to the checkout flow with 4 steps: delivery address, payment method, order review, confirmation.
2. WHEN selecting delivery address, THE System SHALL display saved addresses with map preview and allow adding a new address with Google Maps location picker.
3. WHEN adding a new address, THE System SHALL capture: label (Home/Office/Other), full address, landmark, pincode, delivery instructions, and geocode coordinates.
4. WHEN selecting delivery type, THE System SHALL offer: Standard Delivery (free, 2-3 days), Express Delivery (₹50, next day), Same Day Delivery (₹100, within 8 hours), Village Delivery (₹30, 3-5 days based on distance).
5. WHEN selecting payment method, THE System SHALL display: Cash on Delivery, UPI (Google Pay, PhonePe, Paytm), Credit/Debit Cards, Net Banking, Wallet Balance, Pay Later (BNPL).
6. WHEN the customer selects Razorpay payment, THE System SHALL initialize Razorpay checkout and handle success/failure callbacks.
7. WHEN the customer reviews the order, THE System SHALL display: items summary, delivery address, delivery charge, tax, discount, coupon applied, wallet amount used, and final total.
8. WHEN the customer places the order, THE OrderProvider SHALL create an OrderModel with unique order number (format: HLM-YYYYMMDD-XXXX), save to Firestore, deduct wallet balance if used, and navigate to order confirmation screen.
9. WHEN order is placed successfully, THE System SHALL display order number, estimated delivery date, and send confirmation SMS/notification.

---

### Requirement 5: Order Management and Tracking

**User Story:** As a customer, I want to view my order history, track delivery status, and manage cancellations or returns, so that I can stay informed about my purchases.

#### Acceptance Criteria

1. WHEN the customer accesses "My Orders", THE OrderProvider SHALL load orders from Firestore filtered by customerId, sorted by createdAt (newest first), with pagination (10 orders per page).
2. WHEN viewing order details, THE System SHALL display: order number, items list with images, shop details, payment method, delivery address, order timeline, and current status.
3. THE OrderTimeline SHALL show status progression: Pending → Confirmed → Processing → Packed → Out for Delivery → Delivered, with timestamps for each stage.
4. WHEN order is out for delivery, THE System SHALL display: delivery agent name, phone number, and live location on map.
5. WHEN the customer receives the order, THE System SHALL require OTP verification from the delivery agent to mark as delivered.
6. IF the customer is not available, WHEN the delivery agent attempts delivery 2 times without success, THEN THE System SHALL offer reschedule or return options.
7. WHEN the customer cancels an order (before processing), THE System SHALL update status to Cancelled, refund wallet amount if used, restore stock, and send notification.
8. WHEN the customer requests return (within 7 days of delivery), THE System SHALL create a return request and notify the shop owner.
9. WHEN the customer needs help with an order, THE System SHALL provide in-app chat with shop owner and call button for delivery agent.

---

### Requirement 6: Shop Owner Dashboard

**User Story:** As a shop owner, I want to manage my products, view orders, and track my shop's performance, so that I can efficiently run my business.

#### Acceptance Criteria

1. WHEN a shop owner logs in, THE System SHALL display the Shop Owner Dashboard with: today's orders, pending orders, total revenue, and quick actions.
2. WHEN the shop owner views "My Products", THE ProductProvider SHALL load products filtered by shopId with options to add, edit, or delete products.
3. WHEN adding a new product, THE ProductForm SHALL capture: name, description, price, original price, unit, category, subcategory, stock quantity, images (up to 5), specifications, tags, barcode, brand, origin, expiry date, and weight.
4. WHEN editing a product, THE System SHALL allow updating all fields and support image upload/replacement via camera or gallery.
5. WHEN stock quantity reaches zero, THE System SHALL automatically mark product as unavailable.
6. WHEN new orders arrive, THE System SHALL send push notification to shop owner and display badge on orders tab.
7. WHEN the shop owner views an order, THE System SHALL display: customer details, items, delivery address, and action buttons based on status.
8. WHEN the shop owner confirms an order, THE System SHALL update status to Confirmed and notify the customer.
9. WHEN the shop owner marks order as Packed, THE System SHALL notify delivery agent for pickup.
10. THE ShopDashboard SHALL display analytics: daily/weekly/monthly revenue, top selling products, order trends, and customer ratings.

---

### Requirement 7: Delivery Agent Module

**User Story:** As a delivery agent, I want to receive delivery assignments, navigate to locations, and update delivery status, so that I can complete deliveries efficiently.

#### Acceptance Criteria

1. WHEN a delivery agent logs in, THE System SHALL display the Delivery Dashboard with: assigned deliveries, completed today, earnings, and current location.
2. WHEN a new delivery is assigned, THE System SHALL send push notification and display on the dashboard with pickup and delivery addresses on map.
3. WHEN the delivery agent taps a delivery, THE System SHALL show: order details, items list, pickup location, delivery location, customer phone, and OTP for verification.
4. WHEN the delivery agent picks up an order, THE System SHALL update status to "Out for Delivery" and notify the customer with ETA.
5. WHEN navigating to delivery, THE System SHALL integrate with Google Maps for turn-by-turn navigation.
6. WHEN the delivery agent arrives at customer location, THE System SHALL request OTP from customer and verify against order OTP.
7. WHEN delivery is complete, THE System SHALL update status to Delivered, calculate delivery fee, and add to agent earnings.
8. WHEN delivery fails, THE DeliveryAgent SHALL select reason (Customer Not Available, Wrong Address, Order Refused) and reschedule or return to shop.
9. THE DeliveryAgentDashboard SHALL display earnings history, delivery statistics, and ratings from customers.

---

### Requirement 8: Search and Discovery

**User Story:** As a customer, I want to search for products, discover deals, and get personalized recommendations, so that I can find relevant products quickly.

#### Acceptance Criteria

1. WHEN the customer taps the search bar, THE System SHALL show recent searches and popular products.
2. WHEN entering search query, THE SearchService SHALL perform real-time search with debounce (300ms) and display results instantly.
3. THE SearchIndex SHALL support searching by: product name, brand, category, shop name, and barcode (via QR scanner).
4. WHEN scanning a product barcode, THE ProductProvider SHALL lookup the product and navigate to its detail page.
5. WHEN no results found, THE System SHALL suggest related categories and display "Notify when available" option.
6. THE RecommendationEngine SHALL display "You May Also Like" products based on: purchase history, browsing history, and similar user preferences.
7. THE DealSection SHALL highlight: flash sales (with countdown), bundle offers, and buy-one-get-one offers.
8. WHEN filtering by district or village, THE System SHALL show only products available in the selected hyperlocal area.

---

### Requirement 9: Wishlist and Save for Later

**User Story:** As a customer, I want to save products to a wishlist and get price drop notifications, so that I can purchase items when I want.

#### Acceptance Criteria

1. WHEN a customer taps the heart icon on a product, THE WishlistManager SHALL add the product to the wishlist and display confirmation.
2. WHEN viewing the wishlist, THE System SHALL display saved products with current price, original price, discount percentage, and stock status.
3. WHEN a wishlist item goes out of stock, THE System SHALL display "Out of Stock" badge.
4. WHEN a wishlist item price drops by more than 10%, THE NotificationService SHALL send push notification to the customer.
5. WHEN tapping a wishlist item, THE System SHALL navigate to the product detail page.
6. WHEN removing an item from wishlist, THE System SHALL delete it and update the wishlist count.
7. THE WishlistManager SHALL persist wishlist locally and sync with Firestore for cross-device access.

---

### Requirement 10: Reviews and Ratings

**User Story:** As a customer, I want to rate products and write reviews, so that I can share my feedback with other customers.

#### Acceptance Criteria

1. WHEN an order is delivered, THE System SHALL prompt the customer to rate the products and shop within 7 days.
2. WHEN rating a product, THE RatingComponent SHALL allow selecting 1-5 stars with optional text review and image upload (up to 3 images).
3. WHEN submitting a review, THE ReviewValidator SHALL check for: minimum 3 characters for text, valid star rating, and profanity filter.
4. THE ProductRatingCalculator SHALL update the product's average rating and review count within 1 hour of new review.
5. WHEN viewing reviews, THE System SHALL display reviews sorted by: Most Recent, Highest Rating, Lowest Rating, and Most Helpful.
6. WHEN a shop owner responds to a review, THE System SHALL append the response below the original review.
7. THE ReviewModerationSystem SHALL flag inappropriate reviews for admin review.

---

### Requirement 11: Wallet and Rewards

**User Story:** As a customer, I want to use my wallet balance and earn reward points, so that I can save money on purchases.

#### Acceptance Criteria

1. WHEN a customer completes a purchase, THE WalletService SHALL calculate and add cashback (1% of order value) to wallet balance.
2. THE RewardSystem SHALL award points based on: purchase amount (1 point per ₹10), first order (100 points), reviews (20 points), and referrals (50 points).
3. WHEN applying reward points at checkout, THE System SHALL convert points to currency (100 points = ₹1) and deduct from order total.
4. WHEN redeeming wallet balance, THE System SHALL allow using up to 50% of order value from wallet.
5. THE MembershipTierCalculator SHALL upgrade tiers based on lifetime spending: Bronze (₹0-999), Silver (₹1000-4999), Gold (₹5000-19999), Platinum (₹20000+).
6. WHEN wallet balance is updated, THE System SHALL update Firestore and local cache within 1 second.
7. THE WalletHistory SHALL display: transaction type, amount, order reference, and timestamp with pagination.

---

### Requirement 12: Notifications and Messaging

**User Story:** As a user, I want to receive timely notifications about orders, promotions, and important updates, so that I stay informed.

#### Acceptance Criteria

1. WHEN the app starts, THE NotificationService SHALL request FCM permission and subscribe to relevant topics.
2. THE NotificationCenter SHALL support notification types: Order Updates, Promotions, Price Drops, Shop Updates, and System Messages.
3. WHEN an order status changes, THE System SHALL send push notification with: order number, new status, and action button.
4. WHEN a promotion is available, THE System SHALL send notification with: offer title, discount percentage, validity, and deep link to products.
5. WHEN the customer is offline, THE NotificationService SHALL queue notifications and deliver when online.
6. THE NotificationSettings SHALL allow users to configure: enable/disable each notification type, quiet hours (10 PM - 8 AM), and frequency limits.
7. WHEN the customer taps a notification, THE System SHALL navigate to the relevant screen (Order Details, Product, etc.).

---

### Requirement 13: Location and Delivery Area

**User Story:** As a customer, I want to see if my area is serviceable and get accurate delivery estimates, so that I know if I can use the app.

#### Acceptance Criteria

1. WHEN the app starts, THE LocationService SHALL request location permission and detect current coordinates.
2. THE DeliveryAreaValidator SHALL check if the location is within the configured district boundaries.
3. WHEN the location is outside service area, THE System SHALL display: service area map, nearest available location, and option to join waitlist.
4. WHEN the customer enters a pincode, THE System SHALL validate serviceability and display available delivery options.
5. THE DeliveryEstimator SHALL calculate estimated delivery time based on: shop distance, delivery type, current queue, and traffic conditions.
6. WHEN scheduling a delivery, THE System SHALL show available time slots for the next 7 days.
7. THE VillageDeliveryService SHALL support extended delivery to surrounding villages with adjusted delivery times and charges.

---

### Requirement 14: Admin Panel

**User Story:** As an admin, I want to manage users, shops, products, and view analytics, so that I can oversee the platform operations.

#### Acceptance Criteria

1. WHEN an admin logs in, THE AdminDashboard SHALL display: total users, active shops, today's orders, revenue, and platform health metrics.
2. THE UserManagementModule SHALL allow: viewing user list, disabling users, resetting passwords, and viewing transaction history.
3. THE ShopManagementModule SHALL allow: approving new shop registrations, verifying documents, suspending shops, and managing shop categories.
4. THE ProductModerationModule SHALL allow: flagging inappropriate products, hiding products, and deleting products with reason.
5. THE OrderManagementModule SHALL allow: viewing all orders, manually updating status, processing refunds, and handling disputes.
6. THE CouponManagementModule SHALL allow: creating, editing, and deleting promotional coupons with configurable parameters.
7. THE AnalyticsModule SHALL display: revenue charts (daily/weekly/monthly), user growth, top products, top shops, and delivery performance.
8. THE SystemSettingsModule SHALL allow: configuring delivery charges, service areas, commission rates, and promotional banners.

---

### Requirement 15: Offline Support and Performance

**User Story:** As a user, I want the app to work offline for basic features and load quickly, so that I have a smooth experience.

#### Acceptance Criteria

1. WHEN the device is offline, THE OfflineManager SHALL cache: last viewed products, categories, and user profile using Hive.
2. WHEN viewing cached products, THE System SHALL display cached data within 100ms and show "Offline" indicator.
3. WHEN adding items to cart offline, THE CartProvider SHALL save to local storage and sync when online.
4. WHEN placing orders offline, THE OrderQueue SHALL queue the order and attempt submission when connectivity is restored.
5. THE AppStartupTime SHALL be under 3 seconds on first launch and under 1 second on subsequent launches.
6. THE ImageLoader SHALL lazy load product images with placeholder and implement efficient caching.
7. THE NetworkMonitor SHALL detect connectivity changes and update UI accordingly (online/offline banner).

---

### Requirement 16: Accessibility and Localization

**User Story:** As a user with disabilities or language preferences, I want the app to be accessible and available in my language, so that I can use it comfortably.

#### Acceptance Criteria

1. THE App SHALL support screen readers (TalkBack/VoiceOver) with proper labels for all interactive elements.
2. THE App SHALL support minimum contrast ratio of 4.5:1 for text and 3:1 for large text.
3. THE App SHALL support touch target size of at least 44x44 pixels for all buttons.
4. THE App SHALL be fully functional with keyboard navigation.
5. THE App SHALL support Hindi language in addition to English, with proper font rendering.
6. THE CurrencyFormatter SHALL display prices in Indian Rupees (₹) with proper localization.
7. THE DateTimeFormatter SHALL display dates in DD/MM/YYYY format and times in 12-hour format with AM/PM.
8. THE App SHALL support right-to-left (RTL) layout for Hindi language.

---

### Requirement 17: Security and Privacy

**User Story:** As a user, I want my data to be secure and my privacy protected, so that I feel safe using the app.

#### Acceptance Criteria

1. THE AuthService SHALL use Firebase Auth with phone number verification and implement rate limiting (max 5 OTP requests per hour).
2. THE DataEncryption SHALL encrypt sensitive data (wallet balance, payment tokens) using AES-256.
3. THE SessionManager SHALL automatically log out after 30 minutes of inactivity.
4. THE API Security SHALL implement Firestore security rules to prevent unauthorized access to user data.
5. THE PrivacyCompliance SHALL not store Aadhaar numbers, full PAN numbers, or other sensitive identity documents.
6. THE DataExport SHALL allow users to request a copy of their data (GDPR compliance).
7. THE App SHALL not share user data with third parties except as necessary for payment processing and delivery.

---

### Requirement 18: Analytics and Crash Reporting

**User Story:** As a developer, I want to track app usage and monitor crashes, so that I can improve the app.

#### Acceptance Criteria

1. THE AnalyticsService SHALL track: screen views, user actions, search queries, conversion funnels, and session duration using Firebase Analytics.
2. THE CrashReporter SHALL capture stack traces and custom logs using Firebase Crashlytics.
3. THE PerformanceMonitor SHALL track: app startup time, screen rendering time, and API response times.
4. THE UserProperties SHALL track: user role, membership tier, total orders, and location district.
5. THE EventLogging SHALL log key events: product_view, add_to_cart, checkout_started, purchase_completed, and search_performed.
6. THE Dashboard SHALL display real-time analytics for active users, orders, and revenue.