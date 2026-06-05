# Fufaji's Online — Production Deployment Script
# Deploys: Firebase Rules + Functions + Hosting + APK build
#
# Usage:
#   .\scripts\deploy.ps1               # deploy everything
#   .\scripts\deploy.ps1 -target rules
#   .\scripts\deploy.ps1 -target functions
#   .\scripts\deploy.ps1 -target hosting
#   .\scripts\deploy.ps1 -target apk
#   .\scripts\deploy.ps1 -target firebase   # rules + functions + hosting

param(
  [string]$target = "all"  # all, functions, rules, hosting, apk, firebase
)

$ErrorActionPreference = "Stop"

# ── Colours ────────────────────────────────────────────────────────────────
function Write-Success { param([string]$msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Fail    { param([string]$msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Write-Step    { param([string]$msg) Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Info    { param([string]$msg) Write-Host "  $msg" -ForegroundColor Yellow }

# ── Result tracking ────────────────────────────────────────────────────────
$results = @{}

function Run-Step {
  param([string]$name, [scriptblock]$block)
  Write-Step $name
  try {
    & $block
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) { throw "Exit code $LASTEXITCODE" }
    Write-Success $name
    $results[$name] = "OK"
  } catch {
    Write-Fail "$name — $_"
    $results[$name] = "FAILED"
  }
}

# ── Project root ───────────────────────────────────────────────────────────
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot
Write-Host "`nFufaji's Online — Deployment" -ForegroundColor Magenta
Write-Host "Project root : $projectRoot"
Write-Host "Target       : $target"
Write-Host "Date         : $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host ("-" * 50)

# ── TASK: Firestore security rules ────────────────────────────────────────
if ($target -in @("all", "firebase", "rules")) {
  Run-Step "Deploy Firestore Rules" {
    firebase deploy --only firestore:rules --project fufaji-online-business
  }
}

# ── TASK: Storage security rules ──────────────────────────────────────────
if ($target -in @("all", "firebase", "rules")) {
  Run-Step "Deploy Storage Rules" {
    firebase deploy --only storage --project fufaji-online-business
  }
}

# ── TASK: Cloud Functions ─────────────────────────────────────────────────
if ($target -in @("all", "firebase", "functions")) {
  Run-Step "Install Functions Dependencies" {
    Set-Location "$projectRoot\functions"
    npm install
    Set-Location $projectRoot
  }
  Run-Step "Deploy Cloud Functions" {
    firebase deploy --only functions --project fufaji-online-business
  }
}

# ── TASK: Firebase Hosting ────────────────────────────────────────────────
if ($target -in @("all", "firebase", "hosting")) {
  Run-Step "Deploy Firebase Hosting" {
    firebase deploy --only hosting --project fufaji-online-business
  }
}

# ── TASK: Flutter Release APK ─────────────────────────────────────────────
if ($target -in @("all", "apk")) {
  Run-Step "Flutter Clean" {
    flutter clean
  }
  Run-Step "Flutter Pub Get" {
    flutter pub get
  }
  Run-Step "Build Release APK" {
    flutter build apk --release --no-tree-shake-icons
  }
}

# ── Summary ────────────────────────────────────────────────────────────────
Write-Host "`n$("-" * 50)" -ForegroundColor Magenta
Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Magenta
Write-Host ("-" * 50)
foreach ($key in $results.Keys) {
  if ($results[$key] -eq "OK") {
    Write-Host "  [OK]   $key" -ForegroundColor Green
  } else {
    Write-Host "  [FAIL] $key" -ForegroundColor Red
  }
}

$apkPath = "$projectRoot\build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
  Write-Host "`nAPK Location:" -ForegroundColor Cyan
  Write-Info $apkPath
  $apkSize = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
  Write-Info "Size: ${apkSize} MB"
}

Write-Host "`nFirebase Hosting URL:" -ForegroundColor Cyan
Write-Info "https://fufaji-online-business.web.app"
Write-Info "https://fufaji-online-business.firebaseapp.com"

$failed = ($results.Values | Where-Object { $_ -eq "FAILED" }).Count
if ($failed -gt 0) {
  Write-Host "`n$failed step(s) failed. Check output above." -ForegroundColor Red
  exit 1
} else {
  Write-Host "`nAll steps completed successfully!" -ForegroundColor Green
  exit 0
}
