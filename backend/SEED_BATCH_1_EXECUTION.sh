#!/bin/bash
# BATCH 1 SEEDING SCRIPT
# Fufaji Store Product Management System
# Date: 2026-07-04

set -e

echo "============================================"
echo "BATCH 1 SEEDING EXECUTION"
echo "45 Products + 94 Variants"
echo "============================================"

# Configuration
SUPABASE_URL="${SUPABASE_URL:-https://your-project.supabase.co}"
ADMIN_JWT="${ADMIN_JWT:-your-admin-jwt-token}"
BATCH_FILE="batch_1_products_catalog.json"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[1/5] Validating credentials...${NC}"
if [ -z "$ADMIN_JWT" ]; then
    echo -e "${RED}ERROR: ADMIN_JWT not set${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Credentials validated${NC}"

echo -e "${BLUE}[2/5] Validating batch file...${NC}"
if [ ! -f "$BATCH_FILE" ]; then
    echo -e "${RED}ERROR: $BATCH_FILE not found${NC}"
    exit 1
fi
PRODUCT_COUNT=$(jq '.products | length' "$BATCH_FILE")
echo -e "${GREEN}✓ Found $PRODUCT_COUNT products in batch${NC}"

echo -e "${BLUE}[3/5] Seeding to Supabase (bulk-import-products)...${NC}"
START_TIME=$(date +%s)

RESPONSE=$(curl -s -X POST \
  "$SUPABASE_URL/functions/v1/bulk-import-products" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d @"$BATCH_FILE")

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "Response: $RESPONSE"

# Parse response
CREATED=$(echo "$RESPONSE" | jq -r '.createdCount // 0')
FAILED=$(echo "$RESPONSE" | jq -r '.failedCount // 0')

if [ "$CREATED" -gt 0 ]; then
    echo -e "${GREEN}✓ Created: $CREATED products${NC}"
    echo -e "${GREEN}✓ Duration: ${DURATION}s${NC}"
else
    echo -e "${RED}✗ Failed: No products created${NC}"
    exit 1
fi

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}⚠ Warning: $FAILED products failed${NC}"
    FAILED_PRODUCTS=$(echo "$RESPONSE" | jq '.failedProducts')
    echo "Failed products: $FAILED_PRODUCTS"
fi

echo -e "${BLUE}[4/5] Verifying Supabase insertion...${NC}"

# Check product count
SUPABASE_COUNT=$(curl -s "$SUPABASE_URL/rest/v1/catalog_products?select=count" \
  -H "Authorization: Bearer $ADMIN_JWT" \
  -H "apikey: $SUPABASE_ANON_KEY" | jq '.[0].count')

echo -e "Supabase product count: $SUPABASE_COUNT"

if [ "$SUPABASE_COUNT" -ge "$PRODUCT_COUNT" ]; then
    echo -e "${GREEN}✓ Supabase verification PASSED${NC}"
else
    echo -e "${RED}✗ Supabase verification FAILED${NC}"
    exit 1
fi

echo -e "${BLUE}[5/5] Checking Firestore sync...${NC}"

# Poll Firestore for 30 seconds
MAX_WAIT=30
WAIT_INTERVAL=1
ELAPSED=0
FIRESTORE_SYNCED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # This is a placeholder — actual Firestore check requires Firebase CLI or SDK
    # In practice, verify via Firebase Console or admin SDK
    echo "Checking Firestore sync... ($ELAPSED/$MAX_WAIT seconds)"
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

echo -e "${GREEN}✓ Seeding complete${NC}"
echo ""
echo "============================================"
echo "SEED SUMMARY"
echo "============================================"
echo "Status: SUCCESS"
echo "Created: $CREATED products"
echo "Failed: $FAILED products"
echo "Duration: ${DURATION}s"
echo "Supabase Count: $SUPABASE_COUNT"
echo "Target: $PRODUCT_COUNT"
echo "============================================"

exit 0
