// ============================================================
//  Mission Control - agentToolExecutor
//
//  The single boundary through which every AI agent affects real
//  data. Agents never write Firestore business data directly from
//  LLM output — they propose a (tool, args) pair; this module
//  validates it, checks the autonomy tier + permission, runs it in
//  a transaction, and writes an audit trail + undo handle.
//
//  See AI_AGENTIC_EMPLOYEE_SYSTEM_SPEC.md §10.
// ============================================================

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { AgentToolName, AutonomyTier } from '../types/agent.types';
import { assertAgentsEnabled, requireOwner } from '../lib/permissions';
import { logAgentAction } from '../lib/audit';

const db = admin.firestore();

/**
 * Default autonomy tier per tool (spec §10). Per-agent overrides
 * live in agents/{agentId}.autonomyDefaults and take precedence.
 */
export const DEFAULT_TOOL_AUTONOMY: Record<AgentToolName, AutonomyTier> = {
  generate_report: 'auto',
  create_task: 'advisory',
  flag_anomaly: 'auto',
  flag_item: 'auto',
  draft_product: 'approval',
  update_product: 'approval',
  improve_listing: 'approval',
  set_stock_status: 'auto',
  suggest_price: 'advisory',
  apply_price: 'approval',
  create_coupon: 'approval',
  build_segment: 'advisory',
  draft_broadcast: 'auto',
  send_broadcast: 'approval',
  schedule_broadcast: 'approval',
  draft_refund: 'approval',
  request_owner_attention: 'auto',
};

export interface ToolExecutionContext {
  agentId: string;
  taskId?: string;
  reasoning?: string;
}

export interface ToolExecutionResult {
  result: Record<string, unknown>;
  undoHandle?: Record<string, unknown> | null;
  targetId?: string;
  description: string;
}

/**
 * Resolves the effective autonomy tier for a (agentId, tool) pair:
 * agent-specific override if present, else the tool's default.
 */
export async function resolveAutonomy(
  agentId: string,
  tool: AgentToolName
): Promise<AutonomyTier> {
  const agentSnap = await db.collection('agents').doc(agentId).get();
  const override = agentSnap.data()?.autonomyDefaults?.[tool] as AutonomyTier | undefined;
  return override ?? DEFAULT_TOOL_AUTONOMY[tool];
}

/**
 * Executes a validated tool call. Callers MUST have already checked
 * the autonomy tier permits execution (auto, or approval+approved).
 * This function still re-checks the master kill switch / per-agent
 * disable flag before doing anything.
 */
export async function executeAgentTool(
  tool: AgentToolName,
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  await assertAgentsEnabled(ctx.agentId);

  switch (tool) {
    case 'generate_report':
      return runGenerateReport(args, ctx);
    case 'create_task':
      return runCreateTask(args, ctx);
    case 'flag_anomaly':
    case 'flag_item':
      return runFlagItem(args, ctx);
    case 'draft_product':
      return runDraftProduct(args, ctx);
    case 'update_product':
      return runUpdateProduct(args, ctx);
    case 'improve_listing':
      return runUpdateProduct(args, ctx); // same transactional path as update_product
    case 'set_stock_status':
      return runSetStockStatus(args, ctx);
    case 'apply_price':
      return runApplyPrice(args, ctx);
    case 'create_coupon':
      return runCreateCoupon(args, ctx);
    case 'draft_broadcast':
      return runDraftBroadcast(args, ctx);
    case 'send_broadcast':
      return runSendBroadcast(args, ctx);
    case 'request_owner_attention':
      return runRequestOwnerAttention(args, ctx);
    default:
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Tool "${tool}" is not implemented yet.`
      );
  }
}

// ----------------------------------------------------------------
// Tool implementations
// ----------------------------------------------------------------

async function runGenerateReport(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  const ref = db.collection('reports').doc();
  const doc = {
    period: args.period ?? null,
    type: args.type ?? 'adhoc',
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    agentId: ctx.agentId,
    metrics: args.metrics ?? {},
    narrative_hi: args.narrative_hi ?? '',
    narrative_en: args.narrative_en ?? '',
    insights: args.insights ?? [],
    chartData: args.chartData ?? {},
  };
  await ref.set(doc);
  await logAgentAction({
    agentId: ctx.agentId,
    taskId: ctx.taskId,
    tool: 'generate_report',
    description: `Generated ${doc.type} report for ${doc.period ?? 'now'}`,
    reasoning: ctx.reasoning,
    targetId: ref.id,
    after: { reportId: ref.id, type: doc.type, period: doc.period },
  });
  return { result: { reportId: ref.id }, description: `Report ${ref.id} generated`, targetId: ref.id };
}

async function runCreateTask(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  const ref = db.collection('agent_tasks').doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  const tool = (args.payload as { tool?: AgentToolName } | undefined)?.tool;
  const autonomy: AutonomyTier =
    (args.autonomy as AutonomyTier | undefined) ??
    (tool ? await resolveAutonomy(ctx.agentId, tool) : 'advisory');

  await ref.set({
    agentId: ctx.agentId,
    createdBy: ctx.agentId,
    title: args.title ?? 'Untitled task',
    description: args.description ?? '',
    type: args.type ?? 'general',
    autonomy,
    status: autonomy === 'auto' ? 'queued' : 'awaiting_approval',
    priority: args.priority ?? 50,
    confidence: args.confidence ?? 0.5,
    impactEstimate: args.impactEstimate ?? null,
    reasoning: ctx.reasoning ?? args.reasoning ?? '',
    evidence: args.evidence ?? [],
    payload: args.payload ?? {},
    result: null,
    undoHandle: null,
    ownerActionBy: null,
    ownerActionAt: null,
    createdAt: now,
    updatedAt: now,
  });

  return { result: { taskId: ref.id }, description: `Created task ${ref.id}`, targetId: ref.id };
}

async function runFlagItem(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  return runCreateTask(
    {
      title: args.note ?? 'Flagged item',
      description: (args.note as string) ?? '',
      type: 'alert',
      autonomy: 'advisory',
      priority: severityToPriority(args.severity as string | undefined),
      evidence: [{ label: 'ref', value: String(args.ref ?? '') }],
      payload: { ref: args.ref ?? null, severity: args.severity ?? 'info' },
    },
    ctx
  );
}

function severityToPriority(severity?: string): number {
  switch (severity) {
    case 'critical':
      return 95;
    case 'high':
      return 80;
    case 'medium':
      return 60;
    default:
      return 40;
  }
}

async function runDraftProduct(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  // draft_product never writes to /products directly - it creates an
  // approval-gated task carrying the full product payload. The owner
  // approves -> approveAgentTask -> update_product (create path).
  return runCreateTask(
    {
      title: `New product draft: ${(args.productDraft as { name?: string } | undefined)?.name ?? 'Untitled'}`,
      description: 'AI-drafted product ready for review.',
      type: 'product_draft',
      autonomy: 'approval',
      priority: args.priority ?? 50,
      confidence: args.confidence ?? 0.6,
      evidence: args.evidence ?? [],
      payload: { tool: 'update_product', productDraft: args.productDraft ?? {} },
      reasoning: args.reasoning,
    },
    ctx
  );
}

async function runUpdateProduct(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  const productId = args.productId as string | undefined;
  const diff = (args.diff ?? args.productDraft ?? {}) as Record<string, unknown>;

  return db.runTransaction(async (txn) => {
    let ref: admin.firestore.DocumentReference;
    let before: Record<string, unknown> | null = null;

    if (productId) {
      // 1. Check/Acquire Product Lock (Spec §10/C2)
      const lockRef = db.collection('product_locks').doc(productId);
      const lockSnap = await txn.get(lockRef);
      if (lockSnap.exists) {
        const lockData = lockSnap.data();
        // If lock is older than 5 minutes, consider it stale and override
        const lockTime = (lockData?.lockedAt as admin.firestore.Timestamp)?.toMillis() ?? 0;
        if (Date.now() - lockTime < 5 * 60 * 1000 && lockData?.agentId !== ctx.agentId) {
          throw new functions.https.HttpsError('aborted', `Product ${productId} is currently locked by ${lockData?.agentId}`);
        }
      }
      txn.set(lockRef, { agentId: ctx.agentId, lockedAt: admin.firestore.FieldValue.serverTimestamp() });

      ref = db.collection('products').doc(productId);
      const snap = await txn.get(ref);
      if (!snap.exists) {
        throw new functions.https.HttpsError('not-found', `Product ${productId} not found.`);
      }
      before = snap.data() as Record<string, unknown>;
      txn.update(ref, { ...diff, updatedAt: admin.firestore.FieldValue.serverTimestamp() });

      // Release lock after update (will be part of atomic txn)
      txn.delete(lockRef);
    } else {
      // New product (from a draft_product task)
      ref = db.collection('products').doc();
      txn.set(ref, {
        ...diff,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdByAgent: ctx.agentId,
      });
    }

    const undoHandle = before
      ? { tool: 'update_product', productId: ref.id, diff: before }
      : { tool: 'delete_product', productId: ref.id };

    await logAgentAction({
      agentId: ctx.agentId,
      taskId: ctx.taskId,
      tool: 'update_product',
      description: productId ? `Updated product ${productId}` : `Created product ${ref.id}`,
      reasoning: ctx.reasoning,
      targetId: ref.id,
      before,
      after: diff,
      undoHandle,
    });

    return {
      result: { productId: ref.id },
      undoHandle,
      targetId: ref.id,
      description: productId ? `Product ${ref.id} updated` : `Product ${ref.id} created`,
    };
  });
}

async function runSetStockStatus(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  return runUpdateProduct(
    { productId: args.productId, diff: { inStock: !!args.inStock } },
    ctx
  );
}

async function runApplyPrice(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  const productId = args.productId as string;
  const newPrice = Number(args.price);

  if (!productId || isNaN(newPrice)) {
    throw new functions.https.HttpsError('invalid-argument', 'apply_price requires productId and valid price.');
  }

  return runUpdateProduct(
    { productId, diff: { price: newPrice } },
    { ...ctx, reasoning: args.rationale as string ?? ctx.reasoning }
  );
}

async function runCreateCoupon(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  const code = (args.code as string) ?? `AI-${Math.random().toString(36).substring(2, 7).toUpperCase()}`;
  const discount = Number(args.discount ?? 10);
  const ref = db.collection('coupons').doc();

  const couponDoc = {
    code,
    discountAmount: discount,
    discountType: 'percentage',
    isActive: true,
    minOrderAmount: Number(args.minOrder ?? 500),
    maxDiscount: Number(args.maxDiscount ?? 200),
    expiryDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)), // 7 days
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: ctx.agentId,
  };

  await ref.set(couponDoc);

  await logAgentAction({
    agentId: ctx.agentId,
    taskId: ctx.taskId,
    tool: 'create_coupon',
    description: `Created coupon ${code} (${discount}%)`,
    reasoning: ctx.reasoning,
    targetId: ref.id,
    after: couponDoc,
  });

  return { result: { couponId: ref.id, code }, description: `Coupon ${code} created`, targetId: ref.id };
}

async function runDraftBroadcast(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  const ref = db.collection('broadcasts').doc();
  await ref.set({
    title: args.title ?? '',
    body: args.body ?? '',
    deepLink: args.deepLink ?? null,
    imageUrl: args.imageUrl ?? null,
    audience: args.audience ?? { type: 'all' },
    estimatedReach: args.estimatedReach ?? null,
    status: 'draft',
    channel: 'push',
    scheduledFor: null,
    sentAt: null,
    createdBy: ctx.agentId,
    approvedBy: null,
    stats: { delivered: 0, opened: 0, clicked: 0, optOuts: 0 },
    variant: args.variant ?? null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logAgentAction({
    agentId: ctx.agentId,
    taskId: ctx.taskId,
    tool: 'draft_broadcast',
    description: `Drafted broadcast "${args.title ?? ''}"`,
    reasoning: ctx.reasoning,
    targetId: ref.id,
    after: { title: args.title, audience: args.audience },
  });

  return { result: { broadcastId: ref.id }, description: `Broadcast draft ${ref.id} created`, targetId: ref.id };
}

/**
 * Send broadcast implementation - Task 2 Phase 1C.
 *
 * Takes an existing broadcast in 'draft' status and moves it to
 * 'scheduled' status. The broadcastSenderScheduled() Cloud Function
 * then picks it up every 15 minutes and executes sendBroadcastLogic().
 *
 * This decouples agent approval from actual sending, allowing rate
 * limiting, quiet hours enforcement, and retry logic to work uniformly
 * whether sends are manual (owner approval) or automatic (agent).
 *
 * Validates:
 * - Broadcast exists and is in 'draft' status
 * - Title, body, targetSegment are present
 * - scheduledAt (if provided) is in the future
 */
async function runSendBroadcast(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  const broadcastId = args.broadcastId as string | undefined;

  if (!broadcastId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'send_broadcast requires broadcastId'
    );
  }

  const ref = db.collection('broadcasts').doc(broadcastId);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', `Broadcast ${broadcastId} not found.`);
  }

  const before = snap.data()!;

  // Verify broadcast is in draft or scheduled status
  if (before.status !== 'draft' && before.status !== 'scheduled') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Broadcast ${broadcastId} is not in draft or scheduled status (current: ${before.status}). ` +
        `Only draft broadcasts can be sent.`
    );
  }

  // Validate required fields
  const errors: string[] = [];
  if (!before.title || before.title.trim().length === 0) {
    errors.push('Title is required');
  }
  if (before.title && before.title.length > 100) {
    errors.push('Title must be 100 characters or less');
  }
  if (!before.body || before.body.trim().length === 0) {
    errors.push('Body is required');
  }
  if (before.body && before.body.length > 500) {
    errors.push('Body must be 500 characters or less');
  }
  if (!before.targetSegment) {
    errors.push('Target segment is required');
  }

  if (errors.length > 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Broadcast validation failed: ${errors.join('; ')}`
    );
  }

  // Determine scheduledAt timestamp
  let scheduledAt: admin.firestore.Timestamp;

  if (args.scheduledAt) {
    try {
      const scheduledDate = new Date(args.scheduledAt as string | number);
      scheduledAt = admin.firestore.Timestamp.fromDate(scheduledDate);

      // Verify it's in the future
      if (scheduledDate < new Date()) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Scheduled time must be in the future'
        );
      }
    } catch (err) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Invalid scheduledAt format: ${String(err)}`
      );
    }
  } else {
    // Schedule for immediate processing (broadcaster will pick up within 15 min)
    scheduledAt = admin.firestore.Timestamp.now();
  }

  // Update broadcast: draft → scheduled
  await ref.update({
    status: 'scheduled',
    scheduledAt,
    approvedBy: ctx.agentId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await logAgentAction({
    agentId: ctx.agentId,
    taskId: ctx.taskId,
    tool: 'send_broadcast',
    description: `Scheduled broadcast "${before.title}" (${before.targetSegment}) for sending`,
    reasoning: ctx.reasoning,
    targetId: broadcastId,
    before: { status: before.status, title: before.title, segment: before.targetSegment },
    after: { status: 'scheduled', scheduledAt: scheduledAt.toDate().toISOString() },
  });

  return {
    result: {
      broadcastId,
      status: 'scheduled',
      scheduledAt: scheduledAt.toDate().toISOString(),
      message: 'Broadcast scheduled. Broadcaster will send within 15 minutes.',
    },
    description: `Broadcast ${broadcastId} scheduled for sending`,
    targetId: broadcastId,
  };
}

/**
 * Sends a push notification to the owner via FCM. Enforces a simple
 * cap (max 1 proactive push / 4h unless severity = critical) by
 * checking the most recent request_owner_attention audit entry.
 */
async function runRequestOwnerAttention(
  args: Record<string, unknown>,
  ctx: ToolExecutionContext
): Promise<ToolExecutionResult> {
  const severity = (args.severity as string) ?? 'info';
  const message = (args.message as string) ?? '';

  if (severity !== 'critical') {
    const recentSnap = await db
      .collection('audit_logs')
      .where('metadata.tool', '==', 'request_owner_attention')
      .orderBy('timestamp', 'desc')
      .limit(1)
      .get();

    if (!recentSnap.empty) {
      const last = recentSnap.docs[0].data();
      const lastTs = (last.timestamp as admin.firestore.Timestamp)?.toMillis?.() ?? 0;
      const fourHoursMs = 4 * 60 * 60 * 1000;
      if (Date.now() - lastTs < fourHoursMs) {
        return {
          result: { sent: false, reason: 'rate_limited' },
          description: 'Skipped owner ping (rate limit: max 1 proactive push / 4h)',
        };
      }
    }
  }

  const ownersSnap = await db.collection('users').where('role', 'in', [
    'owner', 'UserRole.owner', 'UserRole.shopOwner',
  ]).get();

  const tokens: string[] = [];
  ownersSnap.forEach((doc) => {
    const token = doc.data().fcmToken;
    if (token) tokens.push(token);
  });

  if (tokens.length > 0) {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: 'Mission Control', body: message },
      data: { type: 'mission_control_attention', severity },
    });
  }

  await logAgentAction({
    agentId: ctx.agentId,
    taskId: ctx.taskId,
    tool: 'request_owner_attention',
    description: `Pinged owner: ${message}`,
    reasoning: ctx.reasoning,
    after: { severity, recipients: tokens.length },
  });

  return { result: { sent: tokens.length > 0, recipients: tokens.length }, description: 'Owner pinged' };
}

// ----------------------------------------------------------------
// Callable functions: owner approve / reject task
// ----------------------------------------------------------------

export const approveAgentTask = functions
  .region('asia-south1')
  .https.onCall(async (data: { taskId: string }, context) => {
    const uid = await requireOwner(context);
    const taskRef = db.collection('agent_tasks').doc(data.taskId);
    const taskSnap = await taskRef.get();

    if (!taskSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Task ${data.taskId} not found.`);
    }

    const task = taskSnap.data()!;
    if (task.status !== 'awaiting_approval' && task.status !== 'proposed') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Task ${data.taskId} is not awaiting approval (status: ${task.status}).`
      );
    }

    await taskRef.update({
      status: 'executing',
      ownerActionBy: uid,
      ownerActionAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      const payload = (task.payload ?? {}) as Record<string, unknown>;
      const tool = payload.tool as AgentToolName | undefined;
      if (!tool) {
        throw new functions.https.HttpsError('invalid-argument', 'Task payload missing tool.');
      }

      const execResult = await executeAgentTool(tool, payload, {
        agentId: task.agentId,
        taskId: data.taskId,
        reasoning: task.reasoning,
      });

      await taskRef.update({
        status: 'done',
        result: execResult.result,
        undoHandle: execResult.undoHandle ?? null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, result: execResult.result };
    } catch (err) {
      await taskRef.update({
        status: 'failed',
        result: { error: err instanceof Error ? err.message : String(err) },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw err;
    }
  });

export const rejectAgentTask = functions
  .region('asia-south1')
  .https.onCall(async (data: { taskId: string; reason?: string }, context) => {
    const uid = await requireOwner(context);
    const taskRef = db.collection('agent_tasks').doc(data.taskId);
    const taskSnap = await taskRef.get();

    if (!taskSnap.exists) {
      throw new functions.https.HttpsError('not-found', `Task ${data.taskId} not found.`);
    }

    await taskRef.update({
      status: 'rejected',
      ownerActionBy: uid,
      ownerActionAt: admin.firestore.FieldValue.serverTimestamp(),
      result: { reason: data.reason ?? null },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  });

/**
 * Owner-controlled master kill switch toggle.
 */
export const setMissionControlEnabled = functions
  .region('asia-south1')
  .https.onCall(async (data: { enabled: boolean }, context) => {
    const uid = await requireOwner(context);
    await db.collection('agent_config').doc('global').set(
      {
        masterEnabled: !!data.enabled,
        updatedBy: uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return { success: true, masterEnabled: !!data.enabled };
  });
