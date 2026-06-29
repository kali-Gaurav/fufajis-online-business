/**
 * DemandForecastService.js
 * Tracks sales velocity and calculates a weighted demand score
 * using order history, seasonality, stock levels, and view trends.
 */

const { db } = require('../firestore');

class DemandForecastService {
  /**
   * Calculate demand score (0-100) and forecast demand for a product
   * @param {string} productId
   * @returns {Promise<Object>} - { demandScore, salesVelocity, predictedQtyNext7Days }
   */
  static async calculateDemand(productId) {
    try {
      const productDoc = await db().collection('products').doc(productId).get();
      if (!productDoc.exists) {
        throw new Error(`Product not found: ${productId}`);
      }

      const product = productDoc.data();
      const category = product.category || 'default';
      const currentStock = product.stockQuantity ?? product.stock ?? 25;
      const reorderPoint = product.reorderPoint || 10;
      const viewCount = product.viewCount || 0;

      // 1. Sales Velocity Score (last 7 days orders)
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const recentOrders = await db()
        .collection('orders')
        .where('createdAt', '>=', sevenDaysAgo)
        .get();

      let totalQtySold7Days = 0;
      recentOrders.forEach((doc) => {
        const order = doc.data();
        const items = order.items || [];
        items.forEach((item) => {
          if (item.productId === productId) {
            totalQtySold7Days += item.quantity || 1;
          }
        });
      });

      // Normalize velocity: assume 15 units/week is high velocity (100 score) for a single product
      const salesVelocityScore = Math.min(100, (totalQtySold7Days / 15) * 100);

      // 2. Seasonality Score (0-100)
      const month = new Date().getMonth(); // 0-11
      const seasonalityScore = this.calculateSeasonalityScore(month, category);

      // 3. Stock Pressure Score (0-100)
      // High stock pressure = low stock relative to reorder point (we need to buy more, high demand/urgency)
      let stockPressureScore = 50;
      if (currentStock <= 0) {
        stockPressureScore = 100;
      } else {
        const stockRatio = currentStock / reorderPoint;
        if (stockRatio < 0.5) {
          stockPressureScore = 90; // critically low
        } else if (stockRatio < 1.0) {
          stockPressureScore = 75; // below reorder point
        } else if (stockRatio > 2.0) {
          stockPressureScore = 20; // overstock
        } else {
          stockPressureScore = 50; // healthy stock
        }
      }

      // 4. Market Trend Score (0-100)
      // Based on views (popularity)
      const marketTrendScore = Math.min(100, (viewCount / 100) * 100) || 50;

      // Weighted Demand Score Formula
      const demandScore = Math.round(
        0.4 * salesVelocityScore +
        0.25 * seasonalityScore +
        0.2 * stockPressureScore +
        0.15 * marketTrendScore
      );

      // 5. 7-Day Predicted Quantity Forecast (using last 30 days orders)
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      const monthlyOrders = await db()
        .collection('orders')
        .where('createdAt', '>=', thirtyDaysAgo)
        .get();

      let totalQtySold30Days = 0;
      monthlyOrders.forEach((doc) => {
        const order = doc.data();
        const items = order.items || [];
        items.forEach((item) => {
          if (item.productId === productId) {
            totalQtySold30Days += item.quantity || 1;
          }
        });
      });

      const dailyAvgSales = totalQtySold30Days / 30;
      const predictedQtyNext7Days = Math.round(dailyAvgSales * 7);

      return {
        success: true,
        demandScore,
        salesVelocity: totalQtySold7Days,
        predictedQtyNext7Days: Math.max(1, predictedQtyNext7Days),
        breakdown: {
          salesVelocityScore: Math.round(salesVelocityScore),
          seasonalityScore: Math.round(seasonalityScore),
          stockPressureScore: Math.round(stockPressureScore),
          marketTrendScore: Math.round(marketTrendScore)
        }
      };
    } catch (error) {
      console.error('[DemandForecast] Error calculating demand:', error.message);
      return {
        success: false,
        demandScore: 50,
        salesVelocity: 0,
        predictedQtyNext7Days: 5,
        error: error.message
      };
    }
  }

  /**
   * Helper to score seasonality based on month and product category
   */
  static calculateSeasonalityScore(month, category) {
    const cat = category.toLowerCase();

    // Summer months: Apr (3), May (4), June (5)
    if ([3, 4, 5].includes(month)) {
      if (cat.includes('beverage') || cat.includes('drink') || cat.includes('ice') || cat.includes('oil')) {
        return 90;
      }
    }

    // Diwali festive season: Oct (9), Nov (10)
    if ([9, 10].includes(month)) {
      if (cat.includes('sweet') || cat.includes('gift') || cat.includes('dry fruit') || cat.includes('spice')) {
        return 95;
      }
    }

    // Winter months: Dec (11), Jan (0), Feb (1)
    if ([11, 0, 1].includes(month)) {
      if (cat.includes('spice') || cat.includes('dry fruit') || cat.includes('tea') || cat.includes('grain')) {
        return 85;
      }
    }

    return 50; // Default neutral score
  }
}

module.exports = DemandForecastService;
