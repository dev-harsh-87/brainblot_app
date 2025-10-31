# Database Setup Guide

## Production Database Reset

This guide explains how to reset your Firebase database to a clean, production-ready structure.

---

## Prerequisites

1. **Firebase Project Setup**
   - Active Firebase project configured
   - Firestore database enabled
   - Firebase Auth enabled

2. **Flutter Environment**
   - Flutter SDK installed
   - Project dependencies installed (`flutter pub get`)

3. **Admin Credentials**
   - Default admin email: `admin@brainblot.com`
   - Default admin password: `Admin@123456`
   - ⚠️ **Change password immediately after first login!**

---

## Step 1: Backup Current Data (Optional)

If you want to preserve any existing data:

```bash
# Export from Firebase Console
# Go to: Firestore Database > Import/Export
# Or use Firebase CLI:
firebase firestore:export gs://your-bucket-name/backups/$(date +%Y%m%d)
```

---

## Step 2: Clear App State (Important!)

Before running the production setup, if you have the app already installed, you should clear the app state to prevent white screen issues:

```bash
flutter run lib/core/scripts/clear_app_state.dart
```

This script will:
- Sign out the current user
- Clear saved login credentials
- Clear local storage (Hive boxes)

**Alternative:** Uninstall and reinstall the app to start completely fresh.

---

## Step 3: Run Production Setup Script

Execute the production database setup script:

```bash
flutter run lib/core/scripts/production_database_setup.dart
```

### What This Script Does:

1. **Clears Old Data**
   - Removes all documents from existing collections
   - Safely handles large datasets
   - Preserves collection structure

2. **Creates Admin Account**
   - Email: admin@brainblot.com
   - Role: admin (full access)
   - Default subscription: Institute plan

3. **Initializes Subscription Plans**
   - Free Plan (default for new users)
   - Player Plan (individual features)
   - Institute Plan (full access)

4. **Sets Up System Configuration**
   - Feature flags
   - System limits
   - Environment settings

5. **Creates Database Indexes**
   - Optimized query performance
   - Compound indexes for common queries

---

## Step 4: Verify Setup

After running the setup script, verify:

1. **Admin Account**
   ```
   Email: admin@brainblot.com
   Password: Admin@123456
   Role: admin
   ```

2. **Collections Created**
   - users
   - subscription_plans
   - system
   - (Other collections created on-demand)

3. **Test Login**
   - Launch the app
   - Login with admin credentials
   - Verify full access to all features

---

## Step 5: Deploy Firestore Indexes

Deploy the required indexes for optimal query performance:

```bash
firebase deploy --only firestore:indexes
```

This will create indexes for:
- subscription_plans (isActive, priority)
- drills (various combinations)
- programs (various combinations)
- sessions (user queries)
- Other collections

**Note:** Index creation can take several minutes. You can monitor progress in the Firebase Console.

---

## Step 6: Update Firestore Security Rules

Deploy updated security rules:

```bash
firebase deploy --only firestore:rules
```

Verify rules in Firebase Console:
- Go to: Firestore Database > Rules
- Ensure `admin` role has proper permissions
- Test with Rules Playground

---

## Step 7: Change Admin Password

**IMPORTANT:** Change the default admin password immediately!

1. Login with default credentials
2. Navigate to Profile/Settings
3. Change password to a strong, unique password
4. Store securely (use password manager)

---

---

## Troubleshooting White Screen Issue

If you experience a white screen after running the production setup:

### Quick Fix:
```bash
# Run the state cleanup script
flutter run lib/core/scripts/clear_app_state.dart

# Then restart the app
flutter run
```

### Alternative Solutions:

1. **Uninstall and Reinstall:**
   - Completely uninstall the app from your device
   - Run the app again with `flutter run`
   - Login with admin credentials

2. **Clear App Data (Android):**
   - Settings > Apps > BrainBlot
   - Storage > Clear Data
   - Restart the app

3. **Reset Simulator (iOS):**
   - Device > Erase All Content and Settings
   - Run the app again

### Why This Happens:

The white screen occurs because:
- The app tries to auto-login with old credentials that no longer exist
- Cached user profile doesn't match the new database structure
- Local storage contains references to deleted data

The `clear_app_state.dart` script fixes all of these issues.

---

## Database Structure

See [`lib/core/scripts/PRODUCTION_DATABASE.md`](lib/core/scripts/PRODUCTION_DATABASE.md) for complete documentation of:
- Collection schemas
- Indexes
- Security rules
- Data lifecycle
- Performance optimization

---

## Common Issues

### Issue: "Permission Denied" Error

**Solution:**
- Verify Firestore rules are deployed
- Check user authentication status
- Ensure admin role is set correctly

### Issue: Script Fails During Cleanup

**Solution:**
- Check Firebase quotas
- Verify network connectivity
- Run script again (idempotent)

### Issue: Admin Login Not Working

**Solution:**
Run the fix script:
```bash
flutter run lib/core/scripts/fix_admin_account.dart
```

---

## Development vs Production

### Development Setup
- Use Firebase emulator suite
- Test data can be reset freely
- No cost for operations

### Production Setup
- Use live Firebase project
- Backup before major changes
- Monitor costs and quotas

---

## Maintenance

### Regular Tasks

1. **Weekly**
   - Review error logs
   - Check storage usage
   - Monitor query performance

2. **Monthly**
   - Backup database
   - Review security rules
   - Audit user access

3. **Quarterly**
   - Cleanup old sessions
   - Review subscription plans
   - Update documentation

---

## Emergency Procedures

### Restore from Backup

```bash
firebase firestore:import gs://your-bucket-name/backups/YYYYMMDD
```

### Disable Access (Maintenance Mode)

Update system config:
```dart
await FirebaseFirestore.instance
  .collection('system')
  .doc('config')
  .update({
    'maintenance.isMaintenanceMode': true,
    'maintenance.maintenanceMessage': 'System under maintenance'
  });
```

---

## Support

For issues or questions:
1. Check documentation in `/lib/core/scripts/PRODUCTION_DATABASE.md`
2. Review Firebase Console logs
3. Check application logs
4. Verify environment configuration

---

## Security Checklist

- [ ] Admin password changed from default
- [ ] Firestore rules deployed and tested
- [ ] Backup strategy implemented
- [ ] Monitoring enabled
- [ ] Access logs reviewed
- [ ] API keys secured
- [ ] Environment variables configured
- [ ] SSL/TLS enabled

---

Last Updated: October 30, 2025
Version: 1.0.0