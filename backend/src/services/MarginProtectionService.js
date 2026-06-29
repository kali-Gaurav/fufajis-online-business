/**
 * MarginProtectionService.js
 * Enforces price floors and margin safety rules. Prevents recommended prices
 * from falling below procurement cost + category-specific fixed margin floors.
 */

class MarginProtectionService {
  /**
   * Enforce margin floor and return a safe price
   * @param {number} recommendedPrice
   * @param {number} costPrice - Procurement cost
   * @param {number} basePrice - Original base selling price
   * @param {string} category - Product category
   * @returns {Object} - { safePrice, marginFloorTriggered, minMarginRate, minAllowedPrice }
   */
  static enforceMarginSafety(recommendedPrice, costPrice, basePrice, category = 'default') {
    const cat = category.toLowerCase();

    // 1. Determine procurement cost (costPrice)
    // If costPrice is not defined, assume a default 20% margin off original base price (cost = 80% of base)
    const activeCostPrice = costPrice && costPrice > 0 ? costPrice : basePrice * 0.8;

    // 2. Set min margin floors by category
    let minMarginRate = 0.15; // Default 15% margin floor

    if (cat.includes('staple') || cat.includes('grain') || cat.includes('atta') || cat.includes('rice') || cat.includes('dal')) {
      minMarginRate = 0.10; // 10% minimum margin on staples (low-margin, high-volume items)
    } else if (cat.includes('snack') || cat.includes('chocolate') || cat.includes('biscuit') || cat.includes('beverage')) {
      minMarginRate = 0.18; // 18% minimum margin on processed snacks & confectionery
    } else if (cat.includes('dairy') || cat.includes('milk') || cat.includes('butter')) {
      minMarginRate = 0.08; // 8% minimum margin on dairy (highly perishable, fixed-price milk packets)
    }

    // Calculate minimum allowed selling price based on cost price
    const minAllowedPrice = activeCostPrice * (1 + minMarginRate);

    let safePrice = recommendedPrice;
    let marginFloorTriggered = false;

    // If the recommended price drops below the minimum allowed price, raise it to the floor
    if (recommendedPrice < minAllowedPrice) {
      safePrice = minAllowedPrice;
      marginFloorTriggered = true;
    }

    // Keep safePrice rounded to the nearest rupee
    safePrice = Math.round(safePrice);

    return {
      safePrice,
      marginFloorTriggered,
      minMarginRate,
      minAllowedPrice: Math.round(minAllowedPrice),
      actualMarginRate: ((safePrice - activeCostPrice) / activeCostPrice)
    };
  }
}

module.exports = MarginProtectionService;
