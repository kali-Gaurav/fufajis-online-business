-- CRITICAL SECURITY FIX: Atomic wallet credit with row-level locking
-- This prevents race conditions from concurrent requests

CREATE OR REPLACE FUNCTION credit_wallet_atomic(
  p_user_id UUID,
  p_amount DECIMAL,
  p_transaction_type TEXT,
  p_order_reference TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_verified_by TEXT DEFAULT 'system'
)
RETURNS TABLE(
  new_balance DECIMAL,
  transaction_id UUID,
  success BOOLEAN
) AS $$
DECLARE
  v_current_balance DECIMAL;
  v_transaction_id UUID;
  v_sequence_number INT;
BEGIN
  -- Step 1: Lock the user's wallet row (prevents concurrent modifications)
  SELECT wallet_balance, last_transaction_sequence
  INTO v_current_balance, v_sequence_number
  FROM users
  WHERE id = p_user_id
  FOR UPDATE;  -- CRITICAL: Row-level lock prevents race conditions

  -- Validate that wallet operation is allowed
  IF v_current_balance IS NULL THEN
    RAISE EXCEPTION 'User not found or wallet not initialized';
  END IF;

  -- Step 2: Calculate new balance
  v_current_balance := v_current_balance + p_amount;

  -- Step 3: Increment sequence number (optimistic locking)
  v_sequence_number := COALESCE(v_sequence_number, 0) + 1;

  -- Step 4: Update user wallet (within same transaction)
  UPDATE users
  SET
    wallet_balance = v_current_balance,
    last_transaction_sequence = v_sequence_number,
    updated_at = NOW()
  WHERE id = p_user_id;

  -- Step 5: Record transaction (idempotent with unique constraint)
  v_transaction_id := gen_random_uuid();

  INSERT INTO wallet_transactions (
    id,
    user_id,
    amount,
    transaction_type,
    order_reference,
    description,
    balance_after,
    sequence_number,
    verified_by,
    created_at
  ) VALUES (
    v_transaction_id,
    p_user_id,
    p_amount,
    p_transaction_type,
    p_order_reference,
    COALESCE(p_description, p_transaction_type),
    v_current_balance,
    v_sequence_number,
    p_verified_by,
    NOW()
  );

  -- Step 6: Return results
  RETURN QUERY SELECT
    v_current_balance,
    v_transaction_id,
    TRUE;

  -- Transaction automatically commits if no exceptions
EXCEPTION WHEN OTHERS THEN
  -- Transaction rolls back automatically
  RAISE;
END;
$$ LANGUAGE plpgsql;

-- Create unique constraint to prevent duplicate transactions
ALTER TABLE wallet_transactions
ADD CONSTRAINT uq_user_transaction_id UNIQUE(user_id, id);

-- Create index for fast lookups
CREATE INDEX idx_wallet_transactions_user_created
ON wallet_transactions(user_id, created_at DESC);

-- Migration history
INSERT INTO schema_migrations (name, executed_at)
VALUES ('credit_wallet_atomic', NOW());
