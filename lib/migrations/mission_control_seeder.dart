import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Seeder to initialize Mission Control (AI Agentic Employee System)
///
/// This script populates:
/// 1. agents collection with initial roster
/// 2. agent_config/global with default safety caps
/// 3. initial welcome tasks from Chief of Staff
class MissionControlSeeder {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> seedRoster() async {
    try {
      debugPrint('[MissionControlSeeder] Seeding initial AI Agent roster...');

      final Map<String, Map<String, dynamic>> roster = {
        'chief_of_staff': {
          'name': 'Fufaji Chief of Staff',
          'title': 'Mission Control Orchestrator',
          'emoji': '🎖️',
          'role': 'Routes work, sets priorities, briefs the owner. Orchestrates all other agents.',
          'enabled': true,
          'status': 'idle',
          'autonomyDefaults': {
            'prioritize_tasks': 'auto',
            'compose_owner_brief': 'auto',
            'route_to_agent': 'auto',
            'request_owner_attention': 'auto',
          },
          'kpis': {'tasksDone': 0, 'approvalRate': 1.0, 'impactScore': 0.95},
          'model': 'gemini-1.5-pro', // Smarter model for orchestration
          'schedule': {
            'cron': '0 7 * * *', // Every morning at 7:00 AM
            'events': ['agent_run_complete', 'task_created'],
          },
        },
        'business_analyst': {
          'name': 'Fufaji Analyst',
          'title': 'Strategy & Performance Analyst',
          'emoji': '📈',
          'role':
              'Analyzes sales, revenue, and order trends. Generates reports and narrative insights.',
          'enabled': true,
          'status': 'idle',
          'autonomyDefaults': {
            'generate_report': 'auto',
            'flag_anomaly': 'auto',
            'create_task': 'advisory',
          },
          'kpis': {'tasksDone': 0, 'approvalRate': 0, 'impactScore': 0},
          'model': 'gemini-1.5-flash',
          'schedule': {
            'cron': '30 6 * * *', // Daily 6:30 AM (before the brief)
            'events': ['order_created'],
          },
        },
        'inventory_catalog': {
          'name': 'Fufaji Merchant',
          'title': 'Catalog & Inventory Manager',
          'emoji': '📦',
          'role': 'Manages catalog health, stock alerts, and drafts new product listings.',
          'enabled': true,
          'status': 'idle',
          'autonomyDefaults': {
            'draft_product': 'approval',
            'update_product': 'approval',
            'flag_stockout': 'auto',
            'improve_listing': 'approval',
          },
          'kpis': {'tasksDone': 0, 'approvalRate': 0, 'impactScore': 0},
          'model': 'gemini-1.5-flash',
          'schedule': {
            'cron': '0 2 * * *', // Nightly at 2:00 AM
            'events': ['order_created', 'product_updated'],
          },
        },
        'marketing_comms': {
          'name': 'Fufaji Comms',
          'title': 'Marketing & Communication Officer',
          'emoji': '📣',
          'role':
              'Drafts notifications, plans broadcasts, and handles Hinglish customer communications.',
          'enabled': true,
          'status': 'idle',
          'autonomyDefaults': {
            'draft_broadcast': 'auto',
            'send_broadcast': 'approval',
            'schedule_broadcast': 'approval',
          },
          'kpis': {'tasksDone': 0, 'approvalRate': 0, 'impactScore': 0},
          'model': 'gemini-1.5-flash',
          'schedule': {
            'cron': '0 10 * * *', // 10:00 AM daily check
            'events': [],
          },
        },
        'pricing_expert': {
          'name': 'Fufaji Pricing',
          'title': 'Pricing & Promotions Manager',
          'emoji': '💰',
          'role':
              'Suggests dynamic prices, coupons, and festival bundles based on margin and velocity.',
          'enabled': true,
          'status': 'idle',
          'autonomyDefaults': {
            'suggest_price': 'advisory',
            'apply_price': 'approval',
            'create_coupon': 'approval',
          },
          'kpis': {'tasksDone': 0, 'approvalRate': 0, 'impactScore': 0},
          'model': 'gemini-1.5-flash',
          'schedule': {
            'cron': '0 9 * * *', // 9 AM daily
            'events': ['product_updated'],
          },
        },
        'customer_analyst': {
          'name': 'Fufaji Insights',
          'title': 'Customer Lifecycle Analyst',
          'emoji': '👥',
          'role': 'Segments users, monitors churn risk, and suggests loyalty/win-back strategies.',
          'enabled': true,
          'status': 'idle',
          'autonomyDefaults': {'build_segment': 'auto', 'create_task': 'advisory'},
          'kpis': {'tasksDone': 0, 'approvalRate': 0, 'impactScore': 0},
          'model': 'gemini-1.5-flash',
          'schedule': {
            'cron': '0 11 * * 1', // 11 AM every Monday
            'events': ['user_migrated'],
          },
        },
        'ops_manager': {
          'name': 'Fufaji Ops',
          'title': 'Operations & Delivery Manager',
          'emoji': '⚙️',
          'role':
              'Monitors order flow health, delivery SLAs, and drafts refund proposals for issues.',
          'enabled': true,
          'status': 'idle',
          'autonomyDefaults': {'flag_anomaly': 'auto', 'draft_refund': 'approval'},
          'kpis': {'tasksDone': 0, 'approvalRate': 0, 'impactScore': 0},
          'model': 'gemini-1.5-flash',
          'schedule': {
            'cron': '*/30 * * * *', // Every 30 minutes
            'events': ['order_created', 'delivery_delayed'],
          },
        },
      };

      final batch = _db.batch();

      for (var entry in roster.entries) {
        final docRef = _db.collection('agents').doc(entry.key);
        batch.set(docRef, {
          ...entry.value,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Seed Global Config
      final configRef = _db.collection('agent_config').doc('global');
      batch.set(configRef, {
        'masterEnabled': true,
        'dailyBudgetUsd': 5.0,
        'freqCaps': {'maxPromotionalPushPerUserPerDay': 1, 'maxTotalPushPerUserPerDay': 3},
        'quietHours': {'start': '22:00', 'end': '07:00'},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      debugPrint('[MissionControlSeeder] AI Agent roster seeded successfully.');
    } catch (e) {
      debugPrint('[MissionControlSeeder] FAILED to seed roster: $e');
      rethrow;
    }
  }

  static Future<void> seedInitialTasks() async {
    try {
      debugPrint('[MissionControlSeeder] Seeding initial welcome tasks...');

      final welcomeTask = {
        'agentId': 'chief_of_staff',
        'title': 'Welcome to Fufaji Mission Control',
        'description':
            'Your AI workforce is now active. The Chief of Staff, Business Analyst, Inventory Manager, and Comms Officer are standing by for orders.',
        'type': 'system_update',
        'autonomy': 'advisory',
        'status': 'proposed',
        'priority': 100,
        'confidence': 1.0,
        'reasoning': 'Initial system activation briefing.',
        'evidence': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('agent_tasks').add(welcomeTask);
      debugPrint('[MissionControlSeeder] Initial welcome tasks seeded.');
    } catch (e) {
      debugPrint('[MissionControlSeeder] FAILED to seed initial tasks: $e');
    }
  }
}
