#!/bin/bash
# ALL BATCHES SEEDING SCRIPT
# Fufaji Store Product Management System
# Date: 2026-07-04

set -e

echo "============================================"
echo "FULL CATALOG SEEDING EXECUTION"
echo "Batches 1, 2, and 3 (165 Products)"
echo "============================================"

# Configuration
SUPABASE_URL="${SUPABASE_URL:-https://mxjtgpunctckovtuyfmz.supabase.co}"
ADMIN_JWT="${ADMIN_JWT:-your-admin-jwt-token}"
declare -a BATCHES=("batch_1_products_catalog.json" "batch_2_products_catalog.json" "batch_3_products_catalog.json")

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[1/5] Validating credentials...${NC}"
if [ -z "$ADMIN_JWT" ] || [ "$ADMIN_JWT" == "your-admin-jwt-token" ]; then
    echo -e "${RED}ERROR: ADMIN_JWT not set. Using supabase service_role from .env as fallback...${NC}"
    # Extract service role if available from root .env
    if [ -f "../.env" ]; then
        ADMIN_JWT=$(grep '^supabase_service_role=' ../.env | cut -d '=' -f2)
    fi
fi
if [ -z "$ADMIN_JWT" ]; then
    echo -e "${RED}ERROR: Could not find ADMIN_JWT or supabase_service_role${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Credentials validated${NC}"

TOTAL_CREATED=0
TOTAL_FAILED=0

for BATCH_FILE in "${BATCHES[@]}"; do
    echo -e "${BLUE}Processing ${BATCH_FILE}...${NC}"
    if [ ! -f "$BATCH_FILE" ]; then
        echo -e "${RED}ERROR: $BATCH_FILE not found in $(pwd)${NC}"
        continue
    fi
    
    PRODUCT_COUNT=$(jq '.products | length' "$BATCH_FILE")
    echo -e "${GREEN}✓ Found $PRODUCT_COUNT products in $BATCH_FILE${NC}"
    
    START_TIME=$(date +%s)
    
    RESPONSE=$(curl -s -X POST \
      "$SUPABASE_URL/functions/v1/bulk-import-products" \
      -H "Authorization: Bearer $ADMIN_JWT" \
      -H "Content-Type: application/json" \
      -d @"$BATCH_FILE")
      
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    CREATED=$(echo "$RESPONSE" | jq -r '.createdCount // 0')
    FAILED=$(echo "$RESPONSE" | jq -r '.failedCount // 0')
    
    if [ "$CREATED" != "null" ]; then
      TOTAL_CREATED=$((TOTAL_CREATED + CREATED))
    fi
    if [ "$FAILED" != "null" ]; then
      TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
    fi
    
    echo -e "${GREEN}✓ Created: $CREATED products (in ${DURATION}s)${NC}"
    if [ "$FAILED" != "0" ] && [ "$FAILED" != "null" ]; then
        echo -e "${RED}⚠ Warning: $FAILED products failed in $BATCH_FILE${NC}"
    fi
done

echo "============================================"
echo "SEED SUMMARY"
echo "============================================"
echo "Total Created: $TOTAL_CREATED products"
echo "Total Failed: $TOTAL_FAILED products"
echo "============================================"

exit 0
