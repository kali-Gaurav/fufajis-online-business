import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
import 'providers/pos_provider.dart';
import 'providers/business_intelligence_provider.dart';
import 'providers/campaign_provider.dart';
import 'providers/retention_provider.dart';
import 'providers/agent_provider.dart';
import 'providers/agent_task_provider.dart';
import 'providers/report_provider.dart';
import 'providers/broadcast_provider.dart';
import 'providers/operational_intelligence_provider.dart';
import 'providers/identity_provider.dart';
import 'providers/ai_insights_provider.dart';
import 'providers/forecast_provider.dart';
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
import 'services/ai_search_service.dart';
import 'services/update_service.dart';
import 'services/workflow_verification_service.dart';
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'services/logging_service.dart';

import 'services/runtime_config_service.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Load runtime configuration from backend
  // This ensures secrets (RAZORPAY_KEY_SECRET, etc.) are NEVER embedded in APK
  try {
    await RuntimeConfigService.instance.load();
    debugPrint('[main] Runtime configuration loaded successfully');
  } catch (e) {
    debugPrint('[main] Warning: Could not load runtime config, using build defaults: $e');
  }

  // Initialize Firebase FIRST
  await _initializeSecurity();

  // Get Sentry DSN (now from runtime config, with fallback to build-time)
  final sentryDsn = RuntimeConfig.instance.sentryDsn;

  if (sentryDsn.isEmpty) {
    debugPrint(
      '[Warning] SENTRY_DSN is not configured. Crash reporting is disabled.',
    );
  }

  // Initialize Sentry for error tracking, performance monitoring, and crash reporting
  // Features:
  // - Captures unhandled exceptions and crashes
  // - Monitors performance with 20% sampling rate
  // - Tracks breadcrumbs for debugging
  // - Reports user context and device info
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      // Performance sampling rate: 10% of transactions to track performance metrics
      // while minimizing overhead. Adjust based on traffic volume.
      options.tracesSampleRate = 0.1;

      // Set environment (development vs production)
      options.environment = kDebugMode ? 'development' : 'production';

      // Enable attachment collection for crash reports
      options.attachStacktrace = true;

      // Capture breadcrumbs for better debugging
      options.maxBreadcrumbs = 100;

      // Filter out noisy errors
      options.beforeSend = (event, hint) {
        // Ignore certain common non-critical errors
        if (event.throwable?.toString().contains('Connection refused') == true) {
          return null; // Don't send connection errors
        }
        return event;
      };
    },
    appRunner: () async {
      // Global Flutter error handler - captures all Flutter errors
      FlutterError.onError = (details) {
        LoggingService().error(
          'Flutter Error: ${details.exceptionAsString()}',
          details.exception,
          details.stack,
        );
      };

      // Platform dispatcher error handler - captures async errors
      // These are errors that occur outside the Flutter zone
      PlatformDispatcher.instance.onError = (error, stack) {
        LoggingService().error(
          'Platform Error: $error',
          error,
          stack,
        );
        return true; // Prevent app crash
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
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
    LoggingService().info('Firebase App Check activated.');
  } catch (e, stack) {
    LoggingService().error('App Check initialization failed', e, stack);
    _securityInitError ??= e;
    _securityInitStack ??= stack;
  }
}

Future<Widget> _initializeApp() async {
  // Disable debug logs in release mode
  if (const bool.fromEnvironment('dart.vm.product')) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Report early startup errors (App Check / Dotenv) to Sentry
  if (_securityInitError != null) {
    LoggingService().error('Startup Initialization Error', _securityInitError, _securityInitStack);
  }

  // Core Firebase Services (Already initialized in _initializeSecurity, but ensuring persistence)
  try {
    // Enable offline disk persistence for Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Initialize Mobile Ads
    await MobileAds.instance.initialize();
    LoggingService().info('Core Firebase services configured.');
  } catch (e, stack) {
    LoggingService().error('Firebase Configuration error', e, stack);
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

  // Initialize Supabase (Hybrid Architecture)
  await SupabaseConfig.initialize();

  // Initialize Shorebird update check (background)
  ShorebirdService().checkForUpdates();

  // Record application startup time
  PerformanceMonitor.recordAppStartupTime();

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
      ChangeNotifierProvider(create: (_) => PosProvider()),
      ChangeNotifierProvider(create: (_) => BusinessIntelligenceProvider()),
      ChangeNotifierProvider(create: (_) => CampaignProvider()),
      ChangeNotifierProvider(create: (_) => RetentionProvider()),
      // Mission Control ("Karyalay") - AI Agentic Employee System
      ChangeNotifierProvider(create: (_) => AgentProvider()),
      ChangeNotifierProvider(create: (_) => AgentTaskProvider()),
      ChangeNotifierProvider(create: (_) => ReportProvider()),
      ChangeNotifierProvider(create: (_) => BroadcastProvider()),
      ChangeNotifierProvider(create: (_) => OperationalIntelligenceProvider()),
      ChangeNotifierProvider(create: (_) => IdentityProvider()),
      ChangeNotifierProvider(create: (_) => AiInsightsProvider()),
      ChangeNotifierProvider(create: (_) => ForecastProvider()),
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

  late Future<bool> _forceUpdateFuture;

  @override
  void initState() {
    super.initState();
    _forceUpdateFuture = RemoteConfigService().isForceUpdateRequired();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize(context);
      UpdateService().handleVersionCheck(context);
    });
  }

  @override
  void dispose() {
    // Add any necessary cleanup here
    super.dispose();
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
          locale: Locale(accessibilityProvider.preferredLanguage),
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
                future: _forceUpdateFuture,
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
