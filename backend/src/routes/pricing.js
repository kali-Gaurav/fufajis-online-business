/**
 * routes/pricing.js
 * AI Price Intelligence & Margin Optimization endpoints
 * Uses manual owner approval flow to safeguard village trust.
 */

const express = require('express');
const router = express.Router();
const { verifyToken, requireRole } = require('../auth');
const { db } = require('../firestore');

const CompetitorIntelligenceService = require('../services/CompetitorIntelligenceService');
const DemandForecastService = require('../services/DemandForecastService');
const PricingOptimizationService = require('../services/PricingOptimizationService');

// ── Analyze Product (Competitors & Demand) ──────────────────────────────────
router.post('/analyze', verifyToken, requireRole('UserRole.shopOwner', 'UserRole.admin'), async (req, res) => {
  const { productId } = req.body || {};

  if (!productId) {
    return res.status(400).json({ success: false, error: 'productId is required.' });
  }

  try {
    const product = await db().collection('products').doc(productId).get();
    if (!product.exists) {
      return res.status(404).json({ success: false, error: `Product not found: ${productId}` });
    }

    const productData = product.data();
    const basePrice = productData.basePrice || productData.price;

    const competitorPrices = await CompetitorIntelligenceService.getCompetitorPrices(
      productId,
      productData.name,
      productData.category,
      basePrice
    );

    const demandResult = await DemandForecastService.calculateDemand(productId);

    return res.json({
      success: true,
      productId,
      productName: productData.name,
      category: productData.category,
      currentPrice: basePrice,
      competitorPrices,
      demand: demandResult
    });
  } catch (error) {
    console.error('[pricing/analyze] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Generate AI Recommendation ──────────────────────────────────────────────
router.post('/recommend', verifyToken, requireRole('UserRole.shopOwner', 'UserRole.admin'), async (req, res) => {
  const { productId } = req.body || {};

  if (!productId) {
    return res.status(400).json({ success: false, error: 'productId is required.' });
  }

  try {
    const result = await PricingOptimizationService.analyzeAndRecommend(productId);
    if (!result.success) {
      return res.status(500).json(result);
    }
    return res.json(result);
  } catch (error) {
    console.error('[pricing/recommend] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Apply Approved Price (Manual Owner Approval Flow) ───────────────────────
router.post('/apply', verifyToken, requireRole('UserRole.shopOwner', 'UserRole.admin'), async (req, res) => {
  const { productId, approvedPrice, reason } = req.body || {};

  if (!productId || approvedPrice === undefined) {
    return res.status(400).json({ success: false, error: 'productId and approvedPrice are required.' });
  }

  if (approvedPrice < 0) {
    return res.status(400).json({ success: false, error: 'Price cannot be negative.' });
  }

  try {
    const approvedBy = req.user.email || req.user.uid || 'owner';
    const result = await PricingOptimizationService.applyPricing(
      productId,
      Math.round(approvedPrice),
      reason || 'Manual AI-assisted price adjustment',
      approvedBy
    );

    if (!result.success) {
      return res.status(500).json(result);
    }

    return res.json(result);
  } catch (error) {
    console.error('[pricing/apply] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Get Competitor Prices History ────────────────────────────────────────────
router.get('/competitor/:productId', verifyToken, async (req, res) => {
  const { productId } = req.params;

  try {
    const snapshot = await db()
      .collection('competitor_prices')
      .where('productId', '==', productId)
      .orderBy('timestamp', 'desc')
      .limit(30)
      .get();

    const history = [];
    snapshot.forEach((doc) => {
      const data = doc.data();
      history.push({
        timestamp: data.timestamp?.toDate?.() || new Date(data.timestamp.seconds * 1000),
        prices: data.prices
      });
    });

    return res.json({
      success: true,
      productId,
      history
    });
  } catch (error) {
    console.error('[pricing/competitor] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Get Price Elasticity Report ──────────────────────────────────────────────
router.get('/elasticity/:productId', verifyToken, async (req, res) => {
  const { productId } = req.params;

  try {
    // To compute Elasticity = (% change in demand) / (% change in price)
    // 1. Fetch decisions history (price points)
    const decisions = await db()
      .collection('pricing_decisions')
      .where('productId', '==', productId)
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();

    if (decisions.size < 2) {
      return res.json({
        success: true,
        productId,
        elasticity: 0.0,
        interpretation: 'Inelastic (insufficient historical price adjustment data to compute sensitivity)',
        message: 'Need at least 2 distinct price points in logs to calculate sensitivity.'
      });
    }

    // 2. Fetch orders over the last 60 days
    const sixtyDaysAgo = new Date(Date.now() - 60 * 24 * 60 * 60 * 1000);
    const orders = await db()
      .collection('orders')
      .where('createdAt', '>=', sixtyDaysAgo)
      .get();

    // Group sales volume by the price purchased at
    const priceVolumes = {};
    orders.forEach((doc) => {
      const order = doc.data();
      const items = order.items || [];
      items.forEach((item) => {
        if (item.productId === productId) {
          const price = Math.round(item.price || item.price_at_purchase || 0);
          if (price > 0) {
            priceVolumes[price] = (priceVolumes[price] || 0) + (item.quantity || 1);
          }
        }
      });
    });

    const pricePoints = Object.keys(priceVolumes).map(p => parseInt(p)).sort((a, b) => a - b);

    if (pricePoints.length < 2) {
      return res.json({
        success: true,
        productId,
        elasticity: 0.2, // Default low elasticity for staples/essentials
        interpretation: 'Low Price Sensitivity (essential household product)',
        pricePoints: priceVolumes
      });
    }

    // Calculate elasticity between the two most active price points
    const p1 = pricePoints[0];
    const p2 = pricePoints[pricePoints.length - 1];
    const v1 = priceVolumes[p1];
    const v2 = priceVolumes[p2];

    const pctChangePrice = (p2 - p1) / p1;
    const pctChangeVolume = (v2 - v1) / v1;

    let elasticity = 0.0;
    if (pctChangePrice !== 0) {
      elasticity = Math.abs(pctChangeVolume / pctChangePrice);
    }

    let interpretation = 'Unit Elastic (proportional changes)';
    if (elasticity > 1.5) {
      interpretation = 'Highly Price Sensitive (discounts will significantly boost volume)';
    } else if (elasticity > 1.0) {
      interpretation = 'Price Sensitive (moderate discount potential)';
    } else if (elasticity < 0.5) {
      interpretation = 'Highly Price Inelastic (essential product; demand is stable regardless of price changes)';
    } else {
      interpretation = 'Low Price Sensitivity';
    }

    return res.json({
      success: true,
      productId,
      elasticity: parseFloat(elasticity.toFixed(2)),
      interpretation,
      analysis: {
        pricePoints: priceVolumes,
        priceComparison: `Comparing ₹${p1} (Qty sold: ${v1}) vs. ₹${p2} (Qty sold: ${v2})`,
        pctChangePrice: (pctChangePrice * 100).toFixed(1) + '%',
        pctChangeVolume: (pctChangeVolume * 100).toFixed(1) + '%'
      }
    });
  } catch (error) {
    console.error('[pricing/elasticity] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
