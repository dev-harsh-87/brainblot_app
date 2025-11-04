#!/bin/bash
# Rename BrainBlot to Spark - Unix/Linux/Mac Shell Script
# Run this from the project root directory

echo "===================================="
echo "Renaming BrainBlot to Spark"
echo "===================================="
echo ""

# Backup notification
echo "IMPORTANT: Make sure you have a backup before running this script!"
echo "Press Ctrl+C to cancel, or press Enter to continue..."
read

echo ""
echo "Step 1: Renaming in Dart files..."
echo "===================================="

# Replace brainblot_app with spark_app in all Dart files
find . -type f -name "*.dart" -exec sed -i.bak 's/brainblot_app/spark_app/g' {} \;

# Replace BrainBlot with Spark in display names
find . -type f -name "*.dart" -exec sed -i.bak 's/BrainBlot/Spark/g' {} \;

# Replace brainblot with spark in URLs and emails (but not in package names we already changed)
find . -type f -name "*.dart" -exec sed -i.bak 's/brainblot\([^_]\)/spark\1/g' {} \;

echo ""
echo "Step 2: Updating pubspec.yaml..."
echo "===================================="

if [ -f "pubspec.yaml" ]; then
    sed -i.bak 's/brainblot_app/spark_app/g' pubspec.yaml
    sed -i.bak 's/BrainBlot/Spark/g' pubspec.yaml
    sed -i.bak 's/brainblot/spark/g' pubspec.yaml
fi

echo ""
echo "Step 3: Updating Android configuration..."
echo "===================================="

# Update Android package name in build.gradle
if [ -f "android/app/build.gradle" ]; then
    sed -i.bak 's/com\.tbg\.brainblotApp/com.tbg.sparkApp/g' android/app/build.gradle
    sed -i.bak 's/brainblot/spark/g' android/app/build.gradle
fi

# Update AndroidManifest.xml
if [ -f "android/app/src/main/AndroidManifest.xml" ]; then
    sed -i.bak 's/com\.tbg\.brainblotApp/com.tbg.sparkApp/g' android/app/src/main/AndroidManifest.xml
    sed -i.bak 's/BrainBlot/Spark/g' android/app/src/main/AndroidManifest.xml
    sed -i.bak 's/brainblot/spark/g' android/app/src/main/AndroidManifest.xml
fi

# Update MainActivity.kt
if [ -f "android/app/src/main/kotlin/com/tbg/brainblotApp/MainActivity.kt" ]; then
    sed -i.bak 's/com\.tbg\.brainblotApp/com.tbg.sparkApp/g' android/app/src/main/kotlin/com/tbg/brainblotApp/MainActivity.kt
fi

echo ""
echo "Step 4: Updating iOS configuration..."
echo "===================================="

# Update Info.plist
if [ -f "ios/Runner/Info.plist" ]; then
    sed -i.bak 's/com\.tbg\.brainblotApp/com.tbg.sparkApp/g' ios/Runner/Info.plist
    sed -i.bak 's/BrainBlot/Spark/g' ios/Runner/Info.plist
    sed -i.bak 's/brainblot/spark/g' ios/Runner/Info.plist
fi

# Update project.pbxproj
if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
    sed -i.bak 's/com\.tbg\.brainblotApp/com.tbg.sparkApp/g' ios/Runner.xcodeproj/project.pbxproj
    sed -i.bak 's/brainblot/spark/g' ios/Runner.xcodeproj/project.pbxproj
fi

echo ""
echo "Step 5: Updating Firebase configuration..."
echo "===================================="

if [ -f "lib/firebase_options.dart" ]; then
    sed -i.bak 's/com\.tbg\.brainblotApp/com.tbg.sparkApp/g' lib/firebase_options.dart
    sed -i.bak 's/brainblot/spark/g' lib/firebase_options.dart
fi

echo ""
echo "Step 6: Updating configuration files..."
echo "===================================="

if [ -f "firebase.json" ]; then
    sed -i.bak 's/brainblot/spark/g' firebase.json
fi

if [ -f "README.md" ]; then
    sed -i.bak 's/brainblot_app/spark_app/g' README.md
    sed -i.bak 's/BrainBlot/Spark/g' README.md
    sed -i.bak 's/brainblot/spark/g' README.md
fi

echo ""
echo "Step 7: Renaming Android package directories..."
echo "===================================="

if [ -d "android/app/src/main/kotlin/com/tbg/brainblotApp" ]; then
    mkdir -p android/app/src/main/kotlin/com/tbg/sparkApp
    cp -r android/app/src/main/kotlin/com/tbg/brainblotApp/* android/app/src/main/kotlin/com/tbg/sparkApp/
    rm -rf android/app/src/main/kotlin/com/tbg/brainblotApp
    echo "Android package directory renamed"
fi

echo ""
echo "Step 8: Cleaning up backup files..."
echo "===================================="

# Remove all .bak files created by sed
find . -type f -name "*.bak" -delete
echo "Backup files removed"

echo ""
echo "===================================="
echo "Renaming Complete!"
echo "===================================="
echo ""
echo "Next steps:"
echo "1. Run: flutter clean"
echo "2. Run: flutter pub get"
echo "3. Update Firebase project settings if needed"
echo "4. Test the app thoroughly"
echo ""