# Postgres Connection Pooling

## The problem

`functions/aws_services.js#getPgPool()` creates a `pg.Pool` with `max: 3`
**per warm Cloud Functions instance**. Cloud Functions can scale to dozens
of concurrent instances under load (each `firestore_sync.js` trigger,
`pg_backup.js` backup, and every `rdsQuery`/analytics callable can spin up
its own instance). At 30 concurrent instances × 3 connections = 90
connections — which can exceed a small RDS instance's `max_connections`
(e.g. `db.t3.micro` defaults to ~87) or eat into the budget shared with
`scripts/migration/migrate.js` and any direct `psql`/Supabase Studio
sessions.

A connection pooler sits between Cloud Functions and Postgres, multiplexing
many client connections onto a smaller number of real Postgres backend
connections.

## Recommended: Supabase's built-in pooler (no infra to run)

If the database is a Supabase project, Supabase already runs a PgBouncer
instance for you on **port 6543** (vs. 5432 for the direct connection),
in `transaction` pooling mode. To use it:

```bash
firebase functions:config:set \
  rds.pool_host="<project-ref>.pooler.supabase.com" \
  rds.pool_port="6543"
```

`getPgPool()` (see `functions/aws_services.js`) prefers `rds.pool_host`/
`rds.pool_port` over `rds.host`/`rds.port` if set, so this is a config-only
change — no code or redeploy logic changes needed beyond setting config and
restarting functions (`firebase deploy --only functions` or a cold start).

`rds.host`/`rds.port` (the direct 5432 connection) remain useful for:
- `scripts/migration/migrate.js` and `scripts/pg-backup-restore-test/` —
  long-lived operator scripts where a direct connection is simpler and the
  connection count is bounded (one operator run at a time).
- Anything needing session-level features incompatible with transaction
  pooling (see below) — none of the current codebase needs this, but keep
  the direct endpoint available for `psql` debugging.

## Alternative: self-hosted PgBouncer (for AWS RDS without Supabase pooler)

If running directly on AWS RDS (no Supabase pooler available), deploy
PgBouncer yourself using the template in `infra/pgbouncer/`:

1. Copy `infra/pgbouncer/userlist.txt.example` to `userlist.txt`, fill in
   real `md5(password+username)` hashes (see comments in the file), and
   **do not commit it**.
2. Edit `infra/pgbouncer/pgbouncer.ini`: set the real RDS endpoint under
   `[databases]`.
3. Run PgBouncer on a small always-on host (EC2 t4g.micro, or a Cloud Run
   service with `min-instances=1` so it doesn't cold-start away the pool).
4. Point Cloud Functions at it:
   ```bash
   firebase functions:config:set \
     rds.pool_host="<pgbouncer-host>" \
     rds.pool_port="6432"
   ```

## Transaction-pooling compatibility (why this is safe today)

PgBouncer's `transaction` pooling mode (used by both Supabase's pooler and
the `infra/pgbouncer/pgbouncer.ini` template) hands out a physical Postgres
connection per *transaction*, not per client session. This is incompatible
with:

- Named prepared statements that persist across queries (`pg.Pool#query`
  with an explicit `name`) — **not used anywhere in this codebase**
  (`functions/aws_services.js`, `functions/firestore_sync.js`,
  `functions/pg_backup.js`, `scripts/migration/lib/pg.js` all call
  `pool.query(sql, params)` with no `name`).
- `LISTEN`/`NOTIFY` — not used.
- Session-level `SET` statements expected to persist across separate
  `pool.query()` calls — not used; any `SET` would need to be in the same
  statement/transaction.
- Advisory locks held across multiple `pool.query()` calls on the "same"
  connection — not used (the codebase does not use `pg_advisory_lock`).

So switching `rds.pool_host`/`rds.pool_port` to a transaction pooler is a
drop-in change for the current code. If any future feature needs
session-mode features, give it its own pool pointed at `rds.host`/`rds.port`
directly (or a `session`-mode PgBouncer database entry) rather than changing
the shared pool's mode.

## Sizing guidance

- **Per-instance `pg.Pool` (`rds.pool_max`, default 3)**: keep small (2-5).
  Each Cloud Functions instance only handles one request at a time in
  practice for these triggers, so 3 covers brief overlap (e.g. a
  `firestore_sync.js` trigger plus a concurrent health check).
- **PgBouncer `default_pool_size` (in `pgbouncer.ini`, default 20)**: this is
  the real cap on Postgres backend connections from app traffic. Set it to
  comfortably under `max_connections` minus headroom for migration scripts,
  Supabase Studio, and `pg_backup.js`'s nightly export (which itself uses
  `getPgPool()`, so it shares this budget).
- Monitor via `SHOW POOLS;` / `SHOW STATS;` on the PgBouncer admin console,
  or Supabase's dashboard (Database → Connection Pooling) if using the
  managed pooler.
