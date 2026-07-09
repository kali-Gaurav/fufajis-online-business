-- MODULE 3 FIX: Complete Coupon System with Server-Side Validation
-- VULNERABILITY: maximumDiscountAmount=0 clamps ALL percentage coupons to ₹0
-- OR allows unlimited discounts (zero cap = no cap logic bug)

-- ============================================================================
-- TIER 1: COUPON DEFINITIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(255),
  description TEXT,

  -- Discount type and value
  discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'flat')),
  discount_value DECIMAL(10, 2) NOT NULL CHECK (discount_value > 0),

  -- CRITICAL FIX: Enforce valid maximum discount cap (P0 EXPLOIT)
  -- minimum_order_amount: Order must be at least this much to use coupon
  minimum_order_amount DECIMAL(10, 2) DEFAULT 0 CHECK (minimum_order_amount >= 0),

  -- maximum_discount_amount: Cap on discount applied
  -- MUST be > 0. If not specified, defaults to discount_value * 10 (reasonable cap)
  -- Zero is INVALID and rejected by check constraint
  maximum_discount_amount DECIMAL(10, 2) NOT NULL CHECK (maximum_discount_amount > 0),

  -- Usage limits
  max_uses_total INT, -- NULL = unlimited
  max_uses_per_user INT DEFAULT 1, -- How many times one user can use this coupon

  -- Active period
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP NOT NULL CHECK (end_date > start_date),
  is_active BOOLEAN DEFAULT true,

  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_by UUID -- Admin who created coupon
);

CREATE INDEX idx_coupons_code ON coupons(code);
CREATE INDEX idx_coupons_shop ON coupons(shop_id);
CREATE INDEX idx_coupons_active ON coupons(is_active, end_date);

-- ============================================================================
-- TIER 2: COUPON USAGE TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS coupon_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id UUID NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

  discount_applied DECIMAL(10, 2) NOT NULL,
  usage_date TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_coupon_usage_coupon ON coupon_usage(coupon_id);
CREATE INDEX idx_coupon_usage_user ON coupon_usage(user_id);
CREATE INDEX idx_coupon_usage_order ON coupon_usage(order_id);

-- ============================================================================
-- TIER 3: VALIDATION FUNCTION (Server-Side Only)
-- ============================================================================

-- Function: Validate and apply coupon
CREATE OR REPLACE FUNCTION apply_coupon_validated(
  p_coupon_code VARCHAR(50),
  p_user_id UUID,
  p_order_id UUID,
  p_order_subtotal DECIMAL(10, 2),
  p_shop_id UUID
)
RETURNS TABLE (
  success BOOLEAN,
  error_message TEXT,
  coupon_id UUID,
  discount_amount DECIMAL(10, 2),
  final_amount DECIMAL(10, 2)
) AS $$
DECLARE
  v_coupon RECORD;
  v_discount DECIMAL(10, 2);
  v_final_amount DECIMAL(10, 2);
  v_usage_count INT;
BEGIN
  -- STEP 1: Load coupon (ensure it exists)
  SELECT * INTO v_coupon FROM coupons
  WHERE code = UPPER(p_coupon_code) AND shop_id = p_shop_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, 'Coupon not found'::TEXT, NULL::UUID, 0, p_order_subtotal;
    RETURN;
  END IF;

  -- STEP 2: Validate coupon is active
  IF NOT v_coupon.is_active THEN
    RETURN QUERY SELECT FALSE, 'Coupon is inactive'::TEXT, v_coupon.id, 0, p_order_subtotal;
    RETURN;
  END IF;

  -- STEP 3: Validate date range
  IF CURRENT_TIMESTAMP < v_coupon.start_date THEN
    RETURN QUERY SELECT FALSE, 'Coupon not yet active'::TEXT, v_coupon.id, 0, p_order_subtotal;
    RETURN;
  END IF;

  IF CURRENT_TIMESTAMP > v_coupon.end_date THEN
    RETURN QUERY SELECT FALSE, 'Coupon has expired'::TEXT, v_coupon.id, 0, p_order_subtotal;
    RETURN;
  END IF;

  -- STEP 4: Validate minimum order amount
  IF p_order_subtotal < v_coupon.minimum_order_amount THEN
    RETURN QUERY SELECT FALSE,
      'Order amount too low. Minimum: ₹' || v_coupon.minimum_order_amount,
      v_coupon.id, 0, p_order_subtotal;
    RETURN;
  END IF;

  -- STEP 5: Validate per-user usage limit
  IF v_coupon.max_uses_per_user IS NOT NULL THEN
    SELECT COUNT(*) INTO v_usage_count FROM coupon_usage
    WHERE coupon_id = v_coupon.id AND user_id = p_user_id;

    IF v_usage_count >= v_coupon.max_uses_per_user THEN
      RETURN QUERY SELECT FALSE,
        'You have already used this coupon maximum times',
        v_coupon.id, 0, p_order_subtotal;
      RETURN;
    END IF;
  END IF;

  -- STEP 6: Validate total usage limit
  IF v_coupon.max_uses_total IS NOT NULL THEN
    SELECT COUNT(*) INTO v_usage_count FROM coupon_usage
    WHERE coupon_id = v_coupon.id;

    IF v_usage_count >= v_coupon.max_uses_total THEN
      RETURN QUERY SELECT FALSE,
        'Coupon has reached maximum usage limit',
        v_coupon.id, 0, p_order_subtotal;
      RETURN;
    END IF;
  END IF;

  -- STEP 7: Calculate discount
  IF v_coupon.discount_type = 'percentage' THEN
    v_discount := p_order_subtotal * (v_coupon.discount_value / 100.0);

    -- P0 FIX: Apply maximum discount cap (ALWAYS)
    -- This is the critical fix for the zero-cap exploit
    IF v_discount > v_coupon.maximum_discount_amount THEN
      v_discount := v_coupon.maximum_discount_amount;
    END IF;
  ELSE
    -- Flat discount: never exceed order subtotal
    v_discount := LEAST(v_coupon.discount_value, p_order_subtotal);

    -- Also apply maximum cap if specified
    IF v_discount > v_coupon.maximum_discount_amount THEN
      v_discount := v_coupon.maximum_discount_amount;
    END IF;
  END IF;

  -- STEP 8: Ensure discount is not negative
  v_discount := GREATEST(v_discount, 0);

  -- STEP 9: Calculate final amount
  v_final_amount := p_order_subtotal - v_discount;

  -- STEP 10: Log usage (only on success)
  INSERT INTO coupon_usage (coupon_id, user_id, order_id, discount_applied)
  VALUES (v_coupon.id, p_user_id, p_order_id, v_discount);

  RETURN QUERY SELECT TRUE, 'Coupon applied successfully'::TEXT,
    v_coupon.id, v_discount, v_final_amount;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TIER 4: ADMIN FUNCTIONS
-- ============================================================================

-- Function: Validate coupon on creation/update
CREATE OR REPLACE FUNCTION validate_coupon_on_save()
RETURNS TRIGGER AS $$
BEGIN
  -- P0 FIX: Reject maximum_discount_amount = 0 (the exploit)
  IF NEW.maximum_discount_amount <= 0 THEN
    RAISE EXCEPTION 'Maximum discount amount must be greater than 0';
  END IF;

  -- Ensure end_date > start_date
  IF NEW.end_date <= NEW.start_date THEN
    RAISE EXCEPTION 'End date must be after start date';
  END IF;

  -- Ensure discount_value > 0
  IF NEW.discount_value <= 0 THEN
    RAISE EXCEPTION 'Discount value must be greater than 0';
  END IF;

  -- For percentage discounts, cap should be reasonable (not 0.01 or huge)
  IF NEW.discount_type = 'percentage' AND NEW.maximum_discount_amount < 10 THEN
    RAISE EXCEPTION 'For percentage coupons, maximum discount should be at least ₹10';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER coupon_validation_trigger
BEFORE INSERT OR UPDATE ON coupons
FOR EACH ROW
EXECUTE FUNCTION validate_coupon_on_save();

-- ============================================================================
-- SUMMARY: COUPON SYSTEM FIXES
-- ============================================================================
--
-- VULNERABILITY (P0):
-- maximumDiscountAmount = 0 in Firestore
-- → Client calculates: discount = subtotal * (percentage / 100)
-- → If cap exists AND cap > 0: discount = min(discount, cap)
-- → If cap == 0: clamped to ₹0 (or logic error allowed unlimited discount)
--
-- ATTACK: Admin UI doesn't validate cap on save
-- → Attacker creates 50% coupon with cap=0
-- → Users get 0 discount (unintended) OR unlimited discount (exploit)
--
-- FIX 1: Check constraint: maximum_discount_amount > 0
-- → Database rejects zero-cap coupons on INSERT/UPDATE
--
-- FIX 2: Trigger validation: validates all business rules
-- → Rejects cap < ₹10 for percentage coupons (reasonable minimum)
-- → Ensures end_date > start_date
-- → Ensures discount_value > 0
--
-- FIX 3: Server-side apply_coupon_validated()
-- → All validation on server (not client)
-- → Applies cap: discount = min(discount, maximum_discount_amount)
-- → Checks per-user limits
-- → Checks total usage limits
-- → Logs all applications (audit trail)
--
-- RESULT: Zero-cap exploit impossible
-- Coupons validated server-side only
-- Full audit trail for compliance
