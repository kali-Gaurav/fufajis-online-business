# 🚀 VOICE ORDERING + PRODUCTS DATABASE BUILD
**Status:** FULL BUILD CYCLE - DEPLOYING AGENT  
**Target Quality Score:** ≥ 95/100  
**Date:** July 2, 2026

---

## 📋 PHASE 1: ARCHITECTURE ANALYSIS

### Current State Assessment

**Voice Ordering System:**
✅ Files exist: `voice_order_screen.dart`, `speech_to_text_service.dart`, `voice_order_parser.dart`
✅ Architecture: STT → Parsing (Hinglish + Gemini) → Catalog Matching → Review → Cart
⚠️ **ISSUES IDENTIFIED:**
- Speech recognition may not initialize properly on some devices
- No fallback if Gemini API fails or times out
- Matching threshold (0.42) may be too high for Indian product names
- No barcode/SKU support for alternative matching
- Limited product attributes for smart matching

**Product Database:**
❌ Only ~20 dad-focused products exist
❌ Missing: Hindi names, descriptions, images, nutrition, barcodes, MRP pricing
❌ Firestore schema not optimized for voice search
❌ No category hierarchy for quick filtering

---

### Build Breakdown

| Phase | Component | Status | Priority |
|-------|-----------|--------|----------|
| 1 | Fix Speech Recognition | ⚠️ BUGGY | P0 |
| 2 | Improve Parser (Hinglish + Fallback) | ⚠️ PARTIAL | P0 |
| 3 | Upgrade ProductModel with Rich Metadata | ❌ MISSING | P0 |
| 4 | Fix Catalog Matching Algorithm | ⚠️ LOW-SCORE | P0 |
| 5 | Firestore Schema Optimization | ⚠️ BASIC | P1 |
| 6 | Seed 500+ Indian Grocery Products | ❌ EMPTY | P0 |
| 7 | Image URLs + Barcode Support | ❌ MISSING | P1 |
| 8 | Voice Review Screen Fixes | ⚠️ INCOMPLETE | P1 |
| 9 | Testing + QA | ❌ NONE | P0 |
| 10 | Performance Optimization | ❌ NONE | P1 |

---

## 🛠️ BUILD ORDER (Dependency Chain)

```
1. ProductModel Schema Upgrade
   ↓
2. Firestore Products Collection Schema + Migration
   ↓
3. Voice Order Parser Improvements (better matching)
   ↓
4. Speech-to-Text Service Fixes (initialization, error handling)
   ↓
5. Seed 500+ Products to Database
   ↓
6. Voice Review Screen Enhancements
   ↓
7. Integration Testing
   ↓
8. QA Testing (Happy path + Edge cases)
   ↓
9. Performance Optimization
   ↓
10. Final Deployment
```

---

## 📊 QUALITY TARGETS

| Dimension | Weight | Target |
|-----------|--------|--------|
| Voice Recognition Accuracy | 20% | 90%+ match rate |
| Product Database Completeness | 25% | 500+ items, all fields |
| Parsing Robustness | 20% | 85%+ capture rate |
| Error Handling | 15% | All edge cases covered |
| Performance (p95 latency) | 10% | < 2s voice → cart |
| UX/Accessibility | 10% | WCAG 2.1 AA |

**Overall Target: 95/100**

---

## 🎯 WHAT WE'RE BUILDING

### 1. ProductModel Enhancements
**New Fields:**
```dart
- hindiName (String) — "आलू", "दूध", etc.
- category (String) — "Vegetables", "Dairy", "Staples", etc.
- keywords (List<String>) — ["aloo", "potato", "आलू"] for fuzzy match
- barcode (String?) — for barcode-based lookup
- imageUrl (String?) — product photo from S3/CDN
- mrpPrice (double) — MRP
- sellingPrice (double) — Fufaji price
- unit (String) — "kg", "packet", "l", "piece"
- description (String) — nutritional info, brand
- nutrition (Map<String, String>) — {"protein": "12g", "fiber": "8g"}
- stock (int) — current inventory
```

### 2. Firestore Schema
**Collection: `products`**
```
/products/{productId}
  - name (String)
  - hindiName (String)
  - category (String)
  - keywords (Array) ← indexed for voice search
  - barcode (String)
  - imageUrl (String)
  - mrpPrice (Number)
  - sellingPrice (Number)
  - unit (String)
  - description (String)
  - nutrition (Map)
  - stock (Number)
  - isAvailable (Boolean) — voice only shows available
  - createdAt (Timestamp)
  - updatedAt (Timestamp)
```

### 3. 500+ Indian Grocery Products
**Categories:**
- Grains & Flour (50 items)
- Oils & Ghee (30 items)
- Spices & Condiments (100 items)
- Rice (25 items)
- Vegetables (80 items)
- Dairy & Milk (40 items)
- Snacks (60 items)
- Pulses (30 items)
- Biscuits & Cookies (40 items)
- Sugar & Jaggery (15 items)

**Data per product:** Name, Hindi name, category, brand, price (MRP + selling), description, unit, image URL, barcode, nutrition, stock

### 4. Voice Parser Improvements
**Fixes:**
- Better Hinglish handling ("do kilo aloo" → "2 kg potato")
- Fallback when Gemini timeout (use offline parser only)
- Keyword-based matching (voice says "Maggi" → match "2-Minute Noodles")
- Barcode fallback (if barcode scanner available)
- Confidence scoring by match quality + frequency

### 5. Speech-to-Text Reliability
**Fixes:**
- Proper initialization error handling
- Locale detection (auto-detect Hindi vs English)
- Timeout recovery
- Partial result display while listening
- Clear error messages to user

---

## 🔄 AGENT LOOP STRATEGY

**Loop 1: Foundation**
- Fix ProductModel schema
- Update Firestore rules
- Seed first 100 products (test)
- Fix STT initialization
- QA test

**Loop 2: Scale + Parsing**
- Seed 500 products complete
- Improve parser algorithm
- Test voice parsing accuracy (70%+ target)
- Enhance error handling
- QA test edge cases

**Loop 3: Polish**
- Performance optimization
- Image loading optimization
- Review screen UX
- Accessibility audit
- Final QA

**Exit when:** Quality Score ≥ 95/100

---

## ✅ DEPLOYMENT CHECKLIST

- [ ] ProductModel upgraded with all fields
- [ ] Firestore products collection created with indexes
- [ ] Speech-to-Text service fully reliable
- [ ] Voice parser accuracy ≥ 85%
- [ ] 500+ products seeded with all data
- [ ] Images loading properly
- [ ] Hindi names working correctly
- [ ] Voice review screen functional
- [ ] Error handling for all scenarios
- [ ] Performance < 2s latency
- [ ] QA tests passing
- [ ] Accessibility audit passing

---

## 🚀 READY TO BUILD

This document will be updated as the agent loops through Phases 1-10.
Deployment will continue UNTIL quality ≥ 95/100.

**Current Focus:** PHASE 1 - ARCHITECTURE & SCHEMA DESIGN
**Next:** PHASE 2 - IMPLEMENTATION

---

**Agent Status:** ACTIVE 🤖  
**Monitoring:** Quality Score Loop
**ETA:** Multiple iterations until 95/100 achieved
