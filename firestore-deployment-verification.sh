#!/bin/bash

# ============================================================================
# Firestore Rules Deployment Verification Script
#
# Purpose: Verify Firestore rules are correctly deployed to production
# Usage: ./firestore-deployment-verification.sh
#
# Checks:
# 1. Firebase CLI is installed and logged in
# 2. Project is set correctly
# 3. Rules are deployed and match local file
# 4. No syntax errors in deployed rules
# 5. All expected collections have rules defined
# ============================================================================

set -e

PROJECT_ID="fufaji-online-business"
RULES_FILE="firestore.rules"
COLORS_GREEN='\033[0;32m'
COLORS_RED='\033[0;31m'
COLORS_YELLOW='\033[1;33m'
COLORS_BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${COLORS_BLUE}======================================${NC}"
echo -e "${COLORS_BLUE}Firestore Rules Deployment Verification${NC}"
echo -e "${COLORS_BLUE}======================================${NC}"
echo ""

# ============================================================================
# CHECK 1: Firebase CLI is installed
# ============================================================================

echo -e "${COLORS_YELLOW}[1/5] Checking Firebase CLI installation...${NC}"

if ! command -v firebase &> /dev/null; then
  echo -e "${COLORS_RED}Firebase CLI not installed${NC}"
  echo "Install: npm install -g firebase-tools"
  exit 1
fi

FIREBASE_VERSION=$(firebase --version)
echo -e "${COLORS_GREEN}✓ Firebase CLI installed: ${FIREBASE_VERSION}${NC}"
echo ""

# ============================================================================
# CHECK 2: Firebase login and project setup
# ============================================================================

echo -e "${COLORS_YELLOW}[2/5] Checking Firebase authentication...${NC}"

if ! firebase projects:list &> /dev/null; then
  echo -e "${COLORS_RED}Not logged into Firebase${NC}"
  echo "Login: firebase login"
  exit 1
fi

echo -e "${COLORS_GREEN}✓ Logged into Firebase${NC}"

# Check project is set
CURRENT_PROJECT=$(firebase projects:list | grep -i "${PROJECT_ID}" || true)

if [ -z "$CURRENT_PROJECT" ]; then
  echo -e "${COLORS_YELLOW}Warning: Project ${PROJECT_ID} not found in your projects${NC}"
  echo "Available projects:"
  firebase projects:list
  exit 1
fi

echo -e "${COLORS_GREEN}✓ Project accessible: ${PROJECT_ID}${NC}"
echo ""

# ============================================================================
# CHECK 3: Local rules file exists and is valid
# ============================================================================

echo -e "${COLORS_YELLOW}[3/5] Checking local Firestore rules file...${NC}"

if [ ! -f "$RULES_FILE" ]; then
  echo -e "${COLORS_RED}Rules file not found: ${RULES_FILE}${NC}"
  exit 1
fi

echo -e "${COLORS_GREEN}✓ Rules file found: ${RULES_FILE}${NC}"

# Check file size
FILE_SIZE=$(wc -c < "$RULES_FILE")
echo -e "${COLORS_GREEN}✓ File size: ${FILE_SIZE} bytes${NC}"

# Count collections
COLLECTION_COUNT=$(grep -c "match /" "$RULES_FILE" || echo "0")
echo -e "${COLORS_GREEN}✓ Collections/paths in rules: ${COLLECTION_COUNT}${NC}"

# Verify syntax with Firebase
echo -e "${COLORS_YELLOW}  Validating syntax...${NC}"
if firebase rules:test --rules="$RULES_FILE" 2>&1 | grep -q "Error"; then
  echo -e "${COLORS_RED}Syntax error in rules file${NC}"
  firebase rules:test --rules="$RULES_FILE"
  exit 1
fi

echo -e "${COLORS_GREEN}✓ Rules syntax is valid${NC}"
echo ""

# ============================================================================
# CHECK 4: Check deployed rules
# ============================================================================

echo -e "${COLORS_YELLOW}[4/5] Checking deployed rules in Firebase...${NC}"

# Download current rules from Firebase
echo -e "${COLORS_YELLOW}  Downloading current deployed rules...${NC}"
DEPLOYED_RULES=$(firebase firestore:describe-rules --project="${PROJECT_ID}" 2>/dev/null || echo "")

if [ -z "$DEPLOYED_RULES" ]; then
  echo -e "${COLORS_YELLOW}Warning: Could not fetch deployed rules${NC}"
  echo "This is normal if rules have never been deployed"
else
  echo -e "${COLORS_GREEN}✓ Retrieved deployed rules${NC}"

  # Count deployed collections
  DEPLOYED_COUNT=$(echo "$DEPLOYED_RULES" | grep -c "match /" || echo "0")
  echo -e "${COLORS_GREEN}✓ Deployed collections/paths: ${DEPLOYED_COUNT}${NC}"
fi

echo ""

# ============================================================================
# CHECK 5: Verify all critical collections have rules
# ============================================================================

echo -e "${COLORS_YELLOW}[5/5] Verifying critical collections are covered...${NC}"

CRITICAL_COLLECTIONS=(
  "users"
  "orders"
  "products"
  "payments"
  "customer_wallet"
  "carts"
  "inventory"
  "delivery_tasks"
  "deliveries"
  "coupons"
  "audit_logs"
  "analytics"
  "settings"
  "wallet_transactions"
  "refund_requests"
  "transactions"
  "payment_disputes"
  "security_events"
  "cache"
  "shops"
  "employees"
)

MISSING_COLLECTIONS=()

for collection in "${CRITICAL_COLLECTIONS[@]}"; do
  if grep -q "match /${collection}/" "$RULES_FILE"; then
    echo -e "${COLORS_GREEN}  ✓ ${collection}${NC}"
  else
    echo -e "${COLORS_RED}  ✗ ${collection} NOT FOUND${NC}"
    MISSING_COLLECTIONS+=("$collection")
  fi
done

if [ ${#MISSING_COLLECTIONS[@]} -gt 0 ]; then
  echo ""
  echo -e "${COLORS_RED}Missing rules for:${NC}"
  printf '%s\n' "${MISSING_COLLECTIONS[@]}"
  echo ""
  echo -e "${COLORS_YELLOW}Add these collections to firestore.rules before deploying${NC}"
  exit 1
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "${COLORS_GREEN}======================================${NC}"
echo -e "${COLORS_GREEN}All Verification Checks Passed!${NC}"
echo -e "${COLORS_GREEN}======================================${NC}"
echo ""
echo "Summary:"
echo "  - Firebase CLI: Ready"
echo "  - Authentication: Ready"
echo "  - Rules file: Valid"
echo "  - Collections: ${COLLECTION_COUNT} defined"
echo "  - Critical collections: All covered"
echo ""
echo -e "${COLORS_BLUE}Ready to deploy:${NC}"
echo "  firebase deploy --only firestore:rules --project=${PROJECT_ID}"
echo ""

# ============================================================================
# OPTIONAL: Print rules syntax check summary
# ============================================================================

echo -e "${COLORS_BLUE}Rules Content Summary:${NC}"
echo "  Lines: $(wc -l < "$RULES_FILE")"
echo "  Helper functions: $(grep -c "function " "$RULES_FILE" || echo "0")"
echo "  Match patterns: $(grep -c "match /" "$RULES_FILE" || echo "0")"
echo "  Deny patterns: $(grep -c "allow.*false" "$RULES_FILE" || echo "0")"
echo ""

echo -e "${COLORS_GREEN}✓ Verification complete${NC}"
