/**
 * RecommendationEngine.js
 * Collaborative filtering & content-based recommendations
 * Expected Impact: +20-30% AOV (Average Order Value)
 */

const { db } = require('../firestore');

class RecommendationEngine {
  /**
   * Get personalized recommendations for user
   * Combines collaborative filtering + content-based recommendations
   */
  static async getPersonalizedRecommendations(userId, limit = 10) {
    try {
      const startTime = Date.now();

      // ─── Step 1: Get user's purchase & browsing history ─────────────
      const userProfile = await this.buildUserProfile(userId);
      console.log(`[Recommendations] User profile built: ${userProfile.purchasedProducts.length} purchases, ${userProfile.viewedProducts.length} views`);

      // ─── Step 2: Find similar users (collaborative filtering) ───────
      const similarUsers = await this.findSimilarUsers(userId, userProfile);
      console.log(`[Recommendations] Found ${similarUsers.length} similar users`);

      // ─── Step 3: Get products similar users liked ──────────────────
      const collaborativeRecs = await this.getCollaborativeRecommendations(
        similarUsers,
        userProfile.purchasedProducts,
        limit
      );
      console.log(`[Recommendations] Collaborative filtering: ${collaborativeRecs.length} products`);

      // ─── Step 4: Content-based recommendations ────────────────────
      const contentRecs = await this.getContentBasedRecommendations(
        userProfile,
        limit
      );
      console.log(`[Recommendations] Content-based: ${contentRecs.length} products`);

      // ─── Step 5: Hybrid ranking (combine both methods) ──────────────
      const hybridRecs = this.hybridRanking(
        collaborativeRecs,
        contentRecs,
        limit
      );

      // ─── Step 6: Re-rank by conversion probability ─────────────────
      const finalRecs = await this.finalRanking(hybridRecs, userId);

      return {
        success: true,
        userId,
        recommendations: finalRecs.slice(0, limit),
        metadata: {
          totalRecommendations: finalRecs.length,
          processingTimeMs: Date.now() - startTime,
          strategies: ['collaborative_filtering', 'content_based', 'hybrid_ranking'],
        },
      };
    } catch (error) {
      console.error('[RecommendationEngine] Error:', error.message);
      return {
        success: false,
        error: error.message,
        recommendations: [],
      };
    }
  }

  /**
   * Build user profile from their history
   */
  static async buildUserProfile(userId) {
    try {
      // Get purchase history
      const orders = await db()
        .collection('orders')
        .where('customerId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(50)
        .get();

      const purchasedProducts = [];
      const categories = {};

      orders.forEach((doc) => {
        const items = doc.data().items || [];
        items.forEach((item) => {
          purchasedProducts.push(item.productId);
          // Track category preferences
          if (item.category) {
            categories[item.category] = (categories[item.category] || 0) + 1;
          }
        });
      });

      // Get viewed products (from view logs)
      const viewLogs = await db()
        .collection('user_views')
        .where('userId', '==', userId)
        .orderBy('viewedAt', 'desc')
        .limit(100)
        .get();

      const viewedProducts = [];
      viewLogs.forEach((doc) => {
        viewedProducts.push(doc.data().productId);
      });

      return {
        userId,
        purchasedProducts: [...new Set(purchasedProducts)], // Unique
        viewedProducts: [...new Set(viewedProducts)],
        categoryPreferences: categories,
        totalOrders: orders.size,
      };
    } catch (error) {
      console.warn('[RecommendationEngine] Could not build user profile:', error.message);
      return {
        userId,
        purchasedProducts: [],
        viewedProducts: [],
        categoryPreferences: {},
        totalOrders: 0,
      };
    }
  }

  /**
   * Find similar users based on purchase history
   * Jaccard similarity: |intersection| / |union|
   */
  static async findSimilarUsers(userId, userProfile, limit = 10) {
    try {
      const allUsers = await db()
        .collection('orders')
        .select('customerId', 'items')
        .get();

      const userProducts = new Set(userProfile.purchasedProducts);
      const similarityScores = [];

      allUsers.forEach((doc) => {
        const otherUserId = doc.data().customerId;
        if (otherUserId === userId) return; // Skip self

        const otherProducts = new Set(
          (doc.data().items || []).map((item) => item.productId)
        );

        // Calculate Jaccard similarity
        const intersection = new Set(
          [...userProducts].filter((x) => otherProducts.has(x))
        );
        const union = new Set([...userProducts, ...otherProducts]);
        const similarity = union.size > 0 ? intersection.size / union.size : 0;

        if (similarity > 0.1) {
          // At least 10% similar
          similarityScores.push({
            userId: otherUserId,
            similarity,
            sharedProducts: Array.from(intersection),
          });
        }
      });

      // Return top similar users
      return similarityScores
        .sort((a, b) => b.similarity - a.similarity)
        .slice(0, limit);
    } catch (error) {
      console.warn('[RecommendationEngine] Could not find similar users:', error.message);
      return [];
    }
  }

  /**
   * Get products that similar users purchased (collaborative filtering)
   */
  static async getCollaborativeRecommendations(
    similarUsers,
    userPurchases,
    limit
  ) {
    try {
      const recommendations = {};

      // Count how many similar users bought each product
      for (const similarUser of similarUsers) {
        const orders = await db()
          .collection('orders')
          .where('customerId', '==', similarUser.userId)
          .limit(50)
          .get();

        orders.forEach((doc) => {
          (doc.data().items || []).forEach((item) => {
            // Don't recommend products user already bought
            if (userPurchases.includes(item.productId)) return;

            recommendations[item.productId] =
              (recommendations[item.productId] || 0) +
              similarUser.similarity * 100; // Weight by similarity
          });
        });
      }

      // Convert to sorted array
      const sorted = Object.entries(recommendations)
        .map(([productId, score]) => ({
          productId,
          score: Math.round(score),
          method: 'COLLABORATIVE_FILTERING',
        }))
        .sort((a, b) => b.score - a.score)
        .slice(0, limit);

      return sorted;
    } catch (error) {
      console.warn(
        '[RecommendationEngine] Collaborative filtering failed:',
        error.message
      );
      return [];
    }
  }

  /**
   * Content-based recommendations
   * Recommend products similar to what user already likes
   */
  static async getContentBasedRecommendations(userProfile, limit) {
    try {
      const userPurchases = userProfile.purchasedProducts;
      const recommendations = {};

      // Get all purchased products
      for (const productId of userPurchases.slice(0, 10)) {
        // Look at last 10 purchases
        const product = await db()
          .collection('products')
          .doc(productId)
          .get();

        if (!product.exists) continue;

        const productData = product.data();
        const category = productData.category;
        const price = productData.price || 100;

        // Find similar products
        let query = db()
          .collection('products')
          .where('category', '==', category)
          .limit(20);

        const similar = await query.get();

        similar.forEach((doc) => {
          const otherProduct = doc.data();

          // Don't recommend already purchased
          if (userPurchases.includes(doc.id)) return;

          // Similar category + similar price range
          const priceSimilarity =
            1 - Math.abs(otherProduct.price - price) / Math.max(price, 1) / 2;
          const score = priceSimilarity * 100;

          recommendations[doc.id] =
            (recommendations[doc.id] || 0) + score;
        });
      }

      return Object.entries(recommendations)
        .map(([productId, score]) => ({
          productId,
          score: Math.round(score),
          method: 'CONTENT_BASED',
        }))
        .sort((a, b) => b.score - a.score)
        .slice(0, limit);
    } catch (error) {
      console.warn('[RecommendationEngine] Content-based failed:', error.message);
      return [];
    }
  }

  /**
   * Hybrid ranking - combine collaborative + content-based
   * 60% collaborative, 40% content-based
   */
  static hybridRanking(collaborativeRecs, contentRecs, limit) {
    const combined = {};

    // Add collaborative scores
    collaborativeRecs.forEach((rec) => {
      combined[rec.productId] = (combined[rec.productId] || 0) + rec.score * 0.6;
    });

    // Add content-based scores
    contentRecs.forEach((rec) => {
      combined[rec.productId] = (combined[rec.productId] || 0) + rec.score * 0.4;
    });

    return Object.entries(combined)
      .map(([productId, score]) => ({
        productId,
        score: Math.round(score),
      }))
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);
  }

  /**
   * Final ranking by conversion probability & ratings
   */
  static async finalRanking(recommendations, userId) {
    try {
      const finalRecs = [];

      for (const rec of recommendations) {
        const product = await db()
          .collection('products')
          .doc(rec.productId)
          .get();

        if (!product.exists) continue;

        const productData = product.data();
        const rating = productData.rating || 3;
        const viewCount = productData.viewCount || 0;
        const purchaseCount = productData.purchaseCount || 0;

        // Calculate final score with product popularity
        const finalScore =
          rec.score * 0.5 +
          (rating / 5) * 100 * 0.2 +
          Math.min(viewCount / 100, 100) * 0.2 +
          Math.min(purchaseCount / 50, 100) * 0.1;

        finalRecs.push({
          productId: rec.productId,
          score: Math.round(finalScore),
          name: productData.name,
          price: productData.price,
          rating: rating,
          image: productData.productImage,
          reason: this.getRecommendationReason(rec.score, rating, viewCount),
        });
      }

      return finalRecs.sort((a, b) => b.score - a.score);
    } catch (error) {
      console.warn('[RecommendationEngine] Final ranking failed:', error.message);
      return recommendations.slice(0, 5);
    }
  }

  /**
   * Generate human-readable recommendation reason
   */
  static getRecommendationReason(score, rating, viewCount) {
    if (rating >= 4.5) {
      return 'Highly rated by customers';
    } else if (viewCount > 500) {
      return 'Popular with similar customers';
    } else if (score > 75) {
      return 'Matches your preferences';
    } else {
      return 'You might like this';
    }
  }

  /**
   * Get "Next Product" recommendation for cart
   * Increases AOV by suggesting complementary items
   */
  static async getNextProductRecommendation(cartItems) {
    try {
      const recommendations = {};

      // Find products frequently bought together
      for (const cartItem of cartItems) {
        const orders = await db()
          .collection('orders')
          .where('items', 'array-contains', {
            productId: cartItem.productId,
          })
          .limit(100)
          .get();

        orders.forEach((doc) => {
          (doc.data().items || []).forEach((item) => {
            // Don't recommend items already in cart
            if (cartItems.some((ci) => ci.productId === item.productId))
              return;

            recommendations[item.productId] =
              (recommendations[item.productId] || 0) + 1;
          });
        });
      }

      // Get top complementary product
      const topProduct = Object.entries(recommendations)
        .sort((a, b) => b[1] - a[1])[0];

      if (!topProduct) return null;

      const product = await db()
        .collection('products')
        .doc(topProduct[0])
        .get();

      return {
        productId: topProduct[0],
        name: product.data().name,
        price: product.data().price,
        image: product.data().productImage,
        complementaryTo: cartItems.map((c) => c.productId),
        reason: `${topProduct[1]} customers also bought this`,
      };
    } catch (error) {
      console.warn('[RecommendationEngine] Next product recommendation failed:', error.message);
      return null;
    }
  }

  /**
   * Get trending products (popular right now)
   */
  static async getTrendingProducts(limit = 10) {
    try {
      const products = await db()
        .collection('products')
        .orderBy('viewCount', 'desc')
        .limit(limit)
        .get();

      return products.docs.map((doc) => ({
        productId: doc.id,
        name: doc.data().name,
        price: doc.data().price,
        rating: doc.data().rating,
        viewCount: doc.data().viewCount,
        image: doc.data().productImage,
        trend: 'TRENDING',
      }));
    } catch (error) {
      console.warn('[RecommendationEngine] Trending products failed:', error.message);
      return [];
    }
  }

  /**
   * Log recommendation for analytics
   */
  static async logRecommendation(userId, recommendedProductId, source) {
    try {
      const { admin } = require('../firestore');
      await db()
        .collection('recommendation_logs')
        .add({
          userId,
          productId: recommendedProductId,
          source,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          clicked: false,
          purchased: false,
        });
    } catch (error) {
      console.warn('[RecommendationEngine] Failed to log recommendation:', error.message);
    }
  }
}

module.exports = RecommendationEngine;
