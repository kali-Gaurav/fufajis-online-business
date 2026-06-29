/**
 * routes/recommendations.js
 * Personalized & collaborative recommendations API
 */

const express = require('express');
const router = express.Router();
const { verifyToken } = require('../auth');
const RecommendationEngine = require('../services/RecommendationEngine');

// ── Get Personalized Recommendations ──────────────────────────────────────
router.get('/for-you', verifyToken, async (req, res) => {
  const { limit = 10 } = req.query;
  const userId = req.user.uid;

  try {
    const result = await RecommendationEngine.getPersonalizedRecommendations(
      userId,
      parseInt(limit)
    );

    if (!result.success) {
      return res.status(500).json(result);
    }

    // Log recommendations
    for (const rec of result.recommendations) {
      await RecommendationEngine.logRecommendation(
        userId,
        rec.productId,
        'personalized'
      );
    }

    return res.json(result);
  } catch (error) {
    console.error('[recommendations/for-you] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Get Next Product Suggestion (For Cart) ────────────────────────────────
router.post('/next-product', verifyToken, async (req, res) => {
  const { cartItems } = req.body || {};
  const userId = req.user.uid;

  if (!cartItems || cartItems.length === 0) {
    return res.status(400).json({ success: false, error: 'cartItems is required.' });
  }

  try {
    const recommendation = await RecommendationEngine.getNextProductRecommendation(
      cartItems
    );

    if (recommendation) {
      await RecommendationEngine.logRecommendation(
        userId,
        recommendation.productId,
        'cart_upsell'
      );
    }

    return res.json({
      success: true,
      recommendation,
    });
  } catch (error) {
    console.error('[recommendations/next-product] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Get Trending Products ──────────────────────────────────────────────────
router.get('/trending', async (req, res) => {
  const { limit = 10 } = req.query;

  try {
    const products = await RecommendationEngine.getTrendingProducts(
      parseInt(limit)
    );

    return res.json({
      success: true,
      products,
      totalProducts: products.length,
    });
  } catch (error) {
    console.error('[recommendations/trending] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Similar Products ──────────────────────────────────────────────────────
router.get('/similar/:productId', async (req, res) => {
  const { productId } = req.params;
  const { limit = 5 } = req.query;

  try {
    const { db } = require('../firestore');
    const product = await db()
      .collection('products')
      .doc(productId)
      .get();

    if (!product.exists) {
      return res.status(404).json({ success: false, error: 'Product not found.' });
    }

    const productData = product.data();
    const category = productData.category;

    // Find similar products in same category
    const similarProducts = await db()
      .collection('products')
      .where('category', '==', category)
      .limit(parseInt(limit) + 1) // +1 to account for current product
      .get();

    const recommendations = similarProducts.docs
      .filter((doc) => doc.id !== productId)
      .slice(0, limit)
      .map((doc) => ({
        productId: doc.id,
        name: doc.data().name,
        price: doc.data().price,
        rating: doc.data().rating,
        image: doc.data().productImage,
        similarity: 'SAME_CATEGORY',
      }));

    return res.json({
      success: true,
      baseProduct: {
        productId,
        name: productData.name,
        category: category,
      },
      similarProducts: recommendations,
    });
  } catch (error) {
    console.error('[recommendations/similar] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

// ── Analytics: Track Recommendation Performance ────────────────────────────
router.post('/track-interaction', verifyToken, async (req, res) => {
  const { recommendationId, action } = req.body || {}; // action: clicked, purchased
  const userId = req.user.uid;

  try {
    const { db, admin } = require('../firestore');

    await db()
      .collection('recommendation_logs')
      .doc(recommendationId)
      .update({
        [action]: true,
        [`${action}At`]: admin.firestore.FieldValue.serverTimestamp(),
      });

    return res.json({
      success: true,
      message: `Recommendation interaction tracked: ${action}`,
    });
  } catch (error) {
    console.error('[recommendations/track-interaction] Error:', error.message);
    return res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;
