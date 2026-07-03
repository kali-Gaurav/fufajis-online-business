import * as functions from 'firebase-functions';
import { withAgentRun } from './scheduledAgentRunner';
import { INVENTORY_CATALOG_AGENT_ID, runInventoryCatalogShift } from './inventoryCatalog';
import { OPS_MANAGER_AGENT_ID, runOpsManagerShift } from './opsManager';
import { PRICING_EXPERT_AGENT_ID, runPricingExpertShift } from './pricingExpert';
import { BUSINESS_ANALYST_AGENT_ID } from './businessAnalyst';

/**
 * Wake relevant agents when a new order is created.
 */
export const onOrderCreatedAgentTrigger = functions
  .region('asia-south1')
  .firestore.document('orders/{orderId}')
  .onCreate(async (snap) => {
    console.log(`[EventTrigger] Order created: ${snap.id}. waking agents.`);

    // 1. Run inventory scan immediately to catch potential stockouts
    const inventoryTask = withAgentRun(INVENTORY_CATALOG_AGENT_ID, 'event_triggered_scan', async () => {
      const result = await runInventoryCatalogShift({
        agentId: INVENTORY_CATALOG_AGENT_ID,
        reasoning: `Order ${snap.id} created, triggering inventory health check.`,
      });
      return { trigger: 'order_created', orderId: snap.id, tasksCreated: result.tasksCreated };
    });

    // 2. Wake Ops Manager to monitor this specific order flow
    const opsTask = withAgentRun(OPS_MANAGER_AGENT_ID, 'event_triggered_health_check', async () => {
      const result = await runOpsManagerShift({
        agentId: OPS_MANAGER_AGENT_ID,
        reasoning: `New high-importance order ${snap.id} created. Monitoring for SLA compliance.`,
      });
      return { trigger: 'order_created', orderId: snap.id, tasksCreated: result.tasksCreated };
    });

    await Promise.all([inventoryTask, opsTask]);
  });

/**
 * Wake agents when a product is updated.
 */
export const onProductUpdatedAgentTrigger = functions
  .region('asia-south1')
  .firestore.document('products/{productId}')
  .onUpdate(async (change) => {
    const after = change.after.data();
    const before = change.before.data();

    if (after.stockQuantity === before.stockQuantity && after.name === before.name && after.price === before.price) {
      return;
    }

    console.log(`[EventTrigger] Product updated: ${change.after.id}. waking agents.`);

    // 1. Re-evaluate listing quality
    const inventoryTask = withAgentRun(INVENTORY_CATALOG_AGENT_ID, 'event_triggered_scan', async () => {
      const result = await runInventoryCatalogShift({
        agentId: INVENTORY_CATALOG_AGENT_ID,
        reasoning: `Product ${change.after.id} updated, re-evaluating listing quality.`,
      });
      return { trigger: 'product_updated', productId: change.after.id, tasksCreated: result.tasksCreated };
    });

    // 2. Wake Pricing Expert if stock or price changed
    const pricingTask = withAgentRun(PRICING_EXPERT_AGENT_ID, 'event_triggered_audit', async () => {
      const result = await runPricingExpertShift({
        agentId: PRICING_EXPERT_AGENT_ID,
        reasoning: `Manual update to product ${change.after.id}. Re-analyzing dynamic pricing strategy.`,
      });
      return { trigger: 'product_updated', productId: change.after.id, tasksCreated: result.tasksCreated };
    });

    await Promise.all([inventoryTask, pricingTask]);
  });
