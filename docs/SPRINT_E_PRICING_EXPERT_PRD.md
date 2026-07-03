# Pricing Expert Agent — Product Requirements Document

**Sprint:** E (Phase 3)  
**Status:** In Development  
**Target Release:** 2026-07-15  

---

## Overview

The **Pricing Expert** is a Gemini-powered AI agent that analyzes your product catalog and market conditions to recommend optimal pricing strategies. It runs asynchronously, watching for:
- New products (suggest opening price)
- Stock changes (dynamic price adjustments)
- Competitor activity (parity pricing)
- Seasonal trends (demand-based price hikes)

**Owner User:** Shop manager / Admin  
**Approval Model:** Human-in-the-loop (agent proposes, you approve)

---

## Core Responsibilities

### 1. Dynamic Pricing
**Input:** Product ID, current stock level, historical sales velocity, competitor price  
**Output:** Recommended price adjustment (up/down by ₹X or Y%)  
**Logic:**
- If stock < 5 units → suggest +15% premium (scarcity pricing)
- If stock > 50 units → suggest -5% discount (clear inventory)
- If competitor price < yours by >20% → suggest -10% to stay competitive
- If competitor out of stock → suggest +10% (capture their demand)

### 2. Margin Optimization
**Input:** Product cost, current price, GST (18%)  
**Output:** Margin summary + warnings for low-margin items  
**Logic:**
- Calculate: Margin % = (Price - Cost) / Price
- Flag if margin < 25% (acceptable minimum for retail)
- Suggest minimum price floor to hit 30% margin
- Categorize products: High-margin (>40%), Medium (25–40%), Low (<25%)

### 3. Bundle & Discount Strategy
**Input:** Products with similar categories, sales history, customer reviews  
**Output:** Suggested product bundles + discount rules  
**Logic:**
- Identify frequently co-purchased items → suggest bundle (e.g., "Dad Grooming Combo": Shaver + Trimmer + Aftershave)
- If product has 4.5+ rating + high review volume → suggest volume discount (buy 2 save 5%)
- If product has <3.0 rating → suggest 10% discount to boost trial
- Bundle discount: 10–15% off total (not cumulative per item)

### 4. Price Testing (Phase 3b)
**Input:** Product ID, current price, suggested test range  
**Output:** A/B test plan (50% cohort at price A, 50% at price B)  
**Note:** Phase 3b feature; Phase 3 will only suggest, not implement.

---

## Trigger Events

The Pricing Expert wakes up and analyzes when:

| Event | What Happens |
|---|---|
| Product status = `ACTIVE` (new product) | Suggest opening price based on cost + competitive analysis |
| Stock updated | Re-evaluate dynamic pricing |
| Competitor price changed (monthly check) | Flag parity opportunities |
| Day = 15th of month | Generate monthly pricing report (all products, margin analysis) |
| User clicks "Pricing Review" in Mission Control | On-demand analysis |

---

## Data Model

### `PricingRecommendation` (Firestore)
```json
{
  "id": "price_rec_123",
  "shopId": "shop_1",
  "productId": "product_42",
  "createdAt": "2026-07-10T14:30:00Z",
  "agentVersion": "pricing_expert_v1.0",
  "recommendations": {
    "dynamicPrice": {
      "currentPrice": 599,
      "suggestedPrice": 679,
      "reason": "Stock critically low (3 units); suggest +13% premium",
      "confidence": 0.92
    },
    "marginAnalysis": {
      "cost": 300,
      "currentMargin": 49.9,
      "warningFlag": false,
      "marginalCategory": "High"
    },
    "bundleOpportunity": {
      "bundleName": "Dad Grooming Combo",
      "products": ["product_42", "product_51", "product_63"],
      "suggestedPrice": 1299,
      "savingsPerCustomer": 150,
      "estimatedLift": "12% higher AOV"
    }
  },
  "status": "PENDING",  // PENDING, APPROVED, REJECTED, ARCHIVED
  "approvedAt": null,
  "rejectionReason": null,
  "metrics": {
    "priceChangeImpact": {
      "estimatedRevenueBoost": "₹15,000/month if approved"
    }
  }
}
```

---

## Approval Flow

1. **Agent proposes** → `PricingRecommendation` created with status=`PENDING`
2. **User reviews** → Sees card in Mission Control inbox with diff preview:
   ```
   Current Price: ₹599 | Suggested: ₹679 (+₹80)
   Margin: 49.9% (Healthy)
   Reason: Stock level critically low; premium pricing justified
   [Approve] [Reject] [Edit & Approve]
   ```
3. **User action:**
   - ✅ **Approve** → `PricingRecommendation.status = APPROVED`, product price updated
   - ❌ **Reject** → status = `REJECTED`, reason logged, agent learns not to suggest this
   - ✏️ **Edit & Approve** → User adjusts suggestion, then approves custom price
4. **Agent learns** → Next month, agent skips low-confidence recommendations user rejected

---

## Approval UI Components

**In Mission Control Inbox:**
```
┌─────────────────────────────────────────────────┐
│ 💰 PRICING EXPERT RECOMMENDATION                │
├─────────────────────────────────────────────────┤
│ Product: Papa's Special Glasses (ID: product_42)│
│ Recommendation: Dynamic Price Adjustment        │
│                                                  │
│ Current Price:    ₹599                          │
│ Suggested Price:  ₹679 (+13%)                   │
│ Reason: Stock critically low (3 units)          │
│ Confidence: 92%                                 │
│                                                  │
│ Margin Impact:                                  │
│ Current: 49.9% | Projected: 56.4% ✅           │
│                                                  │
│ Revenue Estimate: +₹15,000/month                │
│                                                  │
│ [Approve] [Reject] [Edit & Approve]             │
└─────────────────────────────────────────────────┘
```

---

## Success Metrics

After launch, measure:

| Metric | Target | Notes |
|---|---|---|
| Avg margin improvement | +2–3% | Across all products |
| Revenue from dynamic pricing | +8–12% | YoY vs. static pricing |
| Bundle adoption rate | >25% | % of customers buying bundles |
| Agent accuracy | >85% | % of approved recommendations that drive expected results |
| Review time | <2 min | User time to review one recommendation |

---

## Integration Points

- **Firestore:** Read from `products`, `orders`, `inventory`; write to `pricing_recommendations`
- **Gemini API:** Analyze product names, descriptions, reviews; generate bundle suggestions
- **Mission Control UI:** New "Pricing" tab in inbox
- **Competitor API:** (Phase 3b) Scheduled daily price checks
- **Analytics:** Track which recommendations were approved vs. rejected

---

## Known Constraints

- Phase 3 does NOT include price testing (A/B testing)
- Competitor pricing is manual input only (no automated scraping)
- Discounts are shop-level only (no per-customer dynamic pricing)
- GST (18%) is always calculated on final price

---

## Dependencies

- ✅ Firestore schema with `products`, `inventory`, `orders`
- ✅ Gemini API access (text-only models)
- ✅ Mission Control UI framework (cards, approval flows)
- ⏳ Customer Analyst (cohort data helps price targeting in Phase 3b)

---

## Acceptance Criteria

- [ ] Agent wakes on all trigger events
- [ ] Generates recommendations with >80% confidence
- [ ] Approval flow is <2 min per item
- [ ] Approved prices sync to product catalog within 30 seconds
- [ ] Rejected recommendations are logged for learning
- [ ] UI shows clear diffs (current vs. suggested)
- [ ] Revenue impact estimates are visible to user
- [ ] No pricing change without explicit user approval

