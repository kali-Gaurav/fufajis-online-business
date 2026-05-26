param(
  [Parameter(Mandatory = $true)]
  [string]$RazorpayKeyId,

  [Parameter(Mandatory = $true)]
  [double]$ShopLatitude,

  [Parameter(Mandatory = $true)]
  [double]$ShopLongitude,

  [double]$DeliveryRadiusKm = 8,

  [string]$ApkDownloadUrl = "",

  [string]$SupportWhatsappNumber = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path "android/app/google-services.json")) {
  throw "Missing android/app/google-services.json. Download it from Firebase Console before building."
}

if (-not (Test-Path "android/key.properties")) {
  Write-Warning "android/key.properties is missing. This build will use debug signing fallback until a production keystore is configured."
}

flutter clean
flutter pub get
flutter build apk --release `
  --dart-define=RAZORPAY_KEY_ID=$RazorpayKeyId `
  --dart-define=SHOP_LATITUDE=$ShopLatitude `
  --dart-define=SHOP_LONGITUDE=$ShopLongitude `
  --dart-define=DELIVERY_RADIUS_KM=$DeliveryRadiusKm `
  --dart-define=APK_DOWNLOAD_URL=$ApkDownloadUrl `
  --dart-define=SUPPORT_WHATSAPP_NUMBER=$SupportWhatsappNumber

Write-Host ""
Write-Host "Release APK created at:"
Write-Host "build/app/outputs/flutter-apk/app-release.apk"
