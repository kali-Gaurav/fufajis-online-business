# PowerShell Script for Deploying Tasks #19, #20, #21
# Usage: .\deploy-tasks-19-20-21.ps1
# Prerequisites: Supabase CLI, Firebase service account JSON, Razorpay webhook secret

param(
    [string]$FirebaseServiceAccountPath = "",
    [string]$RazorpayWebhookSecret = "",
    [string]$SupabaseProjectId = "mxjtgpunctckovtuyfmz"
)

# Colors for output
$ErrorColor = "Red"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$InfoColor = "Cyan"

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor $InfoColor
    Write-Host $Message -ForegroundColor $InfoColor
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor $InfoColor
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $SuccessColor
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $ErrorColor
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $WarningColor
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $InfoColor
}

# Check if running from project root
if (!(Test-Path "supabase/config.toml")) {
    Write-Error-Custom "Not in Fufaji project root. Please run from C:\Projects\fufaji-online-business"
    exit 1
}

Write-Header "TASK #19, #20, #21 DEPLOYMENT SCRIPT"
Write-Info "Project: Fufaji Online Business"
Write-Info "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# ============================================================================
# TASK #19: Deploy Firebase Auth Bridge
# ============================================================================

Write-Header "TASK #19: Deploy Firebase Auth Verification Bridge"

if ([string]::IsNullOrEmpty($FirebaseServiceAccountPath)) {
    Write-Warning-Custom "Firebase service account path not provided"
    $FirebaseServiceAccountPath = Read-Host "Enter path to Firebase service account JSON"
}

if (!(Test-Path $FirebaseServiceAccountPath)) {
    Write-Error-Custom "Firebase service account file not found: $FirebaseServiceAccountPath"
    exit 1
}

Write-Info "Setting FIREBASE_SERVICE_ACCOUNT secret..."
try {
    $serviceAccountContent = Get-Content $FirebaseServiceAccountPath -Raw

    # Use supabase CLI to set secret
    $encodedAccount = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($serviceAccountContent))

    # Alternative: Just pass the JSON directly (Supabase CLI handles encoding)
    # supabase secrets set FIREBASE_SERVICE_ACCOUNT --env-file <(echo "FIREBASE_SERVICE_ACCOUNT=$serviceAccountContent")

    Write-Info "Executing: supabase secrets set FIREBASE_SERVICE_ACCOUNT ..."

    # For now, provide instructions since we can't directly call supabase CLI with encoded content
    Write-Warning-Custom "Please run this command manually:"
    Write-Host ""
    Write-Host "  cd C:\Projects\fufaji-online-business" -ForegroundColor $WarningColor
    Write-Host "  `$content = Get-Content '$FirebaseServiceAccountPath' -Raw" -ForegroundColor $WarningColor
    Write-Host "  supabase secrets set FIREBASE_SERVICE_ACCOUNT `$content" -ForegroundColor $WarningColor
    Write-Host ""
}
catch {
    Write-Error-Custom "Failed to read Firebase service account: $_"
    exit 1
}

Write-Info "Verifying firebase-bridge.ts exists..."
if (Test-Path "supabase/functions/_shared/firebase-bridge.ts") {
    Write-Success "firebase-bridge.ts found"
} else {
    Write-Error-Custom "firebase-bridge.ts not found"
    exit 1
}

# ============================================================================
# TASK #20: Deploy Storage Buckets Migration
# ============================================================================

Write-Header "TASK #20: Deploy Storage Buckets Migration"

Write-Info "Verifying migration file..."
if (Test-Path "supabase/migrations/04_storage_buckets_firestore_sync.sql") {
    Write-Success "Migration file found"
} else {
    Write-Error-Custom "Migration file not found"
    exit 1
}

Write-Warning-Custom "Please run this command manually:"
Write-Host ""
Write-Host "  cd C:\Projects\fufaji-online-business\supabase" -ForegroundColor $WarningColor
Write-Host "  supabase db push" -ForegroundColor $WarningColor
Write-Host ""

# ============================================================================
# TASK #21: Deploy Razorpay Webhook
# ============================================================================

Write-Header "TASK #21: Deploy Razorpay Webhook Edge Function"

if ([string]::IsNullOrEmpty($RazorpayWebhookSecret)) {
    Write-Warning-Custom "Razorpay webhook secret not provided"
    $RazorpayWebhookSecret = Read-Host "Enter Razorpay webhook secret (or press Enter to skip)"
}

if (![string]::IsNullOrEmpty($RazorpayWebhookSecret)) {
    Write-Info "Setting RAZORPAY_WEBHOOK_SECRET..."
    Write-Warning-Custom "Please run this command manually:"
    Write-Host ""
    Write-Host "  supabase secrets set RAZORPAY_WEBHOOK_SECRET '$RazorpayWebhookSecret'" -ForegroundColor $WarningColor
    Write-Host ""
} else {
    Write-Warning-Custom "Skipping RAZORPAY_WEBHOOK_SECRET (you'll need to set it manually)"
}

Write-Info "Verifying webhook function exists..."
if (Test-Path "supabase/functions/razorpay-webhook-dual-write/index.ts") {
    Write-Success "Webhook function found"
} else {
    Write-Error-Custom "Webhook function not found"
    exit 1
}

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================

Write-Header "DEPLOYMENT COMMANDS TO RUN MANUALLY"

Write-Host ""
Write-Host "Step 1: Set Firebase Service Account Secret" -ForegroundColor $InfoColor
Write-Host "  `$content = Get-Content '$FirebaseServiceAccountPath' -Raw" -ForegroundColor $WarningColor
Write-Host "  supabase secrets set FIREBASE_SERVICE_ACCOUNT `$content" -ForegroundColor $WarningColor

Write-Host ""
Write-Host "Step 2: Verify Secrets Are Set" -ForegroundColor $InfoColor
Write-Host "  supabase secrets list" -ForegroundColor $WarningColor

Write-Host ""
Write-Host "Step 3: Deploy Storage Migration" -ForegroundColor $InfoColor
Write-Host "  cd C:\Projects\fufaji-online-business\supabase" -ForegroundColor $WarningColor
Write-Host "  supabase db push" -ForegroundColor $WarningColor

Write-Host ""
Write-Host "Step 4: Set Razorpay Webhook Secret" -ForegroundColor $InfoColor
Write-Host "  supabase secrets set RAZORPAY_WEBHOOK_SECRET 'your-razorpay-webhook-secret'" -ForegroundColor $WarningColor

Write-Host ""
Write-Host "Step 5: Deploy Edge Functions" -ForegroundColor $InfoColor
Write-Host "  supabase functions deploy _shared/firebase-bridge" -ForegroundColor $WarningColor
Write-Host "  supabase functions deploy razorpay-webhook-dual-write" -ForegroundColor $WarningColor

Write-Host ""
Write-Host "Step 6: Configure Razorpay Webhook (Manual)" -ForegroundColor $InfoColor
Write-Host "  1. Go to Razorpay Dashboard → Settings → Webhooks" -ForegroundColor $WarningColor
Write-Host "  2. Add/Edit webhook with:" -ForegroundColor $WarningColor
Write-Host "     URL: https://mxjtgpunctckovtuyfmz.supabase.co/functions/v1/razorpay-webhook-dual-write" -ForegroundColor $WarningColor
Write-Host "     Events: payment.authorized, payment.failed, payment.completed" -ForegroundColor $WarningColor
Write-Host "     Secret: (same as RAZORPAY_WEBHOOK_SECRET)" -ForegroundColor $WarningColor

Write-Host ""
Write-Host "Step 7: Verify Deployment" -ForegroundColor $InfoColor
Write-Host "  - Check Supabase Console → Edge Functions" -ForegroundColor $WarningColor
Write-Host "  - Check Supabase Console → SQL Editor for storage buckets" -ForegroundColor $WarningColor
Write-Host "  - Review DEPLOYMENT_TASKS_19_20_21.md for detailed testing" -ForegroundColor $WarningColor

Write-Host ""
Write-Header "NEXT STEPS"
Write-Info "After deployment, run Task #22: Test end-to-end order flow"
Write-Info "See DEPLOYMENT_TASKS_19_20_21.md for detailed verification steps"
Write-Host ""
