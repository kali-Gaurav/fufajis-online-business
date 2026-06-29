#!/bin/bash

################################################################################
# AWS SSM Parameters Setup Script
#
# This script creates all required AWS Systems Manager Parameter Store entries
# for Fufaji backend production deployment.
#
# CRITICAL: Secrets are stored in AWS SSM Parameter Store with encryption.
# Lambda reads these at runtime via backend/src/secrets.js
#
# Usage:
#   ./scripts/setup_aws_ssm_parameters.sh
#
# Prerequisites:
#   1. AWS CLI installed and configured
#   2. AWS credentials with IAM permissions to create SSM parameters
#   3. KMS key for encryption (or use default /aws/ssm)
#
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-ap-south-1}"
PARAMETER_PREFIX="/fufaji"
KMS_KEY_ALIAS="alias/aws/ssm"  # Default KMS key for SSM
ENVIRONMENT="${1:-production}"

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Fufaji AWS SSM Parameters Setup${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo -e "${YELLOW}Region: $AWS_REGION${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════${NC}"

# Verify AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install it first.${NC}"
    exit 1
fi

# Verify AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Please configure AWS CLI.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI verified${NC}"

# Function to safely prompt for secret
prompt_secret() {
    local prompt_text="$1"
    local variable_name="$2"
    local default_value="${3:-}"

    if [ -z "$default_value" ]; then
        read -sp "$(echo -e ${YELLOW}$prompt_text${NC}): " value
    else
        read -sp "$(echo -e ${YELLOW}$prompt_text [use default]${NC}): " value
        if [ -z "$value" ]; then
            value="$default_value"
        fi
    fi
    echo ""
    eval "$variable_name='$value'"
}

# Function to create SSM parameter
create_parameter() {
    local param_name="$1"
    local param_value="$2"
    local param_description="$3"
    local param_type="${4:-SecureString}"

    echo -e "${YELLOW}Creating parameter: $param_name${NC}"

    aws ssm put-parameter \
        --name "$param_name" \
        --value "$param_value" \
        --type "$param_type" \
        --description "$param_description" \
        --key-id "$KMS_KEY_ALIAS" \
        --overwrite \
        --region "$AWS_REGION" \
        2>/dev/null || {
            echo -e "${RED}❌ Failed to create parameter: $param_name${NC}"
            return 1
        }

    echo -e "${GREEN}✅ Parameter created: $param_name${NC}"
}

echo ""
echo -e "${YELLOW}Please provide the following secrets:${NC}"
echo ""

# Collect all secrets
prompt_secret "Razorpay Key ID (production)" RAZORPAY_KEY_ID
prompt_secret "Razorpay Key Secret" RAZORPAY_KEY_SECRET
prompt_secret "Razorpay Webhook Secret" RAZORPAY_WEBHOOK_SECRET

prompt_secret "Firebase Service Account JSON (paste full JSON)" FIREBASE_SERVICE_ACCOUNT

prompt_secret "Gemini API Key" GEMINI_API_KEY

prompt_secret "SendGrid API Key" SENDGRID_API_KEY

prompt_secret "Twilio Account SID" TWILIO_ACCOUNT_SID
prompt_secret "Twilio Auth Token" TWILIO_AUTH_TOKEN
prompt_secret "Twilio Phone Number" TWILIO_PHONE_NUMBER

prompt_secret "WhatsApp Business Token" WHATSAPP_TOKEN
prompt_secret "WhatsApp Business Phone ID" WHATSAPP_PHONE_ID
prompt_secret "WhatsApp Verify Token" WHATSAPP_VERIFY_TOKEN

prompt_secret "Stripe Secret Key (if using)" STRIPE_SECRET_KEY

echo ""
echo -e "${YELLOW}Summary of parameters to be created:${NC}"
echo "  /fufaji/razorpay/key_id"
echo "  /fufaji/razorpay/key_secret"
echo "  /fufaji/razorpay/webhook_secret"
echo "  /fufaji/firebase/service_account"
echo "  /fufaji/gemini/api_key"
echo "  /fufaji/sendgrid/api_key"
echo "  /fufaji/twilio/account_sid"
echo "  /fufaji/twilio/auth_token"
echo "  /fufaji/twilio/phone_number"
echo "  /fufaji/whatsapp/token"
echo "  /fufaji/whatsapp/phone_id"
echo "  /fufaji/whatsapp/verify_token"
echo "  /fufaji/stripe/secret_key"
echo ""

read -p "Continue with parameter creation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Creating parameters...${NC}"
echo ""

# Create parameters
create_parameter \
    "/fufaji/razorpay/key_id" \
    "$RAZORPAY_KEY_ID" \
    "Razorpay API Key ID for production"

create_parameter \
    "/fufaji/razorpay/key_secret" \
    "$RAZORPAY_KEY_SECRET" \
    "Razorpay API Key Secret (SENSITIVE)"

create_parameter \
    "/fufaji/razorpay/webhook_secret" \
    "$RAZORPAY_WEBHOOK_SECRET" \
    "Razorpay Webhook Secret for signature verification"

create_parameter \
    "/fufaji/firebase/service_account" \
    "$FIREBASE_SERVICE_ACCOUNT" \
    "Firebase Service Account JSON (SENSITIVE)"

create_parameter \
    "/fufaji/gemini/api_key" \
    "$GEMINI_API_KEY" \
    "Google Gemini API Key (SENSITIVE)"

create_parameter \
    "/fufaji/sendgrid/api_key" \
    "$SENDGRID_API_KEY" \
    "SendGrid API Key (SENSITIVE)"

create_parameter \
    "/fufaji/twilio/account_sid" \
    "$TWILIO_ACCOUNT_SID" \
    "Twilio Account SID (SENSITIVE)"

create_parameter \
    "/fufaji/twilio/auth_token" \
    "$TWILIO_AUTH_TOKEN" \
    "Twilio Auth Token (SENSITIVE)"

create_parameter \
    "/fufaji/twilio/phone_number" \
    "$TWILIO_PHONE_NUMBER" \
    "Twilio Phone Number for SMS"

create_parameter \
    "/fufaji/whatsapp/token" \
    "$WHATSAPP_TOKEN" \
    "WhatsApp Business API Token (SENSITIVE)"

create_parameter \
    "/fufaji/whatsapp/phone_id" \
    "$WHATSAPP_PHONE_ID" \
    "WhatsApp Business Phone ID"

create_parameter \
    "/fufaji/whatsapp/verify_token" \
    "$WHATSAPP_VERIFY_TOKEN" \
    "WhatsApp Verify Token for webhooks"

if [ -n "$STRIPE_SECRET_KEY" ] && [ "$STRIPE_SECRET_KEY" != "" ]; then
    create_parameter \
        "/fufaji/stripe/secret_key" \
        "$STRIPE_SECRET_KEY" \
        "Stripe Secret Key (fallback payments)"
fi

echo ""
echo -e "${YELLOW}Verifying parameters...${NC}"
echo ""

# Verify all parameters were created
aws ssm get-parameters-by-path \
    --path "$PARAMETER_PREFIX/" \
    --recursive \
    --region "$AWS_REGION" \
    --query 'Parameters[].Name' \
    --output table

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All parameters created successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Verify parameters in AWS SSM Parameter Store console"
echo "2. Ensure Lambda IAM role has permission to read these parameters"
echo "3. Deploy backend: sam deploy --no-confirm-changeset"
echo "4. Test: curl https://<lambda-function-url>/health"
echo ""
