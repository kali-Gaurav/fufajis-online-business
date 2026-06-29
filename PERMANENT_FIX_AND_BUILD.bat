@echo off
SETLOCAL

:: --- STEP 1: RESOLVE SPACE-IN-PATH ISSUE ---
SET "PUB_CACHE=C:\pub_cache"
IF NOT EXIST "C:\pub_cache" mkdir "C:\pub_cache"
echo [+] Using space-free Pub Cache: %PUB_CACHE%

:: --- STEP 2: CLEAN ENVIRONMENT ---
echo [+] Cleaning project...
call flutter clean

:: --- STEP 3: RE-SYNC DEPENDENCIES ---
echo [+] Downloading packages...
call flutter pub get

:: --- STEP 4: BACKEND SYNC ---
echo [+] Deploying Firebase Rules and Functions...
:: This ensures your UID identity and Custom Claims logic are live
call firebase deploy --only firestore,functions,storage

:: --- STEP 5: SHOREBIRD RELEASE (OVER-THE-AIR UPDATES) ---
echo [+] Starting Shorebird Release for Android...
:: This creates the first release so that future updates can be sent 'in the air'
call shorebird release android

:: --- STEP 6: VERIFICATION ---
IF %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] Build completed! Install the generated AAB/APK on your phone.
    echo [NOTICE] From now on, you can use 'shorebird patch android' to send updates instantly!
) ELSE (
    echo [ERROR] Build failed. Please check the logs above.
)

pause
ENDLOCAL
