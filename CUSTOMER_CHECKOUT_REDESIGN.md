# Customer Checkout — Unified Flow Design
**Date:** June 6, 2026  
**Goal:** Professional, simple checkout for local store ordering

---

## Current Problem

**Fragmented Experience:**
- CheckoutScreen (3-step stepper)
- CheckoutAuthSheet (bottom sheet overlay for OTP)
- PaymentVerificationDialog (overlay for payment status)
- Order confirmation (separate route)

**Issues:**
- Customer doesn't see clear progress (4 different UI layers)
- Payment status unclear ("is it done?")
- Error messages buried or missing
- Guest checkout not streamlined

---

## New Unified Checkout Flow

```
┌─────────────────────────────────────────────────┐
│ STEP 1: VERIFY PHONE (Guest or Returning)       │
├─────────────────────────────────────────────────┤
│ [Phone input] [Request OTP] [Verify OTP]        │
│ Error handling: Rate limit, invalid phone       │
│ ✓ Advance → Cart Review                         │
└─────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────┐
│ STEP 2: REVIEW CART (Order Summary)             │
├─────────────────────────────────────────────────┤
│ Items:                                           │
│  • Milk (2L) × 2 = ₹80                          │
│  • Atta (5kg) × 1 = ₹150                        │
│ Subtotal: ₹230                                  │
│ Delivery: ₹0 (Free)                             │
│ Total: ₹230                                     │
│ [Edit Cart] [Promo Code]                        │
│ ✓ Advance → Select Address                      │
└─────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────┐
│ STEP 3: SELECT ADDRESS & DELIVERY               │
├─────────────────────────────────────────────────┤
│ Saved Addresses: (if returning customer)        │
│  [Home] [Office] [Add New]                      │
│ Delivery Type:                                  │
│  ⭕ Standard (4 hours) FREE                      │
│  ⭕ Express (30 min) ₹50                         │
│ Scheduled: [Select date & time]                 │
│ Delivery Instructions: [Gate 5B]                │
│ ✓ Advance → Payment                             │
└─────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────┐
│ STEP 4: SELECT PAYMENT                          │
├─────────────────────────────────────────────────┤
│ Payment Method:                                 │
│  ⭕ Cash on Delivery (COD)                      │
│  ⭕ UPI/Card (Razorpay)                         │
│  ⭕ Wallet (₹50 available)                      │
│ Total: ₹230                                     │
│ [Place Order]                                   │
│ ✓ → Payment Processing                          │
└─────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────┐
│ STEP 5: PAYMENT PROCESSING & CONFIRMATION       │
├─────────────────────────────────────────────────┤
│ (For COD) ✓ Order Confirmed!                   │
│ Order #12345                                    │
│ Estimated Delivery: 4 hours                     │
│ [Track Order] [Call Store]                      │
│                                                 │
│ (For Razorpay) Processing payment...            │
│ [Loading spinner + cancel button]               │
│ ✓ Payment Success!                              │
│ Order #12345 confirmed                          │
│ [Track Order] [Rate Store]                      │
│                                                 │
│ (For Razorpay) ❌ Payment Failed                │
│ [Retry Payment] [Try Different Method]          │
└─────────────────────────────────────────────────┘
```

---

## Detailed Step Specifications

### STEP 1: VERIFY PHONE (if guest or session expired)

**UI:**
```
┌─────────────────────────────────────┐
│ Verify Your Phone Number            │
│ (to confirm your order)             │
├─────────────────────────────────────┤
│ [+91] [                    ]         │
│         (enter 10 digits)           │
│                                     │
│ [Request OTP]                       │
├─────────────────────────────────────┤
│ OR                                  │
│ [Sign In with Existing Account]     │
└─────────────────────────────────────┘

After [Request OTP]:
┌─────────────────────────────────────┐
│ Enter OTP sent to +91-99999-00000   │
│                                     │
│ [_ _ _ _ _ _]                       │
│ (auto-focus, auto-advance)          │
│                                     │
│ Resend OTP in 30s (or [Resend])     │
└─────────────────────────────────────┘
```

**Logic:**
- If user already logged in → Skip this step
- If guest → Show phone verification
- After OTP verified → Create temporary session
- Rate limiting: Max 3 OTP attempts per phone per 10 minutes

**Errors:**
- "Invalid phone number" (show format)
- "Too many attempts. Try again in 8 minutes"
- "OTP expired. Request a new one"
- "Network error. Check your internet"

---

### STEP 2: REVIEW CART

**UI:**
```
┌─────────────────────────────────────┐
│ Review Your Order                   │
├─────────────────────────────────────┤
│ Items (scrollable if many):         │
│ Milk (2L)                   ₹80 x2  │
│ [Edit] [Remove]                     │
│                                     │
│ Atta (5kg)                 ₹150 x1  │
│ [Edit] [Remove]                     │
├─────────────────────────────────────┤
│ Subtotal          ₹230              │
│ Delivery          FREE (express +50)│
│ Promo Code        [Enter]           │
│ ────────────────────────────────────│
│ Total             ₹230              │
│                                     │
│ [Edit Cart] [Continue]              │
└─────────────────────────────────────┘
```

**Logic:**
- Show all items with quantities
- "Edit Cart" button → Returns to cart screen
- Delivery info shows default + alternative
- Promo code input (optional)
- Continue → Next step

---

### STEP 3: SELECT ADDRESS & DELIVERY

**UI:**
```
┌─────────────────────────────────────┐
│ Delivery Address                    │
├─────────────────────────────────────┤
│ Saved Addresses (if returning):     │
│ [🏠 Home]  [🏢 Office] [+ Add New] │
│                                     │
│ OR Single Address:                  │
│ D-504, Green Towers                 │
│ Sector 5, Delhi                     │
│ [Edit] [Use Current Location]       │
│                                     │
│ Delivery Instructions (optional):   │
│ [Gate 5B, Ring 3 times]            │
│                                     │
│ Delivery Type:                      │
│ ⭕ Standard (4 hours) — FREE        │
│    "Will arrive between 3-5 PM"     │
│                                     │
│ ⭕ Express (30 min) — ₹50           │
│    "Will arrive by 2:30 PM"         │
│    [Unavailable for your area]      │
│                                     │
│ ⭕ Scheduled — FREE                 │
│    Date: [Tomorrow 9 AM - 12 PM]    │
│                                     │
│ [Continue]                          │
└─────────────────────────────────────┘
```

**Logic:**
- Show "Saved Addresses" if customer has 2+ previous orders
- "Use Current Location" → Map picker with one-tap confirmation
- Delivery type options based on address (some areas may not support express)
- Time estimate shown for each option
- Scheduled delivery: Show available dates/slots

**Errors:**
- "We don't deliver to your area. Call us at +91-999-000-0000"
- "Express delivery unavailable for your area"
- "No delivery slots available today"

---

### STEP 4: SELECT PAYMENT

**UI:**
```
┌─────────────────────────────────────┐
│ Choose Payment Method               │
├─────────────────────────────────────┤
│ Order Summary:                      │
│ Subtotal:        ₹230              │
│ Delivery:        FREE               │
│ ────────────────────────────────────│
│ Total:           ₹230              │
│                                     │
│ Payment Options:                    │
│ ⭕ Cash on Delivery (COD)           │
│    "Pay when order arrives"        │
│                                     │
│ ⭕ UPI / Card (Razorpay)            │
│    "Fast & secure payment"         │
│                                     │
│ ⭕ My Wallet (₹50 available)        │
│    ⬜ Use wallet for ₹50           │
│    Remaining: ₹180 (pay via COD)  │
│                                     │
│ [Place Order]                       │
└─────────────────────────────────────┘
```

**Logic:**
- Show available payment methods
- If wallet has balance: Show option to use partial wallet
- COD always available (unless blocked by store)
- UPI/Card shows "Fast & secure" trust indicator

---

### STEP 5: PAYMENT PROCESSING & CONFIRMATION

**Scenario A: Cash on Delivery (Immediate Success)**
```
┌─────────────────────────────────────┐
│ ✓ Order Confirmed!                  │
├─────────────────────────────────────┤
│ Order Number: #12345                │
│ Total: ₹230 (to be paid on delivery)│
│                                     │
│ Estimated Delivery:                 │
│ 📍 4 hours (by 5:00 PM)             │
│ 📱 Your delivery agent will call    │
│                                     │
│ Items:                              │
│ • Milk (2L) × 2                    │
│ • Atta (5kg) × 1                   │
│                                     │
│ [Track Order] [Call Store]          │
│ [Rate Store]                        │
└─────────────────────────────────────┘
```

**Scenario B: Razorpay Payment (Processing)**
```
┌─────────────────────────────────────┐
│ Processing Payment...               │
│                                     │
│ [Loading spinner]                   │
│                                     │
│ Order #12345                        │
│ Amount: ₹230                        │
│ Method: UPI/Card                    │
│                                     │
│ Do not close this screen            │
│ Payment status checking...          │
│                                     │
│ [Cancel Order?]                     │
└─────────────────────────────────────┘
```

**Scenario C: Payment Success**
```
┌─────────────────────────────────────┐
│ ✓ Payment Successful!               │
├─────────────────────────────────────┤
│ Order #12345 Confirmed              │
│ Amount Paid: ₹230                   │
│ Receipt: [Download]                 │
│                                     │
│ Estimated Delivery:                 │
│ 📍 30 minutes (by 2:30 PM)          │
│ 📱 You'll get a call when nearby    │
│                                     │
│ Items:                              │
│ • Milk (2L) × 2                    │
│ • Atta (5kg) × 1                   │
│                                     │
│ [Track Order] [Call Store]          │
│ [Rate Store]                        │
└─────────────────────────────────────┘
```

**Scenario D: Payment Failed**
```
┌─────────────────────────────────────┐
│ ❌ Payment Failed                   │
├─────────────────────────────────────┤
│ "Card was declined"                 │
│ Your order has NOT been placed      │
│                                     │
│ Options:                            │
│ 1. [Retry Payment]                  │
│    (Try same method again)          │
│                                     │
│ 2. [Use Different Method]           │
│    (Back to payment selection)      │
│                                     │
│ 3. [Switch to Cash on Delivery]     │
│    (Change to COD, place order)    │
│                                     │
│ 4. [Call Store for Help]           │
│    +91-999-000-0000                │
│                                     │
│ Cart saved. Items still in your bag.│
└─────────────────────────────────────┘
```

---

## Progress Indicator

**Visual:**
```
Step 1        Step 2         Step 3         Step 4         Step 5
[Phone] ——→ [Cart] ———→ [Address] ——→ [Payment] ——→ [✓ Confirm]
  ✓            ✓            Active/Current      Pending      Pending
```

**Desktop/Tablet:** Show all 5 steps at top with active step highlighted
**Mobile:** Show current step number ("Step 3 of 5") + back button

---

## Error Handling Strategy

### Network Error
```
Icon: 📡 (signal)
Title: "No Internet Connection"
Message: "Check your connection and try again"
Action: [Retry] [Go Back to Cart]
```

### Delivery Area Issue
```
Icon: 📍
Title: "Delivery Not Available"
Message: "We don't deliver to [Sector 10, Delhi]"
Sub: "Closest store: 12 km away"
Action: [Call Store] [Change Address]
```

### Payment Failure (Specific)
```
❌ Card Declined
"Your card issuer declined this payment"
[Retry] [Try Different Card] [Use COD]

❌ Insufficient Balance
"Your wallet has only ₹20, need ₹230"
[Add to Wallet] [Use COD] [Use Card]

❌ Timeout
"Payment gateway not responding"
[Retry] [Change Payment Method]
```

### Stock Issue
```
⚠️ Item Out of Stock
"Milk (2L) is no longer available"
[Remove from Order] [Check Alternatives]
```

---

## Implementation Notes

### Files to Modify/Create
1. **lib/screens/customer/checkout_screen.dart** — Main refactor
2. **lib/screens/customer/checkout_auth_sheet.dart** — Logic merged into checkout_screen
3. **lib/screens/customer/payment_verification_dialog.dart** — Logic merged into checkout_screen
4. **lib/widgets/checkout/checkout_step_indicator.dart** — Update for 5 steps

### State Management
- Use `_currentStep` (0-4) to track progress
- Use `_isProcessing` to disable buttons during payment
- Use `_paymentStatus` for final confirmation state

### Firestore Integration
- Listen to order status during payment
- Auto-confirm after payment succeeds
- Handle timeout after 30 seconds

### Route Handling
After successful order:
- Route to `/customer/order-confirmation?orderId=...&orderNumber=...`
- Clear cart
- Show recent order at top of home screen

---

## Success Criteria

✅ Single checkout screen (not fragmented)  
✅ Clear 5-step progress indicator  
✅ Guest checkout without signup  
✅ Saved address quick-select  
✅ Real-time payment status messaging  
✅ Clear error handling (no cryptic messages)  
✅ All actions return to sensible screens  
✅ Mobile & desktop responsive  
✅ Accessibility (large touch targets, readable text)  

---

## Timeline

- **Step 1 (Phone):** 1 hour
- **Step 2 (Cart):** 30 minutes
- **Step 3 (Address):** 1 hour
- **Step 4 (Payment):** 30 minutes
- **Step 5 (Confirmation):** 1 hour
- **Testing & Polish:** 30 minutes

**Total: 4-5 hours**

---

**Status:** DESIGN READY FOR IMPLEMENTATION
