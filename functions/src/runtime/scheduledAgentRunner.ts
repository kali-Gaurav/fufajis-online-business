// ============================================================
//  Mission Control - scheduledAgentRunner (B3)
//
//  Cloud Scheduler entry points that run AI agent "shifts". Each
//  shift is wrapped by `withAgentRun`, which:
//   - checks the master kill switch + per-agent enabled flag
//   - marks the agent as "working" while it runs
//   - logs a row to `agent_runs` (success or error)
//   - updates the agent's lastRunAt / status / kpis.tasksDone
//
//  Currently wires up the Business Analyst's daily and weekly
//  report shifts (Sprint B). Other agents can reuse `withAgentRun`
//  in later sprints.
// ============================================================

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { assertAgentsEnabled } from '../lib/permissions';
import { computeDailyMetrics, computeWeeklyMetrics } from './metrics';
import { runBusinessAnalystShift, BUSINESS_ANALYST_AGENT_ID } from './businessAnalyst';
import { runInventoryCatalogShift, INVENTORY_CATALOG_AGENT_ID } from './inventoryCatalog';
import { runPricingExpertShift, PRICING_EXPERT_AGENT_ID } from './pricingExpert';
import { runCustomerAnalystShift, CUSTOMER_ANALYST_AGENT_ID } from './customerAnalyst';
import { runOpsManagerShift, OPS_MANAGER_AGENT_ID } from './opsManager';

const db = admin.firestore();

export interface AgentRunSummary {
  [key: string]: unknown;
}

/**
 * Wraps a single agent shift with status tracking + agent_runs
 * logging. Re-throws on failure (after logging) so the Cloud
 * Function shows as failed in the console/monitoring.
 */
export async function withAgentRun(
  agentId: string,
  shiftType: string,
  runFn: () => Promise<AgentRunSummary>
): Promise<void> {
  await assertAgentsEnabled(agentId);

  const agentRef = db.collection('agents').doc(agentId);
  const runRef = db.collection('agent_runs').doc();
  const startedAt = admin.firestore.Timestamp.now();

  await agentRef.set(
    {
      status: 'working',
      lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  try {
    const summary = await runFn();

    await runRef.set({
      agentId,
      shiftType,
      status: 'success',
      startedAt,
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
      summary,
    });

    await agentRef.set(
      {
        status: 'idle',
        currentTaskId: null,
        'kpis.tasksDone': admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  } catch (err) {
    console.error(`[ScheduledAgentRunner] ${agentId} shift "${shiftType}" failed:`, err);

    await runRef.set({
      agentId,
      shiftType,
      status: 'error',
      startedAt,
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
      error: err instanceof Error ? err.message : String(err),
    });

    await agentRef.set(
      {
        status: 'blocked',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    throw err;
  }
}

/**
 * Business Analyst - daily report shift.
 * Runs at 6:30 AM IST, covering "yesterday" vs. the day before.
 */
export const businessAnalystDailyShift = functions
  .region('asia-south1')
  .pubsub.schedule('30 6 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(BUSINESS_ANALYST_AGENT_ID, 'daily_report', async () => {
      const metrics = await computeDailyMetrics();
      const { reportId, anomalyCount, usedAI } = await runBusinessAnalystShift(metrics, {
        agentId: BUSINESS_ANALYST_AGENT_ID,
      });
      return {
        period: 'daily',
        reportId,
        anomalyCount,
        usedAI,
        revenue: metrics.current.revenue,
        orderCount: metrics.current.orderCount,
      };
    });
    return null;
  });

/**
 * Pricing Expert - daily shift.
 * Runs at 9:00 AM IST.
 */
export const pricingExpertDailyShift = functions
  .region('asia-south1')
  .pubsub.schedule('0 9 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(PRICING_EXPERT_AGENT_ID, 'daily_pricing_audit', async () => {
      const result = await runPricingExpertShift({
        agentId: PRICING_EXPERT_AGENT_ID,
      });
      return { tasksCreated: result.tasksCreated, productsAnalyzed: result.productsAnalyzed };
    });
    return null;
  });

/**
 * Customer Analyst - weekly shift.
 * Runs Monday 11:00 AM IST.
 */
export const customerAnalystWeeklyShift = functions
  .region('asia-south1')
  .pubsub.schedule('0 11 * * 1')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(CUSTOMER_ANALYST_AGENT_ID, 'weekly_retention_audit', async () => {
      const result = await runCustomerAnalystShift({
        agentId: CUSTOMER_ANALYST_AGENT_ID,
      });
      return { tasksCreated: result.tasksCreated, segmentsProcessed: result.segmentsProcessed };
    });
    return null;
  });

/**
 * Operations Manager - periodic health check.
 * Runs every 30 minutes.
 */
export const opsManagerHeartbeat = functions
  .region('asia-south1')
  .pubsub.schedule('*/30 * * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(OPS_MANAGER_AGENT_ID, 'ops_health_check', async () => {
      const result = await runOpsManagerShift({
        agentId: OPS_MANAGER_AGENT_ID,
      });
      return { tasksCreated: result.tasksCreated, alertsFlagged: result.alertsFlagged };
    });
    return null;
  });

/**
 * Business Analyst - weekly report shift.
 * Runs Monday 6:45 AM IST, covering the last 7 days vs. the 7 before.
 */
export const businessAnalystWeeklyShift = functions
  .region('asia-south1')
  .pubsub.schedule('45 6 * * 1')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(BUSINESS_ANALYST_AGENT_ID, 'weekly_report', async () => {
      const metrics = await computeWeeklyMetrics();
      const { reportId, anomalyCount, usedAI } = await runBusinessAnalystShift(metrics, {
        agentId: BUSINESS_ANALYST_AGENT_ID,
      });
      return {
        period: 'weekly',
        reportId,
        anomalyCount,
        usedAI,
        revenue: metrics.current.revenue,
        orderCount: metrics.current.orderCount,
      };
    });
    return null;
  });

/**
 * Pricing Expert - daily shift.
 * Runs at 9:00 AM IST.
 */
export const pricingExpertDailyShift = functions
  .region('asia-south1')
  .pubsub.schedule('0 9 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(PRICING_EXPERT_AGENT_ID, 'daily_pricing_audit', async () => {
      const result = await runPricingExpertShift({
        agentId: PRICING_EXPERT_AGENT_ID,
      });
      return { tasksCreated: result.tasksCreated, productsAnalyzed: result.productsAnalyzed };
    });
    return null;
  });

/**
 * Customer Analyst - weekly shift.
 * Runs Monday 11:00 AM IST.
 */
export const customerAnalystWeeklyShift = functions
  .region('asia-south1')
  .pubsub.schedule('0 11 * * 1')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(CUSTOMER_ANALYST_AGENT_ID, 'weekly_retention_audit', async () => {
      const result = await runCustomerAnalystShift({
        agentId: CUSTOMER_ANALYST_AGENT_ID,
      });
      return { tasksCreated: result.tasksCreated, segmentsProcessed: result.segmentsProcessed };
    });
    return null;
  });

/**
 * Operations Manager - periodic health check.
 * Runs every 30 minutes.
 */
export const opsManagerHeartbeat = functions
  .region('asia-south1')
  .pubsub.schedule('*/30 * * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(OPS_MANAGER_AGENT_ID, 'ops_health_check', async () => {
      const result = await runOpsManagerShift({
        agentId: OPS_MANAGER_AGENT_ID,
      });
      return { tasksCreated: result.tasksCreated, alertsFlagged: result.alertsFlagged };
    });
    return null;
  });

/**
 * Inventory & Catalog - scheduled scan shift.
 * Runs every 4 hours to detect stockouts, low inventory, and missing catalog info.
 */
export const inventoryCatalogShift = functions
  .region('asia-south1')
  .pubsub.schedule('0 */4 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(INVENTORY_CATALOG_AGENT_ID, 'catalog_scan', async () => {
      const result = await runInventoryCatalogShift({
        agentId: INVENTORY_CATALOG_AGENT_ID,
      });
      return {
        tasksCreated: result.tasksCreated,
        scannedProducts: result.scannedProducts,
      };
    });
    return null;
  });

/**
 * Pricing Expert - daily shift.
 * Runs at 9:00 AM IST.
 */
export const pricingExpertDailyShift = functions
  .region('asia-south1')
  .pubsub.schedule('0 9 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(PRICING_EXPERT_AGENT_ID, 'daily_pricing_audit', async () => {
      const result = await runPricingExpertShift({
        agentId: PRICING_EXPERT_AGENT_ID,
      });
      return { tasksCreated: result.tasksCreated, productsAnalyzed: result.productsAnalyzed };
    });
    return null;
  });

/**
 * Customer Analyst - weekly shift.
 * Runs Monday 11:00 AM IST.
 */
export const customerAnalystWeeklyShift = functions
  .region('asia-south1')
  .pubsub.schedule('0 11 * * 1')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(CUSTOMER_ANALYST_AGENT_ID, 'weekly_retention_audit', async () => {
      const result = await runCustomerAnalystShift({
        agentId: CUSTOMER_ANALYST_AGENT_ID,
      });
      return { tasksCreated: result.tasksCreated, segmentsProcessed: result.segmentsProcessed };
    });
    return null;
  });

/**
 * Operations Manager - periodic health check.
 * Runs every 30 minutes.
 */
export const opsManagerHeartbeat = functions
  .region('asia-south1')
  .pubsub.schedule('*/30 * * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(OPS_MANAGER_AGENT_ID, 'ops_health_check', async () => {
      const result = await runOpsManagerShift({
        agentId: OPS_MANAGER_AGENT_ID,
      });
      return { tasksCreated: result.tasksCreated, alertsFlagged: result.alertsFlagged };
    });
    return null;
  });

