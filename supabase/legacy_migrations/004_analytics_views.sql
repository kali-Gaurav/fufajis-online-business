-- ============================================================
-- Fufaji Enterprise Architecture
-- Migration 004: Analytics materialized views
--
-- Refresh strategy: call refresh_fufaji_analytics() on a
-- schedule (e.g. nightly Cloud Function / pg_cron) since
-- materialized views do not auto-update.
-- ============================================================

-- ------------------------------------------------------------
-- sales_analytics — daily revenue/order rollups
-- ------------------------------------------------------------
drop materialized view if exists sales_analytics;
create materialized view sales_analytics as
select
  date_trunc('day', o.created_at)::date as sale_date,
  o.shop_id,
  o.vendor_id,
  count(*)                                   as order_count,
  count(*) filter (where o.order_status = 'delivered')   as delivered_count,
  count(*) filter (where o.order_status = 'cancelled')   as cancelled_count,
  coalesce(sum(o.total) filter (where o.order_status = 'delivered'), 0) as revenue,
  coalesce(avg(o.total) filter (where o.order_status = 'delivered'), 0) as avg_order_value
from orders o
group by 1, 2, 3;

create unique index if not exists idx_sales_analytics_unique
  on sales_analytics (sale_date, coalesce(shop_id, '00000000-0000-0000-0000-000000000000'), coalesce(vendor_id, '00000000-0000-0000-0000-000000000000'));

-- ------------------------------------------------------------
-- vendor_analytics — per-vendor lifetime performance
-- ------------------------------------------------------------
drop materialized view if exists vendor_analytics;
create materialized view vendor_analytics as
select
  o.vendor_id,
  count(*)                                                 as total_orders,
  count(*) filter (where o.order_status = 'delivered')     as delivered_orders,
  count(*) filter (where o.order_status = 'cancelled')     as cancelled_orders,
  coalesce(sum(o.total) filter (where o.order_status = 'delivered'), 0) as total_revenue,
  coalesce(avg(r.rating), 0)                               as avg_rating,
  count(distinct r.id)                                     as review_count,
  max(o.created_at)                                        as last_order_at
from orders o
left join order_items oi on oi.order_id = o.id
left join reviews r on r.product_id = oi.product_id
group by o.vendor_id;

create unique index if not exists idx_vendor_analytics_unique
  on vendor_analytics (coalesce(vendor_id, '00000000-0000-0000-0000-000000000000'));

-- ------------------------------------------------------------
-- delivery_analytics — driver/delivery performance
-- ------------------------------------------------------------
drop materialized view if exists delivery_analytics;
create materialized view delivery_analytics as
select
  o.driver_id,
  date_trunc('day', o.created_at)::date as delivery_date,
  count(*)                                                  as assigned_count,
  count(*) filter (where o.order_status = 'delivered')      as delivered_count,
  count(*) filter (where o.order_status = 'cancelled')       as cancelled_count,
  avg(extract(epoch from (o.delivered_at - o.placed_at)) / 60.0)
    filter (where o.delivered_at is not null)               as avg_delivery_minutes
from orders o
where o.driver_id is not null
group by o.driver_id, date_trunc('day', o.created_at);

create unique index if not exists idx_delivery_analytics_unique
  on delivery_analytics (coalesce(driver_id, '00000000-0000-0000-0000-000000000000'), delivery_date);

-- ------------------------------------------------------------
-- Refresh helper (call from a scheduled job / Cloud Function)
-- ------------------------------------------------------------
create or replace function refresh_fufaji_analytics()
returns void
language plpgsql
as $$
begin
  refresh materialized view concurrently sales_analytics;
  refresh materialized view concurrently vendor_analytics;
  refresh materialized view concurrently delivery_analytics;
end;
$$;
