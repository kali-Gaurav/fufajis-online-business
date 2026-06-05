@echo off
REM ================================================================
REM Fufaji's Online — Firebase Functions Config Setup
REM Run this ONCE to set all server-side secrets in Firebase.
REM These secrets are NEVER in the Flutter app or .env file.
REM ================================================================

echo Setting Razorpay server-side secrets...
firebase functions:config:set razorpay.key_secret="ieGG9GcxgN0km2ZVcGyaGEG6"
firebase functions:config:set razorpay.webhook_secret="YOUR_RAZORPAY_WEBHOOK_SECRET_HERE"

echo Setting WhatsApp Business API secrets...
firebase functions:config:set whatsapp.token="EAASZAhYl2VnEBRpd5QHAC2zNRX8c7PdbgZB3hrJgz1L5QFZAUeFlYJi0FZAHn2ccMuRIQWLqyyZChsmHYvOPkMioM5tbUdvg75vPaHfRIxGsb1Nje7nr0mV8rVptzPDrqq8ZCmc08RK9KtC3hZBRTqJDxYg3ZAyfyGRCyL2oGqsCDZBJLxPrVwzdZCqEZB8JTKZAOwZDZD"
firebase functions:config:set whatsapp.phone_id="1086896934513865"
firebase functions:config:set whatsapp.verify_token="fufaji_webhook_verify_2026"

echo Setting Twilio secrets...
firebase functions:config:set twilio.account_sid="AC33d253da4a1076582dc464d9d5e5835f"
firebase functions:config:set twilio.auth_token="e1a666462f5476a669d9058c059831ce"
firebase functions:config:set twilio.phone_number="+91XXXXXXXXXX"

echo Setting app config...
firebase functions:config:set app.owner_phone="+919XXXXXXXXX"
firebase functions:config:set app.shop_name="Fufaji's Online"

echo.
echo ✅ All Firebase Functions config values set!
echo.
echo Now deploy functions:
echo   cd functions
echo   npm install
echo   cd ..
echo   firebase deploy --only functions
echo.
pause
