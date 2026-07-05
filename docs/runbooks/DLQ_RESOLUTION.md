# Dead Letter Queue (DLQ) Resolution Runbook

The DLQ (`dlq_messages` table) catches events that have exhausted their retry limit (usually 7 retries over 72+ hours) in the async sync system. Messages here require manual intervention.

## 1. Monitor the DLQ

Check the health of the DLQ by querying the health view from Supabase Studio or SQL Editor:
```sql
SELECT * FROM vw_dlq_health;
```
If you see rows with status `CRITICAL (Recent)`, you must investigate.

## 2. Investigate the Root Cause

Query the raw messages to see the exact payload and error:
```sql
SELECT id, event_type, payload, error_message, created_at
FROM dlq_messages
WHERE resolved_at IS NULL
ORDER BY created_at DESC;
```

**Common Causes:**
1. **Missing Related Record:** A transaction synced before the user/wallet record was created downstream.
2. **Malformed Payload:** A bug in the Edge Function caused it to reject the sync payload.
3. **Third-Party Outage:** A downstream system (e.g., Firebase) was down for 72+ hours.

## 3. Resolving Messages

Once you identify and fix the underlying issue (e.g., manually inserting the missing record, or fixing the webhook bug), you can resolve the DLQ messages.

### Option A: Replay the Message
If the downstream system is healthy again, you can push the message back into the standard `outbox_events` queue to be retried automatically.

```sql
-- Step 1: Re-insert into outbox_events
INSERT INTO outbox_events (event_type, payload, status, retry_count)
SELECT event_type, payload, 'pending', 0
FROM dlq_messages
WHERE id = 'YOUR_DLQ_MESSAGE_ID';

-- Step 2: Mark DLQ message as resolved
UPDATE dlq_messages 
SET resolved_at = NOW(), resolution_notes = 'Replayed to outbox'
WHERE id = 'YOUR_DLQ_MESSAGE_ID';
```

### Option B: Discard / Manually Handled
If you manually made the changes in the target database (e.g., manually updated Firestore), you don't need to replay the event. Just mark it resolved.

```sql
UPDATE dlq_messages 
SET resolved_at = NOW(), resolution_notes = 'Manually synced to Firestore'
WHERE id = 'YOUR_DLQ_MESSAGE_ID';
```

### Option C: Bulk Replay (Use with Caution)
To bulk replay all messages of a specific error type:
```sql
WITH moved AS (
    INSERT INTO outbox_events (event_type, payload, status, retry_count)
    SELECT event_type, payload, 'pending', 0
    FROM dlq_messages
    WHERE resolved_at IS NULL AND error_message LIKE '%Firestore timeout%'
    RETURNING dlq_messages.id -- Note: Postgres might not allow RETURNING original ID in this context easily, so standard updates are better.
)
-- Instead, do it in a transaction
BEGIN;
    INSERT INTO outbox_events (event_type, payload, status, retry_count)
    SELECT event_type, payload, 'pending', 0
    FROM dlq_messages
    WHERE resolved_at IS NULL AND error_message LIKE '%Firestore timeout%';
    
    UPDATE dlq_messages 
    SET resolved_at = NOW(), resolution_notes = 'Bulk replayed'
    WHERE resolved_at IS NULL AND error_message LIKE '%Firestore timeout%';
COMMIT;
```
