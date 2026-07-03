import * as admin from 'firebase-admin';
import { executeAgentTool, ToolExecutionContext } from './agentToolExecutor';

const db = admin.firestore();
export const OPS_MANAGER_AGENT_ID = 'ops_manager';

/**
 * Operations Manager Shift.
 * Monitors order flow and delivery delays.
 */
export async function runOpsManagerShift(
  ctx: ToolExecutionContext = { agentId: OPS_MANAGER_AGENT_ID }
): Promise<{ tasksCreated: number; alertsFlagged: number }> {
  // 1. Identify Delayed Orders (Processing for > 4 hours)
  const fourHoursAgo = new Date();
  fourHoursAgo.setHours(fourHoursAgo.getHours() - 4);

  const delayedOrdersSnap = await db.collection('orders')
    .where('status', 'in', ['processing', 'confirmed'])
    .where('createdAt', '<', admin.firestore.Timestamp.fromDate(fourHoursAgo))
    .limit(10)
    .get();

  let tasksCreated = 0;
  for (const doc of delayedOrdersSnap.docs) {
    const o = doc.data();
    await executeAgentTool('create_task', {
      title: `SLA Breach: Order #${o.orderNumber}`,
      description: `Order has been stuck in ${o.status} status for over 4 hours.`,
      type: 'operations_alert',
      autonomy: 'advisory',
      priority: 90,
      evidence: [{ label: 'orderId', value: doc.id }],
      reasoning: `Operational delay detected. High risk of customer dissatisfaction and potential cancellation.`
    }, ctx);
    tasksCreated++;
  }

  // 2. Monitor high-value pending payments
  const pendingPaymentsSnap = await db.collection('orders')
    .where('paymentStatus', '==', 'pending')
    .where('totalAmount', '>', 2000)
    .limit(5)
    .get();

  for (const doc of pendingPaymentsSnap.docs) {
    const o = doc.data();
    await executeAgentTool('create_task', {
      title: `High-Value Payment Pending: #${o.orderNumber}`,
      description: `₹${o.totalAmount} order is awaiting payment. Contact customer?`,
      type: 'sales_support',
      autonomy: 'advisory',
      priority: 50,
      reasoning: `High-value orders with pending payments have a 40% higher cart abandonment rate if not followed up within 2 hours.`
    }, ctx);
    tasksCreated++;
  }

  return { tasksCreated, alertsFlagged: delayedOrdersSnap.size };
}
