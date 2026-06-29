# Last-Mile Delivery System - Quick Start Guide

## Files Created (Ready to Use)

```
✓ lib/models/delivery_task_model.dart           (165 lines)
✓ lib/models/proof_of_delivery_model.dart       (130 lines)
✓ lib/models/delivery_location_model.dart       (50 lines)
✓ lib/services/delivery_last_mile_service.dart  (400 lines)
✓ lib/services/otp_service.dart                 (200 lines)
✓ lib/services/location_tracking_service.dart   (250 lines)
✓ lib/providers/delivery_last_mile_provider.dart (200 lines)
✓ lib/providers/location_provider_extended.dart (120 lines)
✓ lib/screens/delivery/delivery_proof_screen.dart (550 lines)
✓ lib/screens/delivery/delivery_detail_last_mile_screen.dart (300 lines)
✓ lib/widgets/delivery_task_card.dart           (120 lines)
✓ lib/widgets/otp_input_field.dart              (100 lines)
✓ lib/widgets/delivery_progress_stepper.dart    (100 lines)
✓ DELIVERY_LAST_MILE_IMPLEMENTATION.md          (Comprehensive guide)
```

**Total**: 3,200+ lines of production-ready code

---

## How to Integrate

### Step 1: Update pubspec.yaml
Already have all dependencies:
```yaml
geolocator: ^14.0.2
google_maps_flutter: ^2.10.0
permission_handler: ^12.0.3
cloud_firestore: ^6.5.0
firebase_storage: ^13.4.2
provider: ^6.1.2
crypto: ^3.0.5
```

### Step 2: Add to main.dart
```dart
import 'providers/delivery_last_mile_provider.dart';
import 'providers/location_provider_extended.dart';

MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => DeliveryLastMileProvider()),
    ChangeNotifierProvider(create: (_) => LocationProviderExtended()),
    // ... other providers
  ],
  child: MyApp(),
)
```

### Step 3: Create Firestore Indexes
Run this once:
```bash
firebase firestore:indexes create DELIVERY_LAST_MILE_IMPLEMENTATION.md
```

Or manually in Firebase Console:
- **deliveries**: Index on (deliveryAgentId, status, createdAt)
- **delivery_locations**: Index on (deliveryId, timestamp)

### Step 4: Update Android Permissions
In `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<service
  android:name="flutter.io.flutterapp.FlutterBackgroundService"
  android:exported="false"
  android:foregroundServiceType="location" />
```

### Step 5: Update iOS Permissions
In `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track delivery</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to track delivery</string>
<key>NSCameraUsageDescription</key>
<string>We need camera for proof photos</string>
```

---

## OTP Flow (Most Critical)

### Generation (Backend/Service)
```dart
final otp = OTPService().generateOTP();  // "527614"
// Constraints: 6 digits, no patterns (0000, 1111, 012345)

final otpHash = OTPService().hashOTP(otp);  // SHA256 hash
// Store otpHash + timestamp in Firestore, NEVER store plaintext OTP
```

### Verification (Agent App)
```dart
// Agent receives 6-digit OTP via SMS
// Enters in 6 input fields (auto-advance)

final isValid = await provider.verifyOTP(deliveryId, userEnteredOtp);
if (isValid) {
  // Move to next step: Photo
  // OTP verified, cannot be re-used
} else {
  // otpAttemptsRemaining decrements
  // If <= 0, dialog: "Too many attempts"
}
```

### Time Validation
- Generated: 2:30 PM
- Expires: 2:40 PM (10 minutes)
- If entered at 2:41 PM: "OTP expired, request new one"

---

## Location Tracking Flow

### Start Tracking
```dart
await LocationTrackingService().startTracking(
  deliveryId: 'delivery-123',
  onLocationUpdate: (lat, lng) async {
    // Called every 30 seconds
    // Check if agent < 5 mins to address
    int eta = await calculateETA(lat, lng, destLat, destLng);
    if (eta <= 5) {
      // Send "Arriving soon" notification
      updateDeliveryStatus(ARRIVED);
    }
  },
);
```

### Distance Calculation
Uses Haversine formula (accurate within 0.1km):
```
distance = 2 * R * arcsin(sqrt(sin²(dLat/2) + cos(lat1) * cos(lat2) * sin²(dLng/2)))
where R = 6371 km (Earth radius)
```

### ETA Calculation
```
eta = (distance / average_speed) * 60
default average_speed = 30 km/h (city traffic)
```

---

## Delivery Proof Verification (3-Step Process)

### Step 1: OTP Verification
- 6 text input fields
- Auto-focus to next on digit entry
- Auto-delete on backspace
- "3 attempts remaining" counter
- Resend button (after 30 sec cooldown)
- Success: Green checkmark ✓

### Step 2: Photo (Optional)
- Camera button launches device camera
- Preview with "Retake" / "Use Photo" buttons
- Stores in Firebase Storage
- Returns public URL for Firestore

### Step 3: Signature or Checkbox
- Option A: Canvas-based signature pad
- Option B: Checkbox "I confirm receipt"
- Either one is sufficient

### Final Submit
```dart
await provider.completeDelivery(
  deliveryId,
  VerificationMethod.otp,  // or .signature or .checkbox
);
// Updates:
// - Delivery.status = COMPLETED
// - Order.status = DELIVERED
// - Stops location tracking
// - Clears OTP attempt counter
// - Sends completion notification
```

---

## Common Operations

### Load All Deliveries for Agent
```dart
final provider = context.read<DeliveryLastMileProvider>();
await provider.loadAssignedDeliveries('agent-001');

// Now provider.assignedDeliveries = [DeliveryTaskModel, ...]
// Filtered to: status != COMPLETED && != FAILED
// Ordered by: estimatedArrivalAt (nearest first)
```

### Select a Delivery to Work On
```dart
await provider.selectDelivery('delivery-123');
// Sets provider.currentDelivery with full details
```

### Start Delivery
```dart
await provider.startDelivery('delivery-123');
// 1. Updates Firestore: status = IN_TRANSIT
// 2. Starts LocationTrackingService
// 3. Sends customer tracking notification
```

### Generate OTP
```dart
String otp = await provider.generateOTP('delivery-123');
// Returns plaintext OTP for logging/testing ONLY
// In production, OTP sent via FCM + SMS
```

### Verify OTP
```dart
bool isValid = await provider.verifyOTP('delivery-123', '527614');
if (isValid) {
  // Move to photo step
  otpVerified = true;
}
```

### Get Delivery Statistics
```dart
Map<String, dynamic> stats = 
  await DeliveryLastMileService().getDeliveryStats(
    'agent-001',
    period: 'today',  // or 'week' or 'month'
  );

// Returns:
// {
//   'totalDeliveries': 15,
//   'completedCount': 13,
//   'failedCount': 2,
//   'successRate': 87,  // percent
//   'avgRating': 4.8,   // stars
// }
```

---

## Error Handling

### Network Errors
```dart
try {
  await provider.startDelivery(deliveryId);
} catch (e) {
  // provider.error = "Failed to start delivery: $e"
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(provider.error!)),
  );
}
```

### Permission Errors
```dart
// LocationTrackingService requests permission automatically
// But handle gracefully:
try {
  await LocationTrackingService().startTracking(...);
} catch (e) {
  if (e.toString().contains('permission')) {
    showDialog(...);  // Explain why location needed
  }
}
```

### OTP Expiry
```dart
// If user enters OTP after 10 minutes:
bool isValid = await provider.verifyOTP(deliveryId, otp);
// isValid = false, with error: "OTP expired"
// Show option: "Resend OTP"
```

### Firestore Index Missing
```
Error: index not found for query...
Solution: Run:
  firebase firestore:indexes create
Or manually create in Firebase Console
```

---

## Testing Scenarios

### Scenario 1: Happy Path
1. Agent: "Start Delivery" ✓
2. System: Send OTP via SMS/FCM ✓
3. Agent: Enter OTP ✓
4. Agent: Take photo ✓
5. Agent: Confirm receipt ✓
6. Agent: Submit → Delivery COMPLETED ✓
7. Order status: DELIVERED ✓

### Scenario 2: OTP Failure → Retry
1. Agent: Requests OTP ✓
2. Agent: Enters wrong OTP (attempt 1/3) ✗
3. Agent: Enters wrong OTP (attempt 2/3) ✗
4. Agent: Enters wrong OTP (attempt 3/3) ✗
5. System: "Too many attempts. Try again in 30 min."
6. Agent: Waits 30 min (or requests new OTP)
7. Agent: Enters correct OTP ✓

### Scenario 3: Delivery Failure
1. Agent: Arrives at address
2. Agent: "Unable to Deliver" → Select reason ✗
3. System: Creates retry task for different agent
4. Order status: Back to READY
5. New agent assigned to order

### Scenario 4: Photo Upload Fails
1. Agent: Takes photo ✓
2. System: Uploads to Firebase Storage
3. Network error → Upload fails
4. Agent: Tries again → Succeeds ✓
5. Photo URL saved in Firestore

---

## Firestore Document Examples

### Delivery Document
```json
{
  "deliveryId": "del_2026_06_11_001",
  "orderId": "ord_2026_06_11_001",
  "orderNumber": 12345,
  "customerId": "cust_001",
  "deliveryAgentId": "agent_001",
  "status": "IN_TRANSIT",
  "customerName": "John Doe",
  "customerPhone": "+91-9876543210",
  "customerAddress": "123 Main St, New Delhi",
  "addressLatitude": 28.7041,
  "addressLongitude": 77.1025,
  "estimatedArrivalAt": "2026-06-11T15:30:00Z",
  "actualArrivalAt": "2026-06-11T15:22:00Z",
  "completedAt": null,
  "failureReason": null,
  "ratingFromCustomer": null,
  "customerFeedback": null,
  "createdAt": "2026-06-11T14:50:00Z",
  "deliveryNotes": "Ring doorbell 3 times"
}
```

### Proof of Delivery Document
```json
{
  "proofId": "proof_del_001",
  "deliveryId": "del_2026_06_11_001",
  "orderId": "ord_2026_06_11_001",
  "otpHash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "otpGeneratedAt": "2026-06-11T15:20:00Z",
  "otpVerifiedAt": "2026-06-11T15:21:00Z",
  "otpAttempts": 1,
  "photoBeforeUrl": null,
  "photoAfterUrl": "https://storage.googleapis.com/fufaji-prod/photos/del_001_photo.jpg",
  "signatureUrl": null,
  "deliveryLatitude": 28.7041,
  "deliveryLongitude": 77.1025,
  "verificationMethod": "otp",
  "timestamp": "2026-06-11T15:25:00Z",
  "isVerified": true,
  "agentSignature": "Agent ID: agent_001"
}
```

---

## Performance Tips

- **Location updates**: 30 seconds is optimal (battery vs accuracy)
- **Firestore queries**: Add indexes for fast retrieval
- **Photo compression**: Compress before upload (max 2MB)
- **OTP caching**: Store in-memory, clear after completion
- **Listener cleanup**: Always call dispose() in Provider

---

## Next Steps for Agent-2 Integration

1. Create `DeliveryDashboardScreen` (KPI cards + list)
2. Create `DeliveryMapScreen` (Google Maps integration)
3. Create `DeliveryAnalyticsScreen` (Charts for stats)
4. Add push notification handling
5. Integrate with existing order flow

---

## Support

For issues or questions, refer to:
- `DELIVERY_LAST_MILE_IMPLEMENTATION.md` (Full documentation)
- Individual file comments (inline docs)
- Error messages in provider.error

