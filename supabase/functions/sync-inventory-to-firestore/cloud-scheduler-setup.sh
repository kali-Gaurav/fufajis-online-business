#!/bin/bash

# Google Cloud Scheduler Setup for Inventory Sync
# This script creates a Cloud Scheduler job to trigger the sync function every 5 minutes

# Prerequisites:
# 1. gcloud CLI installed: https://cloud.google.com/sdk/docs/install
# 2. Authenticated: gcloud auth login
# 3. Project set: gcloud config set project PROJECT_ID
# 4. Cloud Scheduler API enabled: gcloud services enable cloudscheduler.googleapis.com

set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-}"
SUPABASE_PROJECT_ID="${SUPABASE_PROJECT_ID:-}"
SUPABASE_FUNCTION_SECRET="${SUPABASE_FUNCTION_SECRET:-}"
CRON_EXPRESSION="${CRON_EXPRESSION:-*/5 * * * *}"  # Every 5 minutes
JOB_NAME="fufaji-inventory-sync"
JOB_LOCATION="asia-south1"  # India - closest to users
TIMEZONE="Asia/Kolkata"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Validate inputs
if [ -z "$PROJECT_ID" ]; then
  echo -e "${RED}Error: GCP_PROJECT_ID not set${NC}"
  echo "Usage: export GCP_PROJECT_ID=your-gcp-project && export SUPABASE_PROJECT_ID=your-sb-project && bash cloud-scheduler-setup.sh"
  exit 1
fi

if [ -z "$SUPABASE_PROJECT_ID" ]; then
  echo -e "${RED}Error: SUPABASE_PROJECT_ID not set${NC}"
  exit 1
fi

if [ -z "$SUPABASE_FUNCTION_SECRET" ]; then
  echo -e "${RED}Error: SUPABASE_FUNCTION_SECRET not set${NC}"
  echo "Generate with: openssl rand -base64 32"
  exit 1
fi

echo -e "${GREEN}=== Fufaji Inventory Sync Cloud Scheduler Setup ===${NC}"
echo "Project ID: $PROJECT_ID"
echo "Supabase Project: $SUPABASE_PROJECT_ID"
echo "Job Name: $JOB_NAME"
echo "Schedule: $CRON_EXPRESSION"
echo "Timezone: $TIMEZONE"
echo ""

# Check if job already exists
echo "Checking if job already exists..."
if gcloud scheduler jobs describe $JOB_NAME --location=$JOB_LOCATION --project=$PROJECT_ID &>/dev/null; then
  echo -e "${YELLOW}Job already exists. Deleting...${NC}"
  gcloud scheduler jobs delete $JOB_NAME --location=$JOB_LOCATION --project=$PROJECT_ID --quiet
  # Wait for deletion
  sleep 2
fi

# Create the Cloud Scheduler job
echo -e "${GREEN}Creating Cloud Scheduler job...${NC}"

gcloud scheduler jobs create http $JOB_NAME \
  --project=$PROJECT_ID \
  --location=$JOB_LOCATION \
  --schedule="$CRON_EXPRESSION" \
  --timezone="$TIMEZONE" \
  --uri="https://${SUPABASE_PROJECT_ID}.supabase.co/functions/v1/sync-inventory-to-firestore" \
  --http-method=POST \
  --headers="X-Cron-Secret=$SUPABASE_FUNCTION_SECRET,Content-Type=application/json" \
  --message-body='{}' \
  --oidc-service-account-email="default@appspot.gserviceaccount.com" \
  --oidc-token-audience="https://${SUPABASE_PROJECT_ID}.supabase.co/functions/v1/sync-inventory-to-firestore" \
  --retry-attempts=2 \
  --retry-delay=60s

echo -e "${GREEN}✓ Job created successfully!${NC}"

# Verify the job
echo ""
echo -e "${GREEN}Job Details:${NC}"
gcloud scheduler jobs describe $JOB_NAME \
  --location=$JOB_LOCATION \
  --project=$PROJECT_ID

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Verify in Cloud Scheduler console: https://console.cloud.google.com/scheduler"
echo "2. Look for job: $JOB_NAME"
echo "3. Click FORCE RUN to test (should complete in <10 seconds)"
echo "4. Check Supabase Firestore and sync_logs table for data"
echo ""
echo "To monitor:"
echo "  gcloud scheduler jobs describe $JOB_NAME --location=$JOB_LOCATION --project=$PROJECT_ID --log-info"
echo ""
echo "To view execution logs:"
echo "  gcloud scheduler jobs list --location=$JOB_LOCATION --project=$PROJECT_ID --log-history"
echo ""
echo "To disable the job:"
echo "  gcloud scheduler jobs pause $JOB_NAME --location=$JOB_LOCATION --project=$PROJECT_ID"
echo ""
echo "To delete the job:"
echo "  gcloud scheduler jobs delete $JOB_NAME --location=$JOB_LOCATION --project=$PROJECT_ID"
