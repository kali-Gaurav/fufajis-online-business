param(
  [Parameter(Mandatory = $true)]
  [string]$RazorpayKeyId,

  [Parameter(Mandatory = $true)]
  [double]$ShopLatitude,

  [Parameter(Mandatory = $true)]
  [double]$ShopLongitude,

  [double]$DeliveryRadiusKm = 8,

  [string]$SupportWhatsappNumber = ""
)

$ErrorActionPreference = "Stop"

# 1. Run the build script
Write-Host "Step 1: Compiling Release APK..." -ForegroundColor Cyan
$ApkDownloadUrl = "https://fufaji-online-business.web.app/app-release.apk"

.\scripts\build_release_apk.ps1 `
  -RazorpayKeyId $RazorpayKeyId `
  -ShopLatitude $ShopLatitude `
  -ShopLongitude $ShopLongitude `
  -DeliveryRadiusKm $DeliveryRadiusKm `
  -ApkDownloadUrl $ApkDownloadUrl `
  -SupportWhatsappNumber $SupportWhatsappNumber

# 2. Copy the APK to the hosting public directory
Write-Host "Step 2: Copying APK to Firebase Hosting public directory..." -ForegroundColor Cyan
if (-not (Test-Path "public")) {
  New-Item -ItemType Directory -Path "public"
}
Copy-Item "build/app/outputs/flutter-apk/app-release.apk" "public/app-release.apk" -Force

Write-Host "Success! APK copied to public/app-release.apk" -ForegroundColor Green

# 3. Deploy to Firebase Hosting
Write-Host "Step 3: Deploying to Firebase Hosting..." -ForegroundColor Cyan
firebase deploy --only hosting

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "App update successfully deployed!" -ForegroundColor Green
Write-Host "URL: https://fufaji-online-business.web.app/" -ForegroundColor Green
Write-Host "Direct Download: https://fufaji-online-business.web.app/app-release.apk" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
