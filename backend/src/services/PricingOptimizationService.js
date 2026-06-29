/**
 * PricingOptimizationService.js
 * Central AI coordinator for Fufaji's Price Intelligence & Margin Optimization.
 * Aggregates competitor intelligence, demand forecasts, promotions, and margin safety.
 * Calls Gemini 1.5 Flash via Genkit to generate strategic margin adjustments (manual approval only).
 */

const { db, admin } = require('../firestore');
const { getAI } = require('./genkitService');
const { z } = require('zod');
const CompetitorIntelligenceService = require('./CompetitorIntelligenceService');
const DemandForecastService = require('./DemandForecastService');
const MarginProtectionService = require('./MarginProtectionService');
const PromotionRecommendationService = require('./PromotionRecommendationService');
const ProcurementOptimizationService = require('./ProcurementOptimizationService');

class PricingOptimizationService {
  /**
   * Run full pricing analysis and generate AI recommendations
   * @param {string} productId
   * @returns {Promise<Object>} - Complete pricing report with AI rationale
   */
  static async analyzeAndRecommend(productId) {
    try {
      // 1. Fetch product
      const productDoc = await db().collection('products').doc(productId).get();
      if (!productDoc.exists) {
        throw new Error(`Product not found: ${productId}`);
      }

      const productData = productDoc.data();
      const basePrice = productData.basePrice || productData.price || 0;
      const costPrice = productData.costPrice || 0;
      const category = productData.category || 'default';
      const productName = productData.name;

      // 2. Gather Competitor Intelligence
      const competitorPrices = await CompetitorIntelligenceService.getCompetitorPrices(
        productId,
        productName,
        category,
        basePrice
      );

      // 3. Gather Demand Forecast
      const demandResult = await DemandForecastService.calculateDemand(productId);

      // 4. Check for Promotion Recommendations (slow-moving stock check)
      const promoResult = await PromotionRecommendationService.recommendPromotion(
        productData,
        demandResult.salesVelocity || 0
      );

      // 5. Gather Procurement Intelligence
      const procurementResult = await ProcurementOptimizationService.optimizeProcurement(
        productData.sku,
        productName,
        costPrice
      );

      // 6. Calculate default rule-based pricing proposal
      const validCompPrices = competitorPrices.map(c => c.price).filter(p => p > 0);
      const avgCompetitorPrice = validCompPrices.length > 0 
        ? validCompPrices.reduce((sum, p) => sum + p, 0) / validCompPrices.length
        : basePrice;

      let ruleRecommendedPrice = basePrice;
      let ruleReason = 'Maintain stable fixed price.';

      if (promoResult.recommendPromo) {
        ruleRecommendedPrice = promoResult.recommendedPromoPrice;
        ruleReason = promoResult.reason;
      } else if (validCompPrices.length > 0) {
        const priceDiffPercent = ((basePrice - avgCompetitorPrice) / avgCompetitorPrice) * 100;
        
        if (priceDiffPercent > 8.0) {
          ruleRecommendedPrice = avgCompetitorPrice * 1.02; // Competitor average + 2% brand premium
          ruleReason = `Fufaji price is ${priceDiffPercent.toFixed(1)}% higher than competitor average (₹${avgCompetitorPrice.toFixed(0)}). Recommend lowering to ₹${Math.round(ruleRecommendedPrice)} to protect village customer trust.`;
        } else if (priceDiffPercent < -15.0 && demandResult.demandScore > 75) {
          ruleRecommendedPrice = avgCompetitorPrice * 0.92; // Still 8% cheaper than competitors, but recovering margin
          ruleReason = `Fufaji is priced ${Math.abs(priceDiffPercent).toFixed(1)}% lower than competitors with high demand (Score: ${demandResult.demandScore}). Recommend moderate margin recovery to ₹${Math.round(ruleRecommendedPrice)}.`;
        }
      }

      // Enforce margin floor protection on the rule-based price
      const finalRuleSafety = MarginProtectionService.enforceMarginSafety(
        ruleRecommendedPrice,
        costPrice,
        basePrice,
        category
      );

      // 7. Invoke Gemini 1.5 Flash via Genkit for strategic interpretation
      let aiResult = {
        recommendedPrice: finalRuleSafety.safePrice,
        expectedRevenueIncreasePercent: 0,
        expectedSalesVolumeChangePercent: 0,
        rationale: ruleReason,
        aiConfidence: 85
      };

      try {
        const ai = await getAI();
        const response = await ai.generate({
          prompt: `
You are the AI Pricing & Margin Analyst for "Fufaji Store", a community grocery brand in Rajasthan, India.
Our core brand promise is: Trust, Stable Fixed Prices (no marketplace surge gimmicks), and honest, transparent pricing.

Review the following product analytics and suggest a strategic price adjustment recommendation.
Product details:
- Name: "${productName}"
- Category: "${category}"
- Current Price: ₹${basePrice}
- Procurement Cost (Cost Price): ₹${costPrice ? `₹${costPrice}` : 'Unknown (assume 20% margin)'}
- Stock Level: ${productData.stockQuantity || productData.stock || 0} units
- Stock Age: ${promoResult.recommendPromo ? 'Slow moving (over 30 days old)' : 'Healthy turnover'}

Competitor Prices (Blinkit, Zepto, BigBasket):
${competitorPrices.map(c => `- ${c.competitor}: ₹${c.price}`).join('\n')}

Demand & Sales Velocity:
- Demand Score: ${demandResult.demandScore}/100
- Weighted Breakdown: ${JSON.stringify(demandResult.breakdown)}
- Units sold (last 7 days): ${demandResult.salesVelocity}

Rules & Safety Floor:
- Baseline safe price floor: ₹${finalRuleSafety.minAllowedPrice} (never go below this)
- Promotion recommendations: ${promoResult.recommendPromo ? `Yes, ${promoResult.promoName} of ${promoResult.discountPercentage}% recommended` : 'None'}

Goal:
Recommend a stable, fixed selling price. Do NOT recommend dynamic surge pricing.
- If we are overpriced compared to competitors, suggest reducing margin (but keep it above the baseline safety floor).
- If stock is slow-moving, recommend clearance discount.
- If demand is very high and we are excessively cheap, recommend a modest price adjustment upwards (still keeping it cheaper than competitors to maintain trust).
- Provide a strategic rationale written in clear, friendly English with Hinglish hints where appropriate (e.g., calling atta, aloo, etc. by name).
`,
          output: {
            schema: z.object({
              recommendedPrice: z.number().describe('The recommended selling price in INR'),
              expectedRevenueIncreasePercent: z.number().describe('Expected percentage change in revenue'),
              expectedSalesVolumeChangePercent: z.number().describe('Expected percentage change in sales volume'),
              rationale: z.string().describe('Explain the reasoning behind this pricing decision in Hinglish/English'),
              aiConfidence: z.number().describe('AI confidence score from 0 to 100')
            })
          }
        });

        if (response.output) {
          aiResult = response.output;
          console.log(`[PricingOptimization] Gemini AI generated recommendation: ₹${aiResult.recommendedPrice}`);
        }
      } catch (aiError) {
        console.warn('[PricingOptimization] Genkit/Gemini call failed or unconfigured, falling back to rule engine:', aiError.message);
      }

      // Hard guardrail 1: Enforce margin safety on whatever the AI recommended
      const safetyResult = MarginProtectionService.enforceMarginSafety(
        aiResult.recommendedPrice,
        costPrice,
        basePrice,
        category
      );

      let finalPrice = safetyResult.safePrice;
      let anomalyClamped = safetyResult.marginFloorTriggered;
      let clampReason = safetyResult.marginFloorTriggered 
        ? `Adjusted up to ₹${safetyResult.safePrice} to enforce the procurement margin floor.` 
        : '';

      // Hard guardrail 2: Anti-Anomaly Clamps (max 10% change, or max 15% discount for clearance promos)
      const maxDiscountPrice = basePrice * 0.85; // 15% max clearance
      const maxPriceDecrease = basePrice * 0.90; // 10% max standard decrease
      const maxPriceIncrease = basePrice * 1.10; // 10% max standard increase

      const lowerBound = promoResult.recommendPromo 
        ? Math.round(maxDiscountPrice) 
        : Math.round(maxPriceDecrease);
      const upperBound = Math.round(maxPriceIncrease);

      if (finalPrice < lowerBound) {
        finalPrice = lowerBound;
        anomalyClamped = true;
        clampReason = `Clamped to ₹${lowerBound} (Maximum allowed decrease is ${promoResult.recommendPromo ? '15% for clearance' : '10%'} to protect pricing stability).`;
      } else if (finalPrice > upperBound) {
        finalPrice = upperBound;
        anomalyClamped = true;
        clampReason = `Clamped to ₹${upperBound} (Maximum allowed increase is 10% to protect customer trust).`;
      }

      // Confidence Thresholds: flag mandatory review if confidence is low
      const ownerReviewMandatory = aiResult.aiConfidence < 75;

      // Adjust rationale to explain the clamp
      let finalRationale = aiResult.rationale;
      if (anomalyClamped) {
        finalRationale = `${aiResult.rationale} (Safety Guardrail: ${clampReason})`;
      }

      return {
        success: true,
        productId,
        productName,
        category,
        basePrice,
        costPrice: costPrice || Math.round(basePrice * 0.8),
        competitorPrices,
        demandScore: demandResult.demandScore,
        salesVelocity: demandResult.salesVelocity,
        predictedQtyNext7Days: demandResult.predictedQtyNext7Days,
        procurement: procurementResult,
        recommendation: {
          recommendedPrice: finalPrice,
          priceChange: finalPrice - basePrice,
          percentChange: (((finalPrice - basePrice) / basePrice) * 100).toFixed(1),
          expectedImpact: {
            revenueIncreasePercent: aiResult.expectedRevenueIncreasePercent,
            salesVolumeChangePercent: aiResult.expectedSalesVolumeChangePercent
          },
          rationale: finalRationale,
          aiConfidence: aiResult.aiConfidence,
          anomalyClamped,
          clampReason,
          ownerReviewMandatory,
          minAllowedPrice: safetyResult.minAllowedPrice
        }
      };
    } catch (error) {
      console.error('[PricingOptimization] Optimization failed:', error.message);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Apply approved pricing decision (manual approval only)
   * @param {string} productId
   * @param {number} approvedPrice
   * @param {string} reason
   * @param {string} approvedBy
   * @returns {Promise<Object>}
   */
  static async applyPricing(productId, approvedPrice, reason, approvedBy = 'owner') {
    try {
      const productRef = db().collection('products').doc(productId);
      const productDoc = await productRef.get();
      if (!productDoc.exists) {
        throw new Error('Product not found');
      }

      const productData = productDoc.data();
      const oldPrice = productData.basePrice || productData.price;

      // Update product document
      await productRef.update({
        basePrice: approvedPrice,
        price: approvedPrice, // ensure legacy compatibility
        lastPriceUpdateAt: admin.firestore.FieldValue.serverTimestamp(),
        priceUpdateReason: reason
      });

      // Log decision to audit trail (expires in 180 days for clean data retention)
      const expiresAt = new Date(Date.now() + 180 * 24 * 60 * 60 * 1000);
      
      const logDoc = await db().collection('pricing_decisions').add({
        productId,
        productName: productData.name,
        oldPrice,
        recommendedPrice: approvedPrice, // assuming approved matching recommended
        approvedPrice,
        reason,
        aiConfidence: 95,
        approvedBy,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt)
      });

      console.log(`[PricingOptimization] Applied price ₹${approvedPrice} to product ${productId}. Logged decision: ${logDoc.id}`);

      return {
        success: true,
        message: `Successfully applied price ₹${approvedPrice} to ${productData.name}.`,
        logId: logDoc.id
      };
    } catch (error) {
      console.error('[PricingOptimization] Apply pricing failed:', error.message);
      return {
        success: false,
        error: error.message
      };
    }
  }
}

module.exports = PricingOptimizationService;
