/**
 * PromotionRecommendationService.js
 * Identifies slow-moving or aging stock and recommends promotional discounts
 * to optimize inventory turnover without violating margin guidelines.
 */

const MarginProtectionService = require('./MarginProtectionService');

class PromotionRecommendationService {
  /**
   * Determine if a product needs a promotion and calculate the recommended price
   * @param {Object} productData - Product fields from Firestore (createdAt, stockQuantity, costPrice, price, category, etc.)
   * @param {number} salesVelocity - Units sold in the last 7 days
   * @returns {Object} - Promo recommendation detail
   */
  static recommendPromotion(productData, salesVelocity) {
    const basePrice = productData.basePrice || productData.price;
    const costPrice = productData.costPrice || 0;
    const category = productData.category || 'default';
    const createdAt = productData.createdAt;

    // Calculate product age in days (fall back to 35 days if not set, to simulate slow-mover detection)
    let productAgeInDays = 35;
    if (createdAt) {
      const createdDate = createdAt.toDate ? createdAt.toDate() : new Date(createdAt.seconds * 1000);
      productAgeInDays = Math.round((Date.now() - createdDate.getTime()) / (1000 * 60 * 60 * 24));
    }

    const currentStock = productData.stockQuantity || productData.stock || 0;

    let recommendPromo = false;
    let discountPercentage = 0;
    let reason = 'Sales velocity and inventory health are stable.';
    let promoDurationDays = 0;
    let promoName = 'No Promo';

    // Slow-moving stock detection rule:
    // If the product is in stock (qty > 5), age > 30 days, and sales velocity is low (<= 2 units in last 7 days)
    if (currentStock > 5 && productAgeInDays >= 30 && salesVelocity <= 2) {
      recommendPromo = true;

      if (productAgeInDays >= 90) {
        discountPercentage = 15; // Clearance discount
        promoDurationDays = 7;
        promoName = 'Clearance Discount';
        reason = `Critically slow-moving stock (in inventory for ${productAgeInDays} days with low sales velocity). Recommending 15% clearance discount.`;
      } else if (productAgeInDays >= 60) {
        discountPercentage = 10;
        promoDurationDays = 5;
        promoName = 'Inventory Boost Promo';
        reason = `Aging inventory (${productAgeInDays} days old) with flat sales. Recommending 10% promotional discount to stimulate demand.`;
      } else {
        discountPercentage = 5;
        promoDurationDays = 3;
        promoName = 'Quick Sales Booster';
        reason = `Stock age is ${productAgeInDays} days with low sales velocity. Recommending 5% discount for a short boost.`;
      }
    }

    let recommendedPromoPrice = basePrice;
    let marginSafetyResult = null;

    if (recommendPromo) {
      // Calculate discounted price
      const discountedPrice = basePrice * (1 - discountPercentage / 100);

      // Verify the discounted price is safe under margin protection rules
      marginSafetyResult = MarginProtectionService.enforceMarginSafety(
        discountedPrice,
        costPrice,
        basePrice,
        category
      );

      recommendedPromoPrice = marginSafetyResult.safePrice;

      // If margin protection adjusted our price up, adjust the discountPercentage to reflect reality
      if (marginSafetyResult.marginFloorTriggered) {
        discountPercentage = Math.round(((basePrice - recommendedPromoPrice) / basePrice) * 100);
        if (discountPercentage <= 0) {
          recommendPromo = false;
          discountPercentage = 0;
          promoName = 'No Promo';
          reason = 'Stock is slow-moving, but procurement margin floors prevent applying any discount.';
        } else {
          reason += ' (Discount adjusted upwards to protect minimum margin floor).';
        }
      }
    }

    return {
      recommendPromo,
      discountPercentage,
      recommendedPromoPrice,
      promoName,
      promoDurationDays,
      reason,
      marginSafety: marginSafetyResult
    };
  }
}

module.exports = PromotionRecommendationService;
