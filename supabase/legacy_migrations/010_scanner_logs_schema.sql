-- Scanner Audit Logs and Scan Events Database Schemas

-- Table for general scanner logs audit
CREATE TABLE IF NOT EXISTS scan_logs (
    id VARCHAR(128) PRIMARY KEY,
    shop_id VARCHAR(128) NOT NULL,
    branch_id VARCHAR(128),
    employee_id VARCHAR(128) NOT NULL,
    employee_name VARCHAR(255),
    employee_role VARCHAR(50) NOT NULL,
    scan_code TEXT NOT NULL,
    action_type VARCHAR(100) NOT NULL, -- e.g. 'product_search', 'order_packing', 'dispatch'
    action_label VARCHAR(100),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for packing verification scanner logs
CREATE TABLE IF NOT EXISTS packing_scan_logs (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(128) NOT NULL,
    employee_id VARCHAR(128) NOT NULL,
    barcode_scanned VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL, -- e.g., 'VERIFIED', 'MISMATCH', 'DUPLICATE'
    scanned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for inventory receiving and audit scanner logs
CREATE TABLE IF NOT EXISTS inventory_scan_logs (
    id SERIAL PRIMARY KEY,
    audit_id VARCHAR(128),
    product_id VARCHAR(128) NOT NULL,
    barcode_scanned VARCHAR(100) NOT NULL,
    quantity_scanned INT NOT NULL,
    scan_type VARCHAR(50) NOT NULL, -- e.g., 'RECEIVING', 'AUDIT'
    employee_id VARCHAR(128) NOT NULL,
    scanned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for delivery verification scanner logs
CREATE TABLE IF NOT EXISTS delivery_scan_logs (
    id SERIAL PRIMARY KEY,
    parcel_id VARCHAR(128) NOT NULL,
    delivery_agent_id VARCHAR(128) NOT NULL,
    verification_method VARCHAR(50) NOT NULL, -- e.g., 'QR', 'OTP', 'BARCODE'
    status VARCHAR(50) NOT NULL, -- e.g. 'SUCCESS', 'FAILED'
    scanned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes to optimize queries
CREATE INDEX IF NOT EXISTS idx_scan_logs_shop ON scan_logs(shop_id);
CREATE INDEX IF NOT EXISTS idx_scan_logs_employee ON scan_logs(employee_id);
CREATE INDEX IF NOT EXISTS idx_packing_scan_logs_order ON packing_scan_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_inventory_scan_logs_audit ON inventory_scan_logs(audit_id);
CREATE INDEX IF NOT EXISTS idx_delivery_scan_logs_parcel ON delivery_scan_logs(parcel_id);
