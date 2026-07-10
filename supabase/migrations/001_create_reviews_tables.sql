-- Product Reviews Table
CREATE TABLE IF NOT EXISTS product_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Foreign Keys
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  order_item_id UUID,
  
  -- Review Data
  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text TEXT,
  character_count INT DEFAULT 0 CHECK (character_count <= 500),
  
  -- Auto-tags (detected from review_text)
  tags TEXT[] DEFAULT '{}',
  
  -- Status
  is_flagged BOOLEAN DEFAULT FALSE,
  flag_reason TEXT,
  resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMP,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  customer_anonymized BOOLEAN DEFAULT TRUE,
  
  -- Constraints
  CONSTRAINT valid_review_text CHECK (character_count <= 500)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_order_id ON product_reviews(order_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_customer_id ON product_reviews(customer_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_rating ON product_reviews(rating);
CREATE INDEX IF NOT EXISTS idx_product_reviews_created_at ON product_reviews(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_reviews_is_flagged ON product_reviews(is_flagged);
CREATE INDEX IF NOT EXISTS idx_product_reviews_tags ON product_reviews USING GIN(tags);

-- Delivery Feedback Table
CREATE TABLE IF NOT EXISTS delivery_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Foreign Keys
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  employee_id UUID NOT NULL REFERENCES employees(id),
  customer_id UUID NOT NULL REFERENCES customers(id),
  
  -- Feedback Data
  service_rating INT NOT NULL CHECK (service_rating >= 1 AND service_rating <= 5),
  feedback_text TEXT,
  character_count INT DEFAULT 0 CHECK (character_count <= 500),
  
  -- Auto-tags (detected from feedback_text)
  tags TEXT[] DEFAULT '{}',
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  customer_anonymized BOOLEAN DEFAULT TRUE,
  
  -- Constraints
  CONSTRAINT valid_feedback_text CHECK (character_count <= 500)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_delivery_feedback_employee_id ON delivery_feedback(employee_id);
CREATE INDEX IF NOT EXISTS idx_delivery_feedback_order_id ON delivery_feedback(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_feedback_customer_id ON delivery_feedback(customer_id);
CREATE INDEX IF NOT EXISTS idx_delivery_feedback_rating ON delivery_feedback(service_rating);
CREATE INDEX IF NOT EXISTS idx_delivery_feedback_created_at ON delivery_feedback(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delivery_feedback_tags ON delivery_feedback USING GIN(tags);

-- Enable Row Level Security
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_feedback ENABLE ROW LEVEL SECURITY;

-- RLS Policies for product_reviews
-- Customers can insert their own reviews
CREATE POLICY "customers_insert_own_reviews"
  ON product_reviews FOR INSERT
  WITH CHECK (customer_id = auth.uid());

-- Customers can read all reviews (anonymized)
CREATE POLICY "customers_read_reviews"
  ON product_reviews FOR SELECT
  USING (customer_anonymized = TRUE OR customer_id = auth.uid());

-- Owner/Admin can read all reviews with customer info
CREATE POLICY "owner_read_all_reviews"
  ON product_reviews FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM owners
      WHERE owners.id = auth.uid()
    )
  );

-- Owner can update reviews (flag, resolve)
CREATE POLICY "owner_update_reviews"
  ON product_reviews FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM owners
      WHERE owners.id = auth.uid()
    )
  );

-- RLS Policies for delivery_feedback
-- Employees can view their own feedback
CREATE POLICY "employees_read_own_feedback"
  ON delivery_feedback FOR SELECT
  USING (employee_id = auth.uid() OR 
    EXISTS (
      SELECT 1 FROM owners
      WHERE owners.id = auth.uid()
    ));

-- Customers can insert feedback
CREATE POLICY "customers_insert_feedback"
  ON delivery_feedback FOR INSERT
  WITH CHECK (customer_id = auth.uid());

-- Owner can read all feedback
CREATE POLICY "owner_read_all_feedback"
  ON delivery_feedback FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM owners
      WHERE owners.id = auth.uid()
    )
  );

-- Created_at trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_product_reviews_updated_at
  BEFORE UPDATE ON product_reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_delivery_feedback_updated_at
  BEFORE UPDATE ON delivery_feedback
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
