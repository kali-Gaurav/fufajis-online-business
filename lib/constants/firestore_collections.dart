/// Firestore Collections Constants for Fufaji
/// All collection names defined in one place for consistency
class FirestoreCollections {
  // User & Authentication Collections
  static const String USERS = 'users';
  static const String USER_PROFILES = 'user_profiles';
  static const String USER_PREFERENCES = 'user_preferences';
  static const String USER_SESSIONS = 'user_sessions';
  static const String USER_DEVICES = 'user_devices';

  // Shop & Business Collections
  static const String SHOPS = 'shops';
  static const String SHOP_OWNERS = 'shop_owners';
  static const String SHOP_SETTINGS = 'shop_settings';
  static const String SHOP_ANALYTICS = 'shop_analytics';

  // Product Collections
  static const String PRODUCTS = 'products';
  static const String PRODUCT_CATEGORIES = 'product_categories';
  static const String PRODUCT_REVIEWS = 'product_reviews';
  static const String PRODUCT_IMAGES = 'product_images';
  static const String PRODUCT_VARIANTS = 'product_variants';

  // Inventory Collections
  static const String INVENTORY = 'inventory';
  static const String INVENTORY_TRANSACTIONS = 'inventory_transactions';
  static const String INVENTORY_RESERVED = 'inventory_reserved';
  static const String STOCK_LEVELS = 'stock_levels';
  static const String STOCK_MOVEMENTS = 'stock_movements';

  // Order Collections
  static const String ORDERS = 'orders';
  static const String ORDER_ITEMS = 'order_items';
  static const String ORDER_HISTORY = 'order_history';
  static const String ORDER_TRACKING = 'order_tracking';

  // Payment Collections
  static const String PAYMENTS = 'payments';
  static const String PAYMENT_LEDGER = 'payment_ledger';
  static const String PAYMENT_METHODS = 'payment_methods';
  static const String WALLET = 'wallet';
  static const String WALLET_TRANSACTIONS = 'wallet_transactions';
  static const String REFUNDS = 'refunds';
  static const String PAYOUTS = 'payouts';

  // Fulfillment & Packing Collections
  static const String FULFILLMENT_TASKS = 'fulfillment_tasks';
  static const String FULFILLMENT_WORKFLOWS = 'fulfillment_workflows';
  static const String PACKING_STATIONS = 'packing_stations';
  static const String PACKING_BATCHES = 'packing_batches';
  static const String QUALITY_CHECKS = 'quality_checks';

  // Delivery Collections - CONSOLIDATED (Module 9 P0 Security Fix)
  // All delivery data consolidated into single 'delivery_tasks' collection
  // Orphaned collections to be deleted: delivery_tracking, delivery_routes, delivery_assignments,
  // delivery_otp, delivery_agents, delivery_locations, delivery_status, delivery_history,
  // delivery_notifications, delivery_preferences
  static const String DELIVERIES = 'deliveries'; // Legacy, use DELIVERY_TASKS for new code
  static const String DELIVERY_TASKS = 'delivery_tasks'; // SINGLE SOURCE OF TRUTH
  static const String RIDER_LOCATIONS = 'rider_locations';
  static const String DELIVERY_PARTNER_LOCATIONS = 'delivery_partner_locations';

  // Chat & Communication
  static const String CHATS = 'chats';
  static const String MESSAGES = 'messages';
  static const String CHAT_ROOMS = 'chat_rooms';
  static const String NOTIFICATIONS = 'notifications';

  // Coupon & Promotions
  static const String COUPONS = 'coupons';
  static const String PROMOTIONS = 'promotions';
  static const String DISCOUNTS = 'discounts';
  static const String LOYALTY_REWARDS = 'loyalty_rewards';

  // Loyalty & Membership
  static const String LOYALTY = 'loyalty';
  static const String LOYALTY_TRANSACTIONS = 'loyalty_transactions';
  static const String LOYALTY_TIERS = 'loyalty_tiers';
  static const String MEMBERSHIP_PLANS = 'membership_plans';

  // Returns & Complaints
  static const String RETURNS = 'returns';
  static const String RETURN_ITEMS = 'return_items';
  static const String COMPLAINTS = 'complaints';
  static const String COMPLAINT_RESOLUTION = 'complaint_resolution';

  // Audit & Logging
  static const String AUDIT_LOG = 'audit_log';
  static const String ACTIVITY_LOG = 'activity_log';
  static const String SECURITY_LOGS = 'security_logs';
  static const String ERROR_LOGS = 'error_logs';

  // Analytics & Reporting
  static const String ANALYTICS = 'analytics';
  static const String SALES_ANALYTICS = 'sales_analytics';
  static const String USER_ANALYTICS = 'user_analytics';
  static const String BUSINESS_METRICS = 'business_metrics';

  // Settings & Configuration
  static const String APP_CONFIG = 'app_config';
  static const String FEATURE_FLAGS = 'feature_flags';
  static const String PRICING_RULES = 'pricing_rules';
  static const String DELIVERY_ZONES = 'delivery_zones';

  // Employee & Staff
  static const String EMPLOYEES = 'employees';
  static const String EMPLOYEE_ROLES = 'employee_roles';
  static const String EMPLOYEE_SCHEDULES = 'employee_schedules';
  static const String EMPLOYEE_PERFORMANCE = 'employee_performance';

  // Rider & Delivery Partner
  static const String RIDERS = 'riders';
  static const String RIDER_ANALYTICS = 'rider_analytics';
  static const String RIDER_PAYOUTS = 'rider_payouts';
  static const String RIDER_RATINGS = 'rider_ratings';

  // Admin & Management
  static const String ADMIN_USERS = 'admin_users';
  static const String ADMIN_ACTIONS = 'admin_actions';
  static const String SYSTEM_SETTINGS = 'system_settings';
  static const String BACKUP_METADATA = 'backup_metadata';

  // Third-party Integrations
  static const String RAZORPAY_WEBHOOKS = 'razorpay_webhooks';
  static const String SMS_LOGS = 'sms_logs';
  static const String EMAIL_LOGS = 'email_logs';
  static const String WHATSAPP_LOGS = 'whatsapp_logs';

  // ========== CONSOLIDATED DELIVERY COLLECTIONS (Module 9 P0 Security Fix) ==========
  // DEPRECATED - These are being consolidated into DELIVERY_TASKS collection
  // Do NOT use in new code. Use DELIVERY_TASKS instead with nested fields:
  // @deprecated Use DELIVERY_TASKS instead
  static const String DELIVERY_AGENTS = 'delivery_agents';
  @deprecated
  static const String DELIVERY_ROUTES = 'delivery_routes';
  @deprecated
  static const String DELIVERY_TRACKING = 'delivery_tracking';
  @deprecated
  static const String DELIVERY_ASSIGNMENTS = 'delivery_assignments';
  @deprecated
  static const String DELIVERY_OTP = 'delivery_otp';
  @deprecated
  static const String DELIVERY_LOCATIONS = 'delivery_locations';
  @deprecated
  static const String DELIVERY_STATUS = 'delivery_status';
  @deprecated
  static const String DELIVERY_HISTORY = 'delivery_history';
  @deprecated
  static const String DELIVERY_NOTIFICATIONS = 'delivery_notifications';
  @deprecated
  static const String DELIVERY_PREFERENCES = 'delivery_preferences';

  // Fulfillment & Packing - V2
  static const String FULFILLMENT_TASKS_V2 = 'fulfillment_tasks_v2';
  static const String PACKAGE_PROCESSING = 'package_processing';

  // Employee & Agent Daily Metrics
  static const String EMPLOYEE_DAILY_STATS = 'employee_daily_stats';
  static const String AGENT_DAILY_STATS = 'agent_daily_stats';

  // AI & Analytics (Sensitive)
  static const String AI_INSIGHTS = 'ai_insights';
  static const String PRICING_RECOMMENDATIONS = 'pricing_recommendations';

  // Automation & Caching
  static const String AUTOMATION_RULE_LOGS = 'automation_rule_logs';
  static const String CACHE = 'cache';

  // Subcollections
  static String getUserMessagesSubcollection() => 'messages';
  static String getChatMessagesSubcollection() => 'messages';
  static String getOrderItemsSubcollection() => 'items';
  static String getPaymentDetailsSubcollection() => 'details';
  static String getDeliveryHistorySubcollection() => 'history';

  /// Get all collections (for admin purposes)
  static List<String> getAllCollections() => [
    USERS,
    USER_PROFILES,
    USER_PREFERENCES,
    USER_SESSIONS,
    USER_DEVICES,
    SHOPS,
    SHOP_OWNERS,
    SHOP_SETTINGS,
    SHOP_ANALYTICS,
    PRODUCTS,
    PRODUCT_CATEGORIES,
    PRODUCT_REVIEWS,
    PRODUCT_IMAGES,
    PRODUCT_VARIANTS,
    INVENTORY,
    INVENTORY_TRANSACTIONS,
    INVENTORY_RESERVED,
    STOCK_LEVELS,
    STOCK_MOVEMENTS,
    ORDERS,
    ORDER_ITEMS,
    ORDER_HISTORY,
    ORDER_TRACKING,
    PAYMENTS,
    PAYMENT_LEDGER,
    PAYMENT_METHODS,
    WALLET,
    WALLET_TRANSACTIONS,
    REFUNDS,
    PAYOUTS,
    FULFILLMENT_TASKS,
    FULFILLMENT_WORKFLOWS,
    PACKING_STATIONS,
    PACKING_BATCHES,
    QUALITY_CHECKS,
    DELIVERIES,
    DELIVERY_TASKS,
    DELIVERY_ROUTES,
    DELIVERY_TRACKING,
    RIDER_LOCATIONS,
    DELIVERY_PARTNER_LOCATIONS,
    CHATS,
    MESSAGES,
    CHAT_ROOMS,
    NOTIFICATIONS,
    COUPONS,
    PROMOTIONS,
    DISCOUNTS,
    LOYALTY_REWARDS,
    LOYALTY,
    LOYALTY_TRANSACTIONS,
    LOYALTY_TIERS,
    MEMBERSHIP_PLANS,
    RETURNS,
    RETURN_ITEMS,
    COMPLAINTS,
    COMPLAINT_RESOLUTION,
    AUDIT_LOG,
    ACTIVITY_LOG,
    SECURITY_LOGS,
    ERROR_LOGS,
    ANALYTICS,
    SALES_ANALYTICS,
    USER_ANALYTICS,
    BUSINESS_METRICS,
    APP_CONFIG,
    FEATURE_FLAGS,
    PRICING_RULES,
    DELIVERY_ZONES,
    EMPLOYEES,
    EMPLOYEE_ROLES,
    EMPLOYEE_SCHEDULES,
    EMPLOYEE_PERFORMANCE,
    RIDERS,
    RIDER_ANALYTICS,
    RIDER_PAYOUTS,
    RIDER_RATINGS,
    ADMIN_USERS,
    ADMIN_ACTIONS,
    SYSTEM_SETTINGS,
    BACKUP_METADATA,
    RAZORPAY_WEBHOOKS,
    SMS_LOGS,
    EMAIL_LOGS,
    WHATSAPP_LOGS,
    // Missing collections (P0 security fix)
    DELIVERY_AGENTS,
    FULFILLMENT_TASKS_V2,
    PACKAGE_PROCESSING,
    EMPLOYEE_DAILY_STATS,
    AGENT_DAILY_STATS,
    DELIVERY_OTP,
    DELIVERY_LOCATIONS,
    AI_INSIGHTS,
    PRICING_RECOMMENDATIONS,
    AUTOMATION_RULE_LOGS,
    CACHE,
  ];
}

/// Firestore Database Schema and Field Names
class FirestoreDatabaseSchema {
  // User Collection Fields
  static const Users = _UsersFields();

  // Order Collection Fields
  static const Orders = _OrdersFields();

  // Payment Collection Fields
  static const Payments = _PaymentsFields();

  // Inventory Collection Fields
  static const Inventory = _InventoryFields();

  // Delivery Collection Fields
  static const Deliveries = _DeliveriesFields();
}

class _UsersFields {
  const _UsersFields();
  final String UID = 'uid';
  final String PHONE = 'phone';
  final String EMAIL = 'email';
  final String NAME = 'name';
  final String ROLE = 'role'; // customer, shop_owner, rider, employee, admin
  final String AVATAR = 'avatar';
  final String ADDRESSES = 'addresses';
  final String IS_VERIFIED = 'isVerified';
  final String IS_ACTIVE = 'isActive';
  final String CREATED_AT = 'createdAt';
  final String UPDATED_AT = 'updatedAt';
  final String LAST_LOGIN = 'lastLogin';
  final String DEVICE_IDS = 'deviceIds';
}

class _OrdersFields {
  const _OrdersFields();
  final String ORDER_ID = 'orderId';
  final String ORDER_NUMBER = 'orderNumber';
  final String CUSTOMER_ID = 'customerId';
  final String CUSTOMER_NAME = 'customerName';
  final String CUSTOMER_PHONE = 'customerPhone';
  final String SHOP_ID = 'shopId';
  final String ITEMS = 'items';
  final String SUBTOTAL = 'subtotal';
  final String DELIVERY_CHARGE = 'deliveryCharge';
  final String DISCOUNT = 'discount';
  final String TAX = 'tax';
  final String TOTAL_AMOUNT = 'totalAmount';
  final String PAYMENT_METHOD = 'paymentMethod';
  final String PAYMENT_STATUS = 'paymentStatus';
  final String PAYMENT_ID = 'paymentId';
  final String ORDER_STATUS = 'orderStatus';
  final String DELIVERY_ADDRESS = 'deliveryAddress';
  final String DELIVERY_TYPE = 'deliveryType';
  final String CREATED_AT = 'createdAt';
  final String UPDATED_AT = 'updatedAt';
  final String EXPECTED_DELIVERY = 'expectedDelivery';
}

class _PaymentsFields {
  const _PaymentsFields();
  final String PAYMENT_ID = 'paymentId';
  final String ORDER_ID = 'orderId';
  final String ORDER_NUMBER = 'orderNumber';
  final String AMOUNT = 'amount';
  final String CURRENCY = 'currency';
  final String STATUS = 'status';
  final String METHOD = 'method';
  final String VERIFIED = 'verified';
  final String SIGNATURE = 'signature';
  final String CUSTOMER_ID = 'customerId';
  final String CREATED_AT = 'createdAt';
  final String VERIFIED_AT = 'verifiedAt';
}

class _InventoryFields {
  const _InventoryFields();
  final String PRODUCT_ID = 'productId';
  final String SHOP_ID = 'shopId';
  final String QUANTITY = 'quantity';
  final String RESERVED = 'reserved';
  final String AVAILABLE = 'available';
  final String LAST_UPDATED = 'lastUpdated';
  final String WAREHOUSE_LOCATION = 'warehouseLocation';
}

class _DeliveriesFields {
  const _DeliveriesFields();
  final String DELIVERY_ID = 'deliveryId';
  final String ORDER_ID = 'orderId';
  final String CUSTOMER_ID = 'customerId';
  final String RIDER_ID = 'riderId';
  final String STATUS = 'status';
  final String PICKUP_ADDRESS = 'pickupAddress';
  final String DELIVERY_ADDRESS = 'deliveryAddress';
  final String CURRENT_LOCATION = 'currentLocation';
  final String START_TIME = 'startTime';
  final String END_TIME = 'endTime';
  final String DISTANCE = 'distance';
  final String ESTIMATED_TIME = 'estimatedTime';
}
