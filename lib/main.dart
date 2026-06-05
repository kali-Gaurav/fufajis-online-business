import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'providers/order_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/location_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/shop_config_provider.dart';
import 'providers/accessibility_provider.dart';
import 'providers/employee_provider.dart';
import 'providers/review_provider.dart';
import 'providers/guest_provider.dart';
import 'utils/app_router.dart';
import 'utils/app_theme.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';
import 'services/offline_sync_service.dart';
import 'services/remote_config_service.dart';
import 'services/shorebird_service.dart';
import 'widgets/offline_indicator.dart';
import 'widgets/maintenance_overlay.dart';
import 'widgets/force_update_overlay.dart';
import 'services/performance_monitor.dart';
import 'services/storage_service.dart';
import 'services/permission_service.dart';
import 'services/ai_search_service.dart';
import 'services/update_service.dart';
import 'services/workflow_verification_service.dart';
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'services/owner_initialization_service.dart';
import 'services/logging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize App Check before other services (Feature: High Security)
  await _initializeSecurity();

  const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  if (sentryDsn.isEmpty) {
    debugPrint(
      '[Warning] SENTRY_DSN is not configured. Crash reporting is disabled.',
    );
  }

  // Initialize Sentry...
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate =
          0.2; // Optimized sampling rate (Weakness 49 fix)
    },
    appRunner: () async {
      // Step: Global Error Handling Integration
      FlutterError.onError = (details) {
        LoggingService().error('Flutter Error', details.exception, details.stack);
      };
      
      PlatformDispatcher.instance.onError = (error, stack) {
        LoggingService().error('Platform Dispatcher Error', error, stack);
        return true;
      };

      final appWidget = await _initializeApp();
      runApp(appWidget);
    },
  );
}

dynamic _securityInitError;
StackTrace? _securityInitStack;

Future<void> _initializeSecurity() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity, // Using the new class if it exists? Wait.
      appleProvider: AppleProvider.deviceCheck,
    );
    LoggingService().info('Firebase App Check activated.');
  } catch (e, stack) {
    LoggingService().error('App Check initialization failed', e, stack);
    _securityInitError = e;
    _securityInitStack = stack;
  }
}

Future<Widget> _initializeApp() async {
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    LoggingService().warning('.env file not found or failed to load');
  }

  // Disable debug logs in release mode
  if (const bool.fromEnvironment('dart.vm.product')) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Report App Check errors to Sentry if occurred during startup
  if (_securityInitError != null) {
    LoggingService().error('Startup Security Error', _securityInitError, _securityInitStack);
  }

  // Initialize Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Security Hardening: Seed whitelisted owners
    await OwnerInitializationService.seedWhitelistedOwners();

    // Enable offline disk persistence for Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Initialize Mobile Ads
    await MobileAds.instance.initialize();
    LoggingService().info('Core Firebase services initialized.');
  } catch (e, stack) {
    LoggingService().error('Firebase Initialization error', e, stack);
  }

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Cache Service (Step 1.3)
  await CacheService().init();

  // Initialize High-Performance Hive Storage (Step 1.5 Upgrade)
  await StorageService().init();

  // Initialize Remote Config (Feature: Instant OTA Updates)
  await RemoteConfigService().init();

  // Initialize Offline Order Sync Queue
  await OfflineSyncService().init();

  // Initialize Shorebird update check (background)
  ShorebirdService().checkForUpdates();

  // Record application startup time
  PerformanceMonitor.recordAppStartupTime();

  // Initialize Permission Service & Service warm-up (Step 5)
  final permissionService = PermissionService();
  await permissionService.requestAllPermissions();

  // Warm-up AI Search Service
  await AISearchService().warmup();

  // Run Workflow Verification (Feature: Production Guard)
  await WorkflowVerificationService().verifyWorkflow();

  // Return app with providers
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => CartProvider()..loadCart()),
      ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
        create: (_) => ProductProvider(prefs),
        update: (_, auth, product) =>
            product!..updateShopId(auth.currentUser?.id),
      ),
      ChangeNotifierProvider(create: (_) => OrderProvider()),
      ChangeNotifierProvider(create: (_) => DeliveryProvider()),
      ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ChangeNotifierProvider(create: (_) => ChatProvider()),
      ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ChangeNotifierProvider(create: (_) => LocationProvider()),
      ChangeNotifierProvider(create: (_) => WalletProvider()),
      ChangeNotifierProvider(create: (_) => AdminProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => ShopConfigProvider()),
      ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
      ChangeNotifierProvider(create: (_) => EmployeeProvider()),
      ChangeNotifierProvider(create: (_) => ReviewProvider()),
      // Guest mode — local-only, no Firebase user
      // Must come after AuthProvider so route guards can read both
      ChangeNotifierProvider(create: (_) => GuestProvider()),
    ],
    child: const FufajiApp(),
  );
}

class FufajiApp extends StatefulWidget {
  const FufajiApp({super.key});

  @override
  State<FufajiApp> createState() => _FufajiAppState();
}

class _FufajiAppState extends State<FufajiApp> {
  final GoRouter _router = AppRouter.router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize(context);
      UpdateService().handleVersionCheck(context);
    });
  }

  ThemeMode _mapThemeMode(ThemeModeType mode) {
    switch (mode) {
      case ThemeModeType.light:
        return ThemeMode.light;
      case ThemeModeType.dark:
        return ThemeMode.dark;
      case ThemeModeType.system:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remoteConfig = RemoteConfigService();

    return Consumer2<ThemeProvider, AccessibilityProvider>(
      builder: (context, themeProvider, accessibilityProvider, child) {
        return MaterialApp.router(
          title: "Fufaji's Online",
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _mapThemeMode(themeProvider.themeMode),
          locale: accessibilityProvider.isElderlyMode
              ? Locale(accessibilityProvider.preferredLanguage)
              : themeProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', ''), Locale('hi', '')],
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            // Apply scale factor dynamically using textScaler
            final scaledMediaQuery = mediaQuery.copyWith(
              textScaler: TextScaler.linear(
                accessibilityProvider.effectiveFontScale,
              ),
            );

            return MediaQuery(
              data: scaledMediaQuery,
              child: FutureBuilder<bool>(
                future: remoteConfig.isForceUpdateRequired(),
                builder: (context, snapshot) {
                  final bool forceUpdate = snapshot.data ?? false;

                  if (forceUpdate) {
                    return ForceUpdateOverlay(
                      updateUrl: remoteConfig.forceUpdateUrl,
                    );
                  }

                  if (remoteConfig.isMaintenanceMode) {
                    return MaintenanceOverlay(
                      onRetry: () async {
                        await remoteConfig.fetchAndActivate();
                        setState(() {});
                      },
                    );
                  }

                  return OfflineIndicator(child: child!);
                },
              ),
            );
          },
        );
      },
    );
  }
}
