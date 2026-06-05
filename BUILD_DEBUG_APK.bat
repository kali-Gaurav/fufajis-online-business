@echo off
REM ================================================================
REM Fufaji's Online — Quick DEBUG APK (for testing on your phone)
REM No keystore needed. Installs fast. Don't share publicly.
REM ================================================================
cd /d "%~dp0"
echo.
echo Building DEBUG APK for testing...
echo (Faster build, no signing required)
echo.
flutter pub get
flutter build apk --debug --no-tree-shake-icons
echo.
if errorlevel 1 (
    echo ❌ Build failed. Run "flutter doctor" to diagnose.
) else (
    echo ✅ Debug APK ready:
    echo    build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo Install via USB:
    echo    adb install build\app\outputs\flutter-apk\app-debug.apk
    explorer build\app\outputs\flutter-apk\
)
pause
