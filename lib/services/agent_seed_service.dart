import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// AgentSeedService — Sprint A1/A2 (Karyalay / Mission Control)
///
/// Seeds [agent_config/global] and the four MVP agent roster docs if they
/// don't already exist.  Call once at owner-app startup (e.g. from
/// OwnerDailyLoginScreen or main.dart after owner auth is confirmed).
///
/// All documents are written with [SetOptions(merge: false)] on first create
/// so an existing production roster is never accidentally overwritten.
class AgentSeedService {
  AgentSeedService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ---------------------------------------------------------------------------
  // Public entry point
  // ---------------------------------------------------------------------------

  /// Seeds [agent_config/global] and the MVP agent roster.
  /// Safe to call multiple times — skips docs that already exist.
  Future<void> seedIfNeeded() async {
    try {
      await Future.wait([_seedGlobalConfig(), _seedAgentRoster()]);
      debugPrint('[AgentSeedService] Seed check complete.');
    } catch (e, st) {
      debugPrint('[AgentSeedService] Seed error: $e\n$st');
      // Non-fatal — app continues; agents will degrade gracefully.
    }
  }

  // ---------------------------------------------------------------------------
  // agent_config/global
  // ---------------------------------------------------------------------------

  Future<void> _seedGlobalConfig() async {
    final ref = _db.collection('agent_config').doc('global');
    final snap = await ref.get();
    if (snap.exists) return; // already seeded

    await ref.set({
      // Master kill switch — set false to halt ALL agent runs instantly.
      'masterEnabled': false,

      // Maximum AI spend per day in USD (Gemini API).
      // Tune after first few real runs.
      'dailyBudgetUsd': 2.0,

      // Push notification frequency caps (enforced server-side in Cloud Functions).
      // max promotional pushes per user per day / per week.
      'freqCaps': {
        'maxPromoPerDay': 1,
        'maxPromoPerWeek': 4,
        // Max proactive owner pings per 4 hours (Chief of Staff rule).
        'ownerPingIntervalHours': 4,
      },

      // Quiet hours (IST, 24h format): no user broadcasts or owner pings.
      'quietHours': {'start': '22:00', 'end': '07:00', 'timezone': 'Asia/Kolkata'},

      // Model routing: cheap/fast model for most work; stronger for CoS.
      'modelRouting': {
        'default': 'gemini-1.5-flash',
        'chiefOfStaff': 'gemini-1.5-pro',
        'analyst': 'gemini-1.5-flash',
        'catalog': 'gemini-1.5-flash',
        'comms': 'gemini-1.5-flash',
      },

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[AgentSeedService] agent_config/global seeded.');
  }

  // ---------------------------------------------------------------------------
  // agents — MVP roster
  // ---------------------------------------------------------------------------

  Future<void> _seedAgentRoster() async {
    final batch = _db.batch();
    int seeded = 0;

    for (final agent in _mvpAgents) {
      final ref = _db.collection('agents').doc(agent['id'] as String);
      final snap = await ref.get();
      if (snap.exists) continue; // skip existing

      batch.set(ref, {
        ...agent..remove('id'),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      seeded++;
    }

    if (seeded > 0) {
      await batch.commit();
      debugPrint('[AgentSeedService] Seeded $seeded agent(s).');
    }
  }

  // ---------------------------------------------------------------------------
  // MVP agent definitions
  // ---------------------------------------------------------------------------

  static final List<Map<String, dynamic>> _mvpAgents = [
    // ── Agent 0 — Chief of Staff (Orchestrator) ─────────────────────────────
    {
      'id': 'chief_of_staff',
      'name': 'Chief of Staff',
      'title': 'Mukhya Sahayak', // Hindi title shown in UI
      'emoji': '🧑‍💼',
      'role': 'orchestrator',
      'enabled': false, // Enabled once Functions are wired
      'status': 'idle',
      'model': 'gemini-1.5-pro', // Stronger model for prioritisation
      'systemPromptVersion': 'v1',

      // Autonomy: CoS is advisory-only; it routes and summarises, never acts.
      'autonomyDefaults': {
        'prioritize_tasks': 'advisory',
        'compose_owner_brief': 'auto',
        'route_to_agent': 'advisory',
        'request_owner_attention': 'auto',
      },

      // Cloud Scheduler cron (handled in Functions): 7 AM IST daily + after
      // every scheduled agent run.  Stored here for reference / future config UI.
      'schedule': {
        'cron': '30 1 * * *', // 07:00 IST = 01:30 UTC
        'events': ['agent_run_completed'],
      },

      'kpis': {
        'tasksDone': 0,
        'approvalRate': 0.0,
        'impactScore': 0.0,
        'briefOpenRate': 0.0,
        'falseAlarmRate': 0.0,
      },

      'currentTaskId': null,
      'lastRunAt': null,
      'nextRunAt': null,
    },

    // ── Agent 1 — Business Analyst ──────────────────────────────────────────
    {
      'id': 'business_analyst',
      'name': 'Business Analyst',
      'title': 'Vyapar Vishleshan',
      'emoji': '📊',
      'role': 'analyst',
      'enabled': false,
      'status': 'idle',
      'model': 'gemini-1.5-flash',
      'systemPromptVersion': 'v1',

      'autonomyDefaults': {
        'generate_report': 'auto', // Reports run freely
        'flag_anomaly': 'auto', // Anomaly flags run freely
        'create_task': 'advisory', // Follow-up ideas need owner review
      },

      'schedule': {
        // 6:30 AM IST daily (yesterday's numbers), 7:00 AM IST Monday (weekly).
        'cron': '0 1 * * *', // 06:30 IST = 01:00 UTC
        'weeklyCron': '30 1 * * 1', // Monday 07:00 IST = 01:30 UTC
        'events': [],
      },

      'kpis': {
        'tasksDone': 0,
        'approvalRate': 0.0,
        'impactScore': 0.0,
        'reportReadRate': 0.0,
        'insightActionRate': 0.0,
        'anomalyPrecision': 0.0,
      },

      'currentTaskId': null,
      'lastRunAt': null,
      'nextRunAt': null,
    },

    // ── Agent 2 — Inventory & Catalog ───────────────────────────────────────
    {
      'id': 'catalog_agent',
      'name': 'Inventory & Catalog',
      'title': 'Suchi Prabandhan',
      'emoji': '📦',
      'role': 'catalog',
      'enabled': false,
      'status': 'idle',
      'model': 'gemini-1.5-flash',
      'systemPromptVersion': 'v1',

      'autonomyDefaults': {
        'draft_product': 'approval', // Drafts need owner tap to publish
        'update_product': 'approval', // Edits need approval
        'improve_listing': 'approval',
        'set_stock_status': 'advisory', // Can be promoted to 'auto' by owner
        'flag_stockout': 'auto', // Stock alerts run freely
        'create_task': 'advisory',
      },

      'schedule': {
        'cron': '30 20 * * *', // 02:00 AM IST = 20:30 UTC prev day
        'events': ['order_created'],
      },

      'kpis': {
        'tasksDone': 0,
        'approvalRate': 0.0,
        'impactScore': 0.0,
        'draftsApprovedPct': 0.0,
        'listingCompletenessDelta': 0.0,
      },

      'currentTaskId': null,
      'lastRunAt': null,
      'nextRunAt': null,
    },

    // ── Agent 5 — Marketing & Comms ─────────────────────────────────────────
    {
      'id': 'comms_agent',
      'name': 'Marketing & Comms',
      'title': 'Prachar Sanchalan',
      'emoji': '📣',
      'role': 'comms',
      'enabled': false,
      'status': 'idle',
      'model': 'gemini-1.5-flash',
      'systemPromptVersion': 'v1',

      'autonomyDefaults': {
        'draft_broadcast': 'auto', // Drafts created freely
        'send_broadcast': 'approval', // Sends ALWAYS need approval
        'schedule_broadcast': 'approval',
        'create_campaign': 'approval',
      },

      'schedule': {
        'cron': null, // On-demand + festival calendar crons
        'events': ['owner_request', 'analyst_handoff', 'festival_calendar'],
      },

      'kpis': {
        'tasksDone': 0,
        'approvalRate': 0.0,
        'impactScore': 0.0,
        'broadcastDeliveryRate': 0.0,
        'broadcastCtr': 0.0,
        'optOutRate': 0.0,
      },

      'currentTaskId': null,
      'lastRunAt': null,
      'nextRunAt': null,
    },
  ];
}
