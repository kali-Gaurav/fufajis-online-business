# Phase C Monitoring — 4-Layer Observability Strategy

**File:** `/backend/PHASE_C_MONITORING.md`

Monitoring ensures sync system health across infrastructure, workers, sync operations, and business impact.

---

## 4-Layer Monitoring Framework

```
┌─────────────────────────────────────────────────────────┐
│ LAYER 4: Business Impact Metrics                        │
│ (Oversells, Cancellations, SLA Breach Rate)             │
└─────────────────────────────────────────────────────────┘
                            ↑
┌─────────────────────────────────────────────────────────┐
│ LAYER 3: Sync Health Metrics                            │
│ (Drift, Lag, Failed Events, DLQ Backlog)                │
└─────────────────────────────────────────────────────────┘
                            ↑
┌─────────────────────────────────────────────────────────┐
│ LAYER 2: Worker Metrics                                 │
│ (Execution Time, Success Rate, Queue Size)              │
└─────────────────────────────────────────────────────────┘
                            ↑
┌─────────────────────────────────────────────────────────┐
│ LAYER 1: Infrastructure Metrics                         │
│ (Lambda Duration, Memory, Errors, Cold Starts)          │
└─────────────────────────────────────────────────────────┘
```

---

## Layer 1: Infrastructure Monitoring

**What to monitor:** AWS Lambda + API Gateway performance

### Prometheus Queries

```promql
# Lambda invocations per minute
rate(aws_lambda_invocations_total[5m])

# Lambda execution duration (p95)
histogram_quantile(0.95, rate(aws_lambda_duration_seconds_bucket[5m]))

# Lambda errors per minute
rate(aws_lambda_errors_total[5m])

# Cold start ratio
rate(aws_lambda_duration_seconds_bucket{coldstart="true"}[5m]) /
rate(aws_lambda_duration_seconds_bucket[5m])

# API Gateway latency (p99)
histogram_quantile(0.99, rate(aws_apigateway_latency_seconds_bucket[5m]))

# API Gateway errors (4xx, 5xx)
rate(aws_apigateway_http_status{status=~"4|5\\d\\d"}[5m])
```

### CloudWatch Alarms

| Metric | Threshold | Severity | Action |
|--------|-----------|----------|--------|
| Lambda error rate | > 1% | P1 | Page oncall |
| Lambda p95 duration | > 20s | P2 | Investigate memory/CPU |
| Cold start ratio | > 5% | P3 | Scale concurrency |
| API 5xx rate | > 0.1% | P1 | Page oncall |

---

## Layer 2: Worker Metrics

**What to monitor:** Individual sync worker performance

### Prometheus Queries

```promql
# Sync events processed per worker (Class A)
rate(sync_events_completed_total{worker_class="A"}[5m])

# Worker execution latency (p95, by class)
histogram_quantile(0.95,
  rate(sync_worker_duration_seconds_bucket[5m])
) by (worker_class)

# Retry rate (failed → success)
rate(sync_events_retried_total[5m]) /
rate(sync_events_completed_total[5m])

# Worker success rate
rate(sync_events_completed_total[5m]) /
(rate(sync_events_completed_total[5m]) + rate(sync_events_failed_total[5m]))

# Queue backlog by worker class
sync_events_pending_total by (worker_class)

# DLQ pending items
sync_dlq_pending_total

# Reservation expiry rate (per hour)
rate(reservations_expired_total[1h])
```

### Class-Specific SLA Targets

| Class | Latency Target | Success Rate | Queue Backlog | Action on Breach |
|-------|----------------|--------------|---------------|-----------------|
| A (Realtime) | <2s p95 | >99.5% | <100 items | Disable via flag, alert |
| B (Scheduled) | <5min p95 | >99% | <500 items | Scale workers, review logic |
| C (Recovery) | <1h p95 | >90% | <1000 items | Manual review |

### Dashboard: Worker Health

```json
{
  "title": "Sync Worker Health",
  "panels": [
    {
      "title": "Events/Sec by Worker Class",
      "targets": [
        "rate(sync_events_completed_total[5m]) by (worker_class)"
      ],
      "type": "graph"
    },
    {
      "title": "Latency P95 by Worker",
      "targets": [
        "histogram_quantile(0.95, rate(sync_worker_duration_seconds_bucket[5m])) by (worker_name)"
      ],
      "type": "graph"
    },
    {
      "title": "Success Rate % by Class",
      "targets": [
        "100 * (rate(sync_events_completed_total[5m]) / (rate(sync_events_completed_total[5m]) + rate(sync_events_failed_total[5m]))) by (worker_class)"
      ],
      "type": "graph"
    },
    {
      "title": "Queue Backlog",
      "targets": [
        "sync_events_pending_total by (worker_class)",
        "sync_dlq_pending_total"
      ],
      "type": "graph",
      "alert": "If pending > 500, disable worker"
    }
  ]
}
```

---

## Layer 3: Sync Health Metrics

**What to monitor:** Data consistency and event flow health

### Prometheus Queries

```promql
# Sync lag: avg age of pending events (seconds)
avg(sync_events_pending_age_seconds)

# Drift detected: Supabase ≠ Firestore row count
abs(
  (supabase_inventory_count - firestore_inventory_count) /
  supabase_inventory_count
) * 100

# Failed event types
rate(sync_events_failed_total[5m]) by (event_type)

# Events in DLQ by severity
sync_dlq_pending_total by (severity)

# Idempotency: duplicate detection rate
rate(sync_events_duplicate_total[5m]) /
rate(sync_events_received_total[5m])

# Retry attempts distribution
rate(sync_events_retry_total[5m]) by (retry_count)
```

### Critical Checks

```sql
-- Query on v_sync_health view (in database)
SELECT 
    status, 
    COUNT(*) as count,
    AVG(EXTRACT(EPOCH FROM (now() - created_at))) as avg_age_seconds
FROM sync_events
WHERE status IN ('pending', 'failed')
GROUP BY status;

-- Check drift
SELECT 
    COUNT(*) as supabase_count,
    (SELECT COUNT(*) FROM firestore_inventory) as firestore_count,
    ABS(COUNT(*) - (SELECT COUNT(*) FROM firestore_inventory)) as drift_count
FROM supabase_inventory;

-- Check most failed event types
SELECT 
    event_type, 
    COUNT(*) as fail_count,
    MAX(updated_at) as last_failure
FROM sync_events
WHERE status = 'failed'
GROUP BY event_type
ORDER BY fail_count DESC
LIMIT 10;
```

### Dashboard: Sync Health

```json
{
  "title": "Sync System Health",
  "panels": [
    {
      "title": "Pending Events Age (seconds)",
      "targets": [
        "avg(sync_events_pending_age_seconds)",
        "max(sync_events_pending_age_seconds)"
      ],
      "type": "graph",
      "alert": "If max > 300s, page oncall"
    },
    {
      "title": "Drift % (Supabase vs Firestore)",
      "targets": [
        "abs((supabase_inventory_count - firestore_inventory_count) / supabase_inventory_count) * 100"
      ],
      "type": "gauge",
      "alert": "If > 0.5%, critical"
    },
    {
      "title": "Failed Events by Type",
      "targets": [
        "rate(sync_events_failed_total[5m]) by (event_type)"
      ],
      "type": "graph"
    },
    {
      "title": "DLQ Backlog by Severity",
      "targets": [
        "sync_dlq_pending_total by (severity)"
      ],
      "type": "graph",
      "alert": "If critical > 10, page security"
    },
    {
      "title": "Duplicate Detection Rate %",
      "targets": [
        "100 * rate(sync_events_duplicate_total[5m]) / rate(sync_events_received_total[5m])"
      ],
      "type": "gauge"
    }
  ]
}
```

---

## Layer 4: Business Impact Metrics

**What to monitor:** Customer-facing impact of sync failures

### Prometheus Queries

```promql
# Oversells (inventory reserved exceeds available)
sum(inventory_oversells_total)

# Cancelled orders (due to sync failures)
rate(orders_cancelled_due_to_sync_failure[1h])

# SLA breach rate (events exceeding target latency)
rate(sync_events_sla_breach_total[5m]) /
rate(sync_events_completed_total[5m])

# Customer complaints about inventory/order issues
rate(customer_complaints_inventory[1h])
rate(customer_complaints_delivery[1h])

# Revenue impact: lost orders due to sync
sum(orders_failed_due_to_sync_failure[1h]) by (reason)
```

### KPIs (Dashboards & Reports)

| KPI | Target | Calculation | Review Cadence |
|-----|--------|-------------|-----------------|
| **Oversell Rate** | 0% | `SUM(oversells) / SUM(orders)` | Every order |
| **Cancellation Rate** | <0.1% | `SUM(cancelled_due_to_sync) / SUM(total_orders)` | Hourly |
| **SLA Breach Rate** | <0.5% | `SUM(breached) / SUM(total_events)` | 5-minute |
| **Inventory Drift** | <0.5% | `ABS(Supabase - Firestore) / Supabase` | 15-minute |
| **Sync Success Rate** | >99% | `SUM(completed) / (completed + failed)` | Realtime |
| **DLQ Age (Max)** | <30min | `MAX(created_at)` on pending items | Continuous |

### Dashboard: Business Impact

```json
{
  "title": "Business Impact — Sync System",
  "panels": [
    {
      "title": "Oversell Events (24h)",
      "targets": [
        "sum_over_time(inventory_oversells_total[24h])"
      ],
      "type": "stat",
      "alert": "If > 0, critical"
    },
    {
      "title": "Order Cancellations due to Sync (24h)",
      "targets": [
        "sum_over_time(orders_cancelled_due_to_sync_failure[24h])"
      ],
      "type": "stat"
    },
    {
      "title": "Sync SLA Breach %",
      "targets": [
        "100 * rate(sync_events_sla_breach_total[5m]) / rate(sync_events_completed_total[5m])"
      ],
      "type": "gauge",
      "thresholds": [0, 0.5, 1],
      "colors": ["green", "yellow", "red"]
    },
    {
      "title": "Revenue Lost (Hourly)",
      "targets": [
        "sum_over_time(order_revenue_lost_due_to_sync[1h])"
      ],
      "type": "stat"
    }
  ]
}
```

---

## Alerting Strategy

### Escalation Matrix

```
LAYER 1 (Infra) → P3 (investigate)
    ↓
LAYER 2 (Worker) → P2 (pages if SLA breached)
    ↓
LAYER 3 (Sync) → P1 (pages immediately if drift/DLQ)
    ↓
LAYER 4 (Business) → P0 (SEV-1, customer impact)
```

### Alert Rules

```yaml
# Layer 1: Infrastructure
alert: HighLambdaErrorRate
expr: rate(aws_lambda_errors_total[5m]) > 0.01
for: 5m
labels:
  severity: critical
annotations:
  summary: "Lambda error rate > 1%"

# Layer 2: Worker SLA
alert: SyncWorkerSLABreach
expr: |
  histogram_quantile(0.95, rate(sync_worker_duration_seconds_bucket[5m])) > 2
  and on(worker_class) worker_class == "A"
for: 10m
labels:
  severity: warning
annotations:
  summary: "Class A worker latency > 2s"

# Layer 3: Drift Detection
alert: InventoryDriftCritical
expr: |
  abs((supabase_inventory_count - firestore_inventory_count) / supabase_inventory_count) > 0.005
for: 5m
labels:
  severity: critical
annotations:
  summary: "Inventory drift > 0.5%"
  action: "Manually sync or trigger C_RETRY_FAILED"

# Layer 3: DLQ Buildup
alert: DLQBuildup
expr: sync_dlq_pending_total > 100
for: 30m
labels:
  severity: critical
annotations:
  summary: "{{ $value }} items in DLQ"
  action: "Review /sync/dlq, resolve manually"

# Layer 4: Oversell
alert: InventoryOversell
expr: sum(inventory_oversells_total) > 0
for: 1m
labels:
  severity: critical
annotations:
  summary: "CRITICAL: Inventory oversold"
  action: "Page on-call immediately"
```

---

## Grafana Dashboard Templates

### Dashboard 1: Sync System Overview (30-second refresh)

```json
{
  "title": "Fufaji Phase C — Sync System Overview",
  "timezone": "UTC",
  "refresh": "30s",
  "panels": [
    {
      "id": 1,
      "title": "Sync System Health",
      "type": "stat",
      "targets": [
        {
          "expr": "sync_system_health_status",
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "mappings": [
            {"type": "value", "value": "1", "text": "✅ Healthy"},
            {"type": "value", "value": "0", "text": "❌ Unhealthy"}
          ]
        }
      },
      "gridPos": {"x": 0, "y": 0, "w": 4, "h": 4}
    },
    {
      "id": 2,
      "title": "Pending Events (now)",
      "type": "stat",
      "targets": [
        {"expr": "sync_events_pending_total"}
      ],
      "gridPos": {"x": 4, "y": 0, "w": 4, "h": 4}
    },
    {
      "id": 3,
      "title": "DLQ Pending",
      "type": "stat",
      "targets": [
        {"expr": "sync_dlq_pending_total"}
      ],
      "gridPos": {"x": 8, "y": 0, "w": 4, "h": 4}
    },
    {
      "id": 4,
      "title": "Success Rate % (5min)",
      "type": "gauge",
      "targets": [
        {
          "expr": "100 * rate(sync_events_completed_total[5m]) / (rate(sync_events_completed_total[5m]) + rate(sync_events_failed_total[5m]))"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "red", "value": 0},
              {"color": "yellow", "value": 95},
              {"color": "green", "value": 99}
            ]
          }
        }
      },
      "gridPos": {"x": 12, "y": 0, "w": 4, "h": 4}
    }
  ]
}
```

---

## Monitoring Checklist

Before going live with Phase C, verify:

- [ ] Prometheus scraping all Lambda metrics
- [ ] All 4 layers have active dashboards
- [ ] Alerts routed to PagerDuty (P0-P3)
- [ ] On-call runbook links from alerts
- [ ] Grafana dashboards refresh < 1 minute
- [ ] 30-day retention for sync_events table
- [ ] Log streaming to DataDog/CloudWatch Logs
- [ ] Anomaly detection on sync latency
- [ ] SLA tracking per worker class
- [ ] Weekly sync health report generated

---

## Running Production Monitoring

### Health Check Endpoint

```bash
# GET /sync/health (admin only)
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://api.fufaji.com/sync/health

# Returns:
{
  "status": "healthy",
  "queues": {
    "sync_events_pending": 5,
    "sync_events_failed": 0,
    "sync_dlq_pending": 0
  },
  "workers": {
    "syncInventoryToFirestore": {
      "status": "running",
      "last_run": "2026-07-03T12:34:56Z"
    }
  },
  "alerts": []
}
```

### Manual Intervention Workflow

If any layer breaches SLA:

1. **Layer 1 (Infra)**: Check Lambda CloudWatch logs, scale memory if OOM
2. **Layer 2 (Worker)**: Check worker logic, disable via system flag, review queue
3. **Layer 3 (Sync)**: Check drift, query sync_dlq, replay or manually fix
4. **Layer 4 (Business)**: Announce incident, refund affected customers

---

## References

- **Architecture:** `/backend/PHASE_C_ARCHITECTURE.md`
- **Event Router:** `/backend/src/services/event-router.js`
- **Inventory Locking:** `/backend/src/services/inventory-locking.js`
- **Sync Routes:** `/backend/src/routes/sync.js`
- **System Flags:** `/backend/src/routes/system-flags.js`
