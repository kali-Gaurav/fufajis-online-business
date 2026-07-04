package com.fufaji.store.utils;

import com.fufaji.store.BuildConfig;

public class Constants {
    // Firebase
    public static final String FIREBASE_PRODUCTS_COLLECTION = "products";
    public static final String FIREBASE_USERS_COLLECTION = "users";
    public static final String FIREBASE_ORDERS_COLLECTION = "orders";
    public static final String FIREBASE_CARTS_COLLECTION = "carts";
    public static final String FIREBASE_CATEGORIES_COLLECTION = "categories";
    public static final String FIREBASE_SETTINGS_COLLECTION = "settings";

    // Preferences
    public static final String PREFERENCES_NAME = "fufaji_prefs";

    // Razorpay
    public static final String RAZORPAY_KEY_ID = BuildConfig.RAZORPAY_KEY_ID;

    // Payment
    public static final String PAYMENT_METHOD_UPI = "upi";
    public static final String PAYMENT_METHOD_CARD = "card";
    public static final String PAYMENT_METHOD_NETBANKING = "netbanking";

    // Order Status
    public static final String ORDER_STATUS_PENDING = "pending";
    public static final String ORDER_STATUS_CONFIRMED = "confirmed";
    public static final String ORDER_STATUS_PACKED = "packed";
    public static final String ORDER_STATUS_OUT_FOR_DELIVERY = "out_for_delivery";
    public static final String ORDER_STATUS_DELIVERED = "delivered";
    public static final String ORDER_STATUS_CANCELLED = "cancelled";

    // Payment Status
    public static final String PAYMENT_STATUS_PENDING = "pending";
    public static final String PAYMENT_STATUS_SUCCESS = "success";
    public static final String PAYMENT_STATUS_FAILED = "failed";
    public static final String PAYMENT_STATUS_REFUNDED = "refunded";

    // User Roles
    public static final String ROLE_CUSTOMER = "customer";
    public static final String ROLE_EMPLOYEE = "employee";
    public static final String ROLE_DELIVERY_PARTNER = "delivery_partner";
    public static final String ROLE_OWNER = "owner";
    public static final String ROLE_ADMIN = "admin";

    // Colors (Material Design 3)
    public static final int COLOR_PRIMARY = 0xFF1A5276;          // Blue
    public static final int COLOR_ACCENT = 0xFFE67E22;           // Orange
    public static final int COLOR_BACKGROUND = 0xFFFDFEFE;       // Off-white
    public static final int COLOR_TEXT_PRIMARY = 0xFF1C2833;     // Dark gray
    public static final int COLOR_TEXT_SECONDARY = 0xFF5D6D7B;   // Light gray
    public static final int COLOR_SUCCESS = 0xFF27AE60;          // Green
    public static final int COLOR_ERROR = 0xFFE74C3C;            // Red
    public static final int COLOR_WARNING = 0xFFF39C12;          // Orange
    public static final int COLOR_SURFACE = 0xFFFFFFFF;          // White

    // Animations
    public static final int ANIMATION_DURATION_SHORT = 200;
    public static final int ANIMATION_DURATION_MEDIUM = 400;
    public static final int ANIMATION_DURATION_LONG = 600;

    // Timeouts
    public static final long FIREBASE_TIMEOUT = 30000;           // 30 seconds
    public static final long OTP_TIMEOUT = 60000;                // 1 minute
    public static final long OTP_EXPIRY = 600000;                // 10 minutes

    // Pagination
    public static final int PRODUCTS_PAGE_SIZE = 20;
    public static final int ORDERS_PAGE_SIZE = 10;

    // Cache
    public static final long CACHE_DURATION_PRODUCTS = 3600000;  // 1 hour
    public static final long CACHE_DURATION_CATEGORIES = 86400000; // 24 hours

    // Preferences Keys
    public static final String PREF_USER_ID = "user_id";
    public static final String PREF_USER_NAME = "user_name";
    public static final String PREF_USER_PHONE = "user_phone";
    public static final String PREF_USER_ROLE = "user_role";
    public static final String PREF_DEFAULT_ADDRESS = "default_address";
    public static final String PREF_THEME = "theme";
    public static final String PREF_NOTIFICATION_ENABLED = "notification_enabled";

    // Language (Default: English only - no switching)
    public static final String LANGUAGE_ENGLISH = "en";

    // Categories (Emojis)
    public static final String CATEGORY_VEGETABLES = "🥬";
    public static final String CATEGORY_DAIRY = "🥛";
    public static final String CATEGORY_GRAINS = "🌾";
    public static final String CATEGORY_SPICES = "🧂";
    public static final String CATEGORY_OILS = "🫒";
    public static final String CATEGORY_FRUITS = "🍎";
    public static final String CATEGORY_SNACKS = "🍪";
    public static final String CATEGORY_BEVERAGES = "☕";
    public static final String CATEGORY_HOUSEHOLD = "🧹";
    public static final String CATEGORY_HEALTH = "🏥";

    // Delivery
    public static final int DELIVERY_TIME_STANDARD = 30;         // 30 minutes
    public static final int DELIVERY_TIME_EXPRESS = 15;          // 15 minutes
    public static final double MIN_ORDER_VALUE = 100.0;          // ₹100

    // Dad Jokes (for app personality)
    public static final String DAD_JOKE_ADD_TO_CART = "Your cart is so full, even express delivery might be slow! 😂";
    public static final String DAD_JOKE_CHECKOUT = "Your order will arrive so fast, the delivery partner will be surprised! 🚚";
    public static final String DAD_JOKE_ORDER_PLACED = "Order placed! Now just sit back and enjoy the shopping bliss! 🎉";
    public static final String DAD_JOKE_EMPTY_CART = "Cart is empty! Maybe your appetite disappeared too! 😋";
}
