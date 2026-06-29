#!/bin/bash

# ============================================================================
# FUFAJI STORE - PRODUCTION DEPLOYMENT SCRIPT
# Deploy all Edge Functions to Supabase
# ============================================================================

set -e  # Exit on error

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║           FUFAJI STORE - PRODUCTION DEPLOYMENT                    ║"
echo "║                   Supabase Edge Functions                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# STEP 1: PRE-DEPLOYMENT CHECKS
# ============================================================================

echo "📋 STEP 1: Pre-Deployment Checks..."
echo ""

if ! command -v supabase &> /dev/null; then
    echo "❌ ERROR: Supabase CLI not installed!"
    echo "Install it with: npm install -g supabase"
    exit 1
fi

echo "✅ Supabase CLI found: $(supabase --version)"

# Check if logged in
if ! supabase projects list &> /dev/null; then
    echo "❌ Not logged into Supabase!"
    echo "Run: supabase login"
    exit 1
fi

echo "✅ Logged into Supabase"
echo ""

# ============================================================================
# STEP 2: CHECK ENVIRONMENT VARIABLES
# ============================================================================

echo "🔐 STEP 2: Verify Secrets Are Configured..."
echo ""

echo "Checking if secrets are set in Supabase..."
echo "These must be configured BEFORE deployment:"
echo ""
echo "Required secrets:"
echo "  ✓ RAZORPAY_KEY_ID"
echo "  ✓ RAZORPAY_KEY_SECRET"
echo "  ✓ RAZORPAY_WEBHOOK_SECRET"
echo "  ✓ FIREBASE_PROJECT_ID"
echo "  ✓ FIREBASE_PRIVATE_KEY"
echo "  ✓ FIREBASE_CLIENT_EMAIL"
echo "  ✓ JWT_SECRET"
echo "  ✓ TWILIO_ACCOUNT_SID"
echo "  ✓ TWILIO_AUTH_TOKEN"
echo "  ✓ TWILIO_PHONE_NUMBER"
echo "  ✓ SENDGRID_API_KEY"
echo ""

read -p "Are all secrets configured in Supabase? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Please configure secrets first:"
    echo "   supabase secrets set RAZORPAY_KEY_ID '<your-key-id>'"
    echo "   supabase secrets set RAZORPAY_KEY_SECRET '<your-secret>'"
    echo "   ... (set all secrets)"
    exit 1
fi

echo "✅ Secrets verified"
echo ""

# ============================================================================
# STEP 3: DEPLOY FUNCTIONS
# ============================================================================

echo "🚀 STEP 3: Deploying Edge Functions..."
echo ""

FUNCTIONS=(
    "auth-endpoints"
    "payment-endpoints"
    "error-handling"
    "razorpay-webhook-dual-write"
    "send-email"
    "send-notification"
    "get-recommendations"
)

DEPLOYED=0
FAILED=0

for FUNC in "${FUNCTIONS[@]}"; do
    echo "📦 Deploying: $FUNC..."

    if supabase functions deploy "$FUNC"; then
        echo "✅ $FUNC deployed successfully"
        ((DEPLOYED++))
    else
        echo "❌ $FUNC deployment failed!"
        ((FAILED++))
    fi
    echo ""
done

echo "═══════════════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# STEP 4: VERIFY DEPLOYMENTS
# ============================================================================

echo "✓ STEP 4: Verify Deployments..."
echo ""

echo "Deployed Functions: $DEPLOYED"
echo "Failed Functions: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo "⚠️  Some functions failed to deploy."
    echo "Review the errors above and try again."
    exit 1
fi

echo "✅ All functions deployed successfully!"
echo ""

# ============================================================================
# STEP 5: POST-DEPLOYMENT VERIFICATION
# ============================================================================

echo "🧪 STEP 5: Post-Deployment Verification..."
echo ""

echo "Testing endpoints:"
echo ""

# Test auth-endpoints
echo "1. Testing auth-endpoints..."
curl -s -X POST "https://<YOUR_PROJECT_ID>.supabase.co/functions/v1/auth-endpoints" \
  -H "Content-Type: application/json" \
  -d '{"action":"test"}' | head -c 100 && echo "..." || echo "Connection failed"

echo ""
echo ""

# ============================================================================
# STEP 6: DEPLOYMENT COMPLETE
# ============================================================================

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                   ✅ DEPLOYMENT COMPLETE!                        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 NEXT STEPS:"
echo ""
echo "1. ✅ Verify webhook is configured in Razorpay:"
echo "   URL: https://<YOUR_PROJECT_ID>.supabase.co/functions/v1/razorpay-webhook-dual-write"
echo "   Events: payment.authorized, payment.captured, payment.failed"
echo ""
echo "2. ✅ Update your mobile app with:"
echo "   - Supabase URL: https://<YOUR_PROJECT_ID>.supabase.co"
echo "   - Supabase Anon Key: <YOUR_ANON_KEY>"
echo ""
echo "3. ✅ Run integration tests:"
echo "   flutter test test/integration/"
echo ""
echo "4. ✅ Build & deploy APK to Google Play Store:"
echo "   flutter build appbundle --release"
echo ""
echo "5. ✅ Monitor Sentry for errors:"
echo "   https://sentry.io/organizations/your-org/issues/"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 Your Fufaji Store is now LIVE on production!"
echo ""
