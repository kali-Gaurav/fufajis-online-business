-- ============================================================
-- Migration 005: Firestore migration compatibility columns
--
-- The Firestore -> Postgres historical backfill script
-- (scripts/migration/migrate.js) needs a stable, idempotent key
-- to upsert against for every table it touches. `products`,
-- `orders`, and `audit_logs` already have a `firestore_id`
-- column (see 001_core_schema.sql); this migration adds the
-- same column (nullable, unique where the table has no other
-- natural Firestore-derived key) to every remaining table the
-- backfill writes to, so re-running the script is always safe
-- (ON CONFLICT (firestore_id) DO UPDATE).
--
-- `users` already has a unique `firebase_uid`, which IS the
-- Firestore document id for that collection — no new column
-- needed there.
-- ============================================================

do $$
begin
  if not exists (select 1 from information_schema.columns where table_name = 'categories' and column_name = 'firestore_id') then
    alter table categories add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'addresses' and column_name = 'firestore_id') then
    alter table addresses add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'order_items' and column_name = 'firestore_id') then
    alter table order_items add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'order_status_history' and column_name = 'firestore_id') then
    alter table order_status_history add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'wallet_transactions' and column_name = 'firestore_id') then
    alter table wallet_transactions add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'delivery_tracking' and column_name = 'firestore_id') then
    alter table delivery_tracking add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'reviews' and column_name = 'firestore_id') then
    alter table reviews add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'notifications' and column_name = 'firestore_id') then
    alter table notifications add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'support_tickets' and column_name = 'firestore_id') then
    alter table support_tickets add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'coupons' and column_name = 'firestore_id') then
    alter table coupons add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'inventory_logs' and column_name = 'firestore_id') then
    alter table inventory_logs add column firestore_id text unique;
  end if;

  if not exists (select 1 from information_schema.columns where table_name = 'kyc_documents' and column_name = 'firestore_id') then
    alter table kyc_documents add column firestore_id text unique;
  end if;
end $$;

-- ------------------------------------------------------------
-- migration_runs — bookkeeping for the backfill script.
-- One row per (collection) per run, so progress / cursors can
-- be inspected and resumed without re-scanning everything.
-- ------------------------------------------------------------
create table if not exists migration_runs (
  id              uuid primary key default gen_random_uuid(),
  collection      text not null,
  status          text not null default 'running'
                    check (status in ('running','completed','failed')),
  documents_seen  integer not null default 0,
  documents_written integer not null default 0,
  documents_skipped integer not null default 0,
  last_doc_id     text,
  error           text,
  started_at      timestamptz not null default now(),
  finished_at     timestamptz
);

create index if not exists idx_migration_runs_collection on migration_runs(collection, started_at desc);
