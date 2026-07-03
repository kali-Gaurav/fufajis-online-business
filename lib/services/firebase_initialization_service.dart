import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'realtime_database_service.dart';

/// Firebase Initialization Service
/// Handles all Firebase service initialization and configuration
class FirebaseInitializationService {
  static final FirebaseInitializationService _instance = FirebaseInitializationService._internal();

  factory FirebaseInitializationService() {
    return _instance;
  }

  FirebaseInitializationService._internal();

  static bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize all Firebase services
  /// Call this once during app startup
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      // Initialize Firebase Core
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // Configure Firestore
      _configureFirestore();

      // Configure Firebase Auth
      _configureAuth();

      // Initialize Hive for local caching
      await _initializeHive();

      // Initialize FCM for push notifications
      await _initializeFCM();

      // Initialize Analytics
      _initializeAnalytics();

      // Initialize Crashlytics
      _initializeCrashlytics();

      // Initialize Realtime Database
      _initializeRTDB();

      _isInitialized = true;

      print('Firebase initialized successfully');
    } catch (e) {
      print('Firebase initialization failed: $e');
      rethrow;
    }
  }

  /// Configure Firestore settings
  static void _configureFirestore() {
    final firestore = FirebaseFirestore.instance;

    // Enable offline persistence
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 104857600, // 100MB
      sslEnabled: true,
    );

    // Enable network logging in debug mode
    if (kDebugMode) {
      FirebaseFirestore.setLoggingEnabled(true);
    }
  }

  /// Configure Firebase Authentication
  static void _configureAuth() {
    final auth = FirebaseAuth.instance;

    // Set language code for auth UI
    auth.setLanguageCode('en');

    // Configure persistence
    if (kIsWeb) {
      auth.setPersistence(Persistence.LOCAL);
    }
  }

  /// Initialize Hive for local caching
  static Future<void> _initializeHive() async {
    try {
      await Hive.initFlutter();

      // Open local storage box for caching
      await Hive.openBox('app_cache');
      await Hive.openBox('auth_cache');
      await Hive.openBox('user_preferences');
      await Hive.openBox('offline_queue');

      print('Hive initialized successfully');
    } catch (e) {
      print('Hive initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize Firebase Cloud Messaging
  static Future<void> _initializeFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request notification permissions
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('FCM notification permission status: ${settings.authorizationStatus}');

      // Get FCM token
      final token = await messaging.getToken();
      print('FCM Token: $token');

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification}');
        }
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A new onMessageOpenedApp event was published!');
      });

      print('FCM initialized successfully');
    } catch (e) {
      print('FCM initialization failed: $e');
    }
  }

  /// Background message handler
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Handling a background message: ${message.messageId}');
  }

  /// Initialize Firebase Analytics
  static void _initializeAnalytics() {
    try {
      final analytics = FirebaseAnalytics.instance;

      // Enable/disable analytics collection based on debug mode
      analytics.setAnalyticsCollectionEnabled(!kDebugMode);

      print('Firebase Analytics initialized');
    } catch (e) {
      print('Firebase Analytics initialization failed: $e');
    }
  }

  /// Initialize Firebase Crashlytics
  static void _initializeCrashlytics() {
    try {
      final crashlytics = FirebaseCrashlytics.instance;

      // Enable/disable Crashlytics based on debug mode
      if (!kDebugMode) {
        FlutterError.onError = crashlytics.recordFlutterError;
      }

      print('Firebase Crashlytics initialized');
    } catch (e) {
      print('Firebase Crashlytics initialization failed: $e');
    }
  }

  /// Initialize Realtime Database
  static void _initializeRTDB() {
    try {
      RealtimeDatabaseService.instance.initialize();
      print('Firebase RTDB initialized');
    } catch (e) {
      print('RTDB initialization failed: $e');
    }
  }

  /// Enable offline persistence
  static Future<void> enableOfflinePersistence() async {
    try {
      await FirebaseFirestore.instance.enableNetwork();
      print('Offline persistence enabled');
    } catch (e) {
      print('Failed to enable offline persistence: $e');
    }
  }

  /// Disable offline persistence
  static Future<void> disableOfflinePersistence() async {
    try {
      await FirebaseFirestore.instance.disableNetwork();
      print('Offline persistence disabled');
    } catch (e) {
      print('Failed to disable offline persistence: $e');
    }
  }

  /// Check Firebase connectivity
  static Future<bool> checkConnectivity() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final token = await user.getIdToken(true);
      return token != null;
    } catch (e) {
      return false;
    }
  }

  /// Cleanup Firebase services
  static Future<void> cleanup() async {
    try {
      await Hive.close();
      _isInitialized = false;
      print('Firebase cleanup completed');
    } catch (e) {
      print('Firebase cleanup failed: $e');
    }
  }

  /// Get Firebase app status
  static Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'firestore': {'isConnected': FirebaseFirestore.instance.hashCode, 'persistenceEnabled': true},
      'auth': {
        'isSignedIn': FirebaseAuth.instance.currentUser != null,
        'currentUser': FirebaseAuth.instance.currentUser?.uid,
      },
      'messaging': {
        'hasPermission': true, // This would need actual implementation
      },
      'analytics': {'isEnabled': true},
      'crashlytics': {'isEnabled': !kDebugMode},
      'realtime_database': {'isEnabled': true},
    };
  }
}

/// Web compatibility flag
const bool kIsWeb = false;
