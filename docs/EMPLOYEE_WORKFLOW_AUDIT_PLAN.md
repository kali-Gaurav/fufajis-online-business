# EMPLOYEE WORKFLOW: 25-STEP PRODUCTION HARDENING

Target: 96%+ Operational Efficiency for Store Staff.

## Phase 1: Picking & Packing
- [ ] 1. **File Mapping:** Index `order_packing_screen.dart`, `packing_terminal_screen.dart`, `scanner_service.dart`.
- [ ] 2. **Item Scanning:** Force barcode scan for high-value items during packing to ensure accuracy.
- [ ] 3. **Weight Verification:** Support "Variable Weight" items (e.g., 1.2kg Onion) with manual weight entry.
- [ ] 4. **Substitution Flow:** Implement "Call Customer" or "Send Photo" directly from the packing screen for out-of-stock items.
- [ ] 5. **Packing Photo Proof:** Mandate a photo of the open parcel before sealing (Cloud Storage link).

## Phase 2: Inventory & Shelving
- [ ] 6. **Shelf Location:** Display "Aisle/Shelf" numbers in the picking list to reduce search time.
- [ ] 7. **Refill Logic:** Trigger "Refill Task" when a picker reports "Last item taken" from the shelf.
- [ ] 8. **Damage Reporting:** Integrate rapid photo-upload for items found damaged during picking.
- [ ] 9. **Transfer Verification:** Use QR scans to verify stock moving from "Warehouse" to "Shelf".
- [ ] 10. **Expiry Check:** Mandate a "Batch/Expiry" entry for dairy and bakery items during receiving.

## Phase 3: Hardware & Performance
- [ ] 11. **Continuous Scanner:** Port the `ContinuousScannerDialog` logic to the picking list.
- [ ] 12. **Offline Picklist:** Allow employees to download picklists for large stores with no Wi-Fi zones.
- [ ] 13. **Zebra/Honeywell Integration:** Ensure compatibility with dedicated hardware scan buttons (KeyEvent listener).
- [ ] 14. **Thermal Labels:** Support printing "Parcel Labels" (Order # + QR) from the packing terminal.
- [ ] 15. **Haptic Pick:** Use distinct vibrations for "Correct Item" (Heavy) vs "Wrong Item" (Triple Vibrate).

## Phase 4: Tasks & Priorities
- [ ] 16. **Task Board:** Implement a Kanban board for employees (Pending -> Picking -> Packing -> Ready).
- [ ] 17. **Priority Sort:** Sort picklists by "Fastest Delivery" or "Perishable Items" first.
- [ ] 18. **Employee Chat:** Harden the "Picker to Owner" chat for missing item approvals.
- [ ] 19. **Performance KPI:** Track "Items per minute" picking speed for staff incentives.
- [ ] 20. **Error Boundaries:** Add `FjErrorState` to recovery from Firebase disconnects during audit.

## Phase 5: Security & UI
- [ ] 21. **Access Control:** Restrict Employee access to "Inventory Only" (block Earnings/Settlements).
- [ ] 22. **Attendance Wall:** Block picking actions if the employee hasn't "Clocked In" for the day.
- [ ] 23. **Small Screen pass:** Ensure the packing list items don't overlap on 320dp screens.
- [ ] 24. **Multi-language:** Verify that "Aisle/Shelf" labels are translated to Hindi.
- [ ] 25. **Final Clean:** Polish all buttons/cards to `FjButton` and `FjCard`.
