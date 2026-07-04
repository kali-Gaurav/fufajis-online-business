# Migration Progress

- `order_service.dart`: Replaced Firebase Cloud Functions calls (`changeOrderStatus`, `failOrderDelivery`, `resolveDeliveryException`, `processCheckout`) with `SupabaseConfig.client.functions.invoke`.
- `delivery_verification_service.dart`: Replaced `verifyDeliveryOTP` with Supabase edge function call.
- `smart_dispatch_screen.dart`: Replaced `dispatchCluster` Firebase call with Supabase edge function call.
- Deleted `changeOrderStatus.js`, `failOrderDelivery.js`, `resolveDeliveryException.js`, `dispatchCluster.js`, `verifyDeliveryOtp.js`, `processCheckout.js` from `functions/src/`.
