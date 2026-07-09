-- ============================================================================
-- FIRESTORE DOWNSTREAM SYNC TRIGGERS FOR WALLET
-- ============================================================================
-- Purpose: Setup PostgreSQL triggers to automatically call the Edge Function
--          `sync-to-firestore` whenever a wallet balance or transaction changes.
-- ============================================================================

-- Create triggers for the relevant tables
DROP TRIGGER IF EXISTS sync_wallet_balance_to_firestore_trigger ON public.wallet_balance;
CREATE TRIGGER sync_wallet_balance_to_firestore_trigger
  AFTER INSERT OR UPDATE ON public.wallet_balance
  FOR EACH ROW EXECUTE FUNCTION public.notify_firestore_sync();

DROP TRIGGER IF EXISTS sync_wallet_transactions_to_firestore_trigger ON public.wallet_transactions;
CREATE TRIGGER sync_wallet_transactions_to_firestore_trigger
  AFTER INSERT ON public.wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION public.notify_firestore_sync();
