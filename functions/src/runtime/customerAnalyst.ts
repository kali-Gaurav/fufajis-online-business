import * as admin from 'firebase-admin';
import { executeAgentTool, ToolExecutionContext } from './agentToolExecutor';

const db = admin.firestore();
export const CUSTOMER_ANALYST_AGENT_ID = 'customer_analyst';

/**
 * Customer Analyst Shift.
 * Segments users based on order frequency and recency.
 */
export async function runCustomerAnalystShift(
  ctx: ToolExecutionContext = { agentId: CUSTOMER_ANALYST_AGENT_ID }
): Promise<{ tasksCreated: number; segmentsProcessed: number }> {
  // 1. Identify Churn Risk (No orders in 60 days but previously active)
  const sixtyDaysAgo = new Date();
  sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60);

  const inactiveSnap = await db.collection('users')
    .where('role', 'in', ['customer', 'UserRole.customer'])
    .where('lastLogin', '<', admin.firestore.Timestamp.fromDate(sixtyDaysAgo))
    .limit(50)
    .get();

  let tasksCreated = 0;
  if (inactiveSnap.size > 10) {
    await executeAgentTool('create_task', {
      title: `Win-Back Campaign Needed`,
      description: `${inactiveSnap.size} customers haven't logged in for 60+ days.`,
      type: 'marketing_lead',
      autonomy: 'advisory',
      priority: 75,
      payload: {
        tool: 'draft_broadcast',
        title: 'We miss you! ❤️',
        body: 'Special offer inside just for you. Come back and check out our new arrivals.',
        audience: { type: 'segment', segmentId: 'lapsed_users' }
      },
      reasoning: `Detected a growing segment of inactive users. Proactive win-back strategies typically yield 15% better retention than silence.`
    }, ctx);
    tasksCreated++;
  }

  // 2. Identify Potential VIPs (Frequent buyers)
  const usersSnap = await db.collection('users')
    .where('role', 'in', ['customer', 'UserRole.customer'])
    .orderBy('referralCount', 'desc')
    .limit(10)
    .get();

  for (const doc of usersSnap.docs) {
    const u = doc.data();
    if ((u.referralCount || 0) > 5) {
      await executeAgentTool('create_task', {
        title: `Loyalty Reward: ${u.name || u.phoneNumber}`,
        description: `Customer has successfully referred ${u.referralCount} neighbors.`,
        type: 'retention_bonus',
        autonomy: 'approval',
        priority: 60,
        payload: { userId: doc.id, tool: 'request_owner_attention', message: `Consider manual wallet credit for super-referrer ${u.name}` },
        reasoning: `Top 1% of referrers should be nurtured with personalized rewards to maintain brand advocacy.`
      }, ctx);
      tasksCreated++;
    }
  }

  return { tasksCreated, segmentsProcessed: 2 };
}
