@echo off
REM Google Play Services Fix Script for Windows
REM This script helps fix the SecurityException errors by getting SHA certificates

echo 🔧 Google Play Services Fix Script
echo ==================================
echo.

REM Check if we're in the correct directory
if not exist "pubspec.yaml" (
    echo ❌ Error: Please run this script from the project root directory
    exit /b 1
)

echo 📱 Project: com.tbg.spark_app
echo 🔥 Firebase Project: brain-app-18086
echo.

REM Get SHA-1 and SHA-256 fingerprints
echo 🔍 Getting debug SHA certificates...
echo.

cd android
gradlew signingReport | findstr /C:"Variant: debug" /C:"SHA1:" /C:"SHA-256:"
cd ..

echo.
echo ==================================
echo ✅ SHA certificates displayed above
echo.
echo 📋 Next Steps:
echo 1. Copy the SHA-1 and SHA-256 values from above
echo 2. Go to: https://console.firebase.google.com/project/brain-app-18086/settings/general
echo 3. Scroll to 'Your apps' → Find Android app
echo 4. Click 'Add fingerprint'
echo 5. Paste SHA-1, click Save
echo 6. Repeat for SHA-256
echo 7. Download new google-services.json
echo 8. Replace android/app/google-services.json
echo 9. Run: flutter clean ^&^& flutter pub get
echo.
echo 📖 Full guide: docs/GOOGLE_PLAY_SERVICES_FIX.md
echo.
pause