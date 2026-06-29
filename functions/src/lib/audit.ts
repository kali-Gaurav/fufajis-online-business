// ============================================================
//  Mission Control - agent audit logging
//
//  Extends the existing `audit_logs` collection (see
//  lib/services/audit_service.dart) with an `agentAction` entry
//  type so every tool execution is attributable, explainable, and
//  (where possible) reversible from the Activity / Audit feed.
// ============================================================

import * as admin from 'firebase-admin';

const db = admin.firestore();

export interface AgentAuditEntry {
  agentId: string;
  taskId?: string;
  tool: string;
  description: string;
  reasoning?: string;
  before?: Record<string, unknown> | null;
  after?: Record<string, unknown> | null;
  targetId?: string;
  undoHandle?: Record<string, unknown> | null;
}

/**
 * Writes an audit_logs entry for an agent tool execution.
 * Fire-and-forget semantics matched to AuditService.logAction:
 * errors are logged but never thrown, so they can't block the
 * business action that triggered them.
 */
export async function logAgentAction(entry: AgentAuditEntry): Promise<void> {
  try {
    await db.collection('audit_logs').add({
      userId: `agent:${entry.agentId}`,
      userName: entry.agentId,
      action: 'agentAction',
      description: entry.description,
      metadata: {
        tool: entry.tool,
        taskId: entry.taskId ?? null,
        reasoning: entry.reasoning ?? null,
        before: entry.before ?? null,
        after: entry.after ?? null,
        undoHandle: entry.undoHandle ?? null,
      },
      targetId: entry.targetId ?? null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error('[Mission Control] Failed to write audit log:', err);
  }
}
