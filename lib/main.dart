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
import 'package:google_sign_in/google_sign_in.dart';
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
import 'package:workmanager/workmanager.dart';
import 'services/gps_tracking_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  final mainStartTime = DateTime.now();
  // Fix 9: Use SentryWidgetsFlutterBinding to enable frame tracking and correct initialization sequence
  SentryWidgetsFlutterBinding.ensureInitialized();
  
  // Fix 12: Record precise start time for startup metrics
  PerformanceMonitor.setAppStartTime(mainStartTime);

  // Load environment variables from .env file (Development only)
  // Note: .env is NOT bundled in release (see pubspec.yaml assets)
  if (kDebugMode) {
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('[main] .env loaded successfully');
    } catch (e) {
      // Quietly ignore missing .env in environments where it's not needed
      debugPrint('[main] Info: .env not loaded (using defaults/remote config)');
    }
  }

  // Initialize Workmanager for background tasks
  Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);

  // CRITICAL: Load runtime configuration from backend
  // This ensures secrets (RAZORPAY_KEY_SECRET, etc.) are NEVER embedded in APK
  try {
    await RuntimeConfigService.instance.load();
    debugPrint('[main] Runtime configuration loaded successfully');
  } catch (e) {
    debugPrint('[main] Warning: Could not load runtime config, using build defaults: $e');
  }

  // Initialize Firebase FIRST (blocking, must be complete)
  await _initializeSecurity();

  // Get Sentry DSN (now from runtime config, with fallback to build-time)
  final sentryDsn = RuntimeConfig.instance.sentryDsn;

  if (sentryDsn.isEmpty) {
    debugPrint('[main] SENTRY_DSN not configured. Running without crash reporting.');
    _runAppOnly();
    return;
  }

  // Initialize Sentry for error tracking, performance monitoring, and crash reporting
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = 0.1;
      options.environment = kDebugMode ? 'development' : 'production';
      options.attachStacktrace = true;
      options.maxBreadcrumbs = 100;
      options.beforeSend = (event, hint) {
        if (event.throwable?.toString().contains('Connection refused') == true) {
          return null;
        }
        return event;
      };
    },
    appRunner: () => _runAppOnly(),
  );
}

/// Extracted app runner to avoid duplication when Sentry is disabled
Future<void> _runAppOnly() async {
  // Global Flutter error handler
  FlutterError.onError = (details) {
    LoggingService().error(
      'Flutter Error: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };

  // Platform dispatcher error handler
  PlatformDispatcher.instance.onError = (error, stack) {
    LoggingService().error('Platform Error: $error', error, stack);
    return true; 
  };

  final appWidget = await _initializeApp();
  runApp(appWidget);
}

dynamic _securityInitError;
StackTrace? _securityInitStack;

Future<void> _initializeSecurity() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
    LoggingService().info('Firebase App Check activated.');
  } catch (e, stack) {
    LoggingService().error('App Check initialization failed', e, stack);
    _securityInitError ??= e;
    _securityInitStack ??= stack;
  }
}

/// ========================================================================
/// OPTIMIZATION FIX: Lazy Initialization Pattern
/// ========================================================================
/// Instead of initializing all services synchronously, we now:
/// 1. Initialize ONLY critical services before runApp()
/// 2. Initialize medium-priority services in postFrame callback
/// 3. Initialize heavy services (AI, Analytics) after first frame
/// 4. Initialize rare-use services only when needed
///
/// This reduces cold start from ~10-12 seconds to ~2-3 seconds
/// ========================================================================

Future<Widget> _initializeApp() async {
  // Disable debug logs in release mode
  if (const bool.fromEnvironment('dart.vm.product')) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Report early startup errors (App Check / Dotenv) to Sentry
  if (_securityInitError != null) {
    LoggingService().error('Startup Initialization Error', _securityInitError, _securityInitStack);
  }

  // TIER 1: CRITICAL SERVICES (must complete before app shows)
  // Time budget: < 500ms
  try {
    // Enable offline disk persistence for Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Fix 10: Moved MobileAds to Tier 2 to reduce main thread blocking during startup
    LoggingService().info('Core Firebase services configured.');
  } catch (e, stack) {
    LoggingService().error('Firebase Configuration error', e, stack);
  }

  // Initialize SharedPreferences (lightweight I/O)
  final prefs = await SharedPreferences.getInstance();

  // Record application startup time
  PerformanceMonitor.recordAppStartupTime();

  // Fix 10: Moved RuntimeConfig to post-first-frame to eliminate cold-start blocking.
  Future<void> initializeTier2() async {
    try {
      try {
        await RuntimeConfigService.instance.load();
        debugPrint('[main] Runtime configuration loaded successfully');
      } catch (e) {
        debugPrint('[main] Warning: Could not load runtime config: $e');
      }

      // Fix 10.1: Moved MobileAds and Ads init to Tier 2 to eliminate main-thread blocking
      await MobileAds.instance.initialize();

      // Initialize Cache Service (Firestore read + Redis connectivity test)
      await CacheService().init();

      // Initialize High-Performance Hive Storage
      await StorageService().init();

      // Initialize Remote Config (Feature: Instant OTA Updates)
      await RemoteConfigService().init();

      // Initialize Offline Order Sync Queue
      await OfflineSyncService().init();
    } catch (e, stack) {
      LoggingService().error('Tier 2 initialization error', e, stack);
    }
  }

  // TIER 3: HEAVY SERVICES (initialize after first frame)
  // Time budget: 2-3 seconds
  // These are AI engines, analytics, and heavy background services
  Future<void> initializeTier3() async {
    try {
      // Initialize Supabase (hybrid architecture)
      await SupabaseConfig.initialize();

      // Warm-up AI Search Service (Gemini/Vision initialization)
      await AISearchService().warmup();

      // Initialize Shorebird update check (background)
      ShorebirdService().checkForUpdates();

      // Initialize Google Sign-In (Identity singleton)
      await GoogleSignIn.instance.initialize();
    } catch (e, stack) {
      LoggingService().error('Tier 3 initialization error', e, stack);
    }
  }

  // TIER 4: VERIFICATION & STARTUP CHECKS (after first frame + 1s)
  // These checks validate app state and should not block startup
  Future<void> initializeTier4() async {
    try {
      // Run Workflow Verification (Feature: Production Guard)
      await WorkflowVerificationService().verifyWorkflow();
    } catch (e, stack) {
      LoggingService().error('Workflow verification failed (non-critical)', e, stack);
      // Continue anyway - workflow verification is not critical for app startup
    }
  }

  // Return app with CRITICAL PROVIDERS ONLY
  // This keeps the provider tree lightweight and fast to build
  return MultiProvider(
    providers: [
      // TIER 1: Critical providers (theme, auth, accessibility)
      // These MUST be available immediately for UI to render
      ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
      ChangeNotifierProvider(create: (_) => GuestProvider()),

      // TIER 2: Essential feature providers (cart, products, orders)
      // Needed soon after app shows, can initialize in background
      ChangeNotifierProvider(create: (_) => CartProvider()..loadCart()),
      ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
        create: (_) => ProductProvider(prefs),
        update: (_, auth, product) => product!..updateShopId(auth.currentUser?.id),
      ),
      ChangeNotifierProvider(create: (_) => OrderProvider()),
      ChangeNotifierProvider(create: (_) => PaymentProvider()),

      // TIER 3: Feature-specific providers (delivery, chat, notifications)
      // Can lazy-initialize when user navigates to those features
      ChangeNotifierProvider(create: (_) => DeliveryProvider()),
      ChangeNotifierProvider(create: (_) => ChatProvider()),
      ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ChangeNotifierProvider(create: (_) => LocationProvider()),
      ChangeNotifierProvider(create: (_) => WalletProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => ShopConfigProvider()),
      ChangeNotifierProvider(create: (_) => EmployeeProvider()),
      ChangeNotifierProvider(create: (_) => ReviewProvider()),

      // TIER 4: Admin/Business Intelligence providers
      // Only needed for owner/admin screens, can be lazy
      ChangeNotifierProvider(create: (_) => AdminProvider()),
      ChangeNotifierProvider(create: (_) => PosProvider()),
      ChangeNotifierProvider(create: (_) => BusinessIntelligenceProvider()),
      ChangeNotifierProvider(create: (_) => CampaignProvider()),
      ChangeNotifierProvider(create: (_) => RetentionProvider()),

      // TIER 5: Mission Control ("Karyalay") - AI Agentic Employee System
      // Heavy async services, can initialize lazily
      ChangeNotifierProvider(create: (_) => AgentProvider()),
      ChangeNotifierProvider(create: (_) => AgentTaskProvider()),
      ChangeNotifierProvider(create: (_) => ReportProvider()),
      ChangeNotifierProvider(create: (_) => BroadcastProvider()),
      ChangeNotifierProvider(create: (_) => OperationalIntelligenceProvider()),
      ChangeNotifierProvider(create: (_) => IdentityProvider()),
      ChangeNotifierProvider(create: (_) => AiInsightsProvider()),
      ChangeNotifierProvider(create: (_) => ForecastProvider()),
    ],
    child: FufajiAppWithAsyncInit(
      onInitTier2: initializeTier2,
      onInitTier3: initializeTier3,
      onInitTier4: initializeTier4,
    ),
  );
}

/// Wrapper widget that triggers async initialization after first frame
class FufajiAppWithAsyncInit extends StatefulWidget {
  final Future<void> Function() onInitTier2;
  final Future<void> Function() onInitTier3;
  final Future<void> Function() onInitTier4;

  const FufajiAppWithAsyncInit({
    required this.onInitTier2,
    required this.onInitTier3,
    required this.onInitTier4,
    super.key,
  });

  @override
  State<FufajiAppWithAsyncInit> createState() => _FufajiAppWithAsyncInitState();
}

class _FufajiAppWithAsyncInitState extends State<FufajiAppWithAsyncInit> {
  @override
  void initState() {
    super.initState();

    // Schedule Tier 2 initialization after first frame (allows UI to render)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.onInitTier2();

      // After Tier 2, schedule Tier 3 (heavy services) with a small delay
      // to keep UI responsive
      await Future.delayed(const Duration(milliseconds: 100));
      await widget.onInitTier3();

      // After Tier 3, schedule Tier 4 verification checks
      await Future.delayed(const Duration(milliseconds: 500));
      await widget.onInitTier4();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const FufajiApp();
  }
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
            
            // Safety: Handle edge case where layout is not yet calculated (Width is zero log)
            if (mediaQuery.size.width == 0 || mediaQuery.size.height == 0) {
              return const SizedBox.shrink();
            }

            // Apply scale factor dynamically using textScaler
            final scaledMediaQuery = mediaQuery.copyWith(
              textScaler: TextScaler.linear(accessibilityProvider.effectiveFontScale),
            );

            return MediaQuery(
              data: scaledMediaQuery,
              child: FutureBuilder<bool>(
                future: _forceUpdateFuture,
                builder: (context, snapshot) {
                  // Safety: Ensure snapshot data is available
                  final bool forceUpdate = snapshot.data ?? false;

                  if (forceUpdate) {
                    return ForceUpdateOverlay(updateUrl: remoteConfig.forceUpdateUrl);
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
