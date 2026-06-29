# Fufaji AI Agentic Employee System — Master Spec

**Codename:** Fufaji Mission Control ("Karyalay" — the office)
**Owner:** Gaurav (Owner / Builder)
**App:** Fufaji's Online (`com.fufajis.online`) — Flutter + Firebase + Gemini + Razorpay
**Document type:** Build-ready specification (plan → scope → architecture → workflows → roadmap → tasks)
**Date:** 2026-06-12
**Status:** Draft v1 — ready for Claude to implement in phases

---

## 0. How to read this document

This is the single source of truth for building an **AI workforce inside the Fufaji owner app**: a team of autonomous "AI employees" that watch the business, research, plan, and execute work 24×7 — adding/managing products, preparing reports, suggesting ideas, queuing and running tasks, and broadcasting notifications — all controlled from one **Owner Control Room** dashboard.

Sections 1–6 are the *product* (what we're building and why). Sections 7–15 are the *engineering* (how it's built on your existing stack). Sections 16–21 are *execution* (guardrails, cost, roadmap, and a sprint-by-sprint task list Claude can run).

Where a decision was genuinely open, I picked a sensible default and flagged it as **[DEFAULT]** in §22 so you can override in one place.

---

## 1. Vision & North Star

**Vision:** Gaurav opens one screen and sees his entire shop being run by a tireless AI staff — each "employee" has a desk, a job, a live status, and a track record. They notice problems before he does, draft the fix, and either do it automatically (low-risk) or put it on his desk for one-tap approval (high-risk).

**North Star metric:** *Owner hours saved per week* — measured as the number of decisions/tasks the AI workforce completed or pre-drafted that Gaurav would otherwise have done by hand.

**Three promises the system must keep:**
1. **Always-on** — agents run 24×7 in the cloud, not just when the app is open.
2. **In control** — nothing irreversible happens without the owner's permission tier allowing it; everything is logged and reversible where possible.
3. **Explainable** — every action shows *why* (the reasoning, the data it saw, the expected impact).

---

## 2. Design Principles

1. **Owner is CEO, AI is staff.** The owner sets goals and approves; agents propose and execute within guardrails. Never the reverse.
2. **Human-in-the-loop by risk, not by default.** Reversible/low-cost actions (draft a report, suggest a price) run free. Irreversible/money/customer-facing actions (publish price change, broadcast to all users, delete product) require approval based on the agent's autonomy tier.
3. **Every action is auditable & reversible.** Reuse the existing `audit_logs` + `security_events` infrastructure. Each agent action writes a structured log with before/after state and an undo handle where possible.
4. **Explainability over magic.** Each task carries a `reasoning` field and the evidence it used. The owner can always ask "why did you do this?"
5. **Build on what exists.** Flutter + Provider, GoRouter, Firebase (Firestore/Auth/Storage/Functions/App Check), Gemini (already wired via `GeminiService`), FCM. No new frameworks unless justified.
6. **Cheap by default.** Agents batch work, cache reasoning, and use the smallest capable model per task. Heavy runs are scheduled, not real-time.
7. **Degrade gracefully.** If Gemini is down or out of quota, agents fall back to rule-based logic and queue the reasoning step — they never crash the owner app.
8. **Bilingual & rural-first.** All owner-facing AI output is available in Hindi + English; all customer-facing copy the agents generate respects the existing Hinglish tone.

---

## 3. Scope

### In scope (this program)
- An **Owner Control Room** dashboard inside the existing owner section of the app.
- A roster of **AI employee agents** (see §6), each with a defined job, tools, and autonomy tier.
- A **24×7 cloud agent runtime** (Cloud Functions + Cloud Scheduler) that runs agents on schedules and on events.
- A **task system** where agents create, queue, prioritize, and execute tasks; the owner approves/rejects/edits.
- **Product operations**: agents can analyze the catalog and draft/add/edit/optimize products (with approval gates).
- **Reports engine**: agents generate daily/weekly/on-demand business reports.
- **Idea/suggestion engine**: agents proactively suggest growth/ops ideas.
- **Notification & broadcast center**: owner (and approved agents) send push notifications to all users or targeted segments, controlled from the dashboard.
- **Guardrails, permissions, audit** for everything above.

### Out of scope (explicitly, for v1)
- Fully autonomous spending of real money (placing supplier orders, paying invoices). Agents may *draft* these; a human executes.
- Agents writing/deploying app code to production by themselves (that stays a Claude-Code + Gaurav workflow).
- Replacing existing customer-facing features (voice order, refer & earn, etc.) — the AI workforce *operates* them, it doesn't rebuild them.
- Multi-tenant / selling this as SaaS to other shops (possible later; architecture should not block it, but it isn't built now).

### MVP vs. Later
- **MVP (Phase 1–2):** Control Room shell, 3 agents (Analyst, Catalog, Comms), task system, reports, broadcast center, full audit + approval.
- **Later (Phase 3+):** Remaining agents, inter-agent collaboration, RAG memory, scheduled autonomous runs, A/B testing of agent suggestions.

---

## 4. Conceptual Model — "AI Employees"

The owner thinks in **people**, not pipelines. We model every agent as a coworker:

| Concept | Real-world analogy | Technical reality |
|---|---|---|
| **Agent** | An employee with a job title | A Cloud Function role + a Firestore `agents/{id}` document + a Gemini system prompt |
| **Shift** | When they're "at work" | Cloud Scheduler cron + event triggers |
| **Task** | A piece of work on their desk | `agent_tasks/{id}` doc with lifecycle status |
| **Skill / Tool** | What they're allowed to do | A registered function the agent may call (see §10) |
| **Autonomy tier** | How much they're trusted | `auto` / `approval` / `advisory` (see §6.2) |
| **Manager** | The boss they report to | The **Chief of Staff** orchestrator agent → the Owner |
| **Performance** | Their track record | Rolling KPIs on the agent card (tasks done, approved %, impact) |
| **Memory** | What they remember | Firestore memory docs + optional vector recall (see §12) |

This metaphor drives the entire dashboard UI: a "team room" where each employee has a **desk card** showing avatar, title, status light (working / idle / waiting on you / blocked), current task, and stats.

---

## 5. End-to-end example (so the abstract becomes concrete)

> 2:14 AM. The **Inventory & Catalog Agent** runs its scheduled shift. It queries `products` + recent `orders`, notices "Aashirvaad Atta 5kg" sold out 3 days ago and has 6 pending searches for it. It also sees competitor-style demand for a 10kg pack the shop doesn't list.
>
> It creates two tasks:
> 1. *"Restock alert: Aashirvaad Atta 5kg — out of stock, 6 missed searches"* → **autonomy: advisory** → lands on owner's desk.
> 2. *"Draft new product: Aashirvaad Atta 10kg"* — it auto-generates the product draft (name Hindi+English, description, suggested price from the 5kg unit price × ratio, category, image placeholder) → **autonomy: approval** → queued for one-tap publish.
>
> At 7:00 AM the **Business Analyst Agent** compiles the overnight report: yesterday's revenue, top products, the 2 new catalog tasks waiting, and one growth idea ("Bundle Atta + Sugar for festival — projected +12% basket size"). It sends Gaurav a push notification: *"☕ Good morning — 1 thing needs you, 2 ideas ready."*
>
> Gaurav opens the Control Room, taps **Approve** on the 10kg product (it goes live), taps **Approve** on a pre-drafted broadcast the **Comms Agent** wrote (*"New: 10kg Atta packs now available 🌾"*) targeted at users who bought atta in the last 60 days. Done in 90 seconds. The AI staff did the other 2 hours of work overnight.

---

## 6. The Agent Roster (AI Employees)

### 6.1 Roster overview

| # | Agent (Employee) | Job in one line | Default autonomy | Runs |
|---|---|---|---|---|
| 0 | **Chief of Staff** (orchestrator) | Routes work, sets priorities, briefs the owner | Advisory | Always + on every event |
| 1 | **Business Analyst** | Watches sales/KPIs, writes reports, spots trends | Auto (reports), Advisory (ideas) | Scheduled (daily/weekly) |
| 2 | **Inventory & Catalog** | Stock health, adds/edits/optimizes products | Approval (writes), Advisory (alerts) | Scheduled + on order events |
| 3 | **Pricing & Promotions** | Suggests prices, coupons, bundles, festival offers | Approval | Scheduled + on demand |
| 4 | **Customer Insights** | Segments users, churn/winback, satisfaction | Advisory | Scheduled (weekly) |
| 5 | **Marketing & Comms** | Drafts + sends notifications, campaigns, copy | Approval (send), Auto (draft) | On demand + scheduled |
| 6 | **Operations & Orders** | Order flow health, delivery SLAs, refunds watch | Advisory + Approval (refund drafts) | On order events |
| 7 | **Growth / Ideas** | Proactive ideas, experiments, opportunity scan | Advisory | Scheduled (weekly) |
| 8 | **Quality & Risk** | Catalog quality, fraud/abuse signals, data hygiene | Advisory + Auto (flagging) | Scheduled + on events |

> **MVP three:** Business Analyst (1), Inventory & Catalog (2), Marketing & Comms (5). The Chief of Staff (0) is required from day one as the thin orchestrator. The rest land in Phase 3.

### 6.2 Autonomy tiers (the trust model)

Every task an agent produces is tagged with one tier. The tier decides what happens when the agent finishes reasoning:

- **`auto`** — Execute immediately, log it, notify owner after the fact. *Only* for reversible, zero-/low-cost, internal actions (generate a report, flag an item, write a draft, recompute a segment).
- **`approval`** — Execute only after the owner taps Approve. Default for anything customer-facing, money-related, or hard to undo (publish/edit/delete product, change price, send broadcast, issue refund draft).
- **`advisory`** — Never executes; it's a recommendation/alert with an optional "convert to task" button. For ideas, warnings, and strategy.

The owner can **promote/demote** any agent's default tier per capability from the agent's settings (e.g., "let Catalog auto-publish stock-status changes but require approval for new products").

### 6.3 Agent spec template (each agent is defined by this)

Every agent in §6.4 is fully specified by:
- **Mission** — one paragraph job description (becomes the system prompt header).
- **Perceives (inputs)** — which Firestore collections / signals it reads.
- **Researches** — what analysis/external lookups it does.
- **Decides** — the kinds of conclusions it's allowed to reach.
- **Executes (tools)** — registered functions it may call (see §10), each with its autonomy tier.
- **Outputs** — tasks, reports, drafts, alerts it produces.
- **Schedule/triggers** — when it wakes up.
- **KPIs** — how its performance card is scored.
- **Guardrails** — hard limits.

### 6.4 Agent definitions (MVP set fully specified; others summarized)

#### Agent 0 — Chief of Staff (Orchestrator) — *required*
- **Mission:** Be Gaurav's right hand. Receive signals and other agents' outputs, deduplicate, prioritize, decide which agent should act, and produce the owner's daily brief. Never does domain work itself; it delegates and summarizes.
- **Perceives:** the `agent_tasks` queue, all agents' outputs, owner's pending-approvals count, system health.
- **Researches:** cross-agent conflicts (e.g., two agents touching the same product), priority scoring (impact × urgency × confidence).
- **Decides:** task priority, routing, what makes the daily brief, when to ping the owner vs. batch.
- **Executes:** `prioritize_tasks`, `compose_owner_brief`, `route_to_agent`, `request_owner_attention` (push).
- **Outputs:** the **Owner Daily/Shift Brief**, the prioritized task queue, "needs you" badge count.
- **Triggers:** every scheduled agent run completion + a 7:00 AM brief cron + when pending-approvals crosses a threshold.
- **KPIs:** brief open rate, % of "needs you" items actually actioned, false-alarm rate.
- **Guardrails:** advisory only; cannot execute domain tools; max 1 proactive push per 4 hours unless severity = critical.

#### Agent 1 — Business Analyst — *MVP*
- **Mission:** Understand how the shop is doing and tell the owner in plain Hindi/English. Turn raw orders/products/users data into daily and weekly reports and surface meaningful trends and anomalies.
- **Perceives:** `orders`, `products`, `users`, `cart`, `coupons`, wallet/referral data.
- **Researches:** revenue, order count, AOV, top/bottom products, category mix, new vs returning, conversion (cart→order), day-over-day and week-over-week deltas, anomaly detection (e.g., sudden drop).
- **Decides:** what's "notable" (threshold + z-score), which 3 insights matter most today, which to escalate as advisory ideas.
- **Executes:** `generate_report(period)` *(auto)*, `create_task` for follow-ups *(advisory)*, `flag_anomaly` *(auto)*.
- **Outputs:** `reports/{id}` doc (structured + narrative + charts data), insight cards, anomaly alerts.
- **Triggers:** daily 6:30 AM (yesterday), Monday 7:00 AM (weekly), on-demand from dashboard.
- **KPIs:** report read rate, insight→action conversion, anomaly precision.
- **Guardrails:** read-only on business data; never changes products/prices; numbers must be computed in code (Cloud Function), not hallucinated by the LLM — the LLM only narrates pre-computed figures.

#### Agent 2 — Inventory & Catalog — *MVP*
- **Mission:** Keep the catalog healthy, complete, and growing. Detect stockouts and slow movers, improve weak product listings, and draft new products the demand data justifies.
- **Perceives:** `products`, `orders`, search/`missed-search` signals (if logged), product view events.
- **Researches:** stock levels vs. velocity, out-of-stock with demand, low-quality listings (missing image/description/Hindi name), gaps vs. demand (searched-but-not-found), reorder timing.
- **Decides:** restock alerts, listing-quality fixes, new product drafts, deactivation of dead SKUs.
- **Executes:** `draft_product` *(approval)*, `update_product` *(approval; can be promoted to auto for stock-status only)*, `improve_listing` *(approval)*, `flag_stockout` *(auto/advisory)*, `create_task` *(advisory)*.
- **Outputs:** product drafts (full schema incl. Hindi/English name, description, price suggestion, category, GST, dadJoke field), edit proposals with before/after diff, stock alerts.
- **Triggers:** nightly 2:00 AM, on `order.created` (decrement awareness), on-demand.
- **KPIs:** % drafts approved, time-to-restock, listing completeness score lift.
- **Guardrails:** never publishes a product without approval (v1); price suggestions must include rationale; image generation is a placeholder/asset-picker, not auto-published imagery without owner OK.

#### Agent 5 — Marketing & Comms — *MVP*
- **Mission:** Be the shop's voice. Draft and (on approval) send push notifications, design simple campaigns, and write customer-facing copy in the right Hinglish tone — to everyone or to a precise segment.
- **Perceives:** `users` (+ segments from Agent 4 when available), `orders`, `products`, festival calendar, the broadcast history.
- **Researches:** best segment for a message, send-time, expected reach, message hygiene (no spam, frequency caps), A/B variants.
- **Decides:** audience, copy, timing, channel (push now; SMS/WhatsApp later via Twilio).
- **Executes:** `draft_broadcast` *(auto)*, `send_broadcast(segment)` *(approval)*, `schedule_broadcast` *(approval)*, `create_campaign` *(approval)*.
- **Outputs:** broadcast drafts (title, body, deep-link, audience, schedule), campaign plans, copy variants.
- **Triggers:** on-demand, festival/calendar cron, on owner request, on Analyst/Growth handoff.
- **KPIs:** delivery rate, open/CTR, opt-out rate (must stay under cap), revenue attributed.
- **Guardrails:** **hard frequency cap** (e.g., max 1 promotional push/user/day, 4/week) enforced in code; every send requires approval in v1; honors user notification preferences/opt-outs; no sending to unverified/guest users.

#### Agents 3, 4, 6, 7, 8 — Phase 3 (summarized)
- **Pricing & Promotions:** suggests price points (margin-aware), coupons, bundles, festival offers; approval-gated writes to `coupons`/`products`.
- **Customer Insights:** builds reusable segments (RFM, churn risk, new-vs-loyal), powers Comms targeting; advisory.
- **Operations & Orders:** monitors order funnel, delivery SLA breaches, refund/dispute patterns; drafts refund proposals (approval).
- **Growth / Ideas:** weekly opportunity scan, experiment proposals, "what to try next"; advisory.
- **Quality & Risk:** catalog data hygiene, duplicate/abuse/fraud signals, security-event correlation; auto-flag, advisory escalation.

---

## 7. System Architecture

```
┌────────────────────────────── OWNER APP (Flutter) ──────────────────────────────┐
│  Owner Control Room (new section under /owner/mission-control)                    │
│   • Team Room (agent desk cards)     • Task Inbox / Approvals                      │
│   • Reports viewer                   • Broadcast Center                            │
│   • Agent settings (autonomy tiers)  • Activity / Audit feed                       │
│  Providers: AgentProvider, TaskProvider, ReportProvider, BroadcastProvider         │
└───────────────▲───────────────────────────────────────────────▲──────────────────┘
                │ Firestore live listeners (streams)              │ callable functions
                │                                                 │ (approve/run/send)
┌───────────────┴─────────────────────────────────────────────────┴────────────────┐
│                              FIREBASE BACKEND                                      │
│  Firestore (agent state, tasks, reports, broadcasts, memory, audit)               │
│  Cloud Functions (the AGENT RUNTIME):                                             │
│     • scheduledAgentRunner  (Cloud Scheduler crons → run agent shifts)            │
│     • eventAgentTriggers    (onCreate orders/products → wake relevant agents)     │
│     • agentToolExecutor     (executes approved tool calls atomically)             │
│     • reportGenerator, broadcastSender (FCM), briefComposer                       │
│  Gemini (reasoning) via existing GeminiService pattern + function-calling         │
│  FCM (push broadcast)   App Check (abuse protection)   Cloud Storage (assets)     │
└───────────────────────────────────────────────────────────────────────────────────┘
```

**Key architectural decisions:**
- **The brain lives in the cloud, not the phone.** Agents run as Cloud Functions so they work 24×7 even when the app is closed. The Flutter app is a *control surface* (read state via streams, trigger actions via callable functions). This is the single most important decision and is why "24×7" is actually true.
- **Numbers in code, words in the LLM.** All metrics/aggregations are computed deterministically in Cloud Functions. Gemini only *narrates, classifies, drafts, and prioritizes*. This prevents hallucinated revenue figures.
- **Tool-calling boundary.** Agents never touch Firestore business data directly through free-form LLM output. They emit a structured **tool call** (validated against a schema) → `agentToolExecutor` runs it in a transaction with permission checks + audit. (See §10.)
- **Reuse existing services.** `AuditService`, `SecurityEventService`, `GeminiService`, FCM, App Check are already in the codebase — extend, don't replace.

---

## 8. Data Model (new Firestore collections)

```
agents/{agentId}
  name, title, emoji, role, enabled,
  autonomyDefaults: { capability: 'auto'|'approval'|'advisory' },
  schedule: { cron, events[] },
  status: 'idle'|'working'|'waiting_owner'|'blocked'|'disabled',
  currentTaskId, lastRunAt, nextRunAt,
  kpis: { tasksDone, approvalRate, impactScore, ... },
  systemPromptVersion, model

agent_runs/{runId}          // one execution of an agent shift
  agentId, startedAt, finishedAt, trigger, status,
  inputSummary, tokensUsed, costEstimate, toolCalls[], error

agent_tasks/{taskId}        // the unit of work on a "desk"
  agentId, createdBy, title, description, type,
  autonomy: 'auto'|'approval'|'advisory',
  status: 'proposed'|'queued'|'awaiting_approval'|'approved'|
          'executing'|'done'|'rejected'|'failed'|'undone',
  priority (0-100), confidence (0-1), impactEstimate,
  reasoning,                 // WHY — explainability
  evidence: [{label, value, ref}],
  payload: {...},            // tool call + args to run on approval
  result: {...}, undoHandle, // for reversibility
  ownerActionBy, ownerActionAt, createdAt, updatedAt

reports/{reportId}
  period, type ('daily'|'weekly'|'adhoc'), generatedAt, agentId,
  metrics: {...},            // pre-computed deterministic numbers
  narrative_hi, narrative_en,
  insights: [{title, detail, severity, relatedTaskId}],
  chartData: {...}

broadcasts/{broadcastId}
  title, body, deepLink, imageUrl,
  audience: { type:'all'|'segment'|'manual', segmentId, filters, userIds[] },
  estimatedReach, status:'draft'|'scheduled'|'sending'|'sent'|'cancelled',
  scheduledFor, sentAt, createdBy, approvedBy,
  stats: { delivered, opened, clicked, optOuts }, variant (A/B)

segments/{segmentId}        // Phase 3 (Customer Insights)
  name, definition (query/RFM rule), size, refreshedAt

agent_memory/{memId}        // durable notes agents keep
  agentId, scope, key, value, embedding?, createdAt, ttl

agent_config/global         // kill switch, global caps, model routing
  masterEnabled, dailyBudgetUsd, freqCaps, quietHours, modelRouting
```

Existing collections reused read-only or write-via-executor: `products`, `orders`, `users`, `coupons`, `cart`, `audit_logs`, `security_events`.

**Firestore security rules:** `agents`, `agent_tasks`, `reports`, `broadcasts`, `agent_config` are **owner-read / owner-or-function-write**. Clients can never write `status:'approved'`→execution directly; approval flips a field that a Cloud Function trigger validates, OR (preferred) the app calls a callable function `approveTask(taskId)` that does the permission check server-side.

---

## 9. Agent Runtime & Orchestration (24×7)

**Three ways an agent wakes up:**
1. **Scheduled (cron):** Cloud Scheduler → Pub/Sub → `scheduledAgentRunner`. e.g., Analyst at 6:30 AM, Catalog at 2:00 AM, Growth Mondays. Defined per-agent in `agents/{id}.schedule.cron`.
2. **Event-driven:** Firestore triggers (`orders/{id}` onCreate, `products/{id}` onWrite) → `eventAgentTriggers` wakes the relevant agent with the event as context.
3. **On-demand:** Owner taps "Run now" / "Ask the team" → callable function → runs that agent immediately.

**One agent shift (the loop):**
```
1. Load agent config + memory + permission tiers
2. PERCEIVE  → Cloud Function gathers inputs (deterministic queries, pre-aggregated)
3. REASON    → Gemini call with: system prompt + inputs + available tools (function-calling)
4. PLAN      → model returns structured tool calls + reasoning + confidence
5. GATE      → for each proposed action, check autonomy tier:
                 auto → execute now (agentToolExecutor, transactional, audited)
                 approval → write agent_task status 'awaiting_approval'
                 advisory → write agent_task status 'proposed' (no execution)
6. RECORD    → write agent_run, update agent KPIs/status, write audit_logs
7. HANDOFF   → notify Chief of Staff; it may re-prioritize / compose brief
```

**Orchestration (Chief of Staff):** after any run, it scores open tasks `priority = impact × urgency × confidence`, resolves conflicts (lock a product so two agents don't both edit it), and decides whether to ping the owner now or batch into the next brief. It enforces the "max 1 proactive push / 4h" rule.

**Failure handling:** every step is wrapped; on Gemini error → retry w/ backoff (reuse `twilio-reliability-patterns` style jitter) → fall back to rule-based path → mark `agent_run.status='degraded'` and surface a soft alert. Agents are idempotent (a re-run doesn't double-create tasks — dedupe by content hash).

---

## 10. Tool / Function-Calling Layer (what agents can actually DO)

Agents act **only** through a registry of typed tools. Gemini is given the tool schemas (function calling); it returns a call; `agentToolExecutor` validates + runs it with the agent's permission. This is the safety boundary.

| Tool | Args | Autonomy (default) | Effect |
|---|---|---|---|
| `generate_report` | period, type | auto | Writes `reports/{id}` |
| `create_task` | title, type, autonomy, payload, reasoning | per type | Adds to `agent_tasks` |
| `flag_anomaly` / `flag_item` | ref, severity, note | auto | Writes alert task |
| `draft_product` | productDraft{} | approval | Creates draft task w/ full product payload |
| `update_product` | productId, diff{} | approval | Edits product on approval (txn + audit) |
| `improve_listing` | productId, fields | approval | Listing copy/image fixes |
| `set_stock_status` | productId, inStock | auto* | (Promotable) toggles availability |
| `suggest_price` / `apply_price` | productId, price, rationale | advisory / approval | Price change |
| `create_coupon` | couponSpec | approval | Writes `coupons` |
| `build_segment` | rule | advisory | Writes `segments` |
| `draft_broadcast` | title, body, audience, deepLink | auto | Draft only |
| `send_broadcast` | broadcastId | approval | FCM send via `broadcastSender` |
| `schedule_broadcast` | broadcastId, when | approval | Scheduled send |
| `draft_refund` | orderId, amount, reason | approval | Refund proposal (human executes in Razorpay) |
| `request_owner_attention` | message, severity | auto (capped) | Push to owner |

Every executor call: ① re-checks permission server-side, ② runs in a Firestore transaction, ③ writes `audit_logs` with before/after + agent id + reasoning, ④ stores an `undoHandle` where the action is reversible, ⑤ updates the task `result`.

---

## 11. Reasoning, Prompts & Model Routing

- **Engine:** Gemini via the existing `GeminiService` pattern (already in the codebase), called *server-side* from Cloud Functions (move the key to Functions config — never ship agent keys in the app).
- **Per-agent system prompt:** versioned (`systemPromptVersion`) and stored so you can iterate without redeploying. Header = the agent's Mission (§6.3); body = guardrails, tone (Hinglish), output schema, available tools.
- **Structured output:** force JSON / function-calling so outputs are machine-validated, never free text into Firestore.
- **Model routing [DEFAULT]:** cheap/fast model for classification, drafting, narration; stronger model only for the Chief of Staff prioritization and complex planning. Configurable in `agent_config.modelRouting`.
- **Grounding:** the prompt only ever contains pre-computed numbers and real records — the model is instructed "never invent figures; if a value isn't provided, say unknown."

## 12. Memory

- **Short-term:** the run's input bundle (this shift only).
- **Durable notes:** `agent_memory` — e.g., "owner rejected festival-bundle idea twice → stop proposing." Agents read relevant memory each shift.
- **Optional vector recall (Phase 3+):** embeddings of past decisions/owner feedback for semantic retrieval, so agents "learn" preferences. Start with simple keyed memory; add vectors only if needed.

---

## 13. Owner Control Room — Dashboard UX

New section, routed at `/owner/mission-control` (gated by existing owner auth: Google → owners collection → device → PIN/biometric).

**Screens / tabs:**

1. **Team Room (home)** — the headline screen.
   - Grid of **agent desk cards**: avatar/emoji, title, **status light** (🟢 working · ⚪ idle · 🟡 waiting on you · 🔴 blocked), current task one-liner, mini-KPIs.
   - Top strip: "**Needs you: N**" (pending approvals), master **kill switch**, "Ask the team" button.
   - Tapping a card → that agent's detail (activity log, settings, run-now).

2. **Task Inbox / Approvals** — the owner's desk.
   - Sections: *Awaiting your approval* · *Advisory (ideas/alerts)* · *Running* · *Done (last 7d)*.
   - Each task: title, the agent, **reasoning**, evidence chips, expected impact, and action buttons: **Approve · Edit · Reject · Snooze**. Approve runs the payload server-side.
   - Bulk approve for low-risk batches.

3. **Reports** — list + reader. Daily/weekly/ad-hoc. Narrative (Hindi/English toggle) + charts (use existing chart libs) + linked insight tasks. "Generate report now" button.

4. **Broadcast Center** — see §14.

5. **Activity / Audit feed** — chronological stream of everything every agent did, backed by `audit_logs`. Filter by agent/type/date. This is the trust surface.

6. **Agent Settings** — per agent: enable/disable, autonomy tier per capability (promote/demote), schedule, quiet hours, prompt version. Plus **global**: daily AI budget cap, frequency caps, master quiet hours.

**Flutter implementation:**
- Providers (ChangeNotifier, matching existing pattern): `AgentProvider`, `TaskProvider`, `ReportProvider`, `BroadcastProvider`, each backed by Firestore `snapshots()` streams for live updates.
- Routes added in `app_router.dart` under the owner-guarded subtree.
- New screens under `screens/owner/mission_control/`. New services: `agent_service.dart`, `task_service.dart`, `report_service.dart`, `broadcast_service.dart` (thin clients over callable functions + Firestore).
- Reuse design tokens/colors already in the app; bilingual strings via existing strings approach.

---

## 14. Notifications & Broadcast System

**Goal:** From the dashboard, send a push to **all users** or a **specified segment**, drafted by the Comms agent or written by the owner, with approval + safety caps.

**Compose flow:**
1. Owner taps "New Broadcast" (or opens a Comms-agent draft).
2. Pick **audience**: All · Segment (e.g., "bought atta last 60d", "inactive 30d", "verified customers in district X") · Manual list.
3. Write/Edit **title + body** (Comms agent can auto-draft + give A/B variants), optional **image** and **deep link** (into a product/screen).
4. **Estimated reach** computed live from the audience query.
5. **Send now** or **Schedule**. Both require approval (owner is the approver; if the owner composed it, that *is* approval).

**Delivery (server):**
- `broadcastSender` Cloud Function fans out via **FCM** (topic for "all"; token batches for segments). Respects: opt-outs, notification preferences, **frequency caps** (`agent_config.freqCaps`), **quiet hours**, and "no guests/unverified."
- Writes per-broadcast `stats` (delivered/opened/clicked/optOut) back for the dashboard.

**Channels:** Push (FCM) in v1. **SMS/WhatsApp later via Twilio** (the Twilio skills are available — `twilio-send-message`, WhatsApp templates) as a Phase 3 add-on for order/marketing messages; design `broadcasts.channel` now so it's a drop-in.

**Targeting data:** v1 ships with a few hard-coded useful segments (all, verified customers, recent buyers, lapsed). Rich dynamic segments come with Agent 4 (Customer Insights) in Phase 3.

---

## 15. Security, Permissions & Audit

- **Access:** Control Room is owner-only, behind the existing owner auth chain (Google → `owners` → approved device → PIN/biometric, with lockout). No employee/customer access in v1.
- **Server-authoritative permissions:** approvals/executions happen in callable functions that re-verify the caller is an owner (custom claims) and that the agent's tier permits the action. The app UI is a convenience, never the gate.
- **Audit everything:** extend `AuditService` with agent action types; every tool execution writes before/after + agentId + reasoning. `SecurityEventService` captures anomalies (e.g., agent attempted a blocked tool).
- **Kill switch:** `agent_config.masterEnabled=false` halts all runs instantly; per-agent disable too.
- **Secrets:** Gemini/FCM/Twilio keys live in Functions config / Secret Manager, never in the Flutter bundle. App Check stays on to protect callable functions.
- **Reversibility:** destructive tools store undo handles; "Undo" appears on done tasks where possible (e.g., revert product edit from stored prior state).
- **Rate/cost limits:** global daily AI budget cap; per-agent token ceilings; broadcast frequency caps — all enforced server-side.

---

## 16. Guardrails (hard rules the system must enforce)

1. No money moves automatically — refunds/supplier orders are drafts only (v1).
2. No customer-facing change (product publish/price/broadcast) without an approval, unless the owner explicitly promoted that capability to `auto`.
3. Frequency caps on user notifications are enforced in code and cannot be overridden by an agent.
4. The LLM never writes Firestore directly and never invents numbers.
5. Every agent action is logged and attributable; nothing is anonymous.
6. Master kill switch and per-agent disable always work, even mid-run (checked between steps).
7. Quiet hours block proactive owner pings and user broadcasts unless severity = critical.
8. Guests/unverified users never receive broadcasts and are never acted upon.

---

## 17. Cost Model (keep it cheap)

- **Compute:** Cloud Functions + Scheduler — pennies/day at this scale (a handful of scheduled runs + event triggers).
- **LLM:** the main variable. Controls: model routing (cheap model for 90% of calls), batching (one Analyst run narrates the whole day, not per-order), caching, and a hard **daily budget cap** in `agent_config`. Realistic early-stage target: **a few dollars/day max**, tunable down.
- **FCM:** free.
- **Firestore:** the new collections are tiny; reads dominated by dashboard streams (cheap, and only when owner is viewing).
- **Twilio (later):** pay-per-message; only when SMS/WhatsApp is enabled.

A "cost meter" on the dashboard shows today's AI spend vs. the cap.

---

## 18. KPIs / Success Metrics for the program

- Owner hours saved/week (North Star, self-reported + task-count proxy).
- % of agent tasks approved (quality of suggestions; target rising over time).
- Time-to-restock and listing completeness (Catalog impact).
- Report engagement (open rate).
- Broadcast performance (CTR up, opt-out under cap).
- Agent reliability (run success rate, degraded-run rate).
- AI cost/day under budget.

---

## 19. Phased Roadmap

**Phase 0 — Foundations (infra & safety)**
Data model + security rules; `agent_config` + kill switch; extend `AuditService`; move Gemini key server-side; tool executor skeleton + permission checks; Control Room shell (Team Room + empty tabs) reading live Firestore.

**Phase 1 — First employee + reports**
Business Analyst (deterministic metrics functions + Gemini narration); `generate_report`; Reports screen; daily 6:30 AM brief via Chief-of-Staff-lite + owner push. *Outcome: owner gets a real AI daily report.*

**Phase 2 — Catalog + Comms + approvals**
Inventory & Catalog agent (`draft_product`/`update_product` with approval); Task Inbox/Approvals UX end-to-end; Marketing & Comms agent + Broadcast Center + `broadcastSender` (FCM, caps, opt-outs). *Outcome: AI proposes products & broadcasts; owner one-tap approves; staff executes.*

**Phase 3 — Full team + intelligence**
Pricing, Customer Insights (segments), Operations, Growth, Quality agents; dynamic segments powering Comms; inter-agent collaboration via Chief of Staff; agent memory; optional vector recall; Twilio SMS/WhatsApp channel; A/B testing of suggestions; cost meter + analytics on the agents themselves.

**Phase 4 — Polish & scale**
Owner "promote to auto" workflows once trust is earned; richer explainability; performance tuning; (optional) groundwork for multi-shop.

---

## 20. Build-Ready Task Breakdown (what Claude executes)

> Mapped to your existing `fufaji-dev-team` roles. Each task = production Flutter/Dart or Cloud Functions code, saved to `C:\Projects\fufaji-online-business`, structurally verified (the repo's truncation-scan rule applies).

**Sprint A — Foundations (Phase 0)**
- A1. (Firebase Eng) Firestore schema + security rules for `agents`, `agent_tasks`, `reports`, `broadcasts`, `agent_config`, `agent_runs`, `agent_memory`.
- A2. (Firebase Eng) `agent_config/global` doc + **kill switch** read path; seed `agents/*` docs for the MVP roster.
- A3. (Security Eng) Move Gemini key to Functions config/Secret Manager; callable-function auth (owner custom-claim check) helper.
- A4. (Backend) `agentToolExecutor` skeleton: tool registry, schema validation, permission gate, transactional write + `AuditService` hook + undo handle.
- A5. (Frontend) Control Room shell: route `/owner/mission-control`, Team Room with agent desk cards bound to `agents` stream, kill switch, empty tabs. Providers: `AgentProvider`, `TaskProvider`.

**Sprint B — Analyst + Reports (Phase 1)**
- B1. (Backend) Deterministic metrics functions (revenue, AOV, top products, deltas, anomalies) over `orders`/`products`/`users`.
- B2. (AI) Business Analyst agent: prompt v1, `generate_report` tool, narration (Hindi+English), insight extraction.
- B3. (Backend) `scheduledAgentRunner` + Cloud Scheduler crons (daily/weekly); `agent_runs` logging + KPI updates.
- B4. (Frontend) Reports screen (list + reader, language toggle, charts) + `ReportProvider`.
- B5. (AI) Chief-of-Staff-lite: 6:30 AM brief composer + owner push (FCM) with "needs you" count.

**Sprint C — Catalog + Approvals (Phase 2a)**
- C1. (AI/E-comm) Inventory & Catalog agent: stock/velocity analysis, `draft_product`, `update_product`, `flag_stockout`, reasoning + evidence.
- C2. (Backend) Executor implementations for product tools (txn + audit + undo); product-lock to avoid conflicts.
- C3. (Frontend) Task Inbox/Approvals: sections, task cards (reasoning, evidence, impact), Approve/Edit/Reject/Snooze wired to callable functions; bulk approve.
- C4. (Backend) `eventAgentTriggers` on `orders`/`products` onWrite (idempotent, dedupe by content hash).

**Sprint D — Comms + Broadcast (Phase 2b)**
- D1. (Backend) `broadcastSender` (FCM topics + token batches) with opt-out, prefs, **frequency caps**, quiet hours.
- D2. (AI) Marketing & Comms agent: `draft_broadcast` (+A/B variants, Hinglish), `send_broadcast`, `schedule_broadcast`.
- D3. (Frontend) Broadcast Center: audience picker (all/segment/manual) + live reach estimate, composer, schedule, stats; `BroadcastProvider`.
- D4. (Frontend) Activity/Audit feed screen over `audit_logs` (filters).
- D5. (Frontend) Agent Settings (autonomy tiers, schedule, quiet hours, global budget/caps).

**Sprint E — Full team (Phase 3)** — Pricing, Customer Insights (+dynamic segments), Operations, Growth, Quality agents; memory; Twilio channel; cost meter; A/B. (Decomposed at the start of Phase 3.)

**Verification step (every sprint):** run the repo's brace-lexer + tail truncation scan on all touched files; confirm callable-function auth + security rules with the Firebase emulator; dry-run agents in a sandbox project before pointing crons at production data; review broadcast caps with a test segment before any real send.

---

## 21. New Code Modules (where things live)

```
Flutter (lib/):
  screens/owner/mission_control/
    team_room_screen.dart
    task_inbox_screen.dart
    report_list_screen.dart  report_detail_screen.dart
    broadcast_center_screen.dart  broadcast_compose_screen.dart
    activity_feed_screen.dart
    agent_settings_screen.dart   agent_detail_screen.dart
  providers/
    agent_provider.dart  task_provider.dart
    report_provider.dart  broadcast_provider.dart
  services/
    agent_service.dart  task_service.dart
    report_service.dart  broadcast_service.dart   // thin clients over callables
  models/
    agent_model.dart  agent_task_model.dart
    report_model.dart  broadcast_model.dart

Cloud Functions (functions/):
  runtime/scheduledAgentRunner.ts  eventAgentTriggers.ts
  runtime/agentToolExecutor.ts     tools/*.ts (one per tool)
  agents/* (prompts + perceive/plan glue)
  reports/metrics.ts  reports/reportGenerator.ts
  comms/broadcastSender.ts  brief/briefComposer.ts
  lib/permissions.ts  lib/audit.ts  lib/gemini.ts
```

---

## 22. Decisions taken as defaults (override any in one place)

- **[DEFAULT] Brain in the cloud (Cloud Functions), not on-device** — required for true 24×7. *Alt: on-device only when app open (rejected — not 24×7).*
- **[DEFAULT] Gemini as the reasoning engine** — already integrated. *Alt: swap via `modelRouting`; Claude/OpenAI possible later.*
- **[DEFAULT] Approval-gated writes in v1** (nothing customer-facing auto-publishes until you promote it). Trust is earned, then loosened.
- **[DEFAULT] Push (FCM) only for broadcast in v1; Twilio SMS/WhatsApp in Phase 3.**
- **[DEFAULT] MVP roster = Chief of Staff + Analyst + Catalog + Comms.** Others in Phase 3.
- **[DEFAULT] Numbers computed in code, LLM only narrates** — non-negotiable for trust.
- **[DEFAULT] Daily AI budget cap** with a dashboard cost meter; start a few $/day.

If you want any of these flipped (e.g., auto-publish catalog from day one, Claude instead of Gemini, SMS in v1), say so and I'll adjust the spec + roadmap before building.

---

## 23. Glossary

- **Agent / AI Employee** — an autonomous role (Cloud Function + prompt + state) that perceives, reasons, and acts within guardrails.
- **Autonomy tier** — `auto` / `approval` / `advisory`; how much an agent's output is trusted to execute.
- **Tool** — a typed, registered action an agent may call; the only way agents change anything.
- **Shift / Run** — one execution of an agent (scheduled, event, or on-demand).
- **Chief of Staff** — the orchestrator agent that prioritizes and briefs the owner.
- **Control Room (Karyalay)** — the owner-only dashboard where the workforce is monitored and approved.
- **Broadcast** — a push (later SMS/WhatsApp) to all users or a segment.

---

*End of spec v1. Next step on your word: I'll start Sprint A (Foundations) and build it for real, or revise any decisions in §22 first.*
