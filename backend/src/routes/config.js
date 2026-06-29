/**
 * ============================================================================
 * config.js - Public Configuration Endpoint
 * ============================================================================
 * Serves public app configuration to Flutter client at startup.
 *
 * CRITICAL: Only returns SAFE config. Never returns secrets.
 * Secrets stay server-side in AWS SSM.
 *
 * Safe to expose (no secrets):
 * - API_BASE_URL
 * - SHOP_LOCATION
 * - DELIVERY_RADIUS
 * - RAZORPAY_KEY_ID (not the secret!)
 * - STRIPE_PUBLISHABLE_KEY (public)
 * - Feature flags
 *
 * Never expose:
 * - RAZORPAY_KEY_SECRET
 * - RAZORPAY_WEBHOOK_SECRET
 * - Firebase service account
 * - Gemini API key
 * - SendGrid API key
 * ============================================================================
 */

const express = require('express');
const router = express.Router();

/**
 * GET /config/app-config
 *
 * Returns safe application configuration that can be embedded in APK.
 * Called by Flutter at startup to get runtime configuration.
 *
 * Example Usage (Flutter):
 * ```dart
 * final response = await http.get(
 *   Uri.parse('${AppConfig.apiBaseUrl}/config/app-config'),
 *   headers: {'Content-Type': 'application/json'}
 * );
 * final config = AppConfig.fromJson(jsonDecode(response.body));
 * ```
 */
router.get('/app-config', async (req, res) => {
  try {
    // SAFE config - no secrets, only public values
    const safeConfig = {
      success: true,
      data: {
        // API & Base URLs
        apiBaseUrl: process.env.API_BASE_URL || 'https://fufaji-api.render.com',

        // Shop Information (public)
        shop: {
          latitude: parseFloat(process.env.SHOP_LATITUDE || '25.1006'),
          longitude: parseFloat(process.env.SHOP_LONGITUDE || '76.5156'),
          maxDeliveryRadiusKm: parseFloat(process.env.DELIVERY_RADIUS_KM || '15'),
          city: 'Baran',
          state: 'Rajasthan',
          address: 'Jalawar Road, Tel Factory, Baran, Rajasthan 325205',
        },

        // Payment Configuration (PUBLIC KEYS ONLY!)
        payments: {
          razorpayKeyId: process.env.RAZORPAY_KEY_ID || '',
          // ⚠️ NEVER include RAZORPAY_KEY_SECRET here
        },

        // Analytics & Monitoring (safe to share)
        monitoring: {
          sentryDsn: process.env.SENTRY_DSN || '',
          // ⚠️ NEVER include Sentry auth token here
        },

        // Google APIs (restricted keys)
        google: {
          mapsKey: process.env.GOOGLE_MAPS_KEY || '',
          // ⚠️ NEVER include Gemini API key here (should never be in app)
        },

        // Supabase Configuration (PUBLIC KEYS ONLY!)
        supabase: {
          url: process.env.SUPABASE_URL || 'https://mxjtgpunctckovtuyfmz.supabase.co',
          anonKey: process.env.SUPABASE_PUBLISHABLE_KEY || '',
        },

        // Feature Flags (can add more as needed)
        features: {
          whatsappEnabled: !!process.env.WHATSAPP_TOKEN,
          aiPricingEnabled: true,
          chatbotEnabled: true,
          deliveryTrackingEnabled: true,
        },

        // App Metadata
        app: {
          name: "Fufaji's Online",
          version: '1.2.1',
          minSupportedVersion: '1.0.0',
          forceUpdateVersion: null, // Set if update is mandatory
        },

        // API Configuration
        api: {
          requestTimeout: 30000,
          retryAttempts: 3,
          retryDelay: 1000,
        },

        // Cache Configuration
        cache: {
          productsRefreshIntervalSeconds: 300, // 5 minutes
          categoriesRefreshIntervalSeconds: 600, // 10 minutes
          inventoryRefreshIntervalSeconds: 60, // 1 minute
        },

        // Delivery Configuration
        delivery: {
          maxDeliveryRadiusKm: parseFloat(process.env.DELIVERY_RADIUS_KM || '15'),
          estimatedDeliveryTimeMinutes: 30,
          minOrderValueForFreeDelivery: 0, // No minimum
          deliveryFeePerKm: 5, // Rupees
        },
      },
      timestamp: new Date().toISOString(),
    };

    // Cache for 1 hour in client
    res.set('Cache-Control', 'public, max-age=3600');
    res.json(safeConfig);
  } catch (error) {
    console.error('[config] Failed to get app config:', error.message);
    res.status(500).json({
      success: false,
      error: 'config_error',
      message: 'Failed to load configuration'
    });
  }
});

/**
 * GET /config/payment-webhooks-enabled
 * Check if payment webhooks are configured (for debugging)
 */
router.get('/payment-webhooks-enabled', (req, res) => {
  res.json({
    success: true,
    razorpayEnabled: !!process.env.RAZORPAY_KEY_ID,
  });
});

module.exports = router;
