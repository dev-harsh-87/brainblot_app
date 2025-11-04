# Renaming BrainBlot to Spark - Instructions

This document provides instructions for renaming the entire project from "BrainBlot" to "Spark".

## ⚠️ IMPORTANT: Backup First!

Before running any scripts, make sure you have a complete backup of your project or commit all changes to Git.

```bash
git add .
git commit -m "Backup before renaming to Spark"
```

## Scripts Provided

Two scripts have been created for cross-platform compatibility:

1. **`rename_to_spark.bat`** - For Windows systems
2. **`rename_to_spark.sh`** - For macOS/Linux/Unix systems

## What Gets Renamed

### Package Names
- `brainblot_app` → `spark_app`
- `com.tbg.brainblotApp` → `com.tbg.sparkApp` (Android/iOS)

### Display Names
- `BrainBlot` → `Spark`

### URLs and Identifiers
- `brainblot.com` → `spark.com`
- `admin@brainblot.com` → `admin@spark.com`
- All other brainblot references → spark

### Files Affected
- All Dart files (*.dart) - 115+ files
- pubspec.yaml
- Android configuration (build.gradle, AndroidManifest.xml, MainActivity.kt)
- iOS configuration (Info.plist, project.pbxproj)
- Firebase configuration (firebase_options.dart)
- Configuration files (firebase.json, README.md)

## How to Run

### On Windows

1. Open Command Prompt or PowerShell as Administrator
2. Navigate to your project root directory:
   ```cmd
   cd C:\path\to\your\project
   ```

3. Run the batch script:
   ```cmd
   rename_to_spark.bat
   ```

### On macOS/Linux/Unix

1. Open Terminal
2. Navigate to your project root directory:
   ```bash
   cd /path/to/your/project
   ```

3. Make the script executable:
   ```bash
   chmod +x rename_to_spark.sh
   ```

4. Run the shell script:
   ```bash
   ./rename_to_spark.sh
   ```

## After Running the Script

### 1. Clean Flutter Build Files
```bash
flutter clean
```

### 2. Get Dependencies
```bash
flutter pub get
```

### 3. Rebuild Generated Files
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Update Firebase Configuration

You'll need to update your Firebase project:

#### For Android:
1. Go to Firebase Console (https://console.firebase.google.com)
2. Select your project
3. Go to Project Settings
4. Under "Your apps", find your Android app
5. Update the package name to `com.tbg.sparkApp`
6. Download the new `google-services.json`
7. Replace `android/app/google-services.json` with the new file

#### For iOS:
1. In Firebase Console, find your iOS app
2. Update the bundle identifier to `com.tbg.sparkApp`
3. Download the new `GoogleService-Info.plist`
4. Replace `ios/Runner/GoogleService-Info.plist` with the new file

### 5. Update App Store/Play Store Listings

If your app is published:

#### Google Play Store:
- You cannot change the package name of a published app
- You'll need to create a new app listing with the new package name
- Or keep the old package name and only update display names

#### Apple App Store:
- You can update the bundle display name
- The bundle identifier change requires a new app submission

### 6. Test Thoroughly

Test all features to ensure everything works:

```bash
# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios
```

### 7. Update Environment Variables

If you have any environment variables or CI/CD configurations that reference "brainblot", update them to "spark".

## Manual Checks Required

After running the script, manually verify these files:

1. **pubspec.yaml** - Check that the name is `spark_app`
2. **lib/main.dart** - Verify the app title is "Spark"
3. **android/app/build.gradle** - Confirm `applicationId "com.tbg.sparkApp"`
4. **ios/Runner/Info.plist** - Verify bundle identifier
5. **Firebase configuration files** - Ensure they're updated with new identifiers

## Troubleshooting

### Issue: Package name conflicts
**Solution**: Run `flutter clean` and `flutter pub get` again

### Issue: Firebase not working
**Solution**: Ensure you've downloaded and replaced the new Firebase config files

### Issue: Build errors on Android
**Solution**: 
1. Delete the `android/build` and `android/app/build` directories
2. Run `flutter clean`
3. Run `flutter pub get`
4. Rebuild the app

### Issue: Build errors on iOS
**Solution**:
1. Delete `ios/Pods` directory
2. Delete `ios/Podfile.lock`
3. Run `cd ios && pod install`
4. Open Xcode and clean build folder (Cmd+Shift+K)

## Rollback

If something goes wrong and you need to rollback:

```bash
git reset --hard HEAD
git clean -fd
```

This will restore your project to the state before renaming.

## Important Notes

1. **Firebase**: You must update Firebase configuration after renaming
2. **Published Apps**: Package name changes affect published apps significantly
3. **Deep Links**: Update any deep link configurations
4. **API Keys**: Update any API keys tied to the old package name
5. **Third-party Services**: Update package/bundle identifiers in any third-party services (analytics, crash reporting, etc.)

## Verification Checklist

After completing the renaming:

- [ ] App builds successfully on Android
- [ ] App builds successfully on iOS
- [ ] App runs without errors
- [ ] Firebase authentication works
- [ ] Firestore database access works
- [ ] All features function correctly
- [ ] App displays "Spark" as the name
- [ ] No references to "BrainBlot" in user-visible areas
- [ ] Deep links work (if applicable)
- [ ] Push notifications work (if applicable)

## Support

If you encounter issues not covered in this document, please:
1. Check the Flutter documentation
2. Verify Firebase configuration
3. Review build logs for specific errors
4. Ensure all dependencies are up to date

---

**Last Updated**: April 11, 2025
**Script Version**: 1.0.0