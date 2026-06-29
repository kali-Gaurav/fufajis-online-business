/**
 * CompetitorIntelligenceService.js
 * Simulates fetching and tracking competitor prices (Blinkit, Zepto, BigBasket)
 * to prevent unreliable LLM estimations.
 */

const { db, admin } = require('../firestore');

class CompetitorIntelligenceService {
  /**
   * Get competitor prices for a product name, category, and base price
   * @param {string} productId
   * @param {string} productName
   * @param {string} category
   * @param {number} basePrice
   * @returns {Promise<Array>} - Array of competitor prices
   */
  static async getCompetitorPrices(productId, productName, category, basePrice) {
    try {
      // Check for cached competitor prices within the last 12 hours
      const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000);
      const cached = await db()
        .collection('competitor_prices')
        .where('productId', '==', productId)
        .where('timestamp', '>=', twelveHoursAgo)
        .orderBy('timestamp', 'desc')
        .limit(1)
        .get();

      if (!cached.empty) {
        console.log(`[CompetitorIntelligence] Using cached prices for product ${productId}`);
        return cached.docs[0].data().prices;
      }

      // If no cache, simulate checking prices from Blinkit, Zepto, and BigBasket
      // Prices are kept within a realistic range of basePrice (-6% to +6%)
      const competitors = [
        { name: 'Blinkit', varianceLower: 0.95, varianceUpper: 1.05 },
        { name: 'Zepto', varianceLower: 0.96, varianceUpper: 1.04 },
        { name: 'BigBasket', varianceLower: 0.94, varianceUpper: 1.06 }
      ];

      const prices = competitors.map((comp) => {
        const factor = comp.varianceLower + Math.random() * (comp.varianceUpper - comp.varianceLower);
        const price = Math.round(basePrice * factor);
        return {
          competitor: comp.name,
          price,
          lastUpdated: new Date()
        };
      });

      // Save to history in Firestore
      await db()
        .collection('competitor_prices')
        .add({
          productId,
          productName,
          category,
          basePrice,
          prices,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

      // Update the product document with competitorPrices array
      await db()
        .collection('products')
        .doc(productId)
        .update({
          competitorPrices: prices,
          competitorPricesLastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });

      return prices;
    } catch (error) {
      console.error('[CompetitorIntelligence] Error getting competitor prices:', error.message);
      // Fallback in case of database or random error
      return [
        { competitor: 'Blinkit', price: basePrice, lastUpdated: new Date() },
        { competitor: 'Zepto', price: basePrice, lastUpdated: new Date() },
        { competitor: 'BigBasket', price: basePrice, lastUpdated: new Date() }
      ];
    }
  }
}

module.exports = CompetitorIntelligenceService;
