# BrainBlot - Quick Setup Guide

## Database Initialization

This guide will help you set up the BrainBlot application with the new subscription-based access control system.

## Prerequisites

- Flutter installed and configured
- Firebase project set up
- Firebase configuration files in place

## Step 1: Initialize Database

Run the database initialization script to set up the default admin and subscription plans:

```bash
dart run lib/core/scripts/init_database.dart
```

This will:
- Clear existing database (if any)
- Create three subscription plans (Free, Player, Institute)
- Create a default Super Admin user
- Create a default Admin user

## Step 2: Default Account Credentials

After initialization, you'll receive two default account credentials:

### Super Admin Account (Full System Access)
**Email:** `superadmin@brainblot.com`
**Password:** `SuperAdmin@123456`
**Role:** Super Admin with full system privileges

### Admin Account (Institute Plan Access)
**Email:** `admin@brainblot.com`
**Password:** `Admin@123456`
**Role:** User with Institute Plan subscription

⚠️ **IMPORTANT:** Change these passwords immediately after first login!

## Step 3: Run the Application

```bash
flutter run
```

## Subscription Plans Overview

### Free Plan ($0)
- Drill module access
- Profile management
- Basic analytics and stats
- Create own drills

### Player Plan ($9.99/month)
- All Free plan features
- Access admin-created drills
- Access admin-created programs
- Create own programs
- Multiple module access
- Advanced analytics
- Multiplayer mode

### Institute Plan ($49.99/month)
- All Player plan features
- Create and manage users
- User analytics dashboard
- Bulk operations
- Team management
- Priority support

## User Roles

### Super Admin
- Full system access
- Manage all users and content
- Manage subscription plans
- System-wide administrative privileges
- Cannot be restricted by subscription plans

### User
- Access based on subscription plan
- Can upgrade/downgrade plans
- Limited to plan-specific features
- Subscription-based permissions

## Testing Access Control

### Test Accounts

Create test users for each subscription level:

```dart
// Free user
Email: free@test.com
Plan: Free

// Player user
Email: player@test.com
Plan: Player

// Institute user
Email: institute@test.com
Plan: Institute
```

### Verify Features

1. **Free User:**
   - ✓ Can create own drills
   - ✓ Can view profile
   - ✓ Can view basic stats
   - ✗ Cannot access admin drills
   - ✗ Cannot create programs

2. **Player User:**
   - ✓ All Free features
   - ✓ Can access admin drills
   - ✓ Can access admin programs
   - ✓ Can create programs
   - ✗ Cannot manage users

3. **Institute User:**
   - ✓ All Player features
   - ✓ Can create and manage users
   - ✓ Can manage teams
   - ✓ Full administrative access

## Database Management

### Complete Database Reset

If you need to completely reset the database:

```dart
final initService = DatabaseInitializationService();
await initService.resetDatabase();
```

### Force Super Admin Creation

If Super Admin is missing but database is initialized:

**Option 1: Use Debug Screen**
```dart
import 'package:brainblot_app/features/debug/admin_debug_screen.dart';

Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const AdminDebugScreen()),
);
```

**Option 2: Call Utility Directly**
```dart
import 'package:brainblot_app/core/utils/create_super_admin.dart';

await CreateSuperAdmin.create();
```

## Troubleshooting

### Issue: Super Admin missing
**Solution:** Use the Debug Screen or `CreateSuperAdmin.create()` utility to create the Super Admin account.

### Issue: Admin user already exists
**Solution:** Either use the existing admin credentials or delete the admin user from Firestore and run the initialization script again.

### Issue: Database initialized but accounts missing
**Solution:** The initialization check now verifies both Super Admin and Admin accounts exist. If either is missing, the initialization will run again automatically on next app start.

### Issue: Permission denied errors
**Solution:** Ensure Firestore Security Rules are properly configured. See `docs/SUBSCRIPTION_SYSTEM.md` for the complete rule set.

### Issue: Subscription features not working
**Solution:** Verify that:
1. User document has subscription object
2. Subscription plan matches one of: free, player, institute
3. Subscription status is 'active'

## Next Steps

1. Log in with the default admin credentials
2. Change the admin password
3. Create test users for each subscription level
4. Verify access control works correctly
5. Configure payment integration for subscription upgrades
6. Customize subscription plans as needed

## Documentation

For detailed documentation, see:
- [`docs/SUBSCRIPTION_SYSTEM.md`](docs/SUBSCRIPTION_SYSTEM.md) - Complete subscription system documentation
- [`lib/core/auth/models/`](lib/core/auth/models/) - User and permission models
- [`lib/core/services/database_initialization_service.dart`](lib/core/services/database_initialization_service.dart) - Database setup service

## Support

For issues or questions:
1. Check the documentation
2. Review the code comments
3. Contact the development team

---

**Version:** 1.0.0  
**Last Updated:** October 29, 2025