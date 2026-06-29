# User Profile & Data Persistence System - Integration Guide

Complete user profile and data persistence system for Fufaji Store Flutter app. Built with async-first patterns, network error handling, and 4-tier local storage.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  (UserProfileScreen, UserSettingsScreen)                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                     Provider Layer                           │
│  UserProvider (ChangeNotifier)                               │
│  - Manages user, addresses, preferences state                │
│  - Emits change notifications to UI                          │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Business Logic Layer                       │
│  UserDataService                                             │
│  - Firestore CRUD operations                                 │
│  - Cache synchronization                                     │
│  - Network error handling                                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│               4-Tier Local Storage Layer                     │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Tier 1: Secure Storage (PINs, tokens)              │    │
│  │ Tier 2: SharedPreferences (theme, language)        │    │
│  │ Tier 3: Hive (cache, profile, cart)                │    │
│  │ Tier 4: SQLite (order history, analytics)          │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │  Firestore  │
                    └─────────────┘
```

## Components

### 1. Models

#### AddressModel (`lib/models/address_model.dart`)
```dart
AddressModel(
  id: String,
  street: String,
  city: String,
  state: String,
  postalCode: String,
  country: String,
  latitude: double,
  longitude: double,
  isDefault: bool,
  addressType: AddressType,  // home, work, other
  landmark: String?,
  deliveryInstructions: String?,
  createdAt: DateTime,
  updatedAt: DateTime,
)
```

**Key Methods:**
- `fromFirestore()` - Parse from Firestore document
- `toFirestore()` - Convert to Firestore format
- `copyWith()` - Immutable updates

#### PreferencesModel (`lib/models/preferences_model.dart`)
```dart
PreferencesModel(
  language: String,              // 'en', 'hi'
  theme: ThemeMode,              // light, dark, system
  notificationsEnabled: bool,
  biometricEnabled: bool,
  pinEnabled: bool,
  mutedCategories: List<String>,
  marketingEmails: bool,
  orderUpdates: bool,
  promotions: bool,
  updatedAt: DateTime,
)
```

**Factory Methods:**
- `fromFirestore()` - Parse from Firestore
- `defaults()` - Create default preferences for new user
- `copyWith()` - Create modified copy

### 2. Services

#### UserDataService (`lib/services/user_data_service.dart`)

**User Profile Management:**
```dart
// Load profile with caching
UserModel? profile = await userDataService.loadUserProfile(uid);

// Update profile fields
await userDataService.updateUserProfile(uid, {
  'name': 'John Doe',
  'email': 'john@example.com',
});

// Watch profile changes in real-time
userDataService.watchUserProfile(uid).listen((user) {
  print('User updated: ${user.name}');
});
```

**Address Management:**
```dart
// Add new address
String addressId = await userDataService.addAddress(uid, address);

// Update address
await userDataService.updateAddress(uid, addressId, updatedAddress);

// Delete address
await userDataService.deleteAddress(uid, addressId);

// Get all addresses
List<AddressModel> addresses = await userDataService.getAddresses(uid);

// Watch address changes
userDataService.watchAddresses(uid).listen((addresses) {
  print('Addresses updated: ${addresses.length}');
});
```

**Preferences Management:**
```dart
// Load preferences
PreferencesModel prefs = await userDataService.loadPreferences(uid);

// Update preferences
await userDataService.updatePreferences(uid, prefs);

// Update language
await userDataService.updateLanguage(uid, 'hi');

// Update theme
await userDataService.updateTheme(uid, ThemeMode.dark);

// Watch preference changes
userDataService.watchPreferences(uid).listen((prefs) {
  print('Preferences updated: ${prefs.language}');
});
```

**Error Handling:**
- Network errors trigger automatic fallback to cached data
- All methods have comprehensive error logging
- Firestore errors are caught and rethrown with context

#### LocalStorageService (`lib/services/local_storage_service.dart`)

**Tier 1: Secure Storage (PINs, sensitive tokens)**
```dart
// Save PIN hash
await localStorage.savePINHash('1234');

// Verify PIN
bool isValid = await localStorage.verifyPIN('1234');

// Save sensitive data
await localStorage.saveToSecureStorage('auth_token', 'token123');

// Retrieve sensitive data
String? token = await localStorage.getFromSecureStorage('auth_token');

// Delete from secure storage
await localStorage.deleteFromSecureStorage('auth_token');
```

**Tier 2: SharedPreferences (settings)**
```dart
// Save preferences of different types
await localStorage.saveToPreferences('theme', 'dark');
await localStorage.saveToPreferences('notifications', true);
await localStorage.saveToPreferences('retry_count', 3);

// Retrieve preferences
String? theme = localStorage.getStringPreference('theme');
bool? notifEnabled = localStorage.getBoolPreference('notifications');
```

**Tier 3: Hive (fast cache)**
```dart
// Save to Hive
await localStorage.saveToHive('profile', 'user_123', userData);

// Retrieve from Hive
Map<String, dynamic>? userData = localStorage.getFromHive('profile', 'user_123');

// Get all from box
Map<dynamic, dynamic> allData = localStorage.getAllFromHive('profile');

// Clear box
await localStorage.clearHiveBox('cart');
```

**Tier 4: SQLite (persistent storage)**
```dart
// Insert order history
int id = await localStorage.insertOrderHistory({
  'id': 'order_123',
  'user_id': uid,
  'total_amount': 500.0,
  'status': 'completed',
  'items_json': jsonEncode(items),
  'created_at': DateTime.now().millisecondsSinceEpoch,
});

// Query order history
List<Map> orders = await localStorage.queryOrderHistory(
  uid,
  limit: 20,
  offset: 0,
);

// Log activity
await localStorage.logActivity(uid, 'product_viewed', {'product_id': 'prod_123'});

// Save device info
await localStorage.saveDeviceInfo(uid, {
  'device_id': 'device_123',
  'device_name': 'Samsung S21',
});
```

**Cleanup:**
```dart
// Clear user data on logout
await localStorage.clearUserData();

// Clear everything (app reset)
await localStorage.clearAllData();

// Optimize database
await localStorage.compactDatabase();

// Close database
await localStorage.closeDatabase();
```

### 3. Provider

#### UserProvider (`lib/providers/user_provider.dart`)

State management with ChangeNotifier pattern:

```dart
// In main.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => UserProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
  ],
  child: MyApp(),
)

// In screens
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    
    // Access state
    print('User: ${userProvider.currentUser?.name}');
    print('Addresses: ${userProvider.addresses.length}');
    print('Default address: ${userProvider.defaultAddress}');
    
    // Load user data
    await userProvider.loadUserData('uid_123');
    
    // Update profile
    await userProvider.updateName('John Doe');
    await userProvider.updateEmail('john@example.com');
    
    // Manage addresses
    await userProvider.addNewAddress(address);
    await userProvider.updateExistingAddress(addressId, updated);
    await userProvider.deleteAddressById(addressId);
    await userProvider.setDefaultAddress(addressId);
    
    // Update preferences
    await userProvider.updateLanguage('hi');
    await userProvider.updateTheme(ThemeMode.dark);
    await userProvider.toggleNotifications(false);
    
    // Listen to changes
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        return Text('Name: ${provider.currentUser?.name}');
      },
    );
  }
}
```

### 4. UI Screens

#### UserProfileScreen (`lib/screens/customer/user_profile_screen.dart`)

Complete profile management screen with:
- Profile information (name, email, phone)
- Edit mode for profile updates
- Address management (add, edit, delete, set default)
- Language toggle (English/Hindi)
- Theme selector (Light/Dark/System)
- Notification preferences
- Sign out

#### UserSettingsScreen (`lib/screens/user_settings_screen.dart`)

Shared settings screen with:
- Language selection
- Theme selection
- Notification preferences
- Privacy policy link
- Data export (GDPR)
- Account deletion (GDPR)
- Sign out
- Version information

## Integration Steps

### Step 1: Initialize Services in main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize local storage
  final localStorage = LocalStorageService();
  await localStorage.initialize();
  
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  
  runApp(MyApp(prefs: prefs, localStorage: localStorage));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final LocalStorageService localStorage;
  
  const MyApp({required this.prefs, required this.localStorage});
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        // Other providers...
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Fufaji Store',
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: _getThemeMode(themeProvider.themeMode),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
  
  ThemeMode _getThemeMode(ThemeModeType type) {
    switch (type) {
      case ThemeModeType.light:
        return ThemeMode.light;
      case ThemeModeType.dark:
        return ThemeMode.dark;
      case ThemeModeType.system:
        return ThemeMode.system;
    }
  }
}
```

### Step 2: Load User Data After Login

```dart
class AuthProvider with ChangeNotifier {
  Future<void> loginUser(String uid) async {
    // ... authentication logic ...
    
    // Load user profile and preferences
    final userProvider = context.read<UserProvider>();
    await userProvider.loadUserData(uid);
    await userProvider.loadPreferences(uid);
    
    notifyListeners();
  }
}
```

### Step 3: Use in Screens

```dart
class CustomerHomeScreen extends StatefulWidget {
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load data on screen init
    Future.microtask(() {
      final userProvider = context.read<UserProvider>();
      if (!userProvider.isAuthenticated) {
        context.read<UserProvider>().loadUserData(firebaseAuth.currentUser!.uid);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        if (userProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (userProvider.error != null) {
          return Center(child: Text('Error: ${userProvider.error}'));
        }
        
        final user = userProvider.currentUser;
        final defaultAddress = userProvider.defaultAddress;
        
        return Column(
          children: [
            Text('Welcome, ${user?.name}'),
            if (defaultAddress != null)
              Text('Delivery to: $defaultAddress'),
          ],
        );
      },
    );
  }
}
```

### Step 4: Navigate to Profile Screen

```dart
// From any screen
context.push('/profile');

// In router configuration
GoRouter(
  routes: [
    GoRoute(
      path: '/profile',
      builder: (context, state) => const UserProfileScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const UserSettingsScreen(),
    ),
  ],
)
```

## Data Flow Examples

### Example 1: Add Delivery Address

```
UI (Add Button)
    ↓
UserProvider.addNewAddress(address)
    ↓
UserDataService.addAddress(uid, address)
    ↓
Firestore: users/{uid}/addresses/{docId}
    ↓
LocalStorageService: Cache in Hive + SQLite
    ↓
UserProvider: Update addresses list
    ↓
UI: Refresh with new address
```

### Example 2: Change Language

```
UI (Language Toggle)
    ↓
ThemeProvider.toggleLanguage()
    ↓
SharedPreferences: Save 'appLocale' = 'hi'
    ↓
UserProvider.updateLanguage('hi')
    ↓
Firestore: users/{uid}/metadata/preferences
    ↓
LocalStorageService: Update cache
    ↓
UI: Rebuild with new locale
```

### Example 3: Offline Support

```
Network unavailable
    ↓
UserDataService tries Firestore
    ↓
FirebaseException caught
    ↓
Fallback to LocalStorageService cache
    ↓
Return cached data to Provider
    ↓
UI displays offline data
    ↓
When network returns
    ↓
Auto-sync queued changes
```

## Firestore Schema

```
users/{uid}
  - id: string
  - name: string
  - email: string
  - phoneNumber: string
  - profileImage: string
  - role: string (customer, shopOwner, deliveryAgent, admin)
  - walletBalance: number
  - rewardPoints: number
  - createdAt: timestamp
  - lastLogin: timestamp
  - ... (other user fields)
  
users/{uid}/addresses/{docId}
  - id: string
  - street: string
  - city: string
  - state: string
  - postalCode: string
  - country: string
  - latitude: number
  - longitude: number
  - isDefault: boolean
  - addressType: string (home, work, other)
  - landmark: string
  - deliveryInstructions: string
  - createdAt: timestamp
  - updatedAt: timestamp
  
users/{uid}/metadata/preferences
  - language: string
  - theme: string
  - notificationsEnabled: boolean
  - biometricEnabled: boolean
  - pinEnabled: boolean
  - mutedCategories: array
  - marketingEmails: boolean
  - orderUpdates: boolean
  - promotions: boolean
  - updatedAt: timestamp
```

## Error Handling

All services implement comprehensive error handling:

```dart
try {
  await userDataService.updateUserProfile(uid, updates);
} on FirebaseException catch (e) {
  print('Firebase error: ${e.message}');
  // Automatically falls back to cache
} on Exception catch (e) {
  print('General error: $e');
  // Show user-friendly message
}
```

## Testing

Run tests:
```bash
flutter test test/services/user_data_service_test.dart
flutter test test/services/local_storage_service_test.dart
flutter test test/providers/user_provider_test.dart
```

## Performance Considerations

1. **Lazy Loading**: Load profile data only when needed
2. **Caching**: Multiple layers reduce database calls
3. **Pagination**: Use limit/offset for large lists
4. **Batch Updates**: Update multiple fields in one call
5. **Stream Optimization**: Use filtered streams where possible

```dart
// Good: Only load when user visits profile
GoRoute(
  path: '/profile',
  builder: (context, state) {
    return FutureBuilder(
      future: context.read<UserProvider>().loadUserData(uid),
      builder: (context, snapshot) => UserProfileScreen(),
    );
  },
)

// Optimize streams with specific queries
FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('addresses')
    .where('isDefault', isEqualTo: true)
    .limit(1)
    .snapshots()
```

## Security

1. **PIN Storage**: Using SHA256 one-way hashing
2. **Secure Storage**: Flutter secure storage for sensitive data
3. **Firestore Rules**: Implement proper security rules
4. **Data Validation**: All inputs validated before sending to Firestore
5. **Offline Cache**: Encrypted by OS-level security

```
Firestore Rules Example:
match /users/{uid} {
  allow read, write: if request.auth.uid == uid;
  allow read: if request.auth.token.role == 'admin';
}
```

## Next Steps

1. Integrate with authentication system
2. Add Firestore security rules
3. Implement data sync on app resume
4. Add analytics tracking
5. Implement backup/restore functionality
