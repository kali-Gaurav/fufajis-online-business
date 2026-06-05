#!/bin/bash
# ============================================================
# Fufaji's Online — Firebase Deployment Script
# Sets all Firebase Functions config, deploys functions +
# Firestore rules + Firestore indexes + Storage + Hosting
# ============================================================
set -e

echo "=================================================="
echo " Fufaji's Online — Firebase Deploy"
echo "=================================================="

# ── Validate required env vars ────────────────────────────
REQUIRED_VARS=(
  LIVE_API_KEY
  LIVE_KEY_SECRET
  WHATSAPP_TOKEN
  WHATSAPP_PHONE_ID
  GEMINI_API_KEY
  TWILIO_ACCOUNT_SID
  TWILIO_AUTH_TOKEN
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "ERROR: $var is not set. Aborting."
    exit 1
  fi
done

# ── Set Firebase Functions config ────────────────────────
echo ""
echo "Setting Firebase Functions config..."

firebase functions:config:set \
  razorpay.key_id="$LIVE_API_KEY" \
  razorpay.key_secret="$LIVE_KEY_SECRET" \
  razorpay.webhook_secret="${RAZORPAY_WEBHOOK_SECRET:-your_webhook_secret}" \
  whatsapp.token="$WHATSAPP_TOKEN" \
  whatsapp.phone_id="$WHATSAPP_PHONE_ID" \
  gemini.api_key="$GEMINI_API_KEY" \
  twilio.account_sid="$TWILIO_ACCOUNT_SID" \
  twilio.auth_token="$TWILIO_AUTH_TOKEN" \
  twilio.phone_number="${TWILIO_PHONE_NUMBER:-+919999999999}"

echo "Functions config set."

# ── Install functions dependencies ────────────────────────
echo ""
echo "Installing functions dependencies..."
cd functions
npm ci --prefer-offline || npm install
cd ..
echo "Dependencies installed."

# ── Run Dart/Flutter build (web) if needed ────────────────
if [ -f "pubspec.yaml" ] && command -v flutter &> /dev/null; then
  echo ""
  echo "Building Flutter web..."
  flutter build web --release --no-sound-null-safety 2>/dev/null \
    || flutter build web --release
  echo "Flutter web build complete."
fi

# ── Deploy all targets ────────────────────────────────────
echo ""
echo "Deploying to Firebase..."

firebase deploy \
  --only functions,firestore:rules,firestore:indexes,storage,hosting \
  --project fufaji-online-business

echo ""
echo "=================================================="
echo " Deployment complete!"
echo " Functions URL:"
echo "   https://asia-south1-fufaji-online-business.cloudfunctions.net"
echo " Hosting URL:"
echo "   https://fufaji-online-business.web.app"
echo "=================================================="
