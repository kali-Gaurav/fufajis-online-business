@echo off
REM ================================================================
REM Fufaji's Online — One-Click APK Builder
REM Double-click this file to build the release APK.
REM ================================================================
setlocal enabledelayedexpansion

echo.
echo  ███████╗██╗   ██╗███████╗ █████╗      ██╗██╗
echo  ██╔════╝██║   ██║██╔════╝██╔══██╗     ██║██║
echo  █████╗  ██║   ██║█████╗  ███████║     ██║██║
echo  ██╔══╝  ██║   ██║██╔══╝  ██╔══██║██   ██║██║
echo  ██║     ╚██████╔╝██║     ██║  ██║╚█████╔╝██║
echo  ╚═╝      ╚═════╝ ╚═╝     ╚═╝  ╚═╝ ╚════╝ ╚═╝
echo  Fufaji's Online — APK Builder v1.1
echo ================================================================
echo.

set PROJECT_DIR=%~dp0
cd /d "%PROJECT_DIR%"

REM ── Step 0: Check Flutter is installed ──────────────────────────
echo [1/7] Checking Flutter installation...
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter not found! Install from https://flutter.dev/docs/get-started/install
    echo    Then add Flutter to your PATH and re-run this script.
    pause
    exit /b 1
)
echo ✅ Flutter found.

REM ── Step 1: Check keystore exists, generate if not ──────────────
echo.
echo [2/7] Checking release keystore...
set KEYSTORE_PATH=%PROJECT_DIR%android\fufaji-upload-key.jks
if exist "%KEYSTORE_PATH%" (
    echo ✅ Keystore found: android\fufaji-upload-key.jks
) else (
    echo ⚠️  Keystore not found. Generating new keystore...
    echo    (This is a one-time setup — save the keystore file safely!)
    echo.
    keytool -genkey -v ^
        -keystore "%KEYSTORE_PATH%" ^
        -alias upload ^
        -keyalg RSA ^
        -keysize 2048 ^
        -validity 10000 ^
        -storepass fufaji123 ^
        -keypass fufaji123 ^
        -dname "CN=Fufaji's Online, OU=Mobile, O=Fufaji Store, L=Baran, S=Rajasthan, C=IN"
    if errorlevel 1 (
        echo ❌ Keystore generation failed! Make sure Java JDK is installed.
        echo    Install: https://adoptium.net/
        pause
        exit /b 1
    )
    echo ✅ Keystore generated at: android\fufaji-upload-key.jks
    echo    ⚠️  IMPORTANT: Back up this file! Losing it means you cannot update the app.
)

REM ── Step 2: Verify key.properties ───────────────────────────────
echo.
echo [3/7] Verifying key.properties...
if not exist "%PROJECT_DIR%android\key.properties" (
    echo Creating key.properties...
    (
        echo storePassword=fufaji123
        echo keyPassword=fufaji123
        echo keyAlias=upload
        echo storeFile=fufaji-upload-key.jks
    ) > "%PROJECT_DIR%android\key.properties"
)
echo ✅ key.properties ready.

REM ── Step 3: Clean previous build ────────────────────────────────
echo.
echo [4/7] Cleaning previous build artifacts...
flutter clean
echo ✅ Clean complete.

REM ── Step 4: Get dependencies ─────────────────────────────────────
echo.
echo [5/7] Getting Flutter packages...
flutter pub get
if errorlevel 1 (
    echo ❌ pub get failed! Check your internet connection.
    pause
    exit /b 1
)
echo ✅ Packages ready.

REM ── Step 5: Build Release APK ────────────────────────────────────
echo.
echo [6/7] Building Release APK...
echo     This takes 3-8 minutes. Please wait...
echo.
flutter build apk --release --no-tree-shake-icons
if errorlevel 1 (
    echo.
    echo ❌ APK build failed!
    echo.
    echo Common fixes:
    echo   1. Run: flutter doctor
    echo   2. Check: android\local.properties has flutter.sdk path
    echo   3. Make sure Android SDK is installed
    pause
    exit /b 1
)

REM ── Step 6: Show result ───────────────────────────────────────────
echo.
echo [7/7] Build complete!
echo ================================================================
echo.
set APK_PATH=%PROJECT_DIR%build\app\outputs\flutter-apk\app-release.apk

if exist "%APK_PATH%" (
    echo ✅ SUCCESS! Your APK is ready:
    echo.
    echo    📱 %APK_PATH%
    echo.
    for %%A in ("%APK_PATH%") do echo    Size: %%~zA bytes (%%~zA / 1048576 MB)
    echo.
    echo ── How to install on your phone ─────────────────────────────
    echo    Option A - USB:
    echo      Connect phone via USB, enable USB debugging, run:
    echo      adb install "%APK_PATH%"
    echo.
    echo    Option B - Share file:
    echo      Copy APK to phone via WhatsApp / Google Drive / USB
    echo      Open on phone → Install (allow unknown sources)
    echo.
    echo    Option C - ADB wireless:
    echo      adb connect YOUR_PHONE_IP:5555
    echo      adb install "%APK_PATH%"
    echo ================================================================

    REM Open the folder containing the APK
    explorer "%PROJECT_DIR%build\app\outputs\flutter-apk\"
) else (
    echo ❌ APK file not found at expected path.
    echo    Check build\app\outputs\flutter-apk\ manually.
)
echo.
pause
