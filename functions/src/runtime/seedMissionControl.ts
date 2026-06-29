// ============================================================
//  Mission Control - one-time / idempotent seed function
//
//  Seeds agent_config/global (with the master kill switch OFF by
//  default) and the agents/* docs for the MVP roster. Safe to call
//  multiple times - uses merge: true and only fills in fields that
//  are missing, so it won't clobber an agent's live status/kpis.
//
//  Owner-only callable. Run once from the Control Room "Setup"
//  action (Sprint A5) or via the Firebase console.
// ============================================================

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { requireOwner } from '../lib/permissions';
import { AgentDoc } from '../types/agent.types';

const db = admin.firestore();

const DEFAULT_MODEL = 'gemini-1.5-flash';

type SeedAgent = Pick<
  AgentDoc,
  'name' | 'title' | 'emoji' | 'role' | 'enabled' | 'autonomyDefaults' | 'schedule' | 'model' | 'systemPromptVersion'
>;

/**
 * MVP roster (spec §6 / §22 phase 1):
 *  - Chief of Staff: orchestrates the daily shift, summarizes other
 *    agents' work, decides what needs owner attention.
 *  - Business Analyst: daily/weekly reports, anomaly detection.
 *  - Inventory & Catalog: stock status, listing quality, product drafts.
 *  - Marketing & Comms: broadcast drafts, segment building.
 */
const MVP_AGENTS: Record<string, SeedAgent> = {
  chief_of_staff: {
    name: 'chief_of_staff',
    title: 'Chief of Staff',
    emoji: '🧭',
    role:
      'Runs the daily shift: reviews what every other agent did, ' +
      'summarizes priorities for the owner, and escalates anything ' +
      'urgent. Does not edit products, prices, or send broadcasts directly.',
    enabled: true,
    autonomyDefaults: {
      generate_report: 'auto',
      create_task: 'advisory',
      request_owner_attention: 'auto',
    },
    schedule: { cron: '0 8 * * *', events: ['agents.shift_complete'] },
    model: DEFAULT_MODEL,
    systemPromptVersion: 'v1',
  },
  business_analyst: {
    name: 'business_analyst',
    title: 'Business Analyst',
    emoji: '📊',
    role:
      'Watches sales, orders, and traffic. Produces the daily/weekly ' +
      'business report and flags anomalies (sales drops, refund spikes, ' +
      'stockouts of best sellers) for the owner.',
    enabled: true,
    autonomyDefaults: {
      generate_report: 'auto',
      flag_anomaly: 'auto',
      create_task: 'advisory',
    },
    schedule: { cron: '30 7 * * *' },
    model: DEFAULT_MODEL,
    systemPromptVersion: 'v1',
  },
  inventory_catalog: {
    name: 'inventory_catalog',
    title: 'Inventory & Catalog',
    emoji: '📦',
    role:
      'Monitors stock levels and listing quality. Can mark items ' +
      'in/out of stock automatically, but drafts and listing ' +
      'improvements require owner approval before going live.',
    enabled: true,
    autonomyDefaults: {
      set_stock_status: 'auto',
      flag_item: 'auto',
      draft_product: 'approval',
      update_product: 'approval',
      improve_listing: 'approval',
    },
    schedule: { cron: '0 */4 * * *' },
    model: DEFAULT_MODEL,
    systemPromptVersion: 'v1',
  },
  marketing_comms: {
    name: 'marketing_comms',
    title: 'Marketing & Comms',
    emoji: '📣',
    role:
      'Drafts customer broadcasts and audience segments based on ' +
      'inventory and sales signals. All sends require owner approval ' +
      'and respect quiet hours / frequency caps.',
    enabled: true,
    autonomyDefaults: {
      draft_broadcast: 'auto',
      build_segment: 'advisory',
      send_broadcast: 'approval',
      schedule_broadcast: 'approval',
    },
    schedule: { cron: '0 10 * * *' },
    model: DEFAULT_MODEL,
    systemPromptVersion: 'v1',
  },
};

export const seedMissionControl = functions
  .region('asia-south1')
  .https.onCall(async (_data, context) => {
    await requireOwner(context);

    const batch = db.batch();

    // agent_config/global - merge so an already-flipped kill switch
    // (masterEnabled: true) is never silently reset to false.
    const configRef = db.collection('agent_config').doc('global');
    const configSnap = await configRef.get();
    if (!configSnap.exists) {
      batch.set(configRef, {
        masterEnabled: false,
        dailyBudgetUsd: 2,
        freqCaps: { promotionalPerUserPerDay: 1, promotionalPerUserPerWeek: 4 },
        quietHours: { start: '21:30', end: '07:00', timezone: 'Asia/Kolkata' },
        modelRouting: { default: DEFAULT_MODEL, orchestrator: DEFAULT_MODEL },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const seeded: string[] = [];
    const skipped: string[] = [];

    for (const [agentId, agent] of Object.entries(MVP_AGENTS)) {
      const ref = db.collection('agents').doc(agentId);
      const snap = await ref.get();
      if (snap.exists) {
        skipped.push(agentId);
        continue;
      }
      batch.set(ref, {
        ...agent,
        status: 'idle',
        currentTaskId: null,
        lastRunAt: null,
        nextRunAt: null,
        kpis: { tasksDone: 0, approvalRate: 0, impactScore: 0 },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      seeded.push(agentId);
    }

    await batch.commit();

    return {
      success: true,
      configSeeded: !configSnap.exists,
      agentsSeeded: seeded,
      agentsSkipped: skipped,
    };
  });
