-- Iteration 8: Inventory Management System Schema
-- Created: 2026-07-11
-- Purpose: Stock management, reordering, supplier coordination, warehouse tracking

-- 1. Inventory Stock Levels (Real-time tracking)
CREATE TABLE IF NOT EXISTS inventory_stock (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  warehouse_id UUID,
  bin_location VARCHAR(50),
  available_quantity INT NOT NULL DEFAULT 0 CHECK (available_quantity >= 0),
  reserved_quantity INT NOT NULL DEFAULT 0 CHECK (reserved_quantity >= 0),
  damaged_quantity INT NOT NULL DEFAULT 0 CHECK (damaged_quantity >= 0),
  batch_number VARCHAR(100),
  expiry_date DATE,
  last_counted_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(product_id, warehouse_id, batch_number)
);

-- 2. Stock Movement History (Audit trail)
CREATE TABLE IF NOT EXISTS inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  movement_type VARCHAR(50) NOT NULL,
  quantity_change INT NOT NULL,
  reason VARCHAR(200),
  notes TEXT,
  reference_id UUID,
  reference_type VARCHAR(50),
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Suppliers
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  contact_person VARCHAR(255),
  phone VARCHAR(20),
  email VARCHAR(255),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  zip_code VARCHAR(20),
  lead_time_days INT DEFAULT 2,
  payment_terms VARCHAR(100),
  rating DECIMAL(3,2) DEFAULT 0.0 CHECK (rating >= 0 AND rating <= 5),
  total_orders INT DEFAULT 0,
  on_time_delivery_rate DECIMAL(5,2) DEFAULT 0.0,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Purchase Orders
CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_number VARCHAR(50) NOT NULL UNIQUE,
  supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
  status VARCHAR(20) NOT NULL DEFAULT 'draft',
  total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(12,2) DEFAULT 0,
  discount_amount DECIMAL(12,2) DEFAULT 0,
  expected_delivery_date DATE,
  actual_delivery_date DATE,
  notes TEXT,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  approved_by UUID REFERENCES auth.users(id),
  received_by UUID REFERENCES auth.users(id),
  approved_at TIMESTAMP WITH TIME ZONE,
  received_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Purchase Order Items
CREATE TABLE IF NOT EXISTS purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  quantity INT NOT NULL CHECK (quantity > 0),
  unit_cost DECIMAL(10,2) NOT NULL,
  total_cost DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
  quantity_received INT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Reorder Points Configuration
CREATE TABLE IF NOT EXISTS reorder_points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
  reorder_point INT NOT NULL DEFAULT 10 CHECK (reorder_point > 0),
  reorder_quantity INT NOT NULL DEFAULT 50 CHECK (reorder_quantity > 0),
  max_stock_level INT,
  auto_reorder BOOLEAN DEFAULT true,
  preferred_supplier_id UUID REFERENCES suppliers(id),
  lead_time_days INT DEFAULT 2,
  safety_stock INT DEFAULT 5,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Expiry Tracking
CREATE TABLE IF NOT EXISTS expiry_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  batch_number VARCHAR(100) NOT NULL,
  manufacture_date DATE,
  expiry_date DATE NOT NULL,
  quantity_received INT NOT NULL,
  quantity_remaining INT NOT NULL,
  location VARCHAR(100),
  status VARCHAR(20) NOT NULL DEFAULT 'fresh',
  disposal_date DATE,
  disposal_method VARCHAR(100),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Inventory Batches (Full batch tracking)
CREATE TABLE IF NOT EXISTS inventory_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_number VARCHAR(100) NOT NULL UNIQUE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  quantity_received INT NOT NULL,
  quantity_remaining INT NOT NULL,
  manufacture_date DATE,
  expiry_date DATE,
  supplier_id UUID REFERENCES suppliers(id),
  po_id UUID REFERENCES purchase_orders(id),
  warehouse_location VARCHAR(100),
  received_date DATE NOT NULL,
  received_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. Warehouse Locations
CREATE TABLE IF NOT EXISTS warehouse_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_name VARCHAR(100) NOT NULL,
  zone VARCHAR(50) NOT NULL,
  bin_id VARCHAR(50) NOT NULL UNIQUE,
  product_id UUID REFERENCES products(id),
  quantity INT DEFAULT 0,
  temperature DECIMAL(5,2),
  humidity DECIMAL(5,2),
  capacity_units INT,
  last_verified_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(warehouse_name, zone, bin_id)
);

-- 10. Stock Adjustments
CREATE TABLE IF NOT EXISTS stock_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  adjustment_type VARCHAR(50) NOT NULL,
  quantity INT NOT NULL,
  reason VARCHAR(200),
  notes TEXT,
  adjusted_by UUID NOT NULL REFERENCES auth.users(id),
  approved_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  approved_at TIMESTAMP WITH TIME ZONE
);

--- INDEXES FOR PERFORMANCE ---

CREATE INDEX IF NOT EXISTS idx_inventory_stock_product_id ON inventory_stock(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_warehouse_id ON inventory_stock(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_expiry_date ON inventory_stock(expiry_date);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_batch_number ON inventory_stock(batch_number);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_product_id ON inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_movement_type ON inventory_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_created_at ON inventory_movements(created_at);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_reference_id ON inventory_movements(reference_id);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_created_at ON purchase_orders(created_at);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_po_number ON purchase_orders(po_number);

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po_id ON purchase_order_items(po_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_product_id ON purchase_order_items(product_id);

CREATE INDEX IF NOT EXISTS idx_reorder_points_product_id ON reorder_points(product_id);
CREATE INDEX IF NOT EXISTS idx_reorder_points_auto_reorder ON reorder_points(auto_reorder);

CREATE INDEX IF NOT EXISTS idx_expiry_tracking_expiry_date ON expiry_tracking(expiry_date);
CREATE INDEX IF NOT EXISTS idx_expiry_tracking_status ON expiry_tracking(status);
CREATE INDEX IF NOT EXISTS idx_expiry_tracking_product_id ON expiry_tracking(product_id);

CREATE INDEX IF NOT EXISTS idx_inventory_batches_batch_number ON inventory_batches(batch_number);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_product_id ON inventory_batches(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_expiry_date ON inventory_batches(expiry_date);

CREATE INDEX IF NOT EXISTS idx_warehouse_locations_warehouse_zone ON warehouse_locations(warehouse_name, zone);
CREATE INDEX IF NOT EXISTS idx_warehouse_locations_bin_id ON warehouse_locations(bin_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_locations_product_id ON warehouse_locations(product_id);

CREATE INDEX IF NOT EXISTS idx_stock_adjustments_product_id ON stock_adjustments(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_created_at ON stock_adjustments(created_at);

--- ROW-LEVEL SECURITY POLICIES ---

-- Inventory Stock visibility
ALTER TABLE inventory_stock ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inventory_stock_owner_all" ON inventory_stock
  FOR ALL USING (auth.jwt() ->> 'email' = 'owner@fufaji.com');

CREATE POLICY "inventory_stock_manager_all" ON inventory_stock
  FOR ALL USING (auth.jwt() ->> 'role' = 'manager');

CREATE POLICY "inventory_stock_staff_view" ON inventory_stock
  FOR SELECT USING (auth.jwt() ->> 'role' = 'staff');

-- Inventory Movements audit trail
ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inventory_movements_owner_all" ON inventory_movements
  FOR ALL USING (auth.jwt() ->> 'email' = 'owner@fufaji.com');

CREATE POLICY "inventory_movements_manager_all" ON inventory_movements
  FOR ALL USING (auth.jwt() ->> 'role' = 'manager');

CREATE POLICY "inventory_movements_user_own" ON inventory_movements
  FOR SELECT USING (created_by = auth.uid());

-- Suppliers
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "suppliers_owner_all" ON suppliers
  FOR ALL USING (auth.jwt() ->> 'email' = 'owner@fufaji.com');

CREATE POLICY "suppliers_manager_all" ON suppliers
  FOR ALL USING (auth.jwt() ->> 'role' = 'manager');

CREATE POLICY "suppliers_view_all" ON suppliers
  FOR SELECT USING (auth.jwt() ->> 'role' IN ('manager', 'staff', 'owner'));

-- Purchase Orders
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "po_owner_all" ON purchase_orders
  FOR ALL USING (auth.jwt() ->> 'email' = 'owner@fufaji.com');

CREATE POLICY "po_manager_all" ON purchase_orders
  FOR ALL USING (auth.jwt() ->> 'role' = 'manager');

CREATE POLICY "po_creator_view" ON purchase_orders
  FOR SELECT USING (created_by = auth.uid());

-- Reorder Points
ALTER TABLE reorder_points ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reorder_points_owner_all" ON reorder_points
  FOR ALL USING (auth.jwt() ->> 'email' = 'owner@fufaji.com');

CREATE POLICY "reorder_points_manager_all" ON reorder_points
  FOR ALL USING (auth.jwt() ->> 'role' = 'manager');

CREATE POLICY "reorder_points_view_all" ON reorder_points
  FOR SELECT USING (auth.jwt() ->> 'role' IN ('manager', 'staff', 'owner'));

-- Expiry Tracking
ALTER TABLE expiry_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "expiry_tracking_owner_all" ON expiry_tracking
  FOR ALL USING (auth.jwt() ->> 'email' = 'owner@fufaji.com');

CREATE POLICY "expiry_tracking_manager_all" ON expiry_tracking
  FOR ALL USING (auth.jwt() ->> 'role' = 'manager');

CREATE POLICY "expiry_tracking_view_all" ON expiry_tracking
  FOR SELECT USING (auth.jwt() ->> 'role' IN ('manager', 'staff', 'owner'));

-- Stock Adjustments
ALTER TABLE stock_adjustments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "stock_adjustments_owner_all" ON stock_adjustments
  FOR ALL USING (auth.jwt() ->> 'email' = 'owner@fufaji.com');

CREATE POLICY "stock_adjustments_manager_all" ON stock_adjustments
  FOR ALL USING (auth.jwt() ->> 'role' = 'manager');

CREATE POLICY "stock_adjustments_creator_view" ON stock_adjustments
  FOR SELECT USING (adjusted_by = auth.uid());
