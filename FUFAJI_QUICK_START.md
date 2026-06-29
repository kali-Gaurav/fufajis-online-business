# ⚡ FUFAJI STORE - QUICK START GUIDE FOR ANDROID STUDIO AI

**For: Android Studio / Development Team**  
**Share this with your AI code generator / Android Studio AI**

---

## 📁 PROJECT STRUCTURE TO CREATE

```
FujafiStore/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/fufaji/store/
│   │   │   │   ├── activities/
│   │   │   │   │   ├── LoginActivity.java
│   │   │   │   │   ├── HomeActivity.java
│   │   │   │   │   ├── ProductDetailActivity.java
│   │   │   │   │   ├── CartActivity.java
│   │   │   │   │   ├── CheckoutActivity.java
│   │   │   │   │   ├── OrderHistoryActivity.java
│   │   │   │   │   ├── OwnerDashboardActivity.java
│   │   │   │   │   ├── InventoryActivity.java
│   │   │   │   │   └── OrderManagementActivity.java
│   │   │   │   ├── adapters/
│   │   │   │   │   ├── ProductAdapter.java
│   │   │   │   │   ├── CartAdapter.java
│   │   │   │   │   └── OrderAdapter.java
│   │   │   │   ├── models/
│   │   │   │   │   ├── User.java
│   │   │   │   │   ├── Product.java
│   │   │   │   │   ├── Order.java
│   │   │   │   │   ├── CartItem.java
│   │   │   │   │   └── Employee.java
│   │   │   │   ├── services/
│   │   │   │   │   ├── FirebaseService.java
│   │   │   │   │   ├── StripeService.java
│   │   │   │   │   ├── NotificationService.java
│   │   │   │   │   └── AuthService.java
│   │   │   │   ├── utils/
│   │   │   │   │   ├── Constants.java
│   │   │   │   │   ├── PricingUtils.java (GST calculation)
│   │   │   │   │   ├── ValidationUtils.java
│   │   │   │   │   └── SharedPrefUtils.java
│   │   │   │   └── MainActivity.java (entry point)
│   │   │   ├── res/
│   │   │   │   ├── layout/
│   │   │   │   │   ├── activity_login.xml
│   │   │   │   │   ├── activity_home.xml
│   │   │   │   │   ├── activity_cart.xml
│   │   │   │   │   ├── activity_checkout.xml
│   │   │   │   │   ├── activity_owner_dashboard.xml
│   │   │   │   │   └── ... (other layouts)
│   │   │   │   ├── drawable/
│   │   │   │   │   ├── ic_home.xml
│   │   │   │   │   ├── ic_cart.xml
│   │   │   │   │   └── ... (icons)
│   │   │   │   ├── values/
│   │   │   │   │   ├── strings.xml (English)
│   │   │   │   │   ├── strings-hi.xml (Hindi)
│   │   │   │   │   ├── colors.xml
│   │   │   │   │   ├── dimens.xml
│   │   │   │   │   └── styles.xml
│   │   │   │   └── menu/
│   │   │   │       └── bottom_navigation.xml
│   │   │   └── AndroidManifest.xml
│   │   └── test/ (unit tests)
│   ├── build.gradle
│   └── proguard-rules.pro
├── build.gradle (project)
├── settings.gradle
├── gradle.properties
└── README.md
```

---

## 🔧 BUILD SETUP INSTRUCTIONS

### Step 1: Dependencies (build.gradle - App Level)

```gradle
dependencies {
    // Firebase
    implementation 'com.google.firebase:firebase-auth:22.3.1'
    implementation 'com.google.firebase:firebase-firestore:24.10.0'
    implementation 'com.google.firebase:firebase-storage:20.3.0'
    implementation 'com.google.firebase:firebase-messaging:23.4.0'
    implementation 'com.google.firebase:firebase-analytics:21.5.0'

    // Stripe (Payment)
    implementation 'com.stripe:stripe-android:20.40.0'

    // UI Components
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
    implementation 'com.google.android.material:material:1.11.0'
    implementation 'androidx.recyclerview:recyclerview:1.3.2'

    // Image Loading
    implementation 'com.squareup.picasso:picasso:2.8'
    // Alternative: implementation 'com.github.bumptech.glide:glide:4.16.0'

    // Network
    implementation 'com.squareup.okhttp3:okhttp:4.11.0'
    implementation 'com.google.code.gson:gson:2.10.1'

    // Local Storage
    implementation 'androidx.datastore:datastore-preferences:1.0.0'
    // Alternative: implementation 'com.google.android.gms:play-services-base:18.3.0'

    // Maps (for Delivery Partner)
    implementation 'com.google.android.gms:play-services-maps:18.2.0'
    implementation 'com.google.android.gms:play-services-location:21.1.0'

    // Logging
    implementation 'com.jakewharton.timber:timber:5.0.1'

    // Testing
    testImplementation 'junit:junit:4.13.2'
    androidTestImplementation 'androidx.test.espresso:espresso-core:3.5.1'
}

android {
    compileSdk 34
    
    defaultConfig {
        applicationId "com.fufaji.store"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }

    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    buildFeatures {
        dataBinding true
        viewBinding true
    }
}

apply plugin: 'com.google.gms.google-services'
```

### Step 2: AndroidManifest.xml Permissions

```xml
<manifest ...>
    <!-- Network -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <!-- Location (for Delivery Partner) -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <!-- Phone State (for OTP) -->
    <uses-permission android:name="android.permission.READ_PHONE_STATE" />
    <uses-permission android:name="android.permission.READ_SMS" />
    <uses-permission android:name="android.permission.RECEIVE_SMS" />

    <!-- Camera (optional, for future) -->
    <uses-permission android:name="android.permission.CAMERA" />

    <!-- Storage (for image upload) -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

    <application
        android:name=".FujafiApplication"
        ... >

        <activity android:name=".activities.LoginActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <activity android:name=".activities.HomeActivity"
            android:exported="false" />
        
        <!-- Other activities -->

        <!-- Firebase Messaging Service -->
        <service android:name=".services.MyFirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>

    </application>
</manifest>
```

---

## 🚀 CORE FUNCTIONALITY CHECKLIST

### Authentication (Firebase Phone OTP)
```
✅ LoginActivity
   ├─ Phone number input (validation: 10 digits, format: +91XXXXXXXXXX)
   ├─ "Send OTP" button
   ├─ OTP input screen (6 digits)
   ├─ Firebase PhoneAuthProvider integration
   ├─ Auto-fill OTP (if available)
   └─ Error handling (wrong OTP, network error, timeout)

✅ User Profile Creation (first-time login)
   ├─ Name input
   ├─ Email (optional)
   ├─ Save to Firestore users/{uid}
   └─ Redirect to HomeActivity
```

### Customer Features
```
✅ HomeActivity
   ├─ Top nav: Shop name + "Search" + "Cart" badge
   ├─ Category filter tabs (All / Groceries / Dairy / Snacks / Health)
   ├─ Product grid (RecyclerView, 2 columns)
   │  ├─ ProductCard: emoji + image + name (hi+en) + price + rating + "Add" btn
   │  └─ Tap → ProductDetailActivity
   ├─ Bottom navigation (Home / Orders / Account)
   └─ Search functionality (real-time filter)

✅ ProductDetailActivity
   ├─ Large product image / emoji
   ├─ Name (Hindi + English)
   ├─ Price + GST indicator
   ├─ Stock status
   ├─ Description
   ├─ Quantity selector (- / number / +)
   ├─ "Add to Cart" button
   └─ Back button

✅ CartActivity
   ├─ List of cart items (CartAdapter)
   │  ├─ ProductCard thumbnail
   │  ├─ Name + Price
   │  ├─ Qty selector (- / + with live total recalc)
   │  └─ Remove (X) button
   ├─ Order Summary box
   │  ├─ Subtotal
   │  ├─ GST (18%)
   │  └─ Total
   ├─ "Proceed to Checkout" button
   ├─ "Continue Shopping" link
   └─ Empty state (if no items)

✅ CheckoutActivity
   ├─ Step 1: Address
   │  ├─ Saved addresses dropdown (if any)
   │  ├─ "Add New Address" option
   │  ├─ Form: Name, Phone, Street, City, Pincode, Landmark
   │  ├─ Validation (phone = 10 digits, pincode = 6 digits)
   │  └─ "Next" button
   ├─ Step 2: Order Summary
   │  ├─ Address (read-only)
   │  ├─ Items list
   │  ├─ Subtotal / GST / Total
   │  └─ "Next" button
   ├─ Step 3: Payment
   │  ├─ Payment method selector (UPI / Card)
   │  ├─ Stripe PaymentIntent integration
   │  ├─ Payment form (Stripe SDK)
   │  └─ "Pay" button (with loading state)
   └─ Success screen (on payment success)

✅ OrderHistoryActivity
   ├─ Filter tabs (All / Pending / Delivered)
   ├─ OrderAdapter (list of past orders)
   │  ├─ Order ID
   │  ├─ Date
   │  ├─ Items summary
   │  ├─ Total
   │  ├─ Status badge
   │  └─ "Reorder" button
   └─ Tap order → OrderDetailActivity
```

### Owner Features
```
✅ OwnerDashboardActivity
   ├─ Summary cards (4 cards, 2x2 grid)
   │  ├─ Today's Orders (count)
   │  ├─ Revenue Today (amount)
   │  ├─ Pending Orders (count)
   │  └─ Low Stock (count)
   ├─ Pending Orders quick view
   └─ Refresh button

✅ InventoryActivity
   ├─ Product list (RecyclerView)
   ├─ Search bar
   ├─ Add Product button (→ AddProductActivity)
   ├─ Each product card:
   │  ├─ Name + Price
   │  ├─ Stock (color-coded: green / yellow / red)
   │  ├─ Edit button (→ EditProductActivity)
   │  └─ Delete button (soft delete)
   └─ Add/Edit form:
      ├─ Name (Hindi)
      ├─ Name (English)
      ├─ Category (dropdown)
      ├─ Price (number)
      ├─ Stock (number)
      ├─ Description (textarea)
      ├─ Emoji picker / Image upload
      └─ Save button

✅ OrderManagementActivity
   ├─ Filter dropdown (All / Pending / Confirmed / Packed / Delivered)
   ├─ OrderAdapter (all orders)
   │  ├─ Order ID + Date
   │  ├─ Customer name + phone
   │  ├─ Items count
   │  ├─ Total
   │  ├─ Status dropdown (update on change)
   │  └─ View details / Print buttons
   └─ Search by Order ID
```

### Employee Features
```
✅ OrderFulfillmentActivity
   ├─ Pending orders only (filter by status = "pending")
   ├─ Tap order → update status to "confirmed"
   ├─ Tap order → update status to "packed"
   └─ Tap order → print packing label
```

### Delivery Partner Features
```
✅ DeliveryActivity
   ├─ Assigned deliveries list
   ├─ Tap delivery → show customer address
   ├─ "Open Maps" button (integrate Google Maps)
   ├─ Call customer (tap phone number)
   ├─ Message customer (tap phone number)
   └─ "Mark as Delivered" button (+ OTP / signature capture)
```

---

## 🔥 FIREBASE SETUP STEPS

### 1. Create Firebase Project
```
1. Go to Firebase Console (console.firebase.google.com)
2. Create new project: "Fufaji Store"
3. Select region: asia-south1 (Mumbai)
4. Register your app as Android
5. Download google-services.json
6. Place in: app/google-services.json
```

### 2. Enable Services
```
✅ Authentication
   ├─ Enable Phone sign-in
   ├─ Add test phone numbers (for development)
   
✅ Firestore Database
   ├─ Create database in asia-south1
   ├─ Start in test mode (for now)
   ├─ Create collections:
   │  ├─ users
   │  ├─ products
   │  ├─ orders
   │  ├─ employees
   │  └─ settings
   
✅ Cloud Storage
   ├─ Create bucket (asia-south1)
   ├─ For product images
   
✅ Cloud Messaging
   ├─ Enable for push notifications
   
✅ Cloud Functions
   ├─ Create function: createPaymentIntent
   └─ For Stripe payment processing
```

### 3. Firestore Security Rules (Update Later)
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Products: Public read
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin'];
    }
    
    // Users: User can read own, admin can read all
    match /users/{userId} {
      allow read: if request.auth.uid == userId || 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow write: if request.auth.uid == userId;
    }
    
    // Orders: User can read own, admin can read all
    match /orders/{orderId} {
      allow read: if request.auth.uid == resource.data.customerId || 
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin'];
      allow create: if request.auth.uid == request.resource.data.customerId;
      allow update: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['owner', 'admin'];
    }
    
    // Deny all else
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 💳 STRIPE INTEGRATION

### 1. Get Stripe Keys
```
1. Go to dashboard.stripe.com
2. Get: Publishable Key (for client) + Secret Key (for server)
3. Save in: app/build.gradle (publishable key only)
4. Save in: Firebase Cloud Function secrets (secret key)
```

### 2. Create Payment Intent (Firebase Cloud Function)

```javascript
// functions/index.js
const functions = require('firebase-functions');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const admin = require('firebase-admin');

admin.initializeApp();

exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User not authenticated');
  }

  const { amount, orderId, currency = 'INR' } = data;

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Stripe expects cents
      currency: currency.toLowerCase(),
      payment_method_types: ['upi', 'card'],
      metadata: { orderId },
    });

    return { clientSecret: paymentIntent.client_secret };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

### 3. Android Integration

```java
// StripeService.java
public class StripeService {
    private Stripe stripe;
    private final FirebaseFunctions functions = FirebaseFunctions.getInstance();

    public StripeService(String publishableKey) {
        this.stripe = new Stripe(context, publishableKey);
    }

    public void createPaymentIntent(String orderId, double amount, OnPaymentListener listener) {
        Map<String, Object> data = new HashMap<>();
        data.put("orderId", orderId);
        data.put("amount", amount);
        data.put("currency", "INR");

        functions.getHttpsCallable("createPaymentIntent")
            .call(data)
            .addOnSuccessListener(result -> {
                Map<String, Object> resultData = (Map<String, Object>) result.getData();
                String clientSecret = (String) resultData.get("clientSecret");
                listener.onPaymentIntentCreated(clientSecret);
            })
            .addOnFailureListener(e -> listener.onError(e.getMessage()));
    }

    public void confirmPayment(String clientSecret, PaymentMethod paymentMethod, OnPaymentListener listener) {
        ConfirmPaymentIntentParams params = ConfirmPaymentIntentParams.createWithPaymentMethodId(
            paymentMethod.id,
            clientSecret,
            "https://yourserver.com/return" // Return URL
        );

        stripe.confirmPayment(activity, params); // Stripe handles rest
    }

    public interface OnPaymentListener {
        void onPaymentIntentCreated(String clientSecret);
        void onPaymentSuccess(String transactionId);
        void onError(String error);
    }
}
```

---

## 💾 LOCAL STORAGE (Cart Persistence)

```java
// SharedPrefUtils.java
public class SharedPrefUtils {
    private static final String PREFS_NAME = "FujafiStore";
    private static final String CART_KEY = "cart";
    private static final String USER_KEY = "user";

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    // Save cart as JSON
    public static void saveCart(Context context, List<CartItem> items) {
        String json = new Gson().toJson(items);
        prefs(context).edit().putString(CART_KEY, json).apply();
    }

    // Load cart from JSON
    public static List<CartItem> loadCart(Context context) {
        String json = prefs(context).getString(CART_KEY, "[]");
        Type type = new TypeToken<List<CartItem>>(){}.getType();
        return new Gson().fromJson(json, type);
    }

    // Save user data
    public static void saveUser(Context context, User user) {
        String json = new Gson().toJson(user);
        prefs(context).edit().putString(USER_KEY, json).apply();
    }

    // Load user data
    public static User loadUser(Context context) {
        String json = prefs(context).getString(USER_KEY, null);
        if (json == null) return null;
        return new Gson().fromJson(json, User.class);
    }

    // Clear cart (on order placed)
    public static void clearCart(Context context) {
        prefs(context).edit().remove(CART_KEY).apply();
    }
}
```

---

## 📊 PRICING UTILITY (GST Calculation)

```java
// PricingUtils.java
public class PricingUtils {
    private static final double GST_RATE = 0.18; // 18%

    // Calculate GST amount
    public static double calculateGST(double price) {
        return price * GST_RATE;
    }

    // Get total with GST
    public static double getTotal(double subtotal) {
        return subtotal + calculateGST(subtotal);
    }

    // Format as Indian currency
    public static String formatINR(double amount) {
        return "₹" + String.format("%.2f", amount);
    }

    // Breakdown for display
    public static Map<String, Double> getBreakdown(double subtotal) {
        Map<String, Double> breakdown = new HashMap<>();
        breakdown.put("subtotal", subtotal);
        breakdown.put("gst", calculateGST(subtotal));
        breakdown.put("total", getTotal(subtotal));
        return breakdown;
    }
}

// Usage in Activity
double subtotal = 1200;
Map<String, Double> breakdown = PricingUtils.getBreakdown(subtotal);
tvSubtotal.setText(PricingUtils.formatINR(breakdown.get("subtotal")));
tvGST.setText(PricingUtils.formatINR(breakdown.get("gst")));
tvTotal.setText(PricingUtils.formatINR(breakdown.get("total")));
```

---

## 🧪 TESTING CHECKLIST

### Functional Testing
```
✅ Login
   ├─ Valid phone number
   ├─ Invalid phone number (shows error)
   ├─ OTP flow
   └─ Profile creation

✅ Shopping
   ├─ Search products
   ├─ Add to cart
   ├─ Update quantity
   ├─ Remove from cart
   └─ Cart persistence (close app, reopen)

✅ Checkout
   ├─ Address validation
   ├─ GST calculation accuracy
   ├─ Payment flow
   ├─ Order creation in Firestore
   └─ Order confirmation

✅ Owner Features
   ├─ View dashboard
   ├─ Add product
   ├─ Update product
   ├─ Delete product
   ├─ View orders
   └─ Update order status

✅ Low-End Device Testing
   ├─ Redmi Note 10 (4GB RAM, API 30)
   ├─ Moto G7 (3GB RAM, API 29)
   └─ Load time, crashes, battery drain
```

---

## 🚀 BUILD & DEPLOY

### Build Release APK
```bash
# Via Android Studio:
# 1. Build → Generate Signed Bundle / APK
# 2. Choose Android App Bundle (AAB)
# 3. Create new keystore (save securely)
# 4. Select release build type
# 5. Build

# Via Command Line:
./gradlew assembleRelease
# APK at: app/build/outputs/apk/release/
```

### Upload to Google Play Store
```
1. Go to play.google.com/console
2. Create app: "Fufaji Store"
3. Add content rating (complete questionnaire)
4. Upload AAB (or APK)
5. Add screenshots (6 total, 1080x1920px each)
6. Add description (Hindi + English)
7. Set price: FREE
8. Select countries: India
9. Submit for review (takes 24-48 hours)
```

---

## 📞 QUICK REFERENCE

| Component | Framework | Library |
|---|---|---|
| Auth | Firebase | Phone OTP |
| Database | Firestore | Real-time |
| Payment | Stripe | UPI + Card |
| Image Loading | Picasso / Glide | - |
| Storage | SharedPreferences | Local |
| Maps | Google Maps SDK | Navigation |
| Notifications | Firebase Cloud Messaging | Push |
| Testing | JUnit + Espresso | Unit + UI |

---

## ✅ FINAL CHECKLIST

Before giving to Android Studio AI:
```
✅ Share: FUFAJI_COMPLETE_BUILD_GUIDE.md
✅ Share: FUFAJI_WORKFLOW_ROADMAP.md
✅ Share: FUFAJI_QUICK_START.md (this file)
✅ Share: FIRESTORE_RULES_PRODUCTION.rules
✅ Clarify: Firebase project name + API keys
✅ Clarify: Stripe test keys + mode
✅ Confirm: Target Android version (API 24-34)
✅ Confirm: Priority features (MVP only)
```

---

**Ready to build? Give all 4 documents to Android Studio AI and it will generate the complete app!**

🚀 Happy building!
