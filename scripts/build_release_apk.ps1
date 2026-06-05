# Fufaji's Online — Release APK Build Script (Windows PowerShell)
# Run from project root: .\scripts\build_release_apk.ps1

Write-Host "== Fufaji's Online - Release Build ==" -ForegroundColor Cyan

# Step 1: Clean previous builds
Write-Host "Cleaning..." -ForegroundColor Yellow
flutter clean

# Step 2: Get packages
Write-Host "Getting packages..." -ForegroundColor Yellow
flutter pub get

# Step 3: Build release APK
Write-Host "Building release APK..." -ForegroundColor Yellow
flutter build apk --release --no-tree-shake-icons

Write-Host ""
Write-Host "BUILD COMPLETE!" -ForegroundColor Green
Write-Host "APK location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
