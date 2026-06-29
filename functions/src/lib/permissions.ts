// ============================================================
//  Mission Control - permission helpers for callable functions
//
//  Server-authoritative: every callable function that approves or
//  executes an agent task MUST call requireOwner(context) before
//  doing anything else. The Flutter app's auth/role checks are a
//  convenience only — this is the real gate.
// ============================================================

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const db = admin.firestore();

/**
 * Verifies the calling user is authenticated AND has role 'owner'
 * (or 'UserRole.owner' / 'UserRole.shopOwner', matching the
 * conventions used elsewhere in this codebase). Throws an
 * HttpsError otherwise.
 *
 * Returns the caller's uid for convenience.
 */
export async function requireOwner(
  context: functions.https.CallableContext
): Promise<string> {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be signed in to call this function.'
    );
  }

  const uid = context.auth.uid;
  const userSnap = await db.collection('users').doc(uid).get();

  if (!userSnap.exists) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'No user profile found for this account.'
    );
  }

  const role: string = userSnap.data()?.role ?? '';
  const isOwner =
    role === 'owner' || role === 'UserRole.owner' || role === 'UserRole.shopOwner';

  if (!isOwner) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only the shop owner can perform this action.'
    );
  }

  return uid;
}

/**
 * Reads agent_config/global and returns it. Falls back to safe
 * defaults if the doc has not been seeded yet.
 */
export async function getAgentConfig(): Promise<{
  masterEnabled: boolean;
  dailyBudgetUsd: number;
  freqCaps: { promotionalPerUserPerDay: number; promotionalPerUserPerWeek: number };
  quietHours: { start: string; end: string; timezone: string };
  modelRouting: Record<string, string>;
}> {
  const snap = await db.collection('agent_config').doc('global').get();
  if (!snap.exists) {
    return {
      masterEnabled: false,
      dailyBudgetUsd: 2,
      freqCaps: { promotionalPerUserPerDay: 1, promotionalPerUserPerWeek: 4 },
      quietHours: { start: '21:30', end: '07:00', timezone: 'Asia/Kolkata' },
      modelRouting: { default: 'gemini-1.5-flash', orchestrator: 'gemini-1.5-flash' },
    };
  }
  return snap.data() as ReturnType<typeof getAgentConfig> extends Promise<infer T> ? T : never;
}

/**
 * Throws if the Mission Control master kill switch is off, or if a
 * specific agent has been individually disabled. Call this at the
 * start of every agent shift and before every tool execution.
 */
export async function assertAgentsEnabled(agentId?: string): Promise<void> {
  const config = await getAgentConfig();
  if (!config.masterEnabled) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Mission Control is currently disabled (master kill switch is off).'
    );
  }
  if (agentId) {
    const agentSnap = await db.collection('agents').doc(agentId).get();
    if (agentSnap.exists && agentSnap.data()?.enabled === false) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Agent "${agentId}" is disabled.`
      );
    }
  }
}
