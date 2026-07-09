-- ============================================================================
-- SYSTEM HEALTH & MONITORING VIEWS
-- ============================================================================
-- Purpose: Operational dashboards for DLQ, Sync Tasks, and Wallet Integrity
-- ============================================================================

-- 1. DLQ HEALTH VIEW
-- Summarizes failures in the dead letter queue by error type and recency
CREATE OR REPLACE VIEW vw_dlq_health AS
SELECT 
    error_message,
    COUNT(*) as total_failures,
    MIN(created_at) as oldest_failure,
    MAX(created_at) as newest_failure,
    CASE 
        WHEN MAX(created_at) > NOW() - INTERVAL '1 hour' THEN 'CRITICAL (Recent)'
        WHEN MAX(created_at) > NOW() - INTERVAL '24 hours' THEN 'WARNING (Active)'
        ELSE 'STALE'
    END as status_severity
FROM dlq_messages
WHERE resolved_at IS NULL
GROUP BY error_message
ORDER BY total_failures DESC;

-- 2. SYNC QUEUE HEALTH VIEW
-- Monitors the size of the sync outbox
CREATE OR REPLACE VIEW vw_sync_queue_health AS
SELECT
    status,
    COUNT(*) as task_count,
    MAX(retry_count) as max_retries_attempted
FROM outbox_events
GROUP BY status;

-- 3. WALLET LEDGER DRIFT VIEW
-- Ensures that the sum of all transactions equals the current wallet balance
CREATE OR REPLACE VIEW vw_wallet_reconciliation AS
SELECT 
    b.user_id,
    b.id as wallet_id,
    b.balance as current_balance,
    COALESCE(SUM(
        CASE 
            WHEN t.direction = 'in' THEN t.amount
            WHEN t.direction = 'out' THEN -t.amount
            ELSE 0 
        END
    ), 0) as computed_balance_from_ledger,
    b.balance - COALESCE(SUM(
        CASE 
            WHEN t.direction = 'in' THEN t.amount
            WHEN t.direction = 'out' THEN -t.amount
            ELSE 0 
        END
    ), 0) as drift_amount
FROM wallet_balance b
LEFT JOIN wallet_transactions t ON b.id = t.wallet_id
GROUP BY b.user_id, b.id, b.balance
HAVING b.balance != COALESCE(SUM(
        CASE 
            WHEN t.direction = 'in' THEN t.amount
            WHEN t.direction = 'out' THEN -t.amount
            ELSE 0 
        END
    ), 0);

-- Grant permissions for admin monitoring
GRANT SELECT ON vw_dlq_health TO authenticated;
GRANT SELECT ON vw_sync_queue_health TO authenticated;
GRANT SELECT ON vw_wallet_reconciliation TO authenticated;
