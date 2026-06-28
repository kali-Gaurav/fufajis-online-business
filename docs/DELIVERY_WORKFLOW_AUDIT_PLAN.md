# DELIVERY WORKFLOW: 25-STEP PRODUCTION HARDENING

Target: 95%+ Production Readiness for Reliable Hyperlocal Fulfillment.

## Phase 1: Dispatch & Assignment
- [ ] 1. **File Mapping:** Index `delivery_orders_screen.dart`, `fleet_service.dart`, `delivery_provider.dart`.
- [ ] 2. **Assignment Logic:** Verify `findNearestActiveRider` logic handles edge cases (no riders online).
- [ ] 3. **Batch Dispatch:** Implement UI for dispatching multiple orders to a single rider in one click.
- [ ] 4. **Rider Acceptance:** Harden the "Accept/Reject" flow with a 2-minute auto-unassign timer.
- [ ] 5. **Queue Management:** Add "Order Stacking" logic (max 3 active orders per rider).

## Phase 2: Navigation & Tracking
- [ ] 6. **Live Maps Integration:** Verify Google Maps API usage for rider navigation.
- [ ] 7. **Battery Efficiency:** Optimize GPS update intervals (e.g., 5s when moving, 30s when stationary).
- [ ] 8. **Offline Tracking:** Implement local buffer for GPS pings when the rider enters a dead zone.
- [ ] 9. **Route Optimization:** Implement "Multi-stop" route sorting for batch deliveries.
- [ ] 10. **Eta Calculation:** Hardened server-side ETA estimation based on distance/speed.

## Phase 3: Proof of Delivery (POD)
- [ ] 11. **Geofence Check:** Enforce 50m proximity lock for "Mark Arrived" and "Deliver" actions.
- [ ] 12. **OTP Verification:** Polish the OTP entry UI with auto-focus and clear errors.
- [ ] 13. **Photo Proof:** Mandate "Parcel Photo" for no-contact deliveries.
- [ ] 14. **Customer Signature:** Add digital signature canvas for high-value orders.
- [ ] 15. **Payment Collection:** Ensure "Mark Delivered" triggers immediate cash ledger entry for COD.

## Phase 4: Rider Safety & Compliance
- [ ] 16. **Cash Limit Enforcement:** Block order pickup if rider cash > ₹5,000.
- [ ] 17. **Attendance Geofence:** Require rider to be within 1km of branch to "Clock In".
- [ ] 18. **Vehicle Check:** Add a daily mandatory vehicle safety checklist during Clock In.
- [ ] 19. **SOS Button:** Implement "Panic/SOS" button with direct dial to owner + location broadcast.
- [ ] 20. **Device State:** Track rider battery level and alert owner if it drops below 15%.

## Phase 5: Settlement & Analytics
- [ ] 21. **Instant Payouts:** Verify Razorpay Route integration for "Pay per Delivery" models.
- [ ] 22. **Distance Audit:** Cross-verify GPS-tracked distance vs. Straight-line distance for payout.
- [ ] 23. **Rider Performance:** Implement "On-time Delivery" and "Customer Rating" KPI tracking.
- [ ] 24. **In-app Chat:** Harden the "Rider to Customer" chat with canned responses (e.g., "I'm outside").
- [ ] 25. **UI Standardization:** Final pass on `FjButton`, `FjCard`, and error handling across all rider screens.
