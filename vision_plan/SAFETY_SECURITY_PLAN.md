# 🛡️ Safety & Security Architecture

Protecting the business and the trust of the customers.

## 1. Fraud Prevention (Suraksha)
*   **COD Verification**: For high-value orders from new customers, an automated IVR call or OTP is required to confirm the order.
*   **Geofencing**: Orders can only be placed from within the serviced village boundaries to prevent "prank" orders from far away.
*   **Rider Deposit Tracking**: Real-time tracking of cash held by riders to ensure daily settlements are accurate.

## 2. Product Safety & Expiry
*   **First-In-First-Out (FIFO) Automation**: The system automatically discounts items that are 2 days away from expiry to ensure Fufaji doesn't lose money on wastage.
*   **Expiry Block**: Items past expiry date are automatically hidden from the storefront—Fufaji doesn't have to manually check.

## 3. Data Privacy
*   **Masked Numbers**: Riders see the location but not the customer's full phone number (accessible only via in-app calling) to protect customer privacy.
*   **Secure Backups**: Daily encrypted backups of the "Bahi-Khata" (Credit Ledger) so Fufaji never loses his records even if a phone is lost.

## 4. Emergency Modes
*   **Panic Button**: A "Shop Emergency" toggle in the owner app that instantly pauses all incoming orders and notifies staff if something goes wrong at the physical store.
*   **Automatic Backup Power Logic**: App detects low battery on the owner's device and warns: *"Fufaji, your phone is dying. Charge it so you don't miss orders!"*
