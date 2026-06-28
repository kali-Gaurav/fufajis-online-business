# ANALYTICS & BROADCAST WORKFLOW: 25-STEP PRODUCTION HARDENING

Target: 98%+ Accuracy in Revenue Tracking & Marketing Reach.

## Phase 1: Revenue & KPI Analytics
- [ ] 1. **File Mapping:** Index `analytics_screen.dart`, `analytics_service.dart`, `order_service.dart`.
- [ ] 2. **Real-time KPI:** Ensure "Daily Sales" and "Active Orders" count updates via Streams, not just one-time fetch.
- [ ] 3. **Net Profit Calc:** Implement "Net Profit" tracking (Revenue - Cost Price - Delivery Expense).
- [ ] 4. **Item Popularity:** Display "Top 5 Sold Items" with stock-out warnings.
- [ ] 5. **Customer Retention:** Track "Repeat vs New Customer" ratio in the dashboard.

## Phase 2: Marketing & Broadcasts
- [ ] 6. **Batch Send Logic:** Harden the `sendBroadcastNotification` Cloud Function to handle 1,000+ users without timeout.
- [ ] 7. **Audience Segmentation:** Support broadcasting to specific groups (e.g., "Inactive for 30 days" or "High spenders").
- [ ] 8. **Image Broadcast:** Support attaching product images to broadcast notifications.
- [ ] 9. **Link Deep-linking:** Ensure broadcast "Action Buttons" correctly open product or coupon screens.
- [ ] 10. **Unsubscribe logic:** Implement mandatory "Opt-out" for marketing notifications to comply with play store rules.

## Phase 3: Reports & Exporting
- [ ] 11. **GST Report:** Generate monthly tax summaries (Sales vs GST Collected).
- [ ] 12. **Inventory Value:** Display "Total Stock Value" based on current purchase price (cost price).
- [ ] 13. **Rider Efficiency:** KPI for "Average Delivery Time" per rider.
- [ ] 14. **PDF Export:** Allow Owner to download "Daily Closing Report" as a PDF.
- [ ] 15. **Excel CSV:** Support exporting customer lists for external CRM usage.

## Phase 4: Data Integrity & Logging
- [ ] 16. **Event Deduplication:** Prevent double-counting of revenue during network retries.
- [ ] 17. **Security Pass:** Ensure only the Owner UID can read the `analytics` collection.
- [ ] 18. **Audit Trail:** Log which employee initiated a broadcast to prevent marketing spam.
- [ ] 19. **Failover Tracking:** Track "Notification Delivery Rate" (Sent vs Delivered vs Opened).
- [ ] 20. **Retention Analytics:** Implement "Churn Prediction" (identifying users who haven't ordered in 2 weeks).

## Phase 5: UI & Presentation
- [ ] 21. **Chart Polish:** Optimize `fl_chart` or equivalent for small screens (no label overlap).
- [ ] 22. **Time Filters:** Support "Yesterday", "Last 7 Days", and "Custom Range" pickers.
- [ ] 23. **Interactive Maps:** Show "Hotspot" areas for deliveries on a heatmap.
- [ ] 24. **Color Coding:** Use `AppTheme.success` for up-trends and `AppTheme.error` for down-trends.
- [ ] 25. **Standardization:** Final sweep to replace all standard cards/buttons with `Fj` library.
