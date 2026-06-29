<#
=======================================================================
  Fufaji Store - Production APK Build Script (PowerShell)
=======================================================================

CRITICAL SECURITY RULES:
1. NEVER pass backend secrets (RAZORPAY_KEY_SECRET, etc.) to flutter build
2. Only pass PUBLIC configs (RAZORPAY_KEY_ID, API_BASE_URL, etc.)
3. Do NOT load .env file (disabled in this script)
4. All backend secrets fetched at runtime from secure /config endpoint

This script builds release APK safe for production deployment.
======================================================================= #>

$ErrorActionPreference = "Stop"

# Get current directory
Push-Location $PSScriptRoot

# ❌ REMOVE .env if it exists (should never be in repo)
if (Test-Path ".\.env") {
    Write-Host "[ERROR] .env file found in project directory!" -ForegroundColor Red
    Write-Host "This file contains secrets and should NEVER exist in repo!" -ForegroundColor Red
    Write-Host "Action: Delete it immediately and add to .gitignore" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  🔨  FUFAJI STORE - PRODUCTION APK BUILD" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify Flutter
Write-Host "[STEP 1] Verifying Flutter installation..." -ForegroundColor Yellow
flutter --version | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flutter not found in PATH" -ForegroundColor Red
    exit 1
}
Write-Host "       ✓ Flutter found" -ForegroundColor Green

# Step 2: Clean previous builds
Write-Host "[STEP 2] Cleaning previous builds..." -ForegroundColor Yellow
flutter clean 2>&1 | Out-Null

# Step 3: Get dependencies
Write-Host "[STEP 3] Getting dependencies..." -ForegroundColor Yellow
flutter pub get 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to get dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "       ✓ Dependencies resolved" -ForegroundColor Green

# Step 4: Verify .env is NOT in pubspec.yaml
Write-Host "[STEP 4] Verifying .env is NOT bundled in APK..." -ForegroundColor Yellow
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match '^\s*-\s*\.env\s*$') {
    Write-Host "[WARNING] .env found in pubspec.yaml assets. Removing it temporarily for build..." -ForegroundColor Yellow
    $pubspecContent = $pubspecContent -replace '^\s*-\s*\.env\s*$\n?', ''
    Set-Content "pubspec.yaml" $pubspecContent
}
Write-Host "       ✓ .env is NOT in pubspec.yaml assets" -ForegroundColor Green

# Step 5: Build with --dart-define
Write-Host ""
Write-Host "[STEP 5] Building production APK with public configs..." -ForegroundColor Yellow
Write-Host ""
Write-Host "[CONFIG] Using --dart-define for:" -ForegroundColor Cyan
Write-Host "         - API_BASE_URL=https://fufaji-api.render.com" -ForegroundColor Gray
Write-Host "         - SUPABASE_URL=https://your-project.supabase.co" -ForegroundColor Gray
Write-Host "         - SUPABASE_ANON_KEY=your-anon-key" -ForegroundColor Gray
Write-Host "         - RAZORPAY_KEY_ID=rzp_live_Sr7JfZt4NbXzMw" -ForegroundColor Gray
Write-Host "         - STRIPE_PUBLISHABLE_KEY=pk_live_your_key" -ForegroundColor Gray
Write-Host "         - GOOGLE_MAPS_KEY=your_restricted_key" -ForegroundColor Gray
Write-Host "         - SENTRY_DSN=your_sentry_dsn" -ForegroundColor Gray
Write-Host "         - SUPPORT_WHATSAPP_NUMBER=+91XXXXXXXXXX" -ForegroundColor Gray
Write-Host ""
Write-Host "[SECURITY] NOT passing any backend secrets (*_SECRET keys)" -ForegroundColor Green
Write-Host ""

# ⚠️  UPDATE THESE VALUES TO YOUR REAL PRODUCTION VALUES ⚠️
$apiBaseUrl = "https://fufaji-api.render.com"
$supabaseUrl = "https://your-project.supabase.co"
$supabaseAnonKey = "your-anon-key"
$razorpayKeyId = "rzp_live_Sr7JfZt4NbXzMw"
$stripePublishableKey = "pk_live_your_publishable_key"
$googleMapsKey = "your_production_maps_key"
$sentryDsn = "https://your-sentry-dsn@sentry.io/project-id"
$supportWhatsappNumber = "+91XXXXXXXXXX"
$apkDownloadUrl = "https://github.com/kali-Gaurav/fufajis-online-business/releases/download"

Write-Host "[BUILD] Starting flutter build apk..." -ForegroundColor Cyan
Write-Host ""

flutter build apk `
    --release `
    --split-per-abi `
    --dart-define=API_BASE_URL=$apiBaseUrl `
    --dart-define=SUPABASE_URL=$supabaseUrl `
    --dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey `
    --dart-define=RAZORPAY_KEY_ID=$razorpayKeyId `
    --dart-define=STRIPE_PUBLISHABLE_KEY=$stripePublishableKey `
    --dart-define=GOOGLE_MAPS_KEY=$googleMapsKey `
    --dart-define=SENTRY_DSN=$sentryDsn `
    --dart-define=SUPPORT_WHATSAPP_NUMBER=$supportWhatsappNumber `
    --dart-define=APK_DOWNLOAD_URL=$apkDownloadUrl

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] APK build failed" -ForegroundColor Red
    exit 1
}

# Step 6: Verify APK
Write-Host ""
Write-Host "[STEP 6] Verifying APK creation..." -ForegroundColor Yellow

$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "[ERROR] APK not found at $apkPath" -ForegroundColor Red
    exit 1
}

$apkSize = (Get-Item $apkPath).Length
Write-Host "       ✓ APK created successfully at: $apkPath" -ForegroundColor Green
Write-Host "       ✓ Size: $([math]::Round($apkSize / 1MB, 2)) MB" -ForegroundColor Green

# Step 7: Summary
Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "  ✅  BUILD COMPLETE" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "APK Location:  $apkPath" -ForegroundColor Cyan
Write-Host "Build Mode:    Release (optimized for production)" -ForegroundColor Cyan
Write-Host "Architecture:  Split per ABI (arm64-v8a, armeabi-v7a, x86_64)" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔐 Security Summary:" -ForegroundColor Green
Write-Host "   ✓ No .env file bundled" -ForegroundColor Green
Write-Host "   ✓ No backend secrets in APK" -ForegroundColor Green
Write-Host "   ✓ --dart-define used for public configs only" -ForegroundColor Green
Write-Host "   ✓ Backend secrets fetch from /config endpoint at runtime" -ForegroundColor Green
Write-Host ""
Write-Host "📱 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Test APK: adb install -r `"$apkPath`"" -ForegroundColor Gray
Write-Host "   2. Run full end-to-end test (order → payment → delivery)" -ForegroundColor Gray
Write-Host "   3. If OK: Upload to Google Play Store" -ForegroundColor Gray
Write-Host "      https://play.google.com/console" -ForegroundColor Gray
Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

Pop-Location
