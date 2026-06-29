-- ============================================================
-- Fufaji Enterprise Architecture
-- Migration 002: Indexes for hot query paths
-- ============================================================

-- enable trigram extension for product name search (used below)
create extension if not exists pg_trgm;

-- users
create index if not exists idx_users_firebase_uid on users(firebase_uid);
create index if not exists idx_users_phone on users(phone);
create index if not exists idx_users_role on users(role);
create index if not exists idx_users_branch_id on users(branch_id);
create index if not exists idx_users_shop_id on users(shop_id);

-- addresses
create index if not exists idx_addresses_user_id on addresses(user_id);

-- categories
create index if not exists idx_categories_parent_id on categories(parent_id);
create index if not exists idx_categories_slug on categories(slug);

-- products
create index if not exists idx_products_category_id on products(category_id);
create index if not exists idx_products_vendor_id on products(vendor_id);
create index if not exists idx_products_shop_id on products(shop_id);
create index if not exists idx_products_status on products(status);
create index if not exists idx_products_barcode on products(barcode);
create index if not exists idx_products_name_trgm on products using gin (name gin_trgm_ops);

-- orders
create index if not exists idx_orders_user_id on orders(user_id);
create index if not exists idx_orders_vendor_id on orders(vendor_id);
create index if not exists idx_orders_driver_id on orders(driver_id);
create index if not exists idx_orders_shop_id on orders(shop_id);
create index if not exists idx_orders_status on orders(order_status);
create index if not exists idx_orders_created_at on orders(created_at);
create index if not exists idx_orders_order_number on orders(order_number);

-- order_items
create index if not exists idx_order_items_order_id on order_items(order_id);
create index if not exists idx_order_items_product_id on order_items(product_id);

-- order_status_history
create index if not exists idx_order_status_history_order_id on order_status_history(order_id);

-- wallet_transactions
create index if not exists idx_wallet_tx_user_id on wallet_transactions(user_id);
create index if not exists idx_wallet_tx_created_at on wallet_transactions(created_at);

-- delivery_tracking
create index if not exists idx_delivery_tracking_order_id on delivery_tracking(order_id);
create index if not exists idx_delivery_tracking_driver_id on delivery_tracking(driver_id);

-- reviews
create index if not exists idx_reviews_product_id on reviews(product_id);
create index if not exists idx_reviews_user_id on reviews(user_id);

-- notifications
create index if not exists idx_notifications_user_id on notifications(user_id);
create index if not exists idx_notifications_created_at on notifications(created_at);

-- support_tickets
create index if not exists idx_support_tickets_user_id on support_tickets(user_id);
create index if not exists idx_support_tickets_status on support_tickets(status);
create index if not exists idx_support_tickets_assigned_to on support_tickets(assigned_to);

-- coupons
create index if not exists idx_coupons_code on coupons(code);
create index if not exists idx_coupons_is_active on coupons(is_active);

-- inventory_logs
create index if not exists idx_inventory_logs_product_id on inventory_logs(product_id);
create index if not exists idx_inventory_logs_created_at on inventory_logs(created_at);

-- audit_logs
create index if not exists idx_audit_logs_user_id on audit_logs(user_id);
create index if not exists idx_audit_logs_action on audit_logs(action);
create index if not exists idx_audit_logs_created_at on audit_logs(created_at);
create index if not exists idx_audit_logs_target on audit_logs(target_id, target_type);

-- kyc_documents
create index if not exists idx_kyc_documents_user_id on kyc_documents(user_id);
create index if not exists idx_kyc_documents_status on kyc_documents(status);
