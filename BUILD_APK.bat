@echo off
REM ============================================================
REM  Fufaji Store — Production APK Build Script
REM  Run this from: C:\Projects\fufaji-online-business\
REM  Requirements: Flutter SDK in .\flutter\, Android SDK set,
REM                RAZORPAY_KEY_ID set in .env or passed below
REM ============================================================

echo.
echo ╔══════════════════════════════════════════════╗
echo ║     FUFAJI STORE — PRODUCTION APK BUILD     ║
echo ╚══════════════════════════════════════════════╝
echo.

REM ── Load .env if present ──────────────────────────────────
if exist .env (
    echo [1/6] Loading .env ...
    for /f "usebackq tokens=1,2 delims==" %%A in (".env") do (
        if not "%%A"=="" if not "%%A:~0,1%"=="#" set "%%A=%%B"
    )
) else (
    echo [1/6] No .env found — using system environment variables
)

REM ── Check RAZORPAY_KEY_ID ──────────────────────────────────
if "%RAZORPAY_KEY_ID%"=="" (
    echo.
    echo ERROR: RAZORPAY_KEY_ID is not set.
    echo   Add it to .env:  RAZORPAY_KEY_ID=rzp_live_XXXXXXXXXXXX
    echo   OR run:  set RAZORPAY_KEY_ID=rzp_live_XXXXXXXXXXXX
    echo.
    pause
    exit /b 1
)
echo        RAZORPAY_KEY_ID = %RAZORPAY_KEY_ID:~0,12%... (truncated for security)

REM ── Clean ─────────────────────────────────────────────────
echo [2/6] Cleaning previous build ...
call flutter\bin\flutter clean
if errorlevel 1 goto :error

REM ── Get dependencies ──────────────────────────────────────
echo [3/6] Getting packages ...
call flutter\bin\flutter pub get
if errorlevel 1 goto :error

REM ── Build release APK ─────────────────────────────────────
echo [4/6] Building release APK (this takes 3-5 minutes) ...
call flutter\bin\flutter build apk ^
    --release ^
    --dart-define=API_BASE_URL=%API_BASE_URL% ^
    --dart-define=RAZORPAY_KEY_ID=%RAZORPAY_KEY_ID% ^
    --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
    --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% ^
    --dart-define=SENTRY_DSN=%SENTRY_DSN% ^
    --dart-define=ENVIRONMENT=production ^
    --obfuscate ^
    --split-debug-info=build\debug-info
if errorlevel 1 goto :error

REM ── Deploy Cloud Functions ────────────────────────────────
echo [5/6] Deploying Cloud Functions (payment CFs + cashback trigger) ...
echo       (Requires Firebase CLI logged in — skip with Ctrl+C if not ready)
cd functions
call npm run build
if errorlevel 1 (
    echo WARNING: Functions TypeScript build had errors — check functions/src/
    cd ..
    goto :apk_done
)
cd ..
call firebase deploy --only functions --project fufaji-store
if errorlevel 1 (
    echo WARNING: Firebase deploy failed. Run manually:
    echo   firebase deploy --only functions
)

REM ── Deploy Firestore rules ────────────────────────────────
echo [6/6] Deploying Firestore security rules ...
call firebase deploy --only firestore:rules --project fufaji-store
if errorlevel 1 (
    echo WARNING: Firestore rules deploy failed. Run manually:
    echo   firebase deploy --only firestore:rules
)

:apk_done
echo.
echo ╔═══════════════════════════════════════════════════════╗
echo ║                   BUILD COMPLETE!                     ║
echo ╠═══════════════════════════════════════════════════════╣
echo ║  APK:  build\app\outputs\flutter-apk\app-release.apk  ║
echo ║                                                       ║
echo ║  Install on device:                                   ║
echo ║    adb install build\app\outputs\flutter-apk\app-release.apk
echo ╚═══════════════════════════════════════════════════════╝
echo.
start "" "build\app\outputs\flutter-apk\"
goto :eof

:error
echo.
echo ╔══════════════════════════════════╗
echo ║   BUILD FAILED — see error above ║
echo ╚══════════════════════════════════╝
pause
exit /b 1
