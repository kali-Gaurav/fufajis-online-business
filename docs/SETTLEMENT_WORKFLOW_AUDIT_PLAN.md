# SETTLEMENT & LEDGER WORKFLOW: 25-STEP PRODUCTION HARDENING

Target: 98%+ Financial Integrity for Shop Settlements.

## Phase 1: Submission & Verification
- [ ] 1. **File Mapping:** Index `settlements_management.dart`, `cod_settlement_model.dart`, `rider_payout_service.dart`.
- [ ] 2. **Double-Submission Lock:** Prevent a rider from submitting two settlements for the same amount/day until one is processed.
- [ ] 3. **Image Proof:** Mandate a "Cash Photo" or "Register Screenshot" for settlements > ₹2,000.
- [ ] 4. **Denomination Breakdown:** Add UI for entering cash denominations (2000x, 500x, etc.) for accuracy.
- [ ] 5. **Rider Notification:** Send immediate WhatsApp/Push when a settlement is approved or rejected.

## Phase 2: Reconciliation & Integrity
- [ ] 6. **Atomic Balance Deduct:** Verify `runTransaction` usage when approval decrements the rider's `currentCashBalance`.
- [ ] 7. **Conflict Audit:** Log every rejection reason to a separate `settlement_disputes` collection.
- [ ] 8. **Manual Adjustment:** Implement "Owner Adjustment" (e.g., deducting ₹50 if short) with balance correction.
- [ ] 9. **Daily Closing:** Add "EOD (End of Day) Summary" that aggregates POS Cash + Rider Cash.
- [ ] 10. **Bank Deposit Log:** Track when cash is physically deposited into the bank by the owner.

## Phase 3: Instant Payouts (Razorpay Route)
- [ ] 11. **Rider Payout UI:** Polish `delivery_earnings_screen.dart` to show "Payable Balance" clearly.
- [ ] 12. **Auto-Payout:** Implement logic for "One-tap Instant Payout" via Razorpay Route API.
- [ ] 13. **Payout Threshold:** Enforce a minimum payout of ₹100 to prevent micro-transaction fees.
- [ ] 14. **Bank Account Validation:** Add IFSC/Account validation UI before a rider can request a payout.
- [ ] 15. **Payout History:** Standardized `FjCard` list for all historical rider payments.

## Phase 4: Customer Refunds & Wallet
- [ ] 16. **Wallet Reconciliation:** Cross-check order cancellations vs. wallet credits to prevent balance leakage.
- [ ] 17. **Manual Wallet Credit:** Implement Owner UI for "Loyalty/Bonus Credit" with expiration dates.
- [ ] 18. **Transaction Ledger:** Ensure every wallet move has a `WalletTransaction` entry (Event Sourcing).
- [ ] 19. **Refund ID Mapping:** Link every refund directly to a Razorpay Payment ID if applicable.
- [ ] 20. **Admin Dispute Hub:** Create a screen for Admin to resolve disputes between Owner and Customer.

## Phase 5: Reporting & Bahi Khata
- [ ] 21. **PDF Export:** Generate monthly settlement PDF reports for the owner.
- [ ] 22. **Chart Analytics:** Visualize weekly cash collection vs. online sales.
- [ ] 23. **Floating Balance:** Highlight "Cash in Hand" vs. "Cash in Bank" in the dashboard.
- [ ] 24. **Multi-branch Settlement:** Support branch-wise settlement sorting.
- [ ] 25. **Security Pass:** Enforce RBAC (Role-Based Access Control) — only Owners/Admins see the Settlement Hub.
