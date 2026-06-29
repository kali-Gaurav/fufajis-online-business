# 👥 CUSTOMER PANEL REVIEW — FUFAJI STORE USER TESTING
**Date:** June 23, 2026  
**Participants:** 3 core personas (Ramesh, Vikram, Sunita)  
**Task:** Download app, create account, place order, track delivery, request refund

---

## TESTING PROTOCOL

Each customer persona was given the app and asked to:
1. ✅ Download from WhatsApp link
2. ✅ Create account with phone OTP
3. ✅ Browse products and add to cart
4. ✅ Complete checkout with payment
5. ✅ Track order status
6. ✅ Receive delivery
7. ✅ Request refund
8. ✅ Rate experience

**Device:** Android phones (low-end Redmi 5A, mid-range Redmi 10, high-end iPhone 13)  
**Network:** 4G LTE (simulating real-world conditions)  
**Time to Complete:** 10 minutes per persona

---

## C1 — RAMESH, 52, DELHI (CORE DAD DEMOGRAPHIC)

### Profile
- Retired govt employee, basic smartphone
- First time using Fufaji
- Speaks Hindi primarily, reads English with difficulty
- Cautious about online payments
- Wants to order lunch for family (vegetarian)

### Experience

**🟢 WHAT WORKED:**
- ✅ **Hindi error messages** - "गलत OTP" (Wrong OTP) made sense. Didn't confuse him.
- ✅ **Large text** - Font size was readable without glasses
- ✅ **WhatsApp link** - Trusted it more than "download from Play Store"
- ✅ **OTP login** - No need to remember passwords. Used code from SMS easily.
- ✅ **Big buttons** - Easy to tap without accidentally clicking adjacent buttons
- ✅ **Product images with Hindi names** - "आलू की सब्जी" (Potato curry) clearly identified
- ✅ **COD option** - "Didn't have to enter card number. Just get food first, pay delivery guy"
- ✅ **Simple checkout** - 3 screens (address → payment method → confirm). Didn't get lost.
- ✅ **Order confirmation in SMS** - Got text with order #, could share with family

**🔴 PROBLEMS ENCOUNTERED:**

1. **First problem: App size too large**
   - "Why is it 150 MB? I have only 2GB storage"
   - Deleted some photos to make space, took 5 minutes
   - **Severity:** 🟡 High - Many Indian users have low storage
   - **Fix needed:** Compress assets, lazy-load images, target 80-100 MB APK

2. **Second problem: UPI payment unclear**
   - "What is UPI? I know PhonePe. Will this work?"
   - He wanted PhonePe, not generic UPI
   - **Severity:** 🟡 Medium - Could use branding (PhonePe/Google Pay logos, not "UPI")
   - **Fix needed:** Show logos of supported apps (PhonePe, Google Pay, BHIM)

3. **Third problem: Delivery time vague**
   - "When will my food come? 10 minutes? 1 hour?"
   - Order screen said "Preparing" but no time estimate
   - **Severity:** 🟠 High - He kept checking app every 2 minutes worrying food was lost
   - **Fix needed:** Show "Expected delivery: 3:45 PM" prominently

4. **Fourth problem: Rider name/number anxiety**
   - "I don't know this rider. Is he safe? What if he doesn't come?"
   - No rider profile, ratings, or verification
   - **Severity:** 🔴 Critical - He didn't feel safe with unknown rider
   - **Fix needed:** Show rider name, phone number, rating, photo, vehicle number

5. **Fifth problem: Refund condition confusion**
   - When asking about returns, he couldn't find how to request a refund
   - No "Contact support" button, no FAQ
   - **Severity:** 🟡 High - Support burden will spike with unclear refund process
   - **Fix needed:** Add FAQ tab explaining refund policy and conditions

**📊 RAMESH'S SCORE:** 6/10
- **Completed order?** ✅ YES (took 8 minutes, 1 mistake)
- **Will use again?** 🟡 MAYBE - "If food quality is good and delivery on time"
- **Would recommend?** ❌ NO - "Too many questions, too scary for a first time"
- **Biggest worry:** "What if food doesn't come? Can I get my money back?"

**Ramesh's Feedback:** *"It works but I don't trust it yet. Need to see if food actually comes. Show me the rider's face, please. And tell me what time food will come."*

---

## C7 — VIKRAM, 33, GURGAON (PREMIUM USER)

### Profile
- Corporate professional, iPhone user
- Used Swiggy 1000+ times
- Expects premium UX
- Testing from office during lunch break
- High expectations

### Experience

**🟢 WHAT WORKED:**
- ✅ **Fast loading** - App opened instantly, no loading spinners
- ✅ **Smooth navigation** - Transitions between screens felt polished
- ✅ **Smart cart** - Remembered my preferences from previous order (if saved)
- ✅ **Payment integration** - 1-tap payment with saved card
- ✅ **Order tracking map** - Live rider location was cool
- ✅ **Estimated delivery time** - Showed "ETA: 2:47 PM" during packing

**🔴 PROBLEMS ENCOUNTERED:**

1. **First problem: No Swiggy feature parity**
   - Swiggy has: Scheduled orders, group orders, promos applied automatically
   - Fufaji has: None of this
   - **Severity:** 🟡 Medium - Missing features that Swiggy users expect
   - **Feedback:** "Why would I switch from Swiggy if Fufaji has fewer features?"

2. **Second problem: Performance on 4G not great**
   - Images took 3+ seconds to load on 4G (switched from WiFi)
   - **Severity:** 🟠 Medium - Indian 4G is standard, should be optimized
   - **Fix needed:** Compress images, use WebP format, lazy-load off-screen items

3. **Third problem: Search functionality limited**
   - Searched for "paneer butter masala" but got results for "butter" and "masala" separately
   - No fuzzy matching, no autocomplete suggestions
   - **Severity:** 🟡 Medium - UX feels basic vs. Swiggy's search quality
   - **Fix needed:** Improve search algorithm, add autocomplete

4. **Fourth problem: No cancellation window shown**
   - Clicked order, but no "cancel if placed within 2 minutes" message
   - Concerned about being locked in
   - **Severity:** 🟡 Low for Vikram (he doesn't cancel), Medium for cautious users
   - **Fix needed:** Show "Cancel order (available for 5 min)" or similar

5. **Fifth problem: Dark mode missing**
   - Phone is set to dark mode, app forced light mode
   - Brightness was harsh at 1 PM in direct sunlight
   - **Severity:** 🟡 Low (not critical), but feels unpolished
   - **Fix needed:** Add system dark mode support

**📊 VIKRAM'S SCORE:** 7/10
- **Completed order?** ✅ YES (took 3 minutes, smooth)
- **Will use again?** 🟡 MAYBE - "Only if your shops have better food/value than Swiggy"
- **Would recommend?** ❌ NO - "Tell me why I should use this over Swiggy first"
- **Deal-breaker:** "No scheduled orders? That's table stakes."

**Vikram's Feedback:** *"App works, but feels like Swiggy 2 years ago. Better execution of basics, or add a feature Swiggy doesn't have to make me switch. Also, dark mode please."*

---

## C10 — SUNITA, 55, AHMEDABAD (CAUTIOUS HOMEMAKER)

### Profile
- Homemaker, new to online shopping
- Gifted smartphone by son
- Extremely cautious about fraud
- Fears "losing money online"
- First time ordering food online

### Experience

**🟢 WHAT WORKED:**
- ✅ **COD option** - "I can pay when food comes, no need to trust the app"
- ✅ **Simple flow** - No unnecessary options, straight path to checkout
- ✅ **Confirmation SMS** - Got text confirmation, screenshot saved for reference
- ✅ **Shop rating/verification** - Icon showing "Verified Shop" gave confidence
- ✅ **Estimated time** - "3:15 PM" let her plan when to be home
- ✅ **Support phone number visible** - "If something goes wrong, I can call"

**🔴 PROBLEMS ENCOUNTERED:**

1. **First problem: Initial anxiety about app legitimacy**
   - "Is this a real app or will my money get stolen?"
   - Downloaded from WhatsApp link, not Play Store (felt less safe)
   - **Severity:** 🔴 Critical - Trust is everything for first-time users
   - **Fix needed:** Display "Downloaded 1M+ times" or "Verified by Fufaji" badge prominently on splash screen

2. **Second problem: Payment screen felt risky**
   - "Why is my card information going here? I don't trust it."
   - Selected COD instead to feel safe
   - **Severity:** 🔴 Critical - She won't use card even with Stripe/Razorpay
   - **Fix needed:** Add security badges (SSL, payment security logo), explain "Your card details go to Razorpay, not us"

3. **Third problem: Delivery uncertainty**
   - "What if rider takes money but doesn't give food?"
   - Wanted to verify rider before order
   - **Severity:** 🟠 High - Lack of rider info = anxiety for cautious users
   - **Fix needed:** Show rider info BEFORE confirming order, let customer verify

4. **Fourth problem: No return address/refund clarity**
   - "If food is bad, how do I send it back?"
   - Couldn't find refund policy in app
   - **Severity:** 🟡 High - Made her second-guess the order
   - **Fix needed:** Simple FAQ: "If food is bad, call us. We'll refund in 5 minutes to your wallet."

5. **Fifth problem: Language clarity**
   - Hindi translation wasn't perfect ("भोजन रद्द करें" felt formal, not conversational)
   - Could have used simpler Hindi ("खाना रद्द करो")
   - **Severity:** 🟡 Low for comprehension, Medium for trust
   - **Fix needed:** Use colloquial Hindi, not formal/textbook Hindi

**📊 SUNITA'S SCORE:** 5/10
- **Completed order?** ✅ YES (took 12 minutes, lots of hesitation)
- **Will use again?** 🟡 MAYBE - "Only if food was good and arrived on time. Then maybe."
- **Would recommend?** ❌ NO - "I'll wait and see if this is real before telling my friends"
- **Biggest barrier:** Trust (doesn't believe payment is safe)

**Sunita's Feedback:** *"I don't trust online payment. COD is good. But show me that your riders are real people, not scammers. And promise that if food is bad, you'll refund immediately. Then I'll tell my friends."*

---

## AGGREGATE CUSTOMER INSIGHTS

### What All 3 Customers Agreed On:

✅ **LOVES:**
1. **Hindi support** - All appreciated Hindi error messages and UI
2. **Simple checkout** - No unnecessary steps, just 3 screens
3. **Status updates** - Knowing when food was packed/out for delivery
4. **COD option** - Trust builder for first-time users
5. **WhatsApp distribution** - Felt more legitimate than unknown app

❌ **HATES:**
1. **No rider information** - None showed rider name/photo before delivery
2. **Unclear refund process** - All asked "What if food is bad?"
3. **No support contact visible** - Fear of being stuck if something goes wrong
4. **Vague delivery times** - "Preparing" doesn't tell you when food arrives
5. **Large APK size** - Ramesh deleted photos to install (150 MB too big)

### Pain Points Summary:

| Issue | Severity | Impact | Fix Effort |
|-------|----------|--------|-----------|
| APK too large (150 MB) | 🟠 High | Low-storage users can't install | Medium (compress assets) |
| No rider info shown | 🔴 Critical | Users don't trust delivery | Low (show rider card) |
| Refund process unclear | 🔴 Critical | Support burden spike | Low (add FAQ) |
| Delivery time vague | 🟠 High | Users anxious about food | Low (show ETA) |
| Payment safety unclear | 🔴 Critical | Users avoid card payment | Low (add security badges) |
| Dark mode missing | 🟡 Low | Premium users annoyed | Medium (implement) |

---

## NPS SCORES (Net Promoter Score)

**Ramesh:** 6 (Detractor - Won't recommend)  
**Vikram:** 7 (Passive - Might recommend if feature-complete)  
**Sunita:** 5 (Detractor - Needs reassurance first)

**Average NPS: 6/10** (Target for launch: 30+)

**Interpretation:** Customers will use it (they completed orders), but won't actively recommend. You need to build trust and add safety signals.

---

## RECOMMENDATIONS FOR LAUNCH DAY

### CRITICAL (Do before launch or in first week):
1. ✅ Show rider name, phone, rating before delivery accepted
2. ✅ Add "Contact Support" button with live chat/phone number
3. ✅ Create simple FAQ answering "What if food is bad?"
4. ✅ Add "Refund in 5 minutes to wallet" guarantee messaging
5. ✅ Add security badges on payment screen

### IMPORTANT (Do in first month):
1. 👷 Reduce APK size from 150 MB to 80-100 MB
2. 👷 Improve search with autocomplete and fuzzy matching
3. 👷 Show "Cancel order (available for 5 min)" on confirmation
4. 👷 Optimize images for 4G loading
5. 👷 Add system dark mode support

### NICE-TO-HAVE (Q3 2026):
1. 💡 Scheduled orders
2. 💡 Group orders
3. 💡 Automatic promo application
4. 💡 Colloquial Hindi translation review

---

## SUCCESS METRICS TO TRACK

Monitor these post-launch:

| Metric | Ramesh Target | Vikram Target | Sunita Target | Overall Target |
|--------|---|---|---|---|
| Completion rate | 80%+ | 95%+ | 60%+ | 78%+ |
| Repeat purchase rate | 30% | 60% | 20% | 37%+ |
| Support contact rate | 5% | 1% | 15% | 7% |
| Refund request rate | 2% | 0.5% | 5% | 2.5% |

---

## FINAL CUSTOMER PANEL VERDICT

🟡 **GO FOR LAUNCH (but be prepared for trust-building work)**

**Why launch despite low NPS:**
1. Customers CAN use the app (they all completed orders)
2. Core functionality works (checkout, payment, tracking)
3. Trust issues are fixable in week 1 (rider info, FAQ, support)
4. You won't know what customers really want until they use it live

**What this tells you:**
- Ramesh (core segment) is cautious but willing
- Vikram (premium segment) will only use if you differentiate vs. Swiggy
- Sunita (conservative segment) needs maximum trust signals

**Post-launch priorities:**
1. Week 1: Add trust signals (rider info, FAQ, support chat)
2. Week 2: Fix performance (APK size, image compression, search)
3. Month 1: Build feature parity with Swiggy for Vikram segment
4. Month 2: Regional language support (Telugu, Tamil, Kannada)

