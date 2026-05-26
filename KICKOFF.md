# Fufaji's Online - Build Kickoff

## Goal

Build a mobile-first local e-commerce app for the family shop: customers can browse and order, the owner can manage products and orders, and delivery partners can track deliveries.

## MVP Scope

1. Customer app
   - Phone OTP login and guest browsing
   - Product browsing, search, cart, checkout
   - COD-first checkout, Razorpay-ready payment path
   - Order history and saved addresses

2. Owner app
   - Dashboard with daily sales and pending orders
   - Product and inventory management
   - Order status workflow from received to delivered

3. Delivery app
   - Assigned orders
   - Delivery status updates
   - Earnings overview

## Brand Direction

- App name: Fufaji's Online
- Positioning: your trusted family shop, now online
- First launch focus: district/local delivery, simple ordering, fast owner operations

## Technical Direction

- Current scaffold: Flutter app with Firebase providers
- State management: Provider
- Routing: GoRouter
- Backend target: Firebase Auth, Firestore, Storage, Messaging
- Payments: COD first, Razorpay integration after product/order flow is stable

## Immediate Next Steps

1. Install/configure Flutter SDK locally and run `flutter pub get`.
2. Connect Firebase app configuration and Android `google-services.json`.
3. Run `flutter analyze` and fix any remaining analyzer issues.
4. Seed products/categories for the first shop catalog.
5. Test the customer flow: login, browse, cart, checkout, order.

## Later Expansion

- Employee packing panel
- WhatsApp notifications
- Multi-vendor local market mode
- Hindi/English language toggle
- Smart stock alerts and recommendations
