#!/bin/bash

# Bash Script for Deploying Tasks #19, #20, #21
# Usage: ./deploy-tasks-19-20-21.sh [--firebase-path /path/to/serviceAccount.json] [--razorpay-secret your-secret]
# Prerequisites: Supabase CLI, Firebase service account JSON, Razorpay webhook secret

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
FIREBASE_SERVICE_ACCOUNT_PATH=""
RAZORPAY_WEBHOOK_SECRET=""
SUPABASE_PROJECT_ID="mxjtgpunctckovtuyfmz"

while [[ $# -gt 0 ]]; do
  case $1 in
    --firebase-path)
      FIREBASE_SERVICE_ACCOUNT_PATH="$2"
      shift 2
      ;;
    --razorpay-secret)
      RAZORPAY_WEBHOOK_SECRET="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Functions for output
write_header() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

write_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

write_error() {
  echo -e "${RED}❌ $1${NC}"
}

write_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

write_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if running from project root
if [ ! -f "supabase/config.toml" ]; then
  write_error "Not in Fufaji project root. Please run from the project directory"
  exit 1
fi

write_header "TASK #19, #20, #21 DEPLOYMENT SCRIPT"
write_info "Project: Fufaji Online Business"
write_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"

# ============================================================================
# TASK #19: Deploy Firebase Auth Bridge
# ============================================================================

write_header "TASK #19: Deploy Firebase Auth Verification Bridge"

if [ -z "$FIREBASE_SERVICE_ACCOUNT_PATH" ]; then
  write_warning "Firebase service account path not provided"
  read -p "Enter path to Firebase service account JSON: " FIREBASE_SERVICE_ACCOUNT_PATH
fi

if [ ! -f "$FIREBASE_SERVICE_ACCOUNT_PATH" ]; then
  write_error "Firebase service account file not found: $FIREBASE_SERVICE_ACCOUNT_PATH"
  exit 1
fi

write_info "Setting FIREBASE_SERVICE_ACCOUNT secret..."
echo ""
write_warning "Please run this command:"
echo ""
echo -e "${YELLOW}  cd $(pwd)${NC}"
SERVICE_ACCOUNT_CONTENT=$(cat "$FIREBASE_SERVICE_ACCOUNT_PATH")
echo -e "${YELLOW}  supabase secrets set FIREBASE_SERVICE_ACCOUNT '${SERVICE_ACCOUNT_CONTENT}'${NC}"
echo ""

write_info "Verifying firebase-bridge.ts exists..."
if [ -f "supabase/functions/_shared/firebase-bridge.ts" ]; then
  write_success "firebase-bridge.ts found"
else
  write_error "firebase-bridge.ts not found"
  exit 1
fi

# ============================================================================
# TASK #20: Deploy Storage Buckets Migration
# ============================================================================

write_header "TASK #20: Deploy Storage Buckets Migration"

write_info "Verifying migration file..."
if [ -f "supabase/migrations/04_storage_buckets_firestore_sync.sql" ]; then
  write_success "Migration file found"
else
  write_error "Migration file not found"
  exit 1
fi

echo ""
write_warning "Please run this command:"
echo ""
echo -e "${YELLOW}  cd $(pwd)/supabase${NC}"
echo -e "${YELLOW}  supabase db push${NC}"
echo ""

# ============================================================================
# TASK #21: Deploy Razorpay Webhook
# ============================================================================

write_header "TASK #21: Deploy Razorpay Webhook Edge Function"

if [ -z "$RAZORPAY_WEBHOOK_SECRET" ]; then
  write_warning "Razorpay webhook secret not provided"
  read -p "Enter Razorpay webhook secret (or press Enter to skip): " RAZORPAY_WEBHOOK_SECRET
fi

if [ -n "$RAZORPAY_WEBHOOK_SECRET" ]; then
  write_info "Setting RAZORPAY_WEBHOOK_SECRET..."
  echo ""
  write_warning "Please run this command:"
  echo ""
  echo -e "${YELLOW}  supabase secrets set RAZORPAY_WEBHOOK_SECRET '${RAZORPAY_WEBHOOK_SECRET}'${NC}"
  echo ""
else
  write_warning "Skipping RAZORPAY_WEBHOOK_SECRET (you'll need to set it manually)"
fi

write_info "Verifying webhook function exists..."
if [ -f "supabase/functions/razorpay-webhook-dual-write/index.ts" ]; then
  write_success "Webhook function found"
else
  write_error "Webhook function not found"
  exit 1
fi

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================

write_header "DEPLOYMENT COMMANDS TO RUN MANUALLY"

echo ""
echo -e "${BLUE}Step 1: Set Firebase Service Account Secret${NC}"
echo -e "${YELLOW}  supabase secrets set FIREBASE_SERVICE_ACCOUNT '$(cat "$FIREBASE_SERVICE_ACCOUNT_PATH")'${NC}"

echo ""
echo -e "${BLUE}Step 2: Verify Secrets Are Set${NC}"
echo -e "${YELLOW}  supabase secrets list${NC}"

echo ""
echo -e "${BLUE}Step 3: Deploy Storage Migration${NC}"
echo -e "${YELLOW}  cd $(pwd)/supabase${NC}"
echo -e "${YELLOW}  supabase db push${NC}"

echo ""
echo -e "${BLUE}Step 4: Set Razorpay Webhook Secret${NC}"
if [ -n "$RAZORPAY_WEBHOOK_SECRET" ]; then
  echo -e "${YELLOW}  supabase secrets set RAZORPAY_WEBHOOK_SECRET '${RAZORPAY_WEBHOOK_SECRET}'${NC}"
else
  echo -e "${YELLOW}  supabase secrets set RAZORPAY_WEBHOOK_SECRET 'your-razorpay-webhook-secret'${NC}"
fi

echo ""
echo -e "${BLUE}Step 5: Deploy Edge Functions${NC}"
echo -e "${YELLOW}  supabase functions deploy _shared/firebase-bridge${NC}"
echo -e "${YELLOW}  supabase functions deploy razorpay-webhook-dual-write${NC}"

echo ""
echo -e "${BLUE}Step 6: Configure Razorpay Webhook (Manual)${NC}"
echo -e "${YELLOW}  1. Go to Razorpay Dashboard → Settings → Webhooks${NC}"
echo -e "${YELLOW}  2. Add/Edit webhook with:${NC}"
echo -e "${YELLOW}     URL: https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/razorpay-webhook-dual-write${NC}"
echo -e "${YELLOW}     Events: payment.authorized, payment.failed, payment.completed${NC}"
echo -e "${YELLOW}     Secret: (same as RAZORPAY_WEBHOOK_SECRET)${NC}"

echo ""
echo -e "${BLUE}Step 7: Verify Deployment${NC}"
echo -e "${YELLOW}  - Check Supabase Console → Edge Functions${NC}"
echo -e "${YELLOW}  - Check Supabase Console → SQL Editor for storage buckets${NC}"
echo -e "${YELLOW}  - Review DEPLOYMENT_TASKS_19_20_21.md for detailed testing${NC}"

echo ""
write_header "NEXT STEPS"
write_info "After deployment, run Task #22: Test end-to-end order flow"
write_info "See DEPLOYMENT_TASKS_19_20_21.md for detailed verification steps"
echo ""
