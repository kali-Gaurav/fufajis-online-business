import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/accessibility_provider.dart';
import '../providers/guest_provider.dart';

import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/order_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/delivery_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/notification_provider.dart';

import '../providers/admin_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/business_intelligence_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/retention_provider.dart';
import '../providers/inventory_provider.dart';

import '../providers/agent_provider.dart';
import '../providers/agent_task_provider.dart';
import '../providers/report_provider.dart';
import '../providers/broadcast_provider.dart';

import '../providers/chat_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/location_provider.dart';
import '../providers/shop_config_provider.dart';
import '../providers/employee_provider.dart';
import '../providers/review_provider.dart';
import '../providers/operational_intelligence_provider.dart';
import '../providers/identity_provider.dart';
import '../providers/ai_insights_provider.dart';
import '../providers/forecast_provider.dart';

/// CORE PROVIDERS (always loaded, shared across all roles)
/// These providers must exist before any UI renders
List<SingleChildWidget> getCoreProviders(SharedPreferences? prefs) {
  return [
    // ThemeProvider: Accept optional prefs
    // If prefs is null, ThemeProvider uses defaults and loads prefs lazily
    ChangeNotifierProvider(
      create: (_) => prefs != null ? ThemeProvider(prefs) : ThemeProvider.withDefaults(),
    ),
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
    ChangeNotifierProvider(create: (_) => GuestProvider()),
    ChangeNotifierProvider(create: (_) => ShopConfigProvider()),
  ];
}

/// CUSTOMER ROLE PROVIDERS (customer/buyer role only)
/// Loaded when user authenticates as customer
List<SingleChildWidget> getCustomerProviders(SharedPreferences? prefs) {
  return [
    // Essential customer features
    ChangeNotifierProvider(create: (_) => CartProvider()), // Async-loaded in post-frame
    ChangeNotifierProxyProvider<AuthProvider, ProductProvider>(
      create: (_) => prefs != null
          ? ProductProvider(prefs)
          : ProductProvider.withDefaults(),
      update: (_, auth, product) => product!..updateShopId(auth.currentUser?.uid),
    ),
    ChangeNotifierProvider(create: (_) => OrderProvider()),
    ChangeNotifierProvider(create: (_) => PaymentProvider()),
    ChangeNotifierProvider(create: (_) => WalletProvider()),
    ChangeNotifierProvider(create: (_) => NotificationProvider()),
    ChangeNotifierProvider(create: (_) => ReviewProvider()),

    // Optional customer features (lazy load these)
    ChangeNotifierProvider(create: (_) => DeliveryProvider()),
    ChangeNotifierProvider(create: (_) => ChatProvider()),
    ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
    ChangeNotifierProvider(create: (_) => LocationProvider()),
  ];
}

/// OWNER/ADMIN ROLE PROVIDERS
/// Loaded when user authenticates as owner or admin
List<SingleChildWidget> getOwnerProviders(SharedPreferences? prefs) {
  return [
    // Admin features
    ChangeNotifierProvider(create: (_) => CartProvider()), // For testing
    ChangeNotifierProvider(
      create: (_) => prefs != null
          ? ProductProvider(prefs)
          : ProductProvider.withDefaults(),
    ),
    ChangeNotifierProvider(create: (_) => OrderProvider()),
    ChangeNotifierProvider(create: (_) => PaymentProvider()),
    ChangeNotifierProvider(create: (_) => WalletProvider()),
    ChangeNotifierProvider(create: (_) => NotificationProvider()),

    // Admin-specific
    ChangeNotifierProvider(create: (_) => AdminProvider()),
    ChangeNotifierProvider(create: (_) => InventoryProvider()),
    ChangeNotifierProvider(create: (_) => PosProvider()),
    ChangeNotifierProvider(create: (_) => BusinessIntelligenceProvider()),
    ChangeNotifierProvider(create: (_) => CampaignProvider()),
    ChangeNotifierProvider(create: (_) => RetentionProvider()),
    ChangeNotifierProvider(create: (_) => EmployeeProvider()),

    // Optional for admin
    ChangeNotifierProvider(create: (_) => DeliveryProvider()),
    ChangeNotifierProvider(create: (_) => ChatProvider()),
    ChangeNotifierProvider(create: (_) => LocationProvider()),
  ];
}

/// RIDER/DELIVERY ROLE PROVIDERS
List<SingleChildWidget> getRiderProviders(SharedPreferences? prefs) => [
  ChangeNotifierProvider(create: (_) => DeliveryProvider()),
  ChangeNotifierProvider(create: (_) => LocationProvider()),
  ChangeNotifierProvider(create: (_) => NotificationProvider()),
  ChangeNotifierProvider(create: (_) => WalletProvider()),
  ChangeNotifierProvider(create: (_) => ChatProvider()),
];

/// EMPLOYEE ROLE PROVIDERS
List<SingleChildWidget> getEmployeeProviders(SharedPreferences? prefs) => [
  ChangeNotifierProvider(create: (_) => EmployeeProvider()),
  ChangeNotifierProvider(create: (_) => InventoryProvider()),
  ChangeNotifierProvider(create: (_) => NotificationProvider()),
  ChangeNotifierProvider(create: (_) => ChatProvider()),
];

/// MISSION CONTROL / AI AGENTIC SYSTEM (heavy, load separately)
/// Only initialized when explicitly needed
List<SingleChildWidget> getAgentProviders() => [
  ChangeNotifierProvider(create: (_) => AgentProvider()),
  ChangeNotifierProvider(create: (_) => AgentTaskProvider()),
  ChangeNotifierProvider(create: (_) => ReportProvider()),
  ChangeNotifierProvider(create: (_) => BroadcastProvider()),
  ChangeNotifierProvider(create: (_) => OperationalIntelligenceProvider()),
  ChangeNotifierProvider(create: (_) => IdentityProvider()),
  ChangeNotifierProvider(create: (_) => AiInsightsProvider()),
  ChangeNotifierProvider(create: (_) => ForecastProvider()),
];

/// BUILD ROLE-BASED PROVIDER TREE
/// Only initialize providers needed for the user's current role
List<SingleChildWidget> getRoleBasedProviders(
  String? userRole,
  SharedPreferences? prefs,
) {
  // Core providers always included
  final providers = <SingleChildWidget>[...getCoreProviders(prefs)];

  // Guest users (null role) need customer providers to browse products and use the cart
  if (userRole == null || userRole.isEmpty) {
    providers.addAll(getCustomerProviders(prefs));
    return providers;
  }

  switch (userRole.toLowerCase()) {
    case 'customer':
      providers.addAll(getCustomerProviders(prefs));
      break;
    case 'owner':
    case 'admin':
      providers.addAll(getOwnerProviders(prefs));
      break;
    case 'rider':
    case 'delivery_agent':
      providers.addAll(getRiderProviders(prefs));
      break;
    case 'employee':
      providers.addAll(getEmployeeProviders(prefs));
      break;
    default:
      providers.addAll(getCustomerProviders(prefs));
  }

  return providers;
}

/// Load Agent providers separately (heavy, AI-intensive)
/// Call this explicitly when Mission Control features are needed
void initializeAgentProviders(BuildContext context) {
  // Lazy-load agent providers into context
  // This prevents blocking startup
  Future.microtask(() {
    if (context.mounted) {
      Provider.of<AgentProvider>(context, listen: false);
    }
  });
}
