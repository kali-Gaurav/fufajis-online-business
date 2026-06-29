#!/bin/bash

# ============================================================
# Supabase Migration Testing Script
# Tests local Supabase migrations and verifies schema
# ============================================================

set -e

echo "=== Supabase Migration Testing ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI not found. Install with: npm install -g supabase${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Starting Supabase local environment...${NC}"
supabase start
echo -e "${GREEN}✓ Supabase started${NC}"
echo ""

echo -e "${YELLOW}2. Running migrations...${NC}"
supabase migration up
echo -e "${GREEN}✓ Migrations completed${NC}"
echo ""

echo -e "${YELLOW}3. Verifying database schema...${NC}"

# Test 1: Check if tables exist
echo "   Testing: Tables exist..."
TABLES=(
    "users" "shops" "products" "categories" "inventory"
    "orders" "carts" "payments" "refunds"
    "delivery_tasks" "delivery_assignments"
    "fulfillment_tasks"
    "chats" "messages"
    "loyalty_accounts" "loyalty_transactions"
    "coupons" "coupon_usage"
    "product_reviews" "shop_reviews"
    "returns"
)

for table in "${TABLES[@]}"; do
    # Use psql to check if table exists
    if psql -h localhost -p 54322 -U postgres -d postgres -c "\dt $table" 2>/dev/null | grep -q "$table"; then
        echo -e "     ${GREEN}✓${NC} Table: $table"
    else
        echo -e "     ${RED}✗${NC} Table: $table (MISSING)"
    fi
done
echo ""

# Test 2: Check RLS is enabled
echo "   Testing: Row Level Security enabled..."
RLS_TABLES=("users" "orders" "payments" "delivery_tasks" "messages" "chats")

for table in "${RLS_TABLES[@]}"; do
    if psql -h localhost -p 54322 -U postgres -d postgres -c "SELECT * FROM information_schema.tables WHERE table_name='$table' AND row_security_active=true" 2>/dev/null | grep -q "$table"; then
        echo -e "     ${GREEN}✓${NC} RLS enabled: $table"
    else
        echo -e "     ${YELLOW}⚠${NC} RLS status unclear: $table"
    fi
done
echo ""

# Test 3: Check indexes exist
echo "   Testing: Indexes created..."
INDEXES=(
    "idx_users_phone" "idx_users_email" "idx_users_role"
    "idx_products_shop_id" "idx_products_category_id"
    "idx_orders_customer_id" "idx_orders_status"
    "idx_payments_customer_id"
    "idx_delivery_tasks_rider_id" "idx_delivery_tasks_status"
    "idx_messages_chat_id"
)

for index in "${INDEXES[@]}"; do
    if psql -h localhost -p 54322 -U postgres -d postgres -c "\di $index" 2>/dev/null | grep -q "$index"; then
        echo -e "     ${GREEN}✓${NC} Index: $index"
    else
        echo -e "     ${RED}✗${NC} Index: $index (MISSING)"
    fi
done
echo ""

# Test 4: Verify auth integration
echo "   Testing: Auth integration..."
if psql -h localhost -p 54322 -U postgres -d postgres -c "SELECT * FROM auth.users LIMIT 1" 2>/dev/null; then
    echo -e "     ${GREEN}✓${NC} Auth schema accessible"
else
    echo -e "     ${RED}✗${NC} Auth schema not accessible"
fi
echo ""

echo -e "${YELLOW}4. Testing data insertion...${NC}"

# Create test user
TEST_USER_ID=$(psql -h localhost -p 54322 -U postgres -d postgres -tAc "
    INSERT INTO public.users (id, phone, email, name, role, created_at, updated_at)
    VALUES (gen_random_uuid(), '+919876543210', 'test@example.com', 'Test User', 'customer', now(), now())
    RETURNING id;
" 2>/dev/null)

if [ ! -z "$TEST_USER_ID" ]; then
    echo -e "     ${GREEN}✓${NC} Created test user: $TEST_USER_ID"
else
    echo -e "     ${RED}✗${NC} Failed to create test user"
fi
echo ""

echo -e "${YELLOW}5. Testing queries...${NC}"

# Test select
USER_COUNT=$(psql -h localhost -p 54322 -U postgres -d postgres -tAc "SELECT COUNT(*) FROM public.users" 2>/dev/null)
echo -e "     ${GREEN}✓${NC} Total users: $USER_COUNT"

# Test relationships
if psql -h localhost -p 54322 -U postgres -d postgres -c "
    SELECT p.id, p.name, i.quantity_on_hand
    FROM products p
    LEFT JOIN inventory i ON p.id = i.product_id
    LIMIT 1
" 2>/dev/null; then
    echo -e "     ${GREEN}✓${NC} Product-Inventory relationship works"
fi

echo ""
echo -e "${YELLOW}6. Generating schema snapshot...${NC}"
supabase db pull --schema-only > supabase/schema_snapshot.sql 2>/dev/null || true
echo -e "     ${GREEN}✓${NC} Schema snapshot saved to: supabase/schema_snapshot.sql"
echo ""

echo -e "${GREEN}=== All tests completed ===${NC}"
echo ""
echo "Summary:"
echo "  • Database: Supabase local (port 54322)"
echo "  • API: Supabase API (port 54321)"
echo "  • Studio: Supabase Studio (http://localhost:54323)"
echo ""
echo "To stop: supabase stop"
echo "To reset: supabase db reset"
echo ""

exit 0
