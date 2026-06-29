# 🏪 FUFAJI STORE - COMPLETE BUILD GUIDE & WORKFLOW
**For Android Studio AI / Development Team**

---

## 📋 TABLE OF CONTENTS
1. [Project Overview](#project-overview)
2. [Technology Stack](#technology-stack)
3. [Complete Feature List](#complete-feature-list)
4. [User Types & Permissions](#user-types--permissions)
5. [Database Architecture](#database-architecture)
6. [Workflow: Step-by-Step Build Order](#workflow-step-by-step-build-order)
7. [UI/UX Specifications](#uiux-specifications)
8. [Authentication System](#authentication-system)
9. [Payment Integration](#payment-integration)
10. [Admin/Owner/Employee Workflows](#adminownemployee-workflows)
11. [Deployment Checklist](#deployment-checklist)

---

## PROJECT OVERVIEW

### App Purpose
**Fufaji Store** is an e-commerce mobile app designed for Indian shopkeepers to sell grocery/daily items to customers. Simple, no confusion, straightforward UX.

### Target Users
- **Customers**: Indian families shopping for daily groceries
- **Shopkeepers/Owners**: Manage inventory, view orders, manage staff
- **Employees**: Process orders, manage inventory in shop
- **Delivery Partners**: Track and deliver orders
- **Admins**: System-wide management

### Core Value Proposition
- Simple product search → Add to cart → Checkout via UPI
- No camera, no snapping photos, no gimmicks
- Real-time inventory management
- Multiple user roles with permission controls
- Production-ready, enterprise-grade security

### Success Criteria
- App must work for low-end Android devices
- Load time < 3 seconds
- No crashes on product operations
- Payment success rate > 99%
- Support Hindi + English languages

---

## TECHNOLOGY STACK

### Frontend
- **Framework**: React Native (Expo) or Flutter (your choice)
- **Navigation**: React Navigation / Flutter GoRouter
- **State Management**: Redux / Provider / GetX
- **UI Components**: Native components + Custom design
- **Local Storage**: AsyncStorage / SharedPreferences

### Backend
- **Primary**: Firebase (Firestore, Authentication, Cloud Functions, Storage)
- **Alternative**: Node.js + Express + MongoDB (if you prefer custom backend)
- **Authentication**: Firebase Auth (Phone OTP)
- **Database**: Firestore (NoSQL, real-time)

### Payments
- **Primary**: Stripe (UPI, Card, NetBanking)
- **Alternative**: Razorpay (simpler UPI integration)

### DevOps
- **Build**: Android Studio / Gradle
- **Testing**: Espresso / JUnit (Android)
- **Deployment**: Google Play Store / APK distribution

---

## COMPLETE FEATURE LIST

### PHASE 1: MVP (MINIMUM VIABLE PRODUCT)
**Timeline**: Week 1-2

#### 1.1 Customer App Features
- [ ] **Authentication**
  - Phone number login with OTP (Firebase)
  - User profile setup (name, address)
  - Persistent login (token storage)
  - Logout functionality

- [ ] **Product Catalog**
  - Display all products with images
  - Search by product name (Hindi + English)
  - Filter by category (Groceries, Dairy, Snacks, Health)
  - Product details: price, description, stock status, emoji rating
  - Product images (emoji previews, actual photos)

- [ ] **Shopping Cart**
  - Add/remove items
  - Update quantity
  - Persistent cart (survives app restart)
  - Display subtotal + GST (18%) + Total
  - Clear cart button

- [ ] **Checkout**
  - Enter/select delivery address
  - Order summary (all items + GST breakdown)
  - Stripe payment integration (UPI primary)
  - Order confirmation page with order ID
  - Receipt generation

- [ ] **Order History**
  - View all past orders
  - Order details (date, items, total, status)
  - Reorder button (add previous order items to cart)

- [ ] **Notifications**
  - Order placed confirmation
  - Order status updates (Confirmed → Packed → Out for Delivery → Delivered)
  - Payment receipt

#### 1.2 Shopkeeper/Owner Features
- [ ] **Authentication**
  - Phone + OTP login
  - Separate owner/admin login

- [ ] **Dashboard**
  - Total orders today
  - Total revenue (today, this week, this month)
  - Pending orders count
  - Low stock alerts

- [ ] **Inventory Management**
  - View all products in database
  - Add new product (name in Hindi + English, price, category, stock, image/emoji)
  - Edit product (price, stock, description)
  - Delete product
  - Bulk upload products (CSV import)
  - Set product emoji/image for preview

- [ ] **Order Management**
  - View all orders (status: pending, confirmed, packed, out for delivery, delivered, cancelled)
  - Update order status
  - View customer details per order
  - Print order receipt/invoice
  - Cancel order (if not shipped)

- [ ] **Staff Management**
  - Add employees (name, phone, role: order-handler, inventory-handler, delivery-partner)
  - View active employees
  - Deactivate employee
  - Set permissions per employee

- [ ] **Basic Reports**
  - Daily sales report
  - Best-selling products
  - Revenue by category
  - Customer count

#### 1.3 Employee Features
- [ ] **Order Fulfillment**
  - View pending orders
  - Update order status (confirmed → packed → ready for pickup)
  - Print packing labels

- [ ] **Inventory Checks**
  - View current stock levels
  - Mark items as restocked
  - Report low stock

#### 1.4 Delivery Partner Features
- [ ] **Delivery Tracking**
  - Assigned deliveries list
  - Customer address + phone
  - Navigate to customer (Google Maps integration)
  - Mark as delivered
  - Customer signature/OTP confirmation

---

### PHASE 2: ENHANCEMENTS (WEEKS 3-4)

- [ ] Wishlist functionality
- [ ] Product ratings & reviews
- [ ] Promo codes / discounts
- [ ] Multiple delivery addresses
- [ ] Wallet / credits system
- [ ] Email receipt
- [ ] SMS notifications
- [ ] Admin analytics dashboard
- [ ] Referral program

---

## USER TYPES & PERMISSIONS

| User Type | Login | Can View Products | Can Order | Can Manage Inventory | Can View Orders | Can Update Status | Can Manage Staff |
|---|---|---|---|---|---|---|---|
| **Customer** | Phone OTP | ✅ | ✅ | ❌ | Own only | ❌ | ❌ |
| **Employee** | Phone OTP | ✅ | ❌ | ✅ (limited) | All | ✅ (assigned) | ❌ |
| **Delivery Partner** | Phone OTP | ❌ | ❌ | ❌ | Assigned only | ✅ (delivery) | ❌ |
| **Shopkeeper/Owner** | Phone OTP | ✅ | ❌ | ✅ | All | ✅ | ✅ |
| **Admin** | Email/Password | ✅ | ❌ | ✅ | All | ✅ | ✅ |

---

## DATABASE ARCHITECTURE

### Collections Structure (Firestore)

#### 1. `users` Collection
```
users/{userId}
├── uid: string (Firebase Auth UID)
├── phone: string (10 digits)
├── name: string
├── email: string (optional)
├── role: string (customer / employee / delivery_partner / owner / admin)
├── isActive: boolean
├── createdAt: timestamp
├── profileImage: string (storage URL)
└── addresses: array
    ├── [0]: { street, city, pincode, isDefault }
    ├── [1]: { ... }
```

#### 2. `products` Collection
```
products/{productId}
├── name: string (Hindi)
├── nameEn: string (English)
├── category: string (Groceries / Dairy / Snacks / Health / Clothing / Others)
├── price: number (in rupees)
├── gst: number (18 for all items)
├── stock: number
├── description: string
├── emoji: string (🥛 for milk, 🍎 for fruits, etc.)
├── image: string (Firebase Storage URL)
├── createdBy: string (owner userId)
├── createdAt: timestamp
├── updatedAt: timestamp
├── isActive: boolean (for soft delete)
└── dadJoke: string (optional, for app personality)
```

#### 3. `orders` Collection
```
orders/{orderId}
├── orderId: string (auto-generated, e.g., "ORD-20240615-001")
├── customerId: string (Firebase Auth UID)
├── customerName: string
├── customerPhone: string
├── customerEmail: string (optional)
├── deliveryAddress: object
│   ├── street: string
│   ├── city: string
│   ├── pincode: string
│   └── lat/lng: geo coordinates (optional)
├── items: array
│   ├── [0]: { productId, productName, quantity, price, gst, totalGst, subtotal }
│   ├── [1]: { ... }
├── subtotal: number (sum of item prices, excl. GST)
├── totalGst: number (sum of all GST)
├── total: number (subtotal + totalGst)
├── paymentMethod: string (upi / card / netbanking)
├── paymentStatus: string (pending / success / failed / refunded)
├── paymentId: string (Stripe/Razorpay transaction ID)
├── orderStatus: string (pending / confirmed / packed / out_for_delivery / delivered / cancelled)
├── assignedEmployee: string (userId, optional)
├── assignedDeliveryPartner: string (userId, optional)
├── createdAt: timestamp
├── deliveredAt: timestamp (when status = delivered)
├── notes: string (special instructions)
└── receipt: object { receiptUrl, invoiceNumber }
```

#### 4. `carts` Collection (Temporary, can also use local AsyncStorage)
```
carts/{userId}
├── items: array
│   ├── [0]: { productId, quantity }
│   ├── [1]: { ... }
├── lastUpdated: timestamp
```

#### 5. `employees` Collection
```
employees/{employeeId}
├── userId: string (reference to users/{userId})
├── name: string
├── phone: string
├── role: string (order_handler / inventory_handler / delivery_partner)
├── permissions: array (view_orders, update_inventory, deliver_orders)
├── isActive: boolean
├── joinedDate: timestamp
├── shopId: string (which shop they work for, if multi-shop)
└── baseSalary: number (optional, for future payroll)
```

#### 6. `inventory` Collection (Optional, for tracking stock separately)
```
inventory/{productId}
├── productId: string
├── currentStock: number
├── reorderLevel: number (alert when stock < this)
├── reorderQuantity: number (how much to order at once)
├── lastRestocked: timestamp
└── history: array (log of stock changes)
```

#### 7. `settings` Collection (Shop Configuration)
```
settings/shop_config
├── shopName: string
├── shopPhone: string
├── shopEmail: string
├── shopAddress: string
├── openingTime: string (HH:MM format, e.g., "09:00")
├── closingTime: string (HH:MM format, e.g., "21:00")
├── isOpen: boolean (real-time status)
├── gstRate: number (18 for now)
├── stripeKeyPublic: string (for client-side)
├── razorpayKeyPublic: string (alternative)
└── logo: string (Firebase Storage URL)
```

#### 8. `notifications` Collection (Optional, for push notifications)
```
notifications/{notificationId}
├── userId: string
├── type: string (order_placed / status_update / payment_success / low_stock)
├── title: string
├── message: string
├── data: object (orderId, etc.)
├── isRead: boolean
└── createdAt: timestamp
```

---

## WORKFLOW: STEP-BY-STEP BUILD ORDER

### BUILD PHASE 1: FOUNDATION (Days 1-3)

#### Step 1: Project Setup & Navigation
1. Create new React Native / Flutter project
2. Set up folder structure:
   ```
   /app
   ├── /screens (CustomerHome, ProductDetail, Cart, Checkout, OrderHistory, OwnerDashboard)
   ├── /components (ProductCard, CartItem, Header, BottomNav)
   ├── /services (FirebaseService, StripeService, NotificationService)
   ├── /models (User, Product, Order, Employee)
   ├── /utils (constants, formatters, validators)
   └── /assets (images, icons)
   ```
3. Install dependencies: Firebase SDK, Navigation, State Management
4. Set up bottom navigation: Customer / Owner / Employee tabs

#### Step 2: Firebase Setup
1. Create Firebase project in console
2. Enable services: Authentication (Phone), Firestore, Storage, Cloud Functions
3. Create Firestore collections: users, products, orders, employees, settings
4. Set up security rules (public read for products, user-specific read/write for orders)
5. Create test data: 20 sample products with emojis

#### Step 3: Authentication (Phone OTP)
1. Implement phone number input screen
2. Implement OTP verification screen
3. Store user profile in Firestore after successful login
4. Implement persistent login (token saved locally)
5. Create logout functionality

---

### BUILD PHASE 2: CUSTOMER FEATURES (Days 4-7)

#### Step 4: Product Catalog
1. Create product list screen with FlatList/RecyclerView
2. Implement search functionality (by name, case-insensitive)
3. Implement category filter (dropdown/tabs)
4. Create product detail screen (full description, larger image, stock status)
5. Add product emoji rating display
6. Pull all products from Firestore in real-time

#### Step 5: Shopping Cart
1. Implement add-to-cart button
2. Create cart screen (list of items, quantity controls, remove button)
3. Implement persistent cart (save to AsyncStorage / SharedPreferences)
4. Calculate and display GST (18%) separately
5. Calculate and display Total (subtotal + GST)
6. Add empty cart state + "Continue Shopping" button

#### Step 6: Checkout
1. Create checkout screen (address selection/input, order summary)
2. Implement address form validation (name, phone, pincode)
3. Display order summary with GST breakdown
4. Integrate Stripe for payment (create PaymentIntent on backend)
5. Display payment method options (UPI primary, Card fallback)
6. Show success screen with order ID + confirmation message

#### Step 7: Order History & Reorder
1. Create order history screen (list of past orders)
2. Query orders from Firestore filtered by `customerId`
3. Display order date, total, status
4. Implement "Reorder" button to add previous items to current cart
5. Add order detail screen (tap to view all items in past order)

---

### BUILD PHASE 3: OWNER/ADMIN FEATURES (Days 8-10)

#### Step 8: Owner Dashboard
1. Create dashboard screen (summary cards: today's orders, revenue, pending count)
2. Calculate and display daily revenue (sum of all orders.total where orderStatus = delivered & date = today)
3. Implement manual refresh button (pull from Firestore)
4. Show real-time low stock alerts

#### Step 9: Inventory Management
1. Create product management screen (list all products with edit/delete buttons)
2. Implement add-product form (name in Hindi + English, price, category, stock, emoji)
3. Implement edit-product form (update price, stock, description)
4. Implement delete (soft delete via `isActive = false`)
5. Add bulk import option (CSV → parse → Firestore batch write)
6. Display real-time stock levels with color coding (green = sufficient, yellow = low, red = out of stock)

#### Step 10: Order Management
1. Create orders-list screen (all orders, filterable by status)
2. Implement status update (dropdown: pending → confirmed → packed → out for delivery → delivered)
3. Show customer details (name, phone, address)
4. Add print functionality (receipt/invoice)
5. Implement order cancellation (if status = pending only)
6. Show payment status (success/failed)

#### Step 11: Employee Management
1. Create employee-list screen
2. Implement add-employee form (name, phone, role, permissions)
3. Implement edit-employee (update permissions, deactivate)
4. Show active/inactive toggle
5. Store employees in Firestore `employees` collection

---

### BUILD PHASE 4: EMPLOYEE & DELIVERY FEATURES (Days 11-12)

#### Step 12: Employee App
1. Create order-fulfillment screen (pending orders only)
2. Implement status update buttons (confirmed → packed → ready)
3. Show customer phone + address for order
4. Add print label functionality

#### Step 13: Delivery Partner App
1. Create delivery-list screen (assigned orders only)
2. Show customer address + phone
3. Integrate Google Maps (navigate to customer location)
4. Implement "Mark as Delivered" button + OTP/signature capture (optional for MVP)
5. Show delivery route optimization (if multi-delivery)

---

### BUILD PHASE 5: PAYMENTS & NOTIFICATIONS (Days 13-14)

#### Step 14: Stripe Integration
1. Create Firebase Cloud Function: `createPaymentIntent` (backend endpoint)
2. Implement Stripe SDK in app
3. Show UPI QR code OR Stripe-hosted payment form
4. Handle payment success/failure responses
5. Update order.paymentStatus in Firestore on success
6. Show receipt/invoice after successful payment

#### Step 15: Notifications
1. Set up Firebase Cloud Messaging (FCM)
2. Send push notifications on: order placed, status update, payment success
3. Store notification history in Firestore
4. Show in-app notification badge/bell

---

### BUILD PHASE 6: TESTING & DEPLOYMENT (Days 15-16)

#### Step 16: Testing
1. Unit tests: GST calculation, validators (phone, pincode)
2. Integration tests: add to cart → checkout → order creation
3. UI tests: all screens render correctly
4. Payment tests: Stripe test mode
5. Test on low-end Android device (API 24+)

#### Step 17: Security & Optimization
1. Review Firestore rules (no hardcoded secrets, proper access control)
2. Implement input validation (XSS prevention, injection prevention)
3. Optimize images (compress, lazy load)
4. Minify code, reduce APK size
5. Test on poor network (throttle connection)

#### Step 18: Deployment
1. Build release APK (Gradle)
2. Sign APK with keystore
3. Test release APK on real device
4. Create Google Play Store listing (Hindi + English)
5. Upload screenshots, description, icon
6. Submit for review

---

## UI/UX SPECIFICATIONS

### Design Tokens
```
Colors:
- Primary: #1A5276 (trustworthy blue)
- Accent: #E67E22 (warm orange)
- Background: #FDFEFE (off-white)
- Text Primary: #1C2833 (dark gray)
- Text Secondary: #5D6D7B (light gray)
- Success: #27AE60 (green)
- Error: #E74C3C (red)
- Warning: #F39C12 (orange)

Typography:
- Font Family: Noto Sans (supports Hindi)
- Heading: 24px, Bold
- Subheading: 18px, Medium
- Body: 14px, Regular
- Small: 12px, Regular

Spacing:
- 4px, 8px, 12px, 16px, 20px, 24px, 32px

Border Radius:
- Small: 4px
- Medium: 8px
- Large: 12px
```

### Screen Specifications

#### Screen 1: Customer Home
```
Layout:
- Header: Shop name + location + open/close status
- Search bar: "Search products..." (placeholder in Hindi too)
- Category filter: Tabs (All / Groceries / Dairy / Snacks / Health)
- Product grid: 2 columns, ProductCard components
  └─ ProductCard: emoji + image + name (hi+en) + price + rating + "Add to Cart" button
- Bottom nav: Home / Orders / Account

Interactions:
- Tap product → ProductDetail screen
- Tap "Add to Cart" → Toast "Added to cart" + cart badge update
- Search → filter products in real-time
- Category tab → filter by category
```

#### Screen 2: Product Detail
```
Layout:
- Header: Back button + product name
- Large product image / emoji
- Name in Hindi + English
- Price (₹599)
- In stock / Out of stock status
- Description (multi-line)
- Dad joke (if available)
- Quantity selector (- / number / +)
- "Add to Cart" button (full-width, primary color)
- "Save to Wishlist" (optional, heart icon)

Interactions:
- Tap quantity +/- → update quantity preview
- Tap "Add to Cart" → go to Cart screen
```

#### Screen 3: Shopping Cart
```
Layout:
- Header: "Your Cart" + item count
- CartItem list:
  └─ [Item]: emoji + name + price + qty selector + remove button
- Order summary box:
  └─ Subtotal: ₹1200
  └─ GST (18%): ₹216
  └─ Total: ₹1416
- "Proceed to Checkout" button (primary, full-width)
- "Continue Shopping" button (secondary)

Interactions:
- Tap qty +/- → recalculate total in real-time
- Tap X (remove) → remove item + recalculate
- Tap "Clear Cart" → show confirmation dialog
- Tap "Proceed" → go to Checkout screen
```

#### Screen 4: Checkout
```
Layout:
- Header: "Checkout" + step indicator (1/3, 2/3, 3/3)
- Step 1: Address
  └─ Saved addresses (if any) + "Add New Address" option
  └─ Form: Name, Phone, Street, City, Pincode, Landmark
  └─ "Next" button
  
- Step 2: Order Summary
  └─ Delivery address (read-only, edit link)
  └─ Item list (from cart)
  └─ Subtotal / GST / Total breakdown
  └─ "Next" button
  
- Step 3: Payment
  └─ Payment method selector (UPI / Card)
  └─ UPI: Show QR code + "Pay Now" button
  └─ Card: Show Stripe-hosted form
  └─ Processing state (spinner) during payment

Interactions:
- Fill address form → validate (phone = 10 digits, pincode = 6 digits)
- Tap "Next" → go to step 2
- Tap "Next" → go to step 3
- Tap "Pay Now" → create Stripe PaymentIntent → show payment UI
- On success → go to Success screen
- On failure → show error message + retry option
```

#### Screen 5: Order Confirmation
```
Layout:
- Checkmark icon (animated, large)
- "Order Placed Successfully! 🎉" message
- Order ID: ORD-20240615-001
- Total amount: ₹1416
- Estimated delivery: "Today by 6 PM" / "Tomorrow by 2 PM"
- Dad joke: "आप का ऑर्डर इतना तेज़ पहुंचेगा कि डिलीवरी पार्टनर को भी आश्चर्य होगा! 😂"
- "View Order" button
- "Continue Shopping" button

Interactions:
- Tap "View Order" → OrderDetail screen
- Tap "Continue Shopping" → HomeScreen
```

#### Screen 6: Order History
```
Layout:
- Header: "My Orders"
- Filter tabs: All / Pending / Delivered
- OrderCard list (newest first):
  └─ Date (15 Jun 2024)
  └─ Order ID (ORD-20240615-001)
  └─ Items summary (3 items)
  └─ Total (₹1416)
  └─ Status badge (Delivered / Out for Delivery / Pending)
  └─ "Reorder" button
  
- Tap to expand order details

Interactions:
- Tap order → OrderDetail screen
- Tap "Reorder" → add items to cart + show toast "Items added to cart"
- Swipe to filter by status
```

#### Screen 7: Owner Dashboard
```
Layout:
- Header: "Dashboard"
- Summary cards (4 cards in 2x2 grid):
  └─ Card 1: "Today's Orders" + count (e.g., 12)
  └─ Card 2: "Revenue Today" + amount (₹5,640)
  └─ Card 3: "Pending Orders" + count (e.g., 3)
  └─ Card 4: "Low Stock Items" + count (e.g., 2)

- Pending Orders Section:
  └─ Quick view of top 5 pending orders
  └─ Each order: customer name + phone + items count + "View Details" link

- Low Stock Alerts:
  └─ List of products with stock < reorder level
  └─ Red background for severity

- Refresh button (top-right)

Interactions:
- Tap "Today's Orders" card → OrdersList screen
- Tap "View Details" → OrderDetail screen
- Tap "Low Stock Items" → Inventory screen
- Pull-to-refresh → reload data from Firestore
```

#### Screen 8: Inventory Management
```
Layout:
- Header: "Inventory" + "Add Product" button
- Search bar: "Search products..."
- Product list:
  └─ ProductItem: name + price + stock (color-coded) + edit + delete buttons

- Add/Edit Product form (modal or new screen):
  └─ Name (Hindi): text input
  └─ Name (English): text input
  └─ Category: dropdown
  └─ Price: number input
  └─ Stock: number input
  └─ Description: textarea
  └─ Emoji picker / Image upload
  └─ "Save" button

Interactions:
- Tap "Add Product" → open form
- Tap edit icon → populate form + "Update" button
- Tap delete icon → show confirmation + delete (soft delete)
- Search → filter products in real-time
```

#### Screen 9: Orders Management (Owner)
```
Layout:
- Header: "All Orders" + filter dropdown
- Filter options: All / Pending / Confirmed / Packed / Out for Delivery / Delivered / Cancelled
- OrderCard list:
  └─ Order ID + Date
  └─ Customer name + phone
  └─ Items count
  └─ Total
  └─ Status (with update dropdown)
  └─ Action buttons: View Details / Print / Cancel (if applicable)

Interactions:
- Tap status dropdown → show status options → save to Firestore
- Tap "View Details" → OrderDetail modal
- Tap "Print" → generate receipt PDF
- Tap "Cancel" → confirm + update status to "cancelled"
```

---

## AUTHENTICATION SYSTEM

### Phone OTP Flow
```
1. User opens app
   ↓
2. Check if user is logged in (stored token in local storage)
   ├─ YES → go to Home screen
   └─ NO → go to Login screen
   ↓
3. User enters phone number (10 digits)
   ↓
4. Firebase sends OTP to phone (via SMS)
   ↓
5. User enters 6-digit OTP
   ↓
6. Firebase verifies OTP
   ├─ SUCCESS → generate user UID
   │   ↓
   │   Create/update user document in Firestore users/{uid}
   │   Store token locally
   │   Go to Home screen (or Profile setup if first-time)
   │
   └─ FAILURE → show error "Invalid OTP" + retry
```

### User Roles & Role-Based Access
```
Role Assignment:
1. Customer (default for new users)
2. Owner/Admin (manual assignment via admin panel)
3. Employee (owner creates employee account)
4. Delivery Partner (owner assigns delivery task)

Role-Based UI:
- Customer sees: Home, Products, Cart, Checkout, Orders, Account
- Owner sees: Dashboard, Inventory, Orders, Employees, Reports, Account
- Employee sees: Orders, Inventory, Tasks, Account
- Delivery Partner sees: Deliveries, Map, Account
```

---

## PAYMENT INTEGRATION

### Stripe UPI Flow (Recommended for India)
```
1. User completes checkout form
2. App creates order document in Firestore (status: pending_payment)
3. App calls Firebase Cloud Function: createPaymentIntent
   └─ Function params: { orderId, amount }
4. Cloud Function creates Stripe PaymentIntent (payment_method_types: ['upi'])
5. App displays PaymentIntent details (client_secret)
6. App shows Stripe-hosted payment form OR custom UPI form
7. User scans UPI QR code OR enters card details
8. Stripe processes payment
9. Webhook called → Cloud Function updates Firestore order.paymentStatus = success
10. App polls order document OR listens to real-time updates
11. Show success screen

Failure handling:
- If payment fails → show error + allow retry
- If PaymentIntent expires (after 24h) → create new one
```

### Razorpay Alternative (Simpler)
```
1-5. Same as Stripe
6. App integrates Razorpay SDK
7. Show Razorpay payment form (UPI primary)
8. User completes payment
9. App gets payment confirmation
10. Update Firestore order
11. Show success screen
```

---

## ADMIN/OWNER/EMPLOYEE WORKFLOWS

### Owner Workflow (Daily)
```
Morning:
1. Open app → Dashboard
2. Check pending orders count
3. Check low stock alerts
4. Go to "All Orders" → update status (confirmed → packed)

Afternoon:
5. Go to "Inventory" → check stock levels
6. Add new products if needed
7. Review today's revenue

Evening:
8. Check delivered orders
9. Review customer feedback (if enabled)
```

### Employee Workflow (During Shift)
```
1. Open app → Orders screen (filtered to pending)
2. Pick pending order
3. Confirm order (status: confirmed)
4. Get items from inventory
5. Mark as packed
6. Notify owner / delivery partner
7. Repeat
```

### Delivery Partner Workflow
```
1. Open app → Deliveries screen
2. See assigned deliveries for the day
3. Tap delivery → show customer address + phone
4. Navigate using Google Maps
5. Reach customer → call or message
6. Get OTP from customer / take signature
7. Mark as delivered
8. Move to next delivery
```

---

## DEPLOYMENT CHECKLIST

### Pre-Launch Security Audit
- [ ] No hardcoded API keys anywhere in code
- [ ] Firestore rules properly restrict access (no `allow read, write: if true`)
- [ ] Firebase Cloud Functions have input validation
- [ ] Payment processing uses Stripe/Razorpay (never store raw card data)
- [ ] Phone numbers validated (10 digits only, no +91)
- [ ] All forms have CSRF protection

### Pre-Launch Performance
- [ ] App loads home screen in < 3 seconds
- [ ] Images optimized (< 500KB per image)
- [ ] Firestore queries use proper indexing
- [ ] APK size < 50MB
- [ ] No memory leaks (test with Android Profiler)
- [ ] Test on Pixel 4a (mid-range) and Redmi (budget)

### Pre-Launch Testing
- [ ] Manual testing: all 9 screens work
- [ ] Payment: test 3 UPI transactions in test mode
- [ ] Auth: test phone login with multiple numbers
- [ ] Orders: create → update status → deliver
- [ ] Offline handling: app doesn't crash on poor network

### Google Play Store Submission
- [ ] App title: "Fufaji Store"
- [ ] Category: Shopping
- [ ] Content rating: Completed questionnaire
- [ ] Description (Hindi + English):
  ```
  फुफाजी स्टोर - आपके दैनिक जरूरत का सामान ऑनलाइन खरीदें।
  सरल, तेज़, और सुरक्षित शॉपिंग अनुभव।
  
  Fufaji Store - Buy your daily groceries online.
  Simple, fast, and secure shopping experience.
  ```
- [ ] Screenshots (6): Home, Product, Cart, Checkout, Orders, Dashboard
- [ ] Icon: 512x512px, PNG
- [ ] Minimum API: 24 (Android 7.0)
- [ ] Target API: 34+ (Android 14)

### Post-Launch
- [ ] Monitor Firebase error logs
- [ ] Check Stripe payment success rate
- [ ] Monitor app crashes via Firebase Crashlytics
- [ ] Customer support channel (email / WhatsApp)
- [ ] Plan v1.1 features based on user feedback

---

## QUICK REFERENCE: KEY NUMBERS

| Metric | Value |
|---|---|
| Target Users | 10,000+ in 3 months |
| Products in catalog | 20-200 (scalable) |
| GST rate | 18% (all items) |
| Payment providers | Stripe (primary), Razorpay (backup) |
| Min Android version | API 24 (Android 7.0) |
| Target Android version | API 34 (Android 14) |
| App load time target | < 3 seconds |
| APK size target | < 50MB |
| Firebase Firestore regions | asia-south1 (Mumbai) |
| Languages | Hindi + English |
| Currency | Indian Rupee (₹) |

---

## NEXT STEPS FOR YOUR DEVELOPMENT TEAM

1. **Share this guide** with your Android Studio AI or dev team
2. **They implement** each section in the build order
3. **Test each phase** (customer → owner → employee → payments)
4. **Deploy to Google Play Store**
5. **Monitor and iterate** based on user feedback

---

**Document Version:** 1.0  
**Last Updated:** June 15, 2024  
**Status:** Ready for Development  
