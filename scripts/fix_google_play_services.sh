#!/bin/bash

# Google Play Services Fix Script
# This script helps fix the SecurityException errors by getting SHA certificates

echo "🔧 Google Play Services Fix Script"
echo "=================================="
echo ""

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

echo "📱 Project: com.tbg.spark_app"
echo "🔥 Firebase Project: brain-app-18086"
echo ""

# Get SHA-1 and SHA-256 fingerprints
echo "🔍 Getting debug SHA certificates..."
echo ""

cd android

if [ -f "gradlew" ]; then
    chmod +x gradlew
    ./gradlew signingReport 2>&1 | grep -A 3 "Variant: debug"
else
    echo "❌ gradlew not found"
    exit 1
fi

echo ""
echo "=================================="
echo "✅ SHA certificates displayed above"
echo ""
echo "📋 Next Steps:"
echo "1. Copy the SHA-1 and SHA-256 values from above"
echo "2. Go to: https://console.firebase.google.com/project/brain-app-18086/settings/general"
echo "3. Scroll to 'Your apps' → Find Android app"
echo "4. Click 'Add fingerprint'"
echo "5. Paste SHA-1, click Save"
echo "6. Repeat for SHA-256"
echo "7. Download new google-services.json"
echo "8. Replace android/app/google-services.json"
echo "9. Run: flutter clean && flutter pub get"
echo ""
echo "📖 Full guide: docs/GOOGLE_PLAY_SERVICES_FIX.md"