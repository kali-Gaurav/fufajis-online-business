# Fufaji's Online — Firebase App Distribution Script
# Builds release APK and uploads to Firebase App Distribution
#
# Prerequisites:
#   firebase appdistribution:distribute requires Firebase CLI >= 11
#   firebase login must have been run
#
# Usage:
#   .\scripts\distribute_apk.ps1
#   .\scripts\distribute_apk.ps1 -releaseNotes "Fixed checkout bug"
#   .\scripts\distribute_apk.ps1 -skipBuild   # upload existing APK

param(
  [string]$releaseNotes = "",
  [switch]$skipBuild = $false
)

$ErrorActionPreference = "Stop"

# ── Config ─────────────────────────────────────────────────────────────────
$projectRoot   = Split-Path $PSScriptRoot -Parent
$appId         = "1:126709583600:android:e6ad41f7d3dfa4f0d5bc35"
$apkPath       = "$projectRoot\build\app\outputs\flutter-apk\app-release.apk"
$testerGroups  = "owners,delivery-team,qa-testers"

# ── Colours ────────────────────────────────────────────────────────────────
function Write-Success { param([string]$msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Fail    { param([string]$msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Write-Step    { param([string]$msg) Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Info    { param([string]$msg) Write-Host "  $msg" -ForegroundColor Yellow }

Set-Location $projectRoot

# ── Auto-detect version from pubspec.yaml ──────────────────────────────────
$version = "1.0.0"
$pubspec = "$projectRoot\pubspec.yaml"
if (Test-Path $pubspec) {
  $versionLine = Select-String -Path $pubspec -Pattern "^version:" | Select-Object -First 1
  if ($versionLine) {
    $version = ($versionLine.Line -replace "version:\s*", "").Trim().Split("+")[0]
  }
}

# ── Build release notes ────────────────────────────────────────────────────
$date = Get-Date -Format "yyyy-MM-dd HH:mm"
if ($releaseNotes -eq "") {
  $releaseNotes = "Fufaji's Online v$version — Build on $date`n`nChanges in this build:`n- Production deployment`n- Firebase integration complete`n- Razorpay + COD payment flow"
}

Write-Host "`nFufaji's Online — App Distribution" -ForegroundColor Magenta
Write-Host "Version      : $version"
Write-Host "Date         : $date"
Write-Host "App ID       : $appId"
Write-Host "Groups       : $testerGroups"
Write-Host ("-" * 50)

# ── Step 1: Build APK ──────────────────────────────────────────────────────
if (-not $skipBuild) {
  Write-Step "Flutter Clean"
  flutter clean
  if ($LASTEXITCODE -ne 0) { Write-Fail "flutter clean failed"; exit 1 }
  Write-Success "Clean done"

  Write-Step "Flutter Pub Get"
  flutter pub get
  if ($LASTEXITCODE -ne 0) { Write-Fail "flutter pub get failed"; exit 1 }
  Write-Success "Dependencies resolved"

  Write-Step "Build Release APK"
  flutter build apk --release --no-tree-shake-icons
  if ($LASTEXITCODE -ne 0) { Write-Fail "APK build failed"; exit 1 }
  Write-Success "APK built"
} else {
  Write-Info "Skipping build (-skipBuild flag set)"
}

# ── Step 2: Verify APK exists ──────────────────────────────────────────────
Write-Step "Verifying APK"
if (-not (Test-Path $apkPath)) {
  Write-Fail "APK not found at: $apkPath"
  Write-Info "Run without -skipBuild to build first."
  exit 1
}
$apkSize = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
Write-Success "APK found — ${apkSize} MB"
Write-Info $apkPath

# ── Step 3: Upload to App Distribution ────────────────────────────────────
Write-Step "Uploading to Firebase App Distribution"
Write-Info "Release notes:`n$releaseNotes"

$notesFile = "$env:TEMP\fufaji_release_notes.txt"
$releaseNotes | Out-File -FilePath $notesFile -Encoding UTF8

firebase appdistribution:distribute $apkPath `
  --app $appId `
  --release-notes-file $notesFile `
  --groups $testerGroups `
  --project fufaji-online-business

if ($LASTEXITCODE -ne 0) {
  Write-Fail "Upload to App Distribution failed"
  Remove-Item $notesFile -ErrorAction SilentlyContinue
  exit 1
}

Remove-Item $notesFile -ErrorAction SilentlyContinue
Write-Success "APK uploaded to Firebase App Distribution"

# ── Summary ────────────────────────────────────────────────────────────────
Write-Host "`n$("-" * 50)" -ForegroundColor Magenta
Write-Host "DISTRIBUTION COMPLETE" -ForegroundColor Green
Write-Info "Version       : $version"
Write-Info "APK size      : ${apkSize} MB"
Write-Info "Notified      : $testerGroups"
Write-Host "`nView in Firebase Console:" -ForegroundColor Cyan
Write-Info "https://console.firebase.google.com/project/fufaji-online-business/appdistribution"
