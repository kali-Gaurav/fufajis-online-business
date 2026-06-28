@echo off
setlocal enabledelayedexpansion

echo.
echo ================================================================
echo  FUFAJI STORE - NATIVE UPDATE PUSHER
echo ================================================================
echo.

set PROJECT_DIR=%~dp0
set APP_DIR=%PROJECT_DIR%app\fufaji-app

cd /d "%PROJECT_DIR%app"

REM ── Step 1: Build Release APK ────────────────────────────────────
echo [1/4] Building latest APK...
call gradlew :app:assembleRelease
if errorlevel 1 (
    echo ❌ Build failed!
    pause
    exit /b 1
)
echo ✅ Build successful.

REM ── Step 2: Identify APK ─────────────────────────────────────────
set APK_PATH=%PROJECT_DIR%app\fufaji-app\build\outputs\apk\release\fufaji-app-release.apk
if not exist "%APK_PATH%" set APK_PATH=%PROJECT_DIR%app\fufaji-app\build\outputs\apk\release\app-release.apk

echo ✅ APK located at: %APK_PATH%

REM ── Step 3: Deployment Instructions ──────────────────────────────
echo.
echo [2/4] DEPLOYMENT STEPS:
echo.
echo 1. UPLOAD APK:
echo    Upload the APK to your Firebase Storage or a public hosting.
echo    Direct link will be needed.
echo.
echo 2. UPDATE REMOTE CONFIG:
echo    Go to: Firebase Console -^> Remote Config
echo    Update these keys:
echo    - latest_version_code: [Incremental number, e.g., 2]
echo    - update_url: [The link to your uploaded APK]
echo    - is_force_update: [true or false]
echo.
echo 3. PUBLISH:
echo    Click "Publish changes" in Firebase Console.
echo.
echo All users will receive the update notification on their next app open!
echo.
echo [3/4] Opening APK folder...
explorer /select,"%APK_PATH%"

echo.
echo [4/4] Done!
pause
