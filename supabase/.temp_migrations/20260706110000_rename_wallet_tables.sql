-- Rename wallet_balance to wallets
ALTER TABLE IF EXISTS wallet_balance RENAME TO "WALLETS";

-- Rename wallet_transactions to wallet_transactions (uppercase as requested)
ALTER TABLE IF EXISTS wallet_transactions RENAME TO "WALLET_TRANSACTIONS";

-- Drop existing indexes and recreate them on the new tables
DROP INDEX IF EXISTS idx_wallet_balance_user;
DROP INDEX IF EXISTS idx_wallet_balance_shop;

CREATE INDEX IF NOT EXISTS idx_wallets_user ON "WALLETS"(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_shop ON "WALLETS"(shop_id);

-- Also ensure that we update the reference for foreign keys if needed, 
-- but Postgres handles table renaming automatically for foreign keys.
