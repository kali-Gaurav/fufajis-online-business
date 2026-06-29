// ============================================================
//  Mission Control ("Karyalay") - shared agent types
// ============================================================

export type AutonomyTier = 'auto' | 'approval' | 'advisory';

export type AgentStatus = 'idle' | 'working' | 'waiting_owner' | 'blocked' | 'disabled';

export type AgentTaskStatus =
  | 'proposed'
  | 'queued'
  | 'awaiting_approval'
  | 'approved'
  | 'executing'
  | 'done'
  | 'rejected'
  | 'failed'
  | 'undone';

export interface AgentDoc {
  name: string;
  title: string;
  emoji: string;
  role: string;
  enabled: boolean;
  autonomyDefaults: Record<string, AutonomyTier>;
  schedule: { cron?: string; events?: string[] };
  status: AgentStatus;
  currentTaskId?: string | null;
  lastRunAt?: unknown;
  nextRunAt?: unknown;
  kpis: {
    tasksDone: number;
    approvalRate: number;
    impactScore: number;
  };
  systemPromptVersion: string;
  model: string;
}

export interface EvidenceItem {
  label: string;
  value: string | number;
  ref?: string;
}

export interface AgentTaskDoc {
  agentId: string;
  createdBy: string;
  title: string;
  description: string;
  type: string;
  autonomy: AutonomyTier;
  status: AgentTaskStatus;
  priority: number; // 0-100
  confidence: number; // 0-1
  impactEstimate?: string;
  reasoning: string;
  evidence: EvidenceItem[];
  payload: Record<string, unknown>;
  result?: Record<string, unknown> | null;
  undoHandle?: Record<string, unknown> | null;
  ownerActionBy?: string | null;
  ownerActionAt?: unknown;
  createdAt: unknown;
  updatedAt: unknown;
}

export interface AgentConfigDoc {
  masterEnabled: boolean;
  dailyBudgetUsd: number;
  freqCaps: {
    promotionalPerUserPerDay: number;
    promotionalPerUserPerWeek: number;
  };
  quietHours: { start: string; end: string; timezone: string };
  modelRouting: Record<string, string>;
}

/** Tool names registered with agentToolExecutor (see §10 of spec). */
export type AgentToolName =
  | 'generate_report'
  | 'create_task'
  | 'flag_anomaly'
  | 'flag_item'
  | 'draft_product'
  | 'update_product'
  | 'improve_listing'
  | 'set_stock_status'
  | 'suggest_price'
  | 'apply_price'
  | 'create_coupon'
  | 'build_segment'
  | 'draft_broadcast'
  | 'send_broadcast'
  | 'schedule_broadcast'
  | 'draft_refund'
  | 'request_owner_attention';
