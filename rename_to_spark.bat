@echo off
REM Rename BrainBlot to Spark - Windows Batch Script
REM Run this from the project root directory

echo ====================================
echo Renaming BrainBlot to Spark
echo ====================================
echo.

REM Backup notification
echo IMPORTANT: Make sure you have a backup before running this script!
echo Press Ctrl+C to cancel, or
pause

echo.
echo Step 1: Renaming in Dart files...
echo ====================================

REM Replace brainblot_app with spark_app in all Dart files
powershell -Command "(Get-ChildItem -Recurse -Filter *.dart) | ForEach-Object { (Get-Content $_.FullName) -replace 'brainblot_app', 'spark_app' | Set-Content $_.FullName }"

REM Replace BrainBlot with Spark in display names
powershell -Command "(Get-ChildItem -Recurse -Filter *.dart) | ForEach-Object { (Get-Content $_.FullName) -replace 'BrainBlot', 'Spark' | Set-Content $_.FullName }"

REM Replace brainblot with spark in URLs and emails
powershell -Command "(Get-ChildItem -Recurse -Filter *.dart) | ForEach-Object { (Get-Content $_.FullName) -replace 'brainblot', 'spark' | Set-Content $_.FullName }"

echo.
echo Step 2: Updating pubspec.yaml...
echo ====================================

powershell -Command "(Get-Content pubspec.yaml) -replace 'brainblot_app', 'spark_app' -replace 'BrainBlot', 'Spark' -replace 'brainblot', 'spark' | Set-Content pubspec.yaml"

echo.
echo Step 3: Updating Android configuration...
echo ====================================

REM Update Android package name
powershell -Command "if (Test-Path 'android/app/build.gradle') { (Get-Content 'android/app/build.gradle') -replace 'com.tbg.brainblotApp', 'com.tbg.sparkApp' -replace 'brainblot', 'spark' | Set-Content 'android/app/build.gradle' }"

REM Update AndroidManifest.xml
powershell -Command "if (Test-Path 'android/app/src/main/AndroidManifest.xml') { (Get-Content 'android/app/src/main/AndroidManifest.xml') -replace 'com.tbg.brainblotApp', 'com.tbg.sparkApp' -replace 'BrainBlot', 'Spark' -replace 'brainblot', 'spark' | Set-Content 'android/app/src/main/AndroidManifest.xml' }"

REM Update MainActivity.kt
powershell -Command "if (Test-Path 'android/app/src/main/kotlin/com/tbg/brainblotApp/MainActivity.kt') { (Get-Content 'android/app/src/main/kotlin/com/tbg/brainblotApp/MainActivity.kt') -replace 'com.tbg.brainblotApp', 'com.tbg.sparkApp' | Set-Content 'android/app/src/main/kotlin/com/tbg/brainblotApp/MainActivity.kt' }"

echo.
echo Step 4: Updating iOS configuration...
echo ====================================

REM Update Info.plist
powershell -Command "if (Test-Path 'ios/Runner/Info.plist') { (Get-Content 'ios/Runner/Info.plist') -replace 'com.tbg.brainblotApp', 'com.tbg.sparkApp' -replace 'BrainBlot', 'Spark' -replace 'brainblot', 'spark' | Set-Content 'ios/Runner/Info.plist' }"

REM Update project.pbxproj
powershell -Command "if (Test-Path 'ios/Runner.xcodeproj/project.pbxproj') { (Get-Content 'ios/Runner.xcodeproj/project.pbxproj') -replace 'com.tbg.brainblotApp', 'com.tbg.sparkApp' -replace 'brainblot', 'spark' | Set-Content 'ios/Runner.xcodeproj/project.pbxproj' }"

echo.
echo Step 5: Updating Firebase configuration...
echo ====================================

powershell -Command "if (Test-Path 'lib/firebase_options.dart') { (Get-Content 'lib/firebase_options.dart') -replace 'com.tbg.brainblotApp', 'com.tbg.sparkApp' -replace 'brainblot', 'spark' | Set-Content 'lib/firebase_options.dart' }"

echo.
echo Step 6: Updating configuration files...
echo ====================================

powershell -Command "if (Test-Path 'firebase.json') { (Get-Content 'firebase.json') -replace 'brainblot', 'spark' | Set-Content 'firebase.json' }"

powershell -Command "if (Test-Path 'README.md') { (Get-Content 'README.md') -replace 'brainblot_app', 'spark_app' -replace 'BrainBlot', 'Spark' -replace 'brainblot', 'spark' | Set-Content 'README.md' }"

echo.
echo Step 7: Renaming Android package directories...
echo ====================================

if exist "android\app\src\main\kotlin\com\tbg\brainblotApp" (
    mkdir "android\app\src\main\kotlin\com\tbg\sparkApp" 2>nul
    xcopy "android\app\src\main\kotlin\com\tbg\brainblotApp\*" "android\app\src\main\kotlin\com\tbg\sparkApp\" /E /I /Y
    rmdir /S /Q "android\app\src\main\kotlin\com\tbg\brainblotApp"
    echo Android package directory renamed
)

echo.
echo ====================================
echo Renaming Complete!
echo ====================================
echo.
echo Next steps:
echo 1. Run: flutter clean
echo 2. Run: flutter pub get
echo 3. Update Firebase project settings if needed
echo 4. Test the app thoroughly
echo.
pause