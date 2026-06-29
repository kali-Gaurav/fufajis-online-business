# Mission Control: AI Agentic Employee System - Task List

**Project:** Fufaji Store - Owner Dashboard (Mission Control)  
**Date Created:** June 2026  
**Status:** In Planning  
**MVP Agents:** Chief of Staff, Business Analyst, Inventory & Catalog, Marketing & Comms

---

## Task 1: Re-align Cron Scheduler Timings ⏰

**Priority:** HIGH  
**Complexity:** Low  
**Estimated Time:** 30 minutes  
**Owner:** Backend Engineer

### Description
The Chief of Staff morning brief currently runs BEFORE the Business Analyst daily report is available, causing the brief to always display a fallback message: *"No report is available yet - the Business Analyst will run soon."*

### Current Timing Issue
```
6:30 AM IST  → Chief of Staff Morning Brief (RUNS FIRST - no data!)
7:30 AM IST  → Business Analyst Daily Shift (data generated AFTER)
```

### Required Fix
```
6:30 AM IST  → Business Analyst Daily Shift (generate data first)
7:30 AM IST  → Chief of Staff Morning Brief (summarize available data)
```

### Acceptance Criteria
- [ ] `businessAnalystDailyShift` cron changed to `30 6 * * *` (6:30 AM IST)
- [ ] `chiefOfStaffMorningBrief` cron changed to `30 7 * * *` (7:30 AM IST)
- [ ] Cloud Scheduler jobs updated in Firebase Console
- [ ] Local `.env` cron schedules match production
- [ ] Test run confirms Analyst executes first, then Chief accesses report data
- [ ] Morning brief no longer displays fallback message for report unavailability

### Files to Modify
- `functions/src/scheduled/businessAnalyst.ts` - Update cron expression
- `functions/src/scheduled/chiefOfStaff.ts` - Update cron expression
- `functions/src/scheduled/scheduledAgentRunner.ts` - Verify execution order
- `.env.example` and production `.env` - Update cron references

### Testing Plan
1. Deploy to Firebase Emulator
2. Manually trigger both shifts in sequence
3. Verify Analyst report writes to `agent_reports/{date}` before Chief reads it
4. Confirm morning brief displays actual summary instead of fallback text

---

## Task 2: Implement Marketing & Comms Agent and Broadcast Infrastructure 📢

**Priority:** HIGH  
**Complexity:** Very High  
**Estimated Time:** 8-10 hours  
**Owner:** Senior Backend + Frontend Engineer (pair programming recommended)

### Description
Implement the complete broadcast infrastructure including:
1. Marketing & Comms agent for drafting broadcasts
2. Backend Cloud Function (`broadcastSender`) for FCM fan-out with caps and quiet hours
3. Flutter UI components for the Broadcasts tab in Owner Dashboard
4. Frontend broadcast models and provider

### Part A: Backend - Broadcast Infrastructure

#### A1. Create Broadcast Data Models
**File:** `functions/src/models/broadcastModels.ts`
```typescript
interface BroadcastDraft {
  id: string;
  title: string;
  body: string;
  targetSegment: 'all' | 'vip' | 'inactive' | 'regional' | string;
  scheduledAt?: Date;
  createdBy: string;
  createdAt: Date;
  status: 'draft' | 'scheduled' | 'sent' | 'failed';
  stats: {
    sent: number;
    delivered: number;
    opened: number;
    failed: number;
  };
}

interface BroadcastLimit {
  maxPerDay: number;
  maxPerHour: number;
  quietHours: { start: number; end: number }; // 24-hour format
  maxSegmentSize: number;
}
```

#### A2. Create broadcastSender Cloud Function
**File:** `functions/src/scheduled/broadcastSender.ts`
```typescript
export const broadcastSender = functions.pubsub
  .schedule('*/15 * * * *') // Every 15 minutes
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    // 1. Fetch all scheduled broadcasts ready to send
    // 2. Check rate limits (per-day, per-hour, quiet hours)
    // 3. For each broadcast:
    //    a. Query target segment from Firestore
    //    b. Batch users into chunks (1000 per batch)
    //    c. Send FCM messages via admin.messaging().sendMulticast()
    //    d. Log delivery stats back to broadcast doc
    // 4. Update broadcast status to 'sent' or 'partial'
  });
```

**Enforcement:**
- Respect `BroadcastLimit` caps (daily max 5, hourly max 1, etc.)
- Enforce quiet hours (e.g., 9 PM - 7 AM no sends)
- Batch segment queries to avoid memory overload
- Retry failed sends with exponential backoff (3 retries max)
- Log all failures to Cloud Logging

#### A3. Update agentToolExecutor for draft_broadcast
**File:** `functions/src/agents/agentToolExecutor.ts`

Replace the stub:
```typescript
// BEFORE:
const runSendBroadcastStub = async (args: any) => {
  console.log('Stub: sendBroadcast', args);
  return { success: true };
};

// AFTER:
const runSendBroadcast = async (args: any) => {
  const draft: BroadcastDraft = {
    id: generateId(),
    title: args.title,
    body: args.body,
    targetSegment: args.targetSegment || 'all',
    scheduledAt: args.scheduledAt ? new Date(args.scheduledAt) : new Date(),
    createdBy: 'marketing_comms_agent',
    createdAt: new Date(),
    status: 'scheduled',
    stats: { sent: 0, delivered: 0, opened: 0, failed: 0 },
  };

  await admin.firestore()
    .collection('broadcasts')
    .doc(draft.id)
    .set(draft);

  return { success: true, broadcastId: draft.id };
};
```

### Part B: Frontend - Flutter UI and Models

#### B1. Create Broadcast Models
**File:** `lib/models/broadcast_model.dart`
```dart
enum BroadcastStatus { draft, scheduled, sent, failed }
enum BroadcastSegment { all, vip, inactive, regional }

class BroadcastDraft {
  final String id;
  final String title;
  final String body;
  final BroadcastSegment targetSegment;
  final DateTime? scheduledAt;
  final String createdBy;
  final DateTime createdAt;
  final BroadcastStatus status;
  final BroadcastStats stats;

  BroadcastDraft({
    required this.id,
    required this.title,
    required this.body,
    required this.targetSegment,
    this.scheduledAt,
    required this.createdBy,
    required this.createdAt,
    required this.status,
    required this.stats,
  });

  factory BroadcastDraft.fromMap(Map<String, dynamic> data) { /* ... */ }
  Map<String, dynamic> toMap() { /* ... */ }
}

class BroadcastStats {
  final int sent;
  final int delivered;
  final int opened;
  final int failed;

  BroadcastStats({
    this.sent = 0,
    this.delivered = 0,
    this.opened = 0,
    this.failed = 0,
  });
}
```

#### B2. Create BroadcastProvider
**File:** `lib/providers/broadcast_provider.dart`
```dart
class BroadcastProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<BroadcastDraft> _broadcasts = [];
  List<BroadcastDraft> get broadcasts => _broadcasts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadBroadcasts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final snap = await _firestore
        .collection('broadcasts')
        .orderBy('createdAt', descending: true)
        .get();
      
      _broadcasts = snap.docs
        .map((d) => BroadcastDraft.fromMap(d.data()))
        .toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> draftBroadcast(
    String title,
    String body,
    BroadcastSegment segment, {
    DateTime? scheduledAt,
  }) async {
    try {
      final broadcast = BroadcastDraft(
        id: generateId(),
        title: title,
        body: body,
        targetSegment: segment,
        scheduledAt: scheduledAt,
        createdBy: 'owner',
        createdAt: DateTime.now(),
        status: BroadcastStatus.draft,
        stats: BroadcastStats(),
      );

      await _firestore
        .collection('broadcasts')
        .doc(broadcast.id)
        .set(broadcast.toMap());

      _broadcasts.insert(0, broadcast);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> scheduleBroadcast(String broadcastId, DateTime scheduledAt) async {
    try {
      await _firestore
        .collection('broadcasts')
        .doc(broadcastId)
        .update({
          'scheduledAt': scheduledAt,
          'status': BroadcastStatus.scheduled.name,
        });

      final index = _broadcasts.indexWhere((b) => b.id == broadcastId);
      if (index >= 0) {
        _broadcasts[index] = _broadcasts[index]
          .copyWith(scheduledAt: scheduledAt, status: BroadcastStatus.scheduled);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBroadcast(String broadcastId) async {
    try {
      await _firestore.collection('broadcasts').doc(broadcastId).delete();
      _broadcasts.removeWhere((b) => b.id == broadcastId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
```

#### B3. Create Broadcasts Tab UI
**File:** `lib/screens/owner/mission_control/broadcasts_tab.dart`

Replace the placeholder with:
```dart
class BroadcastsTab extends StatefulWidget {
  const BroadcastsTab({Key? key}) : super(key: key);

  @override
  State<BroadcastsTab> createState() => _BroadcastsTabState();
}

class _BroadcastsTabState extends State<BroadcastsTab> {
  @override
  void initState() {
    super.initState();
    context.read<BroadcastProvider>().loadBroadcasts();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BroadcastProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.broadcasts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('No broadcasts yet'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showBroadcastDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Draft Broadcast'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: provider.broadcasts.length,
          itemBuilder: (context, index) {
            final broadcast = provider.broadcasts[index];
            return _BroadcastCard(broadcast: broadcast);
          },
        );
      },
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _BroadcastDialog(
        onSave: (title, body, segment, scheduledAt) {
          context.read<BroadcastProvider>().draftBroadcast(
            title,
            body,
            segment,
            scheduledAt: scheduledAt,
          );
        },
      ),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  final BroadcastDraft broadcast;

  const _BroadcastCard({required this.broadcast});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(broadcast.title),
        subtitle: Text(broadcast.body, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(child: Text('Edit')),
            const PopupMenuItem(child: Text('Schedule')),
            const PopupMenuItem(child: Text('Delete')),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _BroadcastDialog extends StatefulWidget {
  final Function(String, String, BroadcastSegment, DateTime?) onSave;

  const _BroadcastDialog({required this.onSave});

  @override
  State<_BroadcastDialog> createState() => _BroadcastDialogState();
}

class _BroadcastDialogState extends State<_BroadcastDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  BroadcastSegment _selectedSegment = BroadcastSegment.all;
  DateTime? _scheduledAt;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draft Broadcast'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            DropdownButton<BroadcastSegment>(
              value: _selectedSegment,
              items: BroadcastSegment.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
              onChanged: (s) => setState(() => _selectedSegment = s!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(
              _titleController.text,
              _bodyController.text,
              _selectedSegment,
              _scheduledAt,
            );
            Navigator.pop(context);
          },
          child: const Text('Draft'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }
}
```

### Acceptance Criteria
- [ ] `BroadcastDraft` and `BroadcastStats` models created
- [ ] `broadcastSender` Cloud Function deployed and tested
- [ ] Rate limits enforced (daily, hourly, quiet hours)
- [ ] FCM batching tested with 1000+ users
- [ ] `BroadcastProvider` fully implements CRUD operations
- [ ] Broadcasts tab replaced with functional UI (no more placeholder)
- [ ] Draft dialog allows title, body, segment, optional scheduling
- [ ] Broadcast list displays all with status badges
- [ ] Edit, schedule, delete operations functional
- [ ] Error messages display clearly to user
- [ ] Backend logs all broadcast sends and failures

### Testing Plan
1. Deploy `broadcastSender` to Cloud Scheduler
2. Manually create a test broadcast via Firestore console
3. Verify FCM messages sent to test device within 15 minutes
4. Test rate limit caps (send 5 broadcasts, verify 6th is queued)
5. Test quiet hours (schedule send at 10 PM, verify queued until 7 AM)
6. Run Flutter app, navigate to Broadcasts tab, draft and schedule a broadcast
7. Verify broadcast appears in Firestore with `scheduled` status
8. Monitor Cloud Logging for send success/failure logs

---

## Task 3: Implement Inventory & Catalog Agent Shifts 📦

**Priority:** MEDIUM  
**Complexity:** High  
**Estimated Time:** 6-8 hours  
**Owner:** Senior Backend Engineer

### Description
Create the Inventory & Catalog agent shift logic that runs every 4 hours to monitor stock levels, generate alerts for low inventory, and provide catalog recommendations.

### Files to Create

#### `functions/src/agents/inventoryCatalog.ts`
```typescript
export const inventoryCatalogShift = async () => {
  // 1. Scan all products in inventory collection
  // 2. Identify low-stock items (< reorder point)
  // 3. Generate alerts for inventory manager
  // 4. Analyze product performance (sold quantity, velocity)
  // 5. Recommend restocking quantities based on demand forecast
  // 6. Check for dead stock (0 sales in 30 days)
  // 7. Suggest product discontinuation or repositioning
  // 8. Write report to agent_reports/{date}_inventory
};
```

### Key Features
- **Low Stock Detection:** Flag items below reorder point
- **Demand Forecasting:** Use sales velocity to predict future needs
- **Dead Stock Analysis:** Identify slow-moving products
- **Reorder Suggestions:** Calculate optimal order quantities
- **Catalog Health:** Monitor product performance metrics
- **Alert Generation:** Create task items for inventory manager

### Prompts & Decision Logic
1. **Perceivers:**
   - Current inventory levels and reorder points
   - Sales data (past 30, 60, 90 days)
   - Supplier lead times
   - Storage capacity constraints

2. **Decision Loop:**
   - Classify products: healthy, at-risk, critical
   - Calculate reorder quantities (EOQ formula)
   - Rank restocking recommendations by urgency
   - Flag dead stock for potential removal

3. **Output:**
   - Structured report with actionable recommendations
   - Tasks for inventory manager
   - Dashboard metrics (stock health %)

### Acceptance Criteria
- [ ] `inventoryCatalog.ts` created with full shift logic
- [ ] Integrated into `scheduledAgentRunner.ts` to run every 4 hours
- [ ] Low-stock detection working with configurable thresholds
- [ ] Demand forecasting algorithm implemented and tested
- [ ] Reports generated and stored in `agent_reports` collection
- [ ] Tasks created for inventory manager with high-confidence alerts
- [ ] Firebase Firestore indexes created for performance (inventory collection queries)
- [ ] Tested with sample product data (100+ items)

### Testing Plan
1. Deploy to Firebase Emulator
2. Seed test data: 50 products with varying stock levels
3. Manually trigger shift and verify report generation
4. Check task creation for low-stock items
5. Verify forecasting accuracy against historical data
6. Test edge cases (out-of-stock, overstocked, new products)

---

## Task 4: Complete Roster Settings & Autonomy Configuration UI ⚙️

**Priority:** MEDIUM  
**Complexity:** Medium  
**Estimated Time:** 4-6 hours  
**Owner:** Senior Flutter Engineer

### Description
Build settings cards in the Owner Dashboard to allow toggling agent activation and editing autonomy defaults (decision caps, budget limits, quiet hours).

### Features

#### A. Agent Toggle Cards
**File:** `lib/screens/owner/mission_control/roster_settings_tab.dart`

Display 4 cards (one per agent):
- Chief of Staff
- Business Analyst
- Inventory & Catalog
- Marketing & Comms

Each card shows:
- Agent name & icon
- Status toggle (enabled/disabled)
- Current autonomy tier (auto, semi-auto, manual)
- Last shift run time
- Next scheduled shift

#### B. Autonomy Configuration Modal
**File:** `lib/screens/owner/mission_control/autonomy_config_modal.dart`

Allow editing per-agent settings:
```dart
class AgentAutonomyConfig {
  String agentId;
  bool enabled;
  String autonomyTier; // 'auto', 'semi-auto', 'manual'
  int dailyTaskBudget;
  int hourlyTaskBudget;
  QuietHours quietHours;
  List<String> capabilityOverrides;
}

class QuietHours {
  int startHour; // 0-23
  int endHour;
  List<int> quietDays; // 0=Mon, 6=Sun
}
```

#### C. Global Settings
Allow owner to set app-wide defaults:
- Global daily broadcast cap (default 5)
- Global hourly cap (default 1)
- System-wide quiet hours
- Max agents running simultaneously

### UI Components

#### Settings Tab
```dart
class RosterSettingsTab extends StatefulWidget {
  @override
  State<RosterSettingsTab> createState() => _RosterSettingsTabState();
}

// Displays:
// - Agent Cards (4x)
// - Global Settings Expandable
// - Save/Reset buttons
```

#### Agent Card
```dart
class AgentCard extends StatelessWidget {
  final Agent agent;
  final VoidCallback onTap;
  
  // Shows toggle, autonomy tier, last/next run, edit button
}
```

### Backend Data Model
**File:** `functions/src/models/agentConfig.ts`
```typescript
interface AgentConfig {
  agentId: string;
  enabled: boolean;
  autonomyTier: 'auto' | 'semi-auto' | 'manual';
  dailyTaskBudget: number;
  hourlyTaskBudget: number;
  quietHours: {
    startHour: number;
    endHour: number;
    quietDays: number[];
  };
  capabilityOverrides: string[];
  updatedAt: Date;
  updatedBy: string;
}

interface GlobalAutonomySettings {
  maxConcurrentAgents: number;
  broadcastDailyLimit: number;
  broadcastHourlyLimit: number;
  systemQuietHours: QuietHours;
}
```

### Firestore Collection Structure
```
agentConfigs/{agentId} → AgentConfig
globalSettings/autonomy → GlobalAutonomySettings
```

### Acceptance Criteria
- [ ] Roster Settings tab created and integrated into Mission Control dashboard
- [ ] All 4 agent cards display with toggle, status, and edit button
- [ ] Agent toggle connects to backend and persists to Firestore
- [ ] Autonomy config modal allows editing all fields (tier, budgets, quiet hours)
- [ ] Changes saved to `agentConfigs/{agentId}` collection
- [ ] Global settings expandable section with system-wide caps
- [ ] Owner can reset settings to defaults
- [ ] Changes take effect on next agent shift (no restart required)
- [ ] UI shows last/next run times for each agent
- [ ] Validation prevents invalid hour ranges (e.g., 25:00)
- [ ] Success toast on save, error toast on failure

### Testing Plan
1. Navigate to Mission Control → Settings tab
2. Toggle each agent on/off, verify Firestore updates
3. Click "Configure" on an agent, modify autonomy tier and budgets
4. Set quiet hours (e.g., 10 PM - 7 AM)
5. Save and verify data persisted
6. Reload dashboard, confirm settings persisted
7. Test global settings (broadcast caps)
8. Verify next agent shift respects new autonomy limits

---

## Summary Table

| Task | Priority | Complexity | Time | Owner | Status |
|------|----------|-----------|------|-------|--------|
| 1. Scheduler Timing | HIGH | Low | 30m | Backend | 🟡 Pending |
| 2. Broadcasts | HIGH | Very High | 8-10h | Backend + Frontend | 🟡 Pending |
| 3. Inventory Agent | MEDIUM | High | 6-8h | Backend | 🟡 Pending |
| 4. Autonomy UI | MEDIUM | Medium | 4-6h | Frontend | 🟡 Pending |

**Total Estimated Effort:** 19-25 hours  
**Recommended Sequence:** 1 → 2 → 3 → 4 (dependencies decrease over time)

---

## Definition of Done (Per Task)

- [ ] Code written and locally tested
- [ ] Firebase Emulator tests pass
- [ ] No console errors or warnings
- [ ] Code reviewed by peer
- [ ] Merged to main branch
- [ ] Deployed to staging
- [ ] Tested in staging environment
- [ ] Documented in `/docs/MISSION_CONTROL_IMPLEMENTATION.md`
- [ ] Deployment notes added to release notes

---

**Next Step:** Approve task list and assign owners. Begin with Task 1 (highest ROI).
