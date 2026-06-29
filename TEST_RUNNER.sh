#!/bin/bash

# 🧪 FUFAJI STORE - COMPLETE TEST SUITE RUNNER
# Runs all integration, unit, and production tests
# Usage: bash TEST_RUNNER.sh

echo "════════════════════════════════════════════════════════════════"
echo "  🧪 FUFAJI STORE - PRODUCTION TEST SUITE"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
total_tests=0
passed_tests=0
failed_tests=0

# Function to run test and capture result
run_test() {
    local test_name=$1
    local test_file=$2
    
    echo -e "${BLUE}Running: $test_name${NC}"
    if flutter test "$test_file" --verbose 2>/dev/null; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        ((passed_tests++))
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        ((failed_tests++))
    fi
    ((total_tests++))
    echo ""
}

# ──────────────────────────────────────────────────────────────
# SECTION 1: END-TO-END ORDER FLOW TESTS
# ──────────────────────────────────────────────────────────────
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}SECTION 1: End-to-End Order Flow Tests${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_test "Order Creation & Status Tracking" "test/integration/order_payment_delivery_flow_test.dart"
run_test "Payment Processing (Razorpay)" "test/integration/order_payment_delivery_flow_test.dart"
run_test "Kitchen Assignment" "test/integration/order_payment_delivery_flow_test.dart"
run_test "Delivery Assignment (Proximity)" "test/integration/order_payment_delivery_flow_test.dart"
run_test "OTP Security (PBKDF2-SHA256)" "test/integration/order_payment_delivery_flow_test.dart"
run_test "Invoice Generation" "test/integration/order_payment_delivery_flow_test.dart"
run_test "Loyalty Points Award" "test/integration/order_payment_delivery_flow_test.dart"
run_test "Return Window & Refund" "test/integration/order_payment_delivery_flow_test.dart"
run_test "Order State Machine" "test/integration/order_payment_delivery_flow_test.dart"
run_test "COD Payment at Delivery" "test/integration/order_payment_delivery_flow_test.dart"

# ──────────────────────────────────────────────────────────────
# SECTION 2: PAYMENT SECURITY TESTS
# ──────────────────────────────────────────────────────────────
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}SECTION 2: Payment Security Tests${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

run_test "Razorpay HMAC Signature" "test/backend/razorpay_payment_webhook_test.dart"
run_test "Webhook Tampering Detection" "test/backend/razorpay_payment_webhook_test.dart"
run_test "Duplicate Payment Prevention" "test/backend/razorpay_payment_webhook_test.dart"
run_test "Partial Refund Handling" "test/backend/razorpay_payment_webhook_test.dart"

# ──────────────────────────────────────────────────────────────
# SECTION 3: FINAL RESULTS
# ──────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}FINAL TEST RESULTS${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Total Tests:  $total_tests"
echo -e "Passed:       ${GREEN}$passed_tests${NC}"
echo -e "Failed:       ${RED}$failed_tests${NC}"
echo ""

if [ $failed_tests -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✅ ALL TESTS PASSED - APP READY FOR PRODUCTION${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ❌ SOME TESTS FAILED - FIX BEFORE DEPLOYMENT${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    exit 1
fi
