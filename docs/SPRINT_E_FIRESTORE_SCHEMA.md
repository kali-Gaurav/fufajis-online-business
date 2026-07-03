# Firestore Schema Extensions — Sprint E (Phase 3)

This document defines new Firestore collections and fields required for the **Pricing Expert** and **Customer Analyst** agents.

---

## New Collections

### 1. `pricing_recommendations` Collection

Stores all pricing agent recommendations with approval status.

**Collection path:** `shops/{shopId}/pricing_recommendations/{recommendationId}`

**Document schema:**
```json
{
  "id": "price_rec_abc123",
  "shopId": "shop_1",
  "productId": "product_42",
  "agentVersion": "pricing_expert_v1.0",
  "createdAt": 1720594200000,  // timestamp in milliseconds
  "updatedAt": 1720594200000,
  "approvedAt": null,
  "rejectionReason": null,
  
  // ======= RECOMMENDATION DETAILS =======
  "recommendations": {
    "dynamicPrice": {
      "currentPrice": 599,
      "suggestedPrice": 679,
      "priceChangePercent": 13.36,
      "reason": "Stock critically low (3 units); apply scarcity premium",
      "confidence": 0.92,
      "triggers": ["low_stock", "competitive_gap"],
      "estimatedRevenueLift": 15000  // ₹ per month if approved
    },
    "marginAnalysis": {
      "cost": 300,
      "currentMarginPercent": 49.91,
      "projectedMarginPercent": 56.43,
      "marginalCategory": "HIGH",  // HIGH, MEDIUM, LOW
      "warningFlag": false,
      "notes": "Healthy margin; no action needed"
    },
    "bundleOpportunity": {
      "bundleName": "Dad Grooming Combo",
      "description": "Shaver + Aftershave + Beard Oil",
      "productIds": ["product_42", "product_51", "product_63"],
      "suggestedBundlePrice": 1299,
      "individualTotal": 1449,
      "bundleDiscount": 150,
      "discountPercent": 10.35,
      "estimatedLift": {
        "aovIncrease": "₹200",
        "adoptionRate": "12%"
      },
      "confidence": 0.78
    }
  },
  
  // ======= APPROVAL STATUS =======
  "status": "PENDING",  // PENDING, APPROVED, REJECTED, ARCHIVED
  "statusHistory": [
    {
      "status": "PENDING",
      "changedAt": 1720594200000,
      "changedBy": "system"
    }
  ],
  
  "approvedBy": null,
  "rejectedBy": null,
  "editedPrice": null,  // If user overrides suggestion
  
  // ======= METRICS =======
  "metrics": {
    "viewCount": 0,
    "timeToApproveSeconds": null,
    "actualOutcome": null  // Populated after approval to track accuracy
  }
}
```

**Indexes required:**
- `shopId, status, createdAt` (for fetching pending recommendations)
- `shopId, productId, createdAt` (for product-specific history)

**Security rules:**
```
match /shops/{shopId}/pricing_recommendations/{docId} {
  allow read: if request.auth.uid == resource.data.shopOwnerId;
  allow create: if request.auth.uid == shopId;  // Agent writes via Service Account
  allow update: if request.auth.uid == resource.data.shopOwnerId;
  allow delete: if false;  // Never delete; archive instead
}
```

---

### 2. `customer_segments` Collection

Stores customer segmentation snapshots (weekly updates).

**Collection path:** `shops/{shopId}/customer_segments/{segmentId}`

**Document schema:**
```json
{
  "id": "seg_highvalue_20260710",
  "shopId": "shop_1",
  "segmentType": "HIGH_VALUE",  // HIGH_VALUE, NEW, REPEAT, ONE_TIME, AT_RISK
  "createdAt": 1720594200000,
  "generatedAt": 1720594200000,
  
  // ======= SEGMENT DEFINITION =======
  "criteria": {
    "ltv_min": 10000,
    "ltv_max": 999999,
    "purchaseFrequencyMin": 1,  // purchases per month
    "recencyDaysMax": 30,
    "description": "Customers with >₹10k lifetime value and purchase frequency >1/month"
  },
  
  // ======= MEMBER DATA =======
  "customerIds": ["user_123", "user_456", "user_789"],
  "count": 24,
  "metrics": {
    "avgLifetimeValue": 18500,
    "avgOrderValue": 2300,
    "totalRevenue": 444000,
    "retentionRate": 0.87,
    "churnRisk": 0.08,
    "purchaseFrequency": 1.8
  },
  
  // ======= RECOMMENDATIONS =======
  "recommendations": [
    {
      "type": "VIP_TREATMENT",
      "description": "Offer VIP early access to new products",
      "action": "Email + App notification",
      "priority": "HIGH"
    },
    {
      "type": "LOYALTY_TIER",
      "description": "Create 'High-Value Member' discount tier (10% off all future purchases)",
      "action": "Manual implementation required",
      "priority": "MEDIUM"
    }
  ],
  
  // ======= ACTIONS TAKEN =======
  "actionsTaken": [
    {
      "action": "VIP_EARLY_ACCESS",
      "appliedAt": 1720594200000,
      "appliedBy": "user_admin"
    }
  ]
}
```

**Document types:**
- `HIGH_VALUE` — LTV > ₹10k, frequency > 1/month
- `NEW` — First purchase < 30 days ago
- `REPEAT` — 3+ purchases, regular intervals
- `ONE_TIME` — Single purchase > 90 days old, no repeat
- `AT_RISK` — No purchase in 60+ days (but used to buy regularly)

**Indexes required:**
- `shopId, segmentType, createdAt` (for pulling all segments of one type)

**Security rules:**
```
match /shops/{shopId}/customer_segments/{docId} {
  allow read: if request.auth.uid == resource.data.shopOwnerId;
  allow create, update: if request.auth.uid == shopId;  // Agent writes via Service Account
  allow delete: if false;  // Archive instead
}
```

---

### 3. `churn_alerts` Collection

Tracks at-risk customers with actionable alerts.

**Collection path:** `shops/{shopId}/churn_alerts/{alertId}`

**Document schema:**
```json
{
  "id": "churn_alert_user_789",
  "shopId": "shop_1",
  "customerId": "user_789",
  "createdAt": 1720594200000,
  
  // ======= RISK ASSESSMENT =======
  "riskScore": 0.82,  // 0–1 scale
  "riskLevel": "AT_RISK",  // LOW, AT_RISK, CRITICAL
  "reason": "No purchase for 65 days; previously bought every 30 days",
  
  // ======= CUSTOMER CONTEXT =======
  "customerMetrics": {
    "lifetimeValue": 18500,
    "totalPurchases": 8,
    "avgPurchaseInterval": 30,
    "lastPurchaseDate": 1717858200000,  // May 6, 2026
    "daysSinceLastPurchase": 65
  },
  
  // ======= SUGGESTED ACTION =======
  "suggestedAction": {
    "type": "WIN_BACK_EMAIL",
    "description": "Send 'We miss you' email with 15% loyalty discount",
    "campaignTemplate": "winback_v1",
    "offerDetails": {
      "discountPercent": 15,
      "validDays": 7
    },
    "priority": "HIGH"
  },
  
  // ======= ACTION HISTORY =======
  "actionTaken": null,  // EMAIL_SENT, DISMISSED, MANUAL_OUTREACH, null
  "actionTakenAt": null,
  "actionTakenBy": null,
  "actionResult": null,  // null, PURCHASED, NO_RESPONSE, UNSUBSCRIBED
  
  // ======= MONITORING =======
  "expiresAt": 1722444600000,  // 30 days from creation; archive if no action
  "resolved": false,
  "resolvedAt": null,
  "resolutionReason": null
}
```

**Indexes required:**
- `shopId, riskLevel, createdAt` (for pulling critical alerts)
- `shopId, resolved, createdAt` (for active vs. resolved)
- `customerId, shopId, createdAt` (for per-customer history)

**Security rules:**
```
match /shops/{shopId}/churn_alerts/{docId} {
  allow read: if request.auth.uid == resource.data.shopOwnerId;
  allow create, update: if request.auth.uid == shopId;  // Agent writes
  allow delete: if false;  // Archive instead
}
```

---

### 4. `feedback_synthesis` Collection

Stores periodic synthesis of product reviews & feedback.

**Collection path:** `shops/{shopId}/feedback_synthesis/{synthesisId}`

**Document schema:**
```json
{
  "id": "feedback_synthesis_20260710",
  "shopId": "shop_1",
  "period": {
    "startDate": "2026-07-01",
    "endDate": "2026-07-10",
    "generatedAt": 1720594200000
  },
  
  // ======= OVERALL SENTIMENT =======
  "overallSentiment": {
    "avgRating": 4.1,
    "totalReviews": 47,
    "ratingDistribution": {
      "5": 28,  // count of 5-star reviews
      "4": 12,
      "3": 5,
      "2": 1,
      "1": 1
    },
    "trend": {
      "direction": "IMPROVING",  // IMPROVING, STABLE, DECLINING
      "change": 0.3,  // points change vs. previous period
      "confidence": 0.85
    }
  },
  
  // ======= BY PRODUCT =======
  "byProduct": {
    "product_42": {
      "productName": "Papa's Special Glasses",
      "avgRating": 3.2,
      "reviewCount": 15,
      "sentiment": "MIXED",
      "commonComplaints": [
        {
          "issue": "Shaver battery doesn't last",
          "mentions": 5,
          "severity": "HIGH"
        },
        {
          "issue": "Charger not included",
          "mentions": 3,
          "severity": "MEDIUM"
        }
      ],
      "commonPraises": [
        {
          "feature": "Comfortable fit",
          "mentions": 8,
          "severity": "POSITIVE"
        }
      ],
      "riskLevel": "CRITICAL",
      "recommendation": "Review quality with supplier; consider free replacement or refund program"
    }
  },
  
  // ======= BY CATEGORY =======
  "byCategory": {
    "electronics": {
      "categoryName": "Electronics",
      "avgRating": 3.8,
      "productCount": 12,
      "commonIssues": [
        {
          "issue": "Shipping delays",
          "mentions": 4,
          "affectedProducts": ["product_42", "product_51"]
        }
      ],
      "trend": "STABLE"
    }
  },
  
  // ======= ACTIONS RECOMMENDED =======
  "recommendations": [
    {
      "priority": "CRITICAL",
      "action": "Quality Review",
      "details": "Contact supplier about battery longevity in product_42",
      "estimatedImpact": "Could improve rating from 3.2 to 4.0+"
    }
  ],
  
  // ======= ACTIONS TAKEN =======
  "actionsTaken": []
}
```

**Indexes required:**
- `shopId, period.endDate` (for pulling latest synthesis)
- `shopId, period.startDate, period.endDate` (for date range queries)

**Security rules:**
```
match /shops/{shopId}/feedback_synthesis/{docId} {
  allow read: if request.auth.uid == resource.data.shopOwnerId;
  allow create, update: if request.auth.uid == shopId;  // Agent writes
  allow delete: if false;
}
```

---

### 5. `cohort_analysis` Collection

Tracks cohort performance month-over-month.

**Collection path:** `shops/{shopId}/cohort_analysis/{cohortId}`

**Document schema:**
```json
{
  "id": "cohort_2026_06",
  "shopId": "shop_1",
  "cohortMonth": "2026-06",  // YYYY-MM format
  "cohortDefinition": "All customers with first purchase in June 2026",
  "createdAt": 1720594200000,
  
  // ======= COHORT METRICS =======
  "metrics": {
    "cohortSize": 156,
    "retention": {
      "day_0": 1.0,
      "day_30": 0.42,
      "day_60": 0.28,
      "day_90": 0.18
    },
    "avgLifetimeValue": 8234,
    "churnRate": 0.82,
    "trend": "DECLINING"  // IMPROVING, STABLE, DECLINING
  },
  
  // ======= COHORT COMPOSITION =======
  "customerIds": ["user_001", "user_002", ...],  // Array of 156 IDs
  
  // ======= COMPARISON TO PREVIOUS COHORT =======
  "comparison": {
    "previousCohort": "2026-05",
    "retentionChange": {
      "day_30": -0.08,  // retention % change
      "day_60": -0.12,
      "day_90": -0.05
    },
    "ltv_change": 0.05,  // +5%
    "insights": [
      {
        "observation": "May cohort had better 30-day retention",
        "hypothesis": "Improved onboarding in May?",
        "investigation": "Compare email campaigns, product selection"
      }
    ]
  },
  
  // ======= RECOMMENDATIONS =======
  "recommendations": [
    {
      "priority": "HIGH",
      "action": "Investigate May onboarding",
      "description": "Why did May cohort retain 8% more customers at day 30?",
      "nextSteps": ["Review email sequences", "Compare product mix", "Check pricing"]
    }
  ],
  
  // ======= ACTIONS TAKEN =======
  "actionsTaken": []
}
```

**Indexes required:**
- `shopId, cohortMonth` (for accessing specific cohort)
- `shopId, metrics.trend` (for filtering improving/declining cohorts)

**Security rules:**
```
match /shops/{shopId}/cohort_analysis/{docId} {
  allow read: if request.auth.uid == resource.data.shopOwnerId;
  allow create, update: if request.auth.uid == shopId;
  allow delete: if false;
}
```

---

## Modified Collections

### `products` — Add pricing history fields

Extend existing `products/{productId}` documents with:

```json
{
  "id": "product_42",
  "shopId": "shop_1",
  
  // ... existing fields ...
  
  // ======= NEW PRICING FIELDS =======
  "priceHistory": {
    "currentPrice": 599,
    "previousPrice": 599,
    "priceChangedAt": null,
    "priceChangeReason": "Initial pricing",
    "cost": 300,
    "marginPercent": 49.91
  },
  
  "pricingMetrics": {
    "lastRecommendationId": "price_rec_abc123",
    "lastRecommendationAt": 1720594200000,
    "recommendationAcceptanceRate": 0.75,  // % of recommendations approved
    "estimatedMonthlyRevenue": 89700
  },
  
  // ======= BUNDLE MEMBERSHIP =======
  "bundleIds": ["bundle_grooming_combo"],  // Products in bundles
  
  // ======= FEEDBACK METRICS =======
  "feedbackMetrics": {
    "avgRating": 4.3,
    "reviewCount": 47,
    "lastReviewDate": 1720594200000,
    "complaintCount": 2,
    "lastComplaint": "Battery longevity",
    "lastComplaintDate": 1720500000000
  }
}
```

---

### `orders` — Add customer analysis fields

Extend existing `orders/{orderId}` documents with:

```json
{
  "id": "order_xyz",
  "shopId": "shop_1",
  "customerId": "user_123",
  
  // ... existing fields ...
  
  // ======= NEW ANALYTICS FIELDS =======
  "customerContext": {
    "isRepeatCustomer": true,
    "previousPurchaseCount": 5,
    "customerSegment": "HIGH_VALUE",
    "customerLifetimeValue": 18500
  },
  
  "cohortData": {
    "cohortMonth": "2026-06",
    "daysInCohort": 34
  }
}
```

---

## Firestore Indexes Summary

**New indexes to create:**

| Collection | Fields | Purpose |
|---|---|---|
| `pricing_recommendations` | `shopId, status, createdAt` | Fetch pending recommendations |
| `pricing_recommendations` | `shopId, productId, createdAt` | Product-specific history |
| `customer_segments` | `shopId, segmentType, createdAt` | Pull segments by type |
| `churn_alerts` | `shopId, riskLevel, createdAt` | Critical alerts first |
| `churn_alerts` | `shopId, resolved, createdAt` | Active vs. resolved |
| `feedback_synthesis` | `shopId, period.endDate` | Latest synthesis |
| `cohort_analysis` | `shopId, cohortMonth` | Access specific cohort |

---

## Data Retention Policy

- **`pricing_recommendations`**: Archive after 90 days of APPROVED/REJECTED status
- **`customer_segments`**: Keep 12 months (weekly snapshots)
- **`churn_alerts`**: Archive after 30 days if unresolved
- **`feedback_synthesis`**: Keep 24 months (historical tracking)
- **`cohort_analysis`**: Keep permanently (historical reference)

---

## Migration Steps

For existing shops, these steps populate historical data:

1. **Week 1:** Deploy new collections (empty)
2. **Week 1:** Agents start writing new `pricing_recommendations`, `customer_segments` on schedule
3. **Week 2:** Generate initial `churn_alerts` from `orders` history (backfill 60+ days of no purchase)
4. **Week 2:** Generate initial `feedback_synthesis` from existing `product_reviews`
5. **Week 3:** Generate initial `cohort_analysis` by analyzing `orders` by customer first-purchase month
6. **Week 4:** Enable agent automation and approval workflows

