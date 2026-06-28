/// App-wide constants for Fufaji's Online
/// Collection names, route paths, status strings, and payment method strings.
library;

// ─── Firestore Collection Names ───────────────────────────────────────────────
const String kUsersCollection = 'users';
const String kProductsCollection = 'products';
const String kOrdersCollection = 'orders';
const String kCategoriesCollection = 'categories';
const String kCartCollection = 'cart';
const String kShopConfigCollection = 'shop_config';
const String kShopBranchesCollection = 'shop_branches';
const String kReviewsCollection = 'reviews';
const String kNotificationsCollection = 'notifications';
const String kPaymentsCollection = 'payments';
const String kDeliveryAgentsCollection = 'delivery_agents';
const String kCouponsCollection = 'coupons';
const String kKhataCollection = 'khata_transactions';
const String kPreAuthorizedUsersCollection = 'pre_authorized_users';
const String kSubscriptionsCollection = 'subscriptions';
const String kGroupOrdersCollection = 'group_orders';

// ─── Route Paths ──────────────────────────────────────────────────────────────
const String kSplashRoute = '/';
const String kLoginRoute = '/login';
const String kOtpRoute = '/otp';
const String kRoleSelectRoute = '/role-select';

// Customer routes
const String kCustomerHomeRoute = '/customer/home';
const String kCustomerSearchRoute = '/customer/search';
const String kCustomerCartRoute = '/customer/cart';
const String kCustomerOrdersRoute = '/customer/orders';
const String kCustomerProfileRoute = '/customer/profile';
const String kCustomerCheckoutRoute = '/customer/checkout';
const String kCustomerProductDetailRoute = '/customer/product';
const String kCustomerOrderDetailRoute = '/customer/order';
const String kCustomerAddressesRoute = '/customer/addresses';
const String kCustomerWalletRoute = '/customer/wallet';
const String kCustomerSettingsRoute = '/customer/settings';
const String kCustomerNotificationsRoute = '/customer/notifications';
const String kCustomerDeliveryTrackingRoute = '/customer/tracking';
const String kCustomerSupportRoute = '/customer/support';
const String kCustomerProfileCreationRoute = '/customer/profile-creation';

// Owner routes
const String kOwnerDashboardRoute = '/owner';
const String kOwnerProductsRoute = '/owner/products';
const String kOwnerOrdersRoute = '/owner/orders';
const String kOwnerInventoryRoute = '/owner/inventory';
const String kOwnerAnalyticsRoute = '/owner/analytics';
const String kOwnerSettingsRoute = '/owner/settings';

// Delivery routes
const String kDeliveryDashboardRoute = '/delivery';
const String kDeliveryOrdersRoute = '/delivery/orders';
const String kDeliveryEarningsRoute = '/delivery/earnings';

// Admin routes
const String kAdminDashboardRoute = '/admin';

// ─── Order Status Strings ──────────────────────────────────────────────────────
const String kOrderStatusPending = 'OrderStatus.pending';
const String kOrderStatusConfirmed = 'OrderStatus.confirmed';
const String kOrderStatusProcessing = 'OrderStatus.processing';
const String kOrderStatusPacked = 'OrderStatus.packed';
const String kOrderStatusOutForDelivery = 'OrderStatus.outForDelivery';
const String kOrderStatusDelivered = 'OrderStatus.delivered';
const String kOrderStatusCancelled = 'OrderStatus.cancelled';
const String kOrderStatusReturned = 'OrderStatus.returned';
const String kOrderStatusRefunded = 'OrderStatus.refunded';

// ─── Payment Method Strings ────────────────────────────────────────────────────
const String kPaymentMethodCod = 'cod';
const String kPaymentMethodRazorpay = 'razorpay';
const String kPaymentMethodWallet = 'wallet';
const String kPaymentMethodUpi = 'upi';
const String kPaymentMethodKhata = 'khata';

// ─── Delivery Type Strings ─────────────────────────────────────────────────────
const String kDeliveryTypeStandard = 'standard';
const String kDeliveryTypeExpress = 'express';
const String kDeliveryTypeSelfPickup = 'selfPickup';
const String kDeliveryTypeScheduled = 'scheduled';

// ─── Misc App Constants ────────────────────────────────────────────────────────
const String kDefaultShopId = 'shop_001';
const String kAppName = "Fufaji's Online";
const String kAppTagline = 'District Hyperlocal Shopping';
const String kDefaultDistrict = 'Baran';
const String kDefaultState = 'Rajasthan';
const double kDefaultShopLatitude = 25.1006;
const double kDefaultShopLongitude = 76.5156;

const int kOtpLength = 6;
const int kOtpResendSeconds = 60;
const int kMaxCartItems = 50;
const double kMinOrderValue = 50.0;
