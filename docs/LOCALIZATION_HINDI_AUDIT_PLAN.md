# MULTI-LANGUAGE (ENGLISH/HINDI) WORKFLOW: 25-STEP PRODUCTION HARDENING

Target: 100% String Coverage for Hyperlocal Accessibility.

## Phase 1: Infrastructure & Boilerplate
- [x] 1. **File Mapping:** Locate `app_en.arb`, `app_hi.arb`, and `l10n.dart`.
- [x] 2. **Provider Sync:** Ensure `AccessibilityProvider` correctly broadcasts language changes to the `MaterialApp` widget.
- [x] 3. **Persistence:** Verify that language selection is saved to `SharedPreferences` on change.
- [x] 4. **Currency Formatting:** Standardize `NumberFormat.currency(locale: 'en_IN', symbol: '₹')` across all screens.
- [x] 5. **Date Localization:** Use `DateFormat.yMMMMd(locale)` to localize dates (e.g., "15 August" vs "15 अगस्त").

## Phase 2: Core Customer UI (i18n)
- [x] 6. **Checkout pass:** Replace all hardcoded strings in `checkout_screen.dart` with `S.of(context)`.
- [x] 7. **Product Grid pass:** Localize "In Stock", "Out of Stock", "Sale", and Unit names (kg, g, piece).
- [x] 8. **Orders history pass:** Localize all 9 status displays (Pending -> Delivered).
- [x] 9. **Category pass:** Ensure category names (Groceries, Dairy) have accurate Hindi equivalents (किराना, डेयरी). Decoupled logic IDs from display labels.
- [x] 10. **Address pass:** Localize "Home", "Work", and "Other" labels. Integrated property type classification and voice tagging UI.

## Phase 3: Owner & POS Operations (i18n)
- [ ] 11. **POS pass:** Localize "Cash", "UPI", "Split", and "Change" in `cash_register_screen.dart`.
- [ ] 12. **Analytics pass:** Localize KPI labels like "Revenue", "Order Volume", and "Customer Growth".
- [ ] 13. **Inventory pass:** Localize shelf locations ("Aisle", "Shelf") and audit status.
- [ ] 14. **Broadcast pass:** Ensure the broadcast creation UI is clear in both languages.
- [ ] 15. **Receipt pass:** Support printing bilingual thermal receipts (Receipt # / रसीद संख्या).

## Phase 4: Logistics & Rider UI (i18n)
- [ ] 16. **Delivery pass:** Localize "Mark Delivered", "Navigate", and "Arrived" for riders.
- [ ] 17. **OTP pass:** Ensure "Enter OTP" instructions are clearly translated.
- [ ] 18. **Earnings pass:** Localize complex payout terms like "Fuel Allowance" and "Incentive".
- [ ] 19. **SOS pass:** Ensure emergency labels are bold and clear in Hindi.
- [ ] 20. **Chat pass:** Implement "Canned Responses" in both languages (e.g., "I have reached" / "मैं पहुँच गया हूँ").

## Phase 5: Testing & Quality
- [ ] 21. **Overflow pass:** Test for text-wrapping issues in Hindi (Hindi strings are often 30% longer than English).
- [ ] 22. **Pluralization:** Implement `plural` logic in ARB files for item counts (1 item vs 2+ items).
- [ ] 23. **Placeholder Audit:** Ensure dynamic data like `{name}` is correctly escaped in translations.
- [ ] 24. **Accessibility pass:** Verify Semantics/TalkBack labels for elderly users in Hindi.
- [ ] 25. **Final Sweep:** Global search for any remaining `""` (double quotes) containing user-visible English text.
