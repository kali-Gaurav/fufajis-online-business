import * as admin from 'firebase-admin';
import { executeAgentTool, ToolExecutionContext } from './agentToolExecutor';

const db = admin.firestore();
export const PRICING_EXPERT_AGENT_ID = 'pricing_expert';

/**
 * Runs the Pricing Expert shift.
 * Analyzes velocity (recent orders) and stock levels to suggest price adjustments.
 */
export async function runPricingExpertShift(
  ctx: ToolExecutionContext = { agentId: PRICING_EXPERT_AGENT_ID }
): Promise<{ tasksCreated: number; productsAnalyzed: number }> {
  // 1. Fetch top products by velocity
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const recentOrdersSnap = await db.collection('orders')
    .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .get();

  const velocityMap: Record<string, number> = {};
  recentOrdersSnap.forEach(doc => {
    const items = doc.data().items || [];
    items.forEach((item: any) => {
      velocityMap[item.productId] = (velocityMap[item.productId] || 0) + (item.quantity || 0);
    });
  });

  // 2. Fetch products to find high-velocity items with stable stock
  const productsSnap = await db.collection('products').limit(20).get();
  let tasksCreated = 0;

  for (const doc of productsSnap.docs) {
    const p = doc.data();
    const pid = doc.id;
    const velocity = velocityMap[pid] || 0;
    const stock = Number(p.stockQuantity || 0);
    const currentPrice = Number(p.price || 0);

    // Scenario A: High velocity, low stock -> Suggest slight price increase to manage demand
    if (velocity > 10 && stock > 0 && stock < 10) {
      const suggestedPrice = Math.round(currentPrice * 1.05);
      await executeAgentTool('create_task', {
        title: `Dynamic Pricing: ${p.name}`,
        description: `High demand (${velocity} units/mo) and low stock (${stock}). Suggesting +5% price adjustment.`,
        type: 'pricing_suggestion',
        autonomy: 'approval',
        priority: 65,
        payload: {
          tool: 'apply_price',
          productId: pid,
          price: suggestedPrice,
          rationale: 'Demand-based dynamic pricing to optimize margins during low stock.'
        },
        reasoning: `Sales velocity of ${velocity} exceeds current stock depth of ${stock}. High risk of stockout before next replenishment.`
      }, ctx);
      tasksCreated++;
    }

    // Scenario B: Low velocity, high stock -> Suggest coupon or price drop
    if (velocity < 2 && stock > 50 && currentPrice > 100) {
      await executeAgentTool('create_task', {
        title: `Inventory Clearance: ${p.name}`,
        description: `Slow mover (${velocity} units/mo) with high capital tied up in stock (${stock} units).`,
        type: 'promotion_idea',
        autonomy: 'advisory',
        priority: 40,
        payload: { productId: pid, tool: 'create_coupon', discount: 15 },
        reasoning: `Overstocked item with low turnover. Freeing up warehouse space and cash flow is prioritized.`
      }, ctx);
      tasksCreated++;
    }
  }

  return { tasksCreated, productsAnalyzed: productsSnap.size };
}
