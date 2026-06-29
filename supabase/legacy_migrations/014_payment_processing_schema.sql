-- Payment Processing Database Schemas (Module 7)

-- Master payment ledger record
CREATE TABLE IF NOT EXISTS payment_ledger (
    payment_id VARCHAR(128) PRIMARY KEY,
    order_id VARCHAR(128) NOT NULL,
    customer_id VARCHAR(128) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'INR',
    payment_method VARCHAR(50) NOT NULL, -- 'razorpay', 'upi', 'cod', 'wallet', 'credit'
    status VARCHAR(50) NOT NULL, -- 'pending', 'success', 'failed', 'refunded', 'disputed'
    razorpay_payment_id VARCHAR(128),
    razorpay_order_id VARCHAR(128),
    needs_reconciliation BOOLEAN DEFAULT FALSE,
    failure_reason TEXT,
    resolved_by VARCHAR(128),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Every payment attempt details
CREATE TABLE IF NOT EXISTS payment_attempts (
    id SERIAL PRIMARY KEY,
    payment_id VARCHAR(128) NOT NULL REFERENCES payment_ledger(payment_id) ON DELETE CASCADE,
    gateway_name VARCHAR(50) NOT NULL, -- 'razorpay', 'stripe', 'upi_intent'
    gateway_payment_id VARCHAR(128),
    gateway_order_id VARCHAR(128),
    status VARCHAR(50) NOT NULL,
    failure_code VARCHAR(100),
    failure_message TEXT,
    payload_response JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Server-side signature & status verification audit trail
CREATE TABLE IF NOT EXISTS payment_verifications (
    id SERIAL PRIMARY KEY,
    payment_id VARCHAR(128) NOT NULL REFERENCES payment_ledger(payment_id) ON DELETE CASCADE,
    verification_type VARCHAR(50) NOT NULL, -- 'signature_verification', 'webhook_reconciliation', 'orphan_scanner'
    is_signature_valid BOOLEAN NOT NULL,
    checked_payload JSONB,
    verified_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Refund ledger records with method-specific routing
CREATE TABLE IF NOT EXISTS refund_ledger (
    refund_id VARCHAR(128) PRIMARY KEY,
    order_id VARCHAR(128) NOT NULL,
    customer_id VARCHAR(128) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    refund_method VARCHAR(50) NOT NULL, -- 'wallet', 'gateway', 'bank'
    status VARCHAR(50) NOT NULL, -- 'pending', 'approved', 'processing', 'completed', 'failed'
    approved_by VARCHAR(128),
    gateway_refund_id VARCHAR(128),
    bank_account_holder_name VARCHAR(255),
    bank_account_number VARCHAR(128),
    bank_ifsc VARCHAR(50),
    payout_id VARCHAR(128),
    idempotency_key VARCHAR(128) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE
);

-- Reconciliation logs between Razorpay, Firestore, and RDS
CREATE TABLE IF NOT EXISTS reconciliation_logs (
    id SERIAL PRIMARY KEY,
    recon_type VARCHAR(50) NOT NULL, -- 'user_wallet', 'system_wide', 'gateway'
    level INT NOT NULL, -- 1, 2, 3
    user_id VARCHAR(128),
    stored_amount NUMERIC(12, 2) NOT NULL,
    calculated_amount NUMERIC(12, 2) NOT NULL,
    difference NUMERIC(12, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'UNRESOLVED', -- 'UNRESOLVED', 'RESOLVED'
    resolved_by VARCHAR(128),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- COD collections and settlements tracking
CREATE TABLE IF NOT EXISTS cod_settlements_rds (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(128) NOT NULL,
    rider_id VARCHAR(128) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'collected', -- 'collected', 'settled', 'disputed'
    collected_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    settled_at TIMESTAMP WITH TIME ZONE,
    settled_by_owner_id VARCHAR(128)
);

-- Rider payout records with Razorpay Route / Transfer references
CREATE TABLE IF NOT EXISTS rider_payouts_rds (
    payout_id VARCHAR(128) PRIMARY KEY,
    rider_id VARCHAR(128) NOT NULL,
    rider_name VARCHAR(255) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'INR',
    status VARCHAR(50) NOT NULL, -- 'pending', 'processed', 'failed'
    transaction_id VARCHAR(128), -- Razorpay transfer / payout ID
    type VARCHAR(50) DEFAULT 'instant_settlement',
    branch_id VARCHAR(128) DEFAULT 'system',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Razorpay dispute/chargeback tracking
CREATE TABLE IF NOT EXISTS payment_disputes_rds (
    dispute_id VARCHAR(128) PRIMARY KEY,
    payment_id VARCHAR(128) REFERENCES payment_ledger(payment_id) ON DELETE SET NULL,
    amount NUMERIC(10, 2) NOT NULL,
    reason VARCHAR(100),
    status VARCHAR(50) NOT NULL, -- 'open', 'under_review', 'won', 'lost', 'closed'
    evidence_deadline TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Wallet credit/debit audit trail
CREATE TABLE IF NOT EXISTS wallet_ledger (
    transaction_id VARCHAR(128) PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'cashback', 'rewardPointsRedeemed', 'walletPayment', 'refund', 'referralBonus', 'reviewBonus', 'firstOrderBonus'
    order_reference VARCHAR(128),
    description TEXT,
    balance_after NUMERIC(10, 2) NOT NULL,
    sequence_number INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes to optimize performance and queries
CREATE INDEX IF NOT EXISTS idx_payment_ledger_order ON payment_ledger(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_ledger_customer ON payment_ledger(customer_id);
CREATE INDEX IF NOT EXISTS idx_payment_ledger_status ON payment_ledger(status);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_payment ON payment_attempts(payment_id);
CREATE INDEX IF NOT EXISTS idx_refund_ledger_order ON refund_ledger(order_id);
CREATE INDEX IF NOT EXISTS idx_refund_ledger_customer ON refund_ledger(customer_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_logs_status ON reconciliation_logs(status);
CREATE INDEX IF NOT EXISTS idx_cod_settlements_rider ON cod_settlements_rds(rider_id);
CREATE INDEX IF NOT EXISTS idx_rider_payouts_rider ON rider_payouts_rds(rider_id);
CREATE INDEX IF NOT EXISTS idx_wallet_ledger_user ON wallet_ledger(user_id);
