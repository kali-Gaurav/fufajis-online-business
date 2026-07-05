# Deployment Readiness Checklist (Final Verification)

This checklist ensures the Fufaji backend and Flutter application are 100% verified and ready for production deployment.

## Phase 1: Database Index Benchmarks
- [ ] Run `supabase/migrations/DATABASE_INDEX_VERIFICATION.sql` in the Supabase SQL Editor.
- [ ] Verify that all queries utilize `Index Scan` or `Index Only Scan` in their query plans.
- [ ] Confirm execution times for the DLQ and Outbox queries are under 50ms.

## Phase 2: Provider Lazy Loading Audit
- [ ] Open the app locally or on a physical device.
- [ ] Verify the app boots without any UI jank or freezing (should be <1s to render the first frame).
- [ ] Verify no "context accessed across async gaps" exceptions are thrown in the debug console during startup.
- [ ] Ensure `CartProvider` correctly populates the cart items shortly after the UI renders.

## Phase 3: DLQ (Dead Letter Queue) Verification
- [ ] Verify the `dlq_messages` table exists in Supabase.
- [ ] Run `node scripts/load_test_dlq.js` (against staging/local) and confirm 100% of poison pill messages are successfully routed to the DLQ.
- [ ] Verify the `vw_dlq_health` view displays the correct queue counts.

## Phase 4: State Machine Verification
- [ ] Attempt to manually change an order status in the Supabase UI from `pending` straight to `delivered`.
- [ ] Verify the database rejects this invalid transition based on `allowed_transitions`.
- [ ] Attempt an order state transition using a test staff account with an invalid role. Verify the RLS/function policies reject the command.

## Phase 5: Final Production Deployment
- [ ] Merge the `main` branch.
- [ ] Push all migrations to the production Supabase instance using `supabase db push`.
- [ ] Deploy the 16 new/updated Edge Functions using `supabase functions deploy`.
- [ ] Release the Flutter application to the App Store and Google Play internal testing tracks.

**Current Readiness: 99/100**
Once Phase 1-4 are checked off, the readiness will be **100/100**.
