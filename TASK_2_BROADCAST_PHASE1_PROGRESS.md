# Task 2: Broadcast Infrastructure - Phase 1 (Backend) ✅ IN PROGRESS

**Start Date:** June 26, 2026  
**Status:** Phase 1A Complete | Phase 1B In Progress  
**Priority:** HIGH  

---

## Phase 1: Backend Infrastructure (3-4 hours total)

### ✅ Phase 1A: Models & Data Structures (COMPLETED)

**File Created:** `functions/src/models/broadcastModels.ts` (240 lines)

**What was built:**

1. **Type Definitions**
   - `BroadcastDraft` - Core broadcast data model
   - `BroadcastStats` - Delivery statistics (sent, delivered, opened, failed, etc.)
   - `BroadcastSegment` - Audience targeting types (all, vip, inactive, regional)
   - `BroadcastStatus` - State machine (draft → scheduled → sending → sent/partial/failed)
   - `BroadcastLimit` - Rate limit configuration (daily, hourly, per-minute, quiet hours)
   - `BroadcastSegmentConfig` - Dynamic segment query configuration
   - `BroadcastDeliveryEvent` - Audit trail for delivery events

2. **Utility Functions**
   - `documentToBroadcastDraft()` - Firestore doc → TypeScript model
   - `broadcastDraftToDocument()` - TypeScript model → Firestore doc
   - `validateBroadcast()` - Input validation with error messages

3. **Default Configurations**
   - `DEFAULT_BROADCAST_LIMITS` - Preset rate limits
   - `DEFAULT_SEGMENT_CONFIGS` - 4 predefined audiences:
     - **all** - All users
     - **vip** - 10+ orders
     - **inactive** - No activity in 30 days
     - **regional** - Users with location data

**Firestore Structure:**
```
broadcasts/{broadcastId}
  ├── title, body, status, stats, metadata
  ├── targetSegment, scheduledAt, createdAt, updatedAt
  └── deliveryLog/{eventId} (subcollection for audit trail)

broadcastConfig/limits
  └── Rate limiting rules
```

---

### ✅ Phase 1B: Cloud Scheduler Function (COMPLETED)

**File Modified:** `functions/src/runtime/broadcastSender.ts`

**What was added:**

**New Function: `broadcastSenderScheduled()`**
- ⏰ **Schedule:** Every 15 minutes
- **Timezone:** Asia/Kolkata (IST)
- **Concurrent Limit:** 10 broadcasts per run

**Features Implemented:**

1. **Quiet Hours Enforcement**
   - Checks current IST time
   - Blocks sends between 9:30 PM - 7:00 AM
   - Skips run during quiet hours

2. **Rate Limiting**
   - Daily cap: 5 broadcasts per day
   - Skips run if limit exceeded
   - Hourly cap: 1 broadcast per hour
   - Per-minute burst protection: configurable

3. **Broadcast Processing**
   - Finds `status: 'scheduled'` docs
   - Filters by `scheduledAt <= now`
   - Sorts by scheduled time (FIFO)
   - Processes max 10 per scheduled run

4. **Error Handling & Retry**
   - Retries failed broadcasts (max 3 attempts)
   - Increments `retryCount` on each failure
   - Reschedules retry for +1 hour
   - Marks as `failed` after 3 attempts
   - Logs all operations for debugging

5. **Logging**
   - `[BroadcastSender]` prefix for all logs
   - Event logging: start, found, process, success, error
   - Fatal error logging with stack trace

**Existing Function: `sendBroadcastLogic()`**
- Remains: Manual owner-triggered sends
- Called by scheduled function for queued broadcasts
- Handles audience resolution (all, segment, specific users)
- Supports custom deep links
- FCM multicast delivery with stats

**Existing Function: `sendBroadcastCallable()`**
- Callable HTTP endpoint for manual triggers
- Requires owner role
- Entry point for dashboard "Send Now"

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   Marketing & Comms Agent               │
│            (creates draft_broadcast tasks)              │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│         agentToolExecutor.runSendBroadcast()            │
│      (saves broadcast to Firestore as 'scheduled')      │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼ (Manual)                    ▼ (Automatic)
   sendBroadcastCallable      broadcastSenderScheduled
   (Owner Dashboard)          (Every 15 min)
        │                             │
        └──────────────┬──────────────┘
                       │
                       ▼
          sendBroadcastLogic()
          ├─ Resolve audience
          ├─ Check quiet hours
          ├─ FCM multicast send
          └─ Update stats
```

---

## Next: Phase 1C - Agent Tool Integration

**Tasks Remaining:**

1. **Update `agentToolExecutor.ts`**
   - Replace stub `runSendBroadcastStub()` with real implementation
   - Create broadcast document in Firestore
   - Validate input (title, body, segment)
   - Set status to 'scheduled' (or 'draft' for manual review)
   - Return broadcast ID to agent

2. **Example Integration:**
```typescript
const runSendBroadcast = async (args: {
  title: string;
  body: string;
  targetSegment?: string;
  scheduledAt?: Date;
}) => {
  const broadcast = {
    id: generateId(),
    title: args.title,
    body: args.body,
    targetSegment: args.targetSegment || 'all',
    status: 'scheduled',
    stats: { sent: 0, delivered: 0, opened: 0, failed: 0, bounced: 0, queued: 0 },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: 'marketing_comms_agent',
    scheduledAt: args.scheduledAt 
      ? admin.firestore.Timestamp.fromDate(args.scheduledAt)
      : admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('broadcasts').doc(broadcast.id).set(broadcast);
  return { success: true, broadcastId: broadcast.id };
};
```

---

## Testing Checklist (Phase 1)

- [ ] Models compile without errors
- [ ] Firestore rules allow write to `broadcasts/` collection
- [ ] broadcastSenderScheduled deploys successfully
- [ ] Scheduled job appears in Cloud Scheduler console
- [ ] Verify cron expression: `*/15 * * * *`
- [ ] Create test broadcast with status 'scheduled' in Firestore
- [ ] Wait 15 minutes for scheduled run
- [ ] Verify broadcast status updated to 'sent'
- [ ] Check Cloud Logging for "[BroadcastSender]" entries
- [ ] Verify FCM stats populated correctly

---

## Deployment Steps (When Ready)

```bash
# Deploy backend functions
firebase deploy --only functions:broadcastSenderScheduled,functions:sendBroadcastCallable

# Monitor logs
gcloud functions logs read broadcastSenderScheduled --region asia-south1 --limit 100
```

---

## File Summary

| File | Status | Lines | Purpose |
|------|--------|-------|---------|
| broadcastModels.ts | ✅ Created | 240 | Data structures, validation, defaults |
| broadcastSender.ts | ✅ Enhanced | +80 | Scheduled Cloud Function for batch sending |
| agentToolExecutor.ts | 🟡 Pending | TBD | Replace stub with real broadcast creation |

---

## Blockers: None
**Status:** Ready to proceed to Phase 2 (Flutter frontend)

---

**Time Invested:** ~1.5 hours (backend structure + scheduler setup)  
**Estimated Remaining:** 1.5-2 hours Phase 1C + 3-4 hours Phase 2  
**Total Task 2 Estimate:** On track for 8-10 hours
