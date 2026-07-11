#!/bin/bash

# 🔐 Fufaji Flutter Build Script with Secrets
# This script builds the Flutter app with all required environment variables

set -e

# ──────────────────────────────────────────────────────
# Configuration - Update these with actual values
# ──────────────────────────────────────────────────────

# Render Backend
API_BASE_URL="https://fufajis-online-business.onrender.com"

# Supabase
SUPABASE_URL="https://your-project-url.supabase.co"
SUPABASE_ANON_KEY="your-anon-key-here"

# Razorpay (get from Render dashboard or .env)
RAZORPAY_KEY_ID="rzp_live_xxxxx"

# Google Maps
GOOGLE_MAPS_KEY="your-google-maps-key"

# Sentry (Optional)
SENTRY_DSN="https://your-sentry-dsn"

# ──────────────────────────────────────────────────────
# Parse Command Line Arguments
# ──────────────────────────────────────────────────────

BUILD_TYPE="${1:-apk}"  # apk, aab, ios, web, debug
FLAVOR="${2:-release}" # release, debug, profile

# ──────────────────────────────────────────────────────
# Load from .env if it exists
# ──────────────────────────────────────────────────────

if [ -f .env ]; then
    echo "📂 Loading secrets from .env..."
    export $(cat .env | xargs)

    API_BASE_URL="${API_BASE_URL:-$API_BASE_URL}"
    SUPABASE_URL="${SUPABASE_URL:-$SUPABASE_URL}"
    SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$SUPABASE_ANON_KEY}"
    RAZORPAY_KEY_ID="${RAZORPAY_KEY_ID:-$RAZORPAY_KEY_ID}"
    GOOGLE_MAPS_KEY="${GOOGLE_MAPS_KEY:-$GOOGLE_MAPS_KEY}"
    SENTRY_DSN="${SENTRY_DSN:-$SENTRY_DSN}"
fi

# ──────────────────────────────────────────────────────
# Validate Required Variables
# ──────────────────────────────────────────────────────

echo "🔍 Validating secrets..."

if [ -z "$API_BASE_URL" ]; then
    echo "❌ Error: API_BASE_URL not set"
    exit 1
fi

if [ -z "$SUPABASE_URL" ]; then
    echo "❌ Error: SUPABASE_URL not set"
    exit 1
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ Error: SUPABASE_ANON_KEY not set"
    exit 1
fi

if [ -z "$RAZORPAY_KEY_ID" ]; then
    echo "❌ Error: RAZORPAY_KEY_ID not set"
    exit 1
fi

echo "✅ All required secrets validated"

# ──────────────────────────────────────────────────────
# Build Command
# ──────────────────────────────────────────────────────

echo ""
echo "🔨 Building Fufaji Flutter App..."
echo "📦 Build Type: $BUILD_TYPE"
echo "🏷️  Flavor: $FLAVOR"
echo ""

# Build flags common to all builds
DART_DEFINES="\
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=RAZORPAY_KEY_ID=$RAZORPAY_KEY_ID \
  --dart-define=GOOGLE_MAPS_KEY=$GOOGLE_MAPS_KEY \
  --dart-define=SENTRY_DSN=$SENTRY_DSN"

case $BUILD_TYPE in
    debug)
        echo "📱 Building debug APK..."
        flutter run $DART_DEFINES
        ;;
    apk)
        echo "📱 Building release APK..."
        if [ "$FLAVOR" = "debug" ]; then
            flutter build apk --debug $DART_DEFINES
        else
            flutter build apk --release $DART_DEFINES
        fi
        echo "✅ APK built: build/app/outputs/flutter-apk/app-release.apk"
        ;;
    aab)
        echo "📦 Building Android App Bundle..."
        flutter build appbundle --release $DART_DEFINES
        echo "✅ AAB built: build/app/outputs/bundle/release/app-release.aab"
        ;;
    ios)
        echo "🍎 Building iOS app..."
        flutter build ios --release $DART_DEFINES
        echo "✅ iOS app built"
        ;;
    web)
        echo "🌐 Building web app..."
        flutter build web --release $DART_DEFINES
        echo "✅ Web app built: build/web"
        ;;
    *)
        echo "❌ Unknown build type: $BUILD_TYPE"
        echo "Usage: ./scripts/build.sh [apk|aab|ios|web|debug] [release|debug]"
        exit 1
        ;;
esac

echo ""
echo "🎉 Build completed successfully!"
echo ""
echo "Next steps:"
echo "1. Test the app on a device"
echo "2. Upload to Play Store / TestFlight"
echo "3. Monitor logs in Sentry and Firebase"
echo "4. Check Supabase console for data sync"
