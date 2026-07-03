# Customer Analyst Agent — Product Requirements Document

**Sprint:** E (Phase 3)  
**Status:** In Development  
**Target Release:** 2026-07-15  

---

## Overview

The **Customer Analyst** is a Gemini-powered AI agent that watches your customer base, detects patterns, and alerts you to opportunities and risks. It segments customers, predicts churn, identifies upsell moments, and synthesizes feedback into actionable insights.

**Owner User:** Shop manager / Marketing team  
**Approval Model:** Human-in-the-loop + automated alerts (critical insights auto-notify)

---

## Core Responsibilities

### 1. Purchase Pattern Analysis
**Input:** All orders (customer ID, products, date, amount, frequency)  
**Output:** Customer segments + purchase insights  
**Logic:**
- **High-Value Customers:** Total lifetime value > ₹10,000 + purchase frequency > 1/month
  - Recommendation: VIP treatment, exclusive pre-launch access, loyalty discount
- **New Customers:** First purchase < 30 days ago
  - Recommendation: Onboarding email, follow-up survey, welcome discount
- **Repeat Customers:** 3+ purchases, regular intervals
  - Recommendation: Upsell complementary products, bundle deals
- **One-Time Buyers:** 1 purchase > 90 days old, no repeat
  - Recommendation: Win-back campaign, ask for feedback

### 2. Churn & Retention Detection
**Input:** Customer purchase history, last purchase date, product reviews  
**Output:** Churn risk score + retention actions  
**Logic:**
- **At-Risk (Score 0.7–0.9):** No purchase in 60+ days (but used to buy monthly)
  - Trigger: "We miss you" email + 15% loyalty discount
- **Critical (Score 0.9+):** No purchase in 90+ days + gave low review (< 3 stars)
  - Trigger: Manual outreach, ask "What went wrong?"
- **Retained (Score < 0.3):** Purchased in last 30 days
  - No action needed; track for repeat

### 3. Satisfaction & Feedback Synthesis
**Input:** Product reviews, support tickets, NPS surveys (future)  
**Output:** Sentiment summary + product/service issues  
**Logic:**
- **By Product:** Identify high-complaint products (e.g., "Shaver broke after 2 weeks")
  - Recommendation: Refund rate analysis, quality investigation, warranty review
- **By Category:** If 3+ reviews mention "shipping delay", flag as logistics issue
  - Recommendation: Escalate to operations
- **Overall Sentiment:** Calculate average rating trend over 30-day windows
  - Alert if trending down (quality or service issue)

### 4. Cohort Analysis
**Input:** Customer segments created in step 1, revenue data  
**Output:** Cohort performance + growth trends  
**Logic:**
- **Cohort = Month of first purchase** (e.g., "June 2026 cohort")
- Measure per cohort:
  - Retention rate after 30/60/90 days
  - Average order value (AOV) over time
  - Churn rate (% who never purchased again)
- **Comparison:** June cohort vs. May cohort → identify if onboarding improved
- **High-Value Cohort:** If May cohort has 40% higher AOV, ask "What changed?"

---

## Trigger Events

The Customer Analyst wakes up and analyzes when:

| Event | What Happens |
|---|---|
| New order placed | Check if customer is at-risk for churn; flag for upsell |
| 7 days after order | Automated request for product review (via notification) |
| 30 days after order | If no repeat purchase, flag as "Retention Risk" |
| Weekly (Monday 9am) | Generate weekly cohort report (top/bottom performers) |
| Monthly (1st of month) | Full customer segmentation report + churn forecast |
| Low review submitted (<3 stars) | Auto-escalate to support, flag product |
| User clicks "Customer Insights" in Mission Control | On-demand deep dive |

---

## Data Model

### `CustomerSegment` (Firestore)
```json
{
  "id": "seg_highvalue_20260710",
  "shopId": "shop_1",
  "segmentType": "HIGH_VALUE",  // HIGH_VALUE, NEW, REPEAT, ONE_TIME, AT_RISK
  "createdAt": "2026-07-10T14:30:00Z",
  "metadata": {
    "ltv_min": 10000,
    "ltv_max": 999999,
    "purchase_frequency_min": 1,
    "recency_days_max": 30
  },
  "customerIds": ["user_123", "user_456"],
  "count": 24,
  "metrics": {
    "avgLTV": 18500,
    "avgAOV": 2300,
    "retention": 0.87,
    "churnRisk": 0.08
  },
  "recommendations": [
    "Offer VIP early access to new products",
    "Create exclusive 'High-Value Member' discount tier",
    "Monthly check-in email from founder"
  ]
}
```

### `ChurnAlert` (Firestore)
```json
{
  "id": "churn_alert_user_789",
  "shopId": "shop_1",
  "customerId": "user_789",
  "createdAt": "2026-07-10T14:30:00Z",
  "riskScore": 0.82,
  "riskLevel": "AT_RISK",  // LOW, AT_RISK, CRITICAL
  "reason": "No purchase for 65 days; previously bought every 30 days",
  "lastPurchaseDate": "2026-05-06",
  "suggestedAction": "Send 'We miss you' email with 15% loyalty discount",
  "actionTaken": null,
  "actionTakenAt": null
}
```

### `FeedbackSynthesis` (Firestore)
```json
{
  "id": "feedback_synthesis_20260710",
  "shopId": "shop_1",
  "period": "2026-07-01 to 2026-07-10",
  "createdAt": "2026-07-10T14:30:00Z",
  "overallSentiment": {
    "avgRating": 4.1,
    "totalReviews": 47,
    "positiveTrend": true,
    "trendChange": "+0.3 stars (vs. previous week)"
  },
  "byProduct": {
    "product_42": {
      "avgRating": 3.2,
      "complaints": [
        "Shaver battery doesn't last (5 mentions)",
        "Charger not included (3 mentions)"
      ],
      "riskLevel": "CRITICAL",
      "recommendation": "Review quality with supplier; consider free replacement or refund program"
    }
  },
  "byCategory": {
    "electronics": {
      "avgRating": 3.8,
      "commonIssue": "Shipping delays (4 mentions across 3 products)"
    }
  }
}
```

### `CohortAnalysis` (Firestore)
```json
{
  "id": "cohort_2026_06",
  "shopId": "shop_1",
  "cohortMonth": "2026-06",
  "createdAt": "2026-07-10T14:30:00Z",
  "cohortSize": 156,
  "metrics": {
    "retention_30d": 0.42,
    "retention_60d": 0.28,
    "retention_90d": 0.18,
    "avgLTV": 8234,
    "churnRate": 0.82,
    "trend": "DECLINING"
  },
  "comparison": {
    "previousCohort": "2026-05",
    "retentionChange": "-8%",
    "ltv_change": "+5%",
    "insight": "Lower retention but higher spending per customer (possible price increase impact?)"
  },
  "recommendations": [
    "Investigate why May cohort had better 30-day retention",
    "Test improved onboarding for July cohort"
  ]
}
```

---

## Approval & Action Flow

**Low-stakes insights** (pattern reports, cohort analysis):
- Generated in background, available in Mission Control "Insights" tab
- User reviews at leisure; no approval needed
- Aggregated into weekly/monthly email digest

**Medium-stakes insights** (churn alerts for 5+ customers):
- Generated as cards in Mission Control inbox
- User can approve suggested action (e.g., "Send win-back campaign")
- Or dismiss if they disagree

**High-stakes insights** (critical feedback—multiple complaints about same product):
- Auto-notified via push notification (if user has enabled alerts)
- Escalated to support team
- User can drill down to see individual reviews

---

## Approval UI Components

**Churn Alert Card (Mission Control Inbox):**
```
┌──────────────────────────────────────────────┐
│ 🚨 CUSTOMER AT CHURN RISK                    │
├──────────────────────────────────────────────┤
│ Customer: Rajesh K. (user_789)               │
│ Lifetime Value: ₹18,500 (HIGH VALUE)         │
│ Last Purchase: May 6, 2026 (65 days ago)     │
│ Typical Frequency: Every 30 days             │
│                                              │
│ Risk Score: 82% — AT RISK                    │
│ Reason: No purchase in 65 days (2x interval) │
│                                              │
│ Suggested Action:                            │
│ Send "We miss you" email with 15% discount   │
│                                              │
│ [Send Now] [Dismiss] [Manual Outreach]       │
└──────────────────────────────────────────────┘
```

**Weekly Insights Report Card:**
```
┌──────────────────────────────────────────────┐
│ 📊 WEEKLY CUSTOMER INSIGHTS                  │
├──────────────────────────────────────────────┤
│ Week of July 7–13, 2026                      │
│                                              │
│ New Customers: 23 ✨                         │
│ Repeat Purchases: 17 🔄                      │
│ Churn Alerts: 8 ⚠️                           │
│                                              │
│ Top Insight:                                 │
│ Product "Papa's Shaver" has 3 complaints    │
│ about battery life. Consider review.         │
│                                              │
│ Cohort Health:                               │
│ June cohort: 42% retention (down 8% vs May)  │
│ Action: Improve onboarding for July?         │
│                                              │
│ [View Full Report]                           │
└──────────────────────────────────────────────┘
```

---

## Success Metrics

After launch, measure:

| Metric | Target | Notes |
|---|---|---|
| Churn prediction accuracy | >75% | % of "AT_RISK" customers who actually churn if no action |
| Win-back email ROI | >3x | Revenue from win-back campaigns vs. campaign cost |
| Retention improvement | +10% | 30-day retention after cohort improvements |
| Feedback-driven actions | 5+/month | How many product/service changes from feedback |
| Insight review time | <5 min | User time to review weekly/monthly reports |
| Segment data freshness | < 1 hour | Latest customer data in segmentation |

---

## Integration Points

- **Firestore:** Read from `orders`, `customers`, `product_reviews`, `support_tickets`
- **Gemini API:** Analyze review sentiment, summarize feedback clusters
- **Mission Control UI:** New "Insights" tab with cards + alerts
- **Email Service:** Trigger win-back, onboarding, review request emails (future phase)
- **Analytics:** Track which churn alerts are acted upon

---

## Known Constraints

- Phase 3 does NOT include predictive churn (machine learning models)
- NPS surveys are manual for now (auto-survey email in Phase 3b)
- Cohort reports are weekly (daily in future)
- Feedback synthesis is powered by Gemini (no custom ML)

---

## Dependencies

- ✅ Firestore schema with `orders`, `customers`, `product_reviews`
- ✅ Gemini API access (text analysis)
- ✅ Mission Control UI framework (cards, tabs, alerts)
- ⏳ Email service (for win-back campaigns, Phase 3b)
- ⏳ NPS survey tool (Phase 3b)

---

## Acceptance Criteria

- [ ] Customer segments generated weekly with >90% accuracy
- [ ] Churn alerts triggered for all customers with risk score >0.7
- [ ] Feedback synthesis identifies common product complaints
- [ ] Cohort analysis compares month-over-month retention
- [ ] Approval UI shows clear segmentation + recommended actions
- [ ] All insights are <1 hour stale
- [ ] No PII exposed in UI (use hashed customer IDs where possible)
- [ ] Insights respect user privacy (no unsolicited profiling)

