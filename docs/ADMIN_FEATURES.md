# Admin Features Documentation

This document outlines all the admin features that have been implemented and are now fully functional in the BrainBlot app.

## Overview

The admin control panel provides comprehensive management capabilities for platform administrators. All features are protected by admin authentication guards and require admin role access.

## Admin Dashboard

**Location:** `lib/features/admin/enhanced_admin_dashboard_screen.dart`

### Features:
- **Real-time Statistics**
  - Total Users count
  - Active Users (last 7 days)
  - Administrator count
  - Active subscription plans count

- **Quick Actions**
  - Add User (navigates to User Management)
  - Manage Plans (navigates to Subscription Management)
  - View Analytics (navigates to Analytics)
  - Permissions (coming soon)

- **Management Tools Grid**
  - User Management card
  - Subscriptions card
  - Permissions card
  - Analytics card

- **Recent Activity**
  - Shows last 5 user registrations
  - Displays user name and time ago

### Access:
Navigate to `/admin` route (only accessible to users with admin role)

---

## User Management Screen

**Location:** `lib/features/admin/ui/user_management_screen.dart`

### Features:

#### User List
- View all users with profile cards
- Search users by name or email
- Filter users by role (Admin/User)
- Real-time updates via Firestore streams

#### User Information Display
- User avatar with initial
- Display name and email
- Role badge (color-coded)
- Subscription plan badge
- Admin-created indicator (if applicable)

#### User Actions (via menu)
1. **Edit User**
   - Update display name
   - Save changes to Firestore

2. **Change Role**
   - Switch between Admin and User roles
   - Updates role in Firestore

3. **Manage Subscription**
   - View current subscription plan
   - (Full management coming soon)

4. **Delete User**
   - Confirmation dialog
   - Removes user from Firestore
   - Attempts to clean up Firebase Auth

#### Create New User
- Add user via floating action button
- Fields:
  - Display Name (required)
  - Email (required, validated)
  - Password (required, min 6 characters)
  - Role selection (Admin/User)
- Creates Firebase Auth account
- Creates Firestore user document
- Tracks who created the user (admin metadata)

#### User Details Dialog
- Full user information
- Email, role, subscription
- Creation date
- Created by (admin) information

### Access:
- From Admin Dashboard → "Add User" quick action
- From Admin Dashboard → "User Management" card
- Direct navigation from code

---

## Subscription Management Screen

**Location:** `lib/features/admin/ui/subscription_management_screen.dart`

### Features:

#### Subscription Overview
- Visual statistics for each plan:
  - Free Plan user count
  - Player Plan user count
  - Institute Plan user count
- Color-coded by plan type

#### Subscription Plans List
- View all subscription plans
- Real-time plan data from Firestore
- Plan cards showing:
  - Plan name and description
  - Active/Inactive status
  - Price per month
  - Number of features
  - Number of accessible modules
  - Color-coded by plan type

#### Plan Actions (via menu)
1. **Edit Plan**
   - (Coming soon - placeholder)

2. **Toggle Status**
   - Activate/Deactivate plan
   - Updates immediately in Firestore

3. **Delete Plan**
   - Confirmation dialog
   - Removes plan from Firestore

#### Plan Details Dialog
- Complete plan information:
  - Description
  - Price
  - Billing cycle
  - Status
  - Full features list
  - Module access chips

#### Create New Plan
- Floating action button
- (Coming soon - placeholder)

### Access:
- From Admin Dashboard → "Manage Plans" quick action
- From Admin Dashboard → "Subscriptions" card

---

## Analytics Screen

**Location:** `lib/features/admin/ui/analytics_screen.dart`

### Features:

#### User Analytics Section
- **Total Users** - All registered users
- **Active Users (7 days)** - Users active in last week  
- **Administrators** - Count of admin users
- **New This Month** - New registrations this month

#### Subscription Analytics Section
- **Free Plan** - Users on free plan
- **Player Plan** - Users on player plan
- **Institute Plan** - Users on institute plan
- **Estimated Revenue** - Monthly revenue calculation
  - Player: $9.99/month
  - Institute: $29.99/month

#### Recent Activity Section
- Last 5 user registrations
- Shows:
  - Activity type (New user registered)
  - User display name
  - Time ago (Just now, Xm ago, Xh ago, etc.)

### Access:
- From Admin Dashboard → "View Analytics" quick action
- From Admin Dashboard → "Analytics" card

---

## Admin Section on Home Screen

**Location:** `lib/features/home/ui/admin_section_enhanced.dart`

### Features:
- Prominent admin controls section
- Large admin dashboard card
- Quick action cards for:
  - Users management
  - Analytics
  - Settings
- All navigate to `/admin` route
- Only visible to users with admin role

---

## Authentication & Security

### Admin Guard
**Location:** `lib/core/auth/guards/admin_guard.dart`

- Protects all admin routes
- Validates user role before rendering
- Shows unauthorized message for non-admins
- Redirects to login if not authenticated

### Permission Service
**Location:** `lib/core/auth/services/permission_service.dart`

- Checks if user is admin
- Validates permissions for sensitive operations
- Role-based access control

### User Management Service
**Location:** `lib/core/auth/services/user_management_service.dart`

- Creates users (with admin tracking)
- Deletes users (with cleanup)
- Updates user information
- Handles Firebase Auth and Firestore operations

---

## Default Admin Account

### Credentials:
- **Email:** `admin@brianblot.com`
- **Password:** `Admin@123456`

### Setup:
- Created automatically during database initialization
- Has full Institute plan access
- Has admin role with all permissions

⚠️ **Important:** Change the default password after first login!

---

## Color Coding

### Role Colors:
- **Admin:** Red (`#DC2626`)
- **User:** Neutral/Gray

### Subscription Plan Colors:
- **Free:** Gray (`#6B7280`)
- **Player:** Blue (`#3B82F6`)
- **Institute:** Purple (`#7C3AED`)

---

## Navigation Structure

```
/admin (Admin Dashboard)
├── User Management Screen
│   ├── Create User Dialog
│   ├── Edit User Dialog
│   ├── Change Role Dialog
│   ├── User Details Dialog
│   └── Delete Confirmation
├── Subscription Management Screen
│   ├── Plan Details Dialog
│   ├── Toggle Plan Status
│   └── Delete Plan Confirmation
└── Analytics Screen
    ├── User Analytics
    ├── Subscription Analytics
    └── Recent Activity
```

---

## Future Enhancements

### Planned Features:
1. **Permission Management Screen**
   - Granular permission controls
   - Custom permission sets
   - Role-based permissions

2. **Enhanced Plan Creation**
   - Full form for creating subscription plans
   - Price customization
   - Feature builder
   - Module access selector

3. **Advanced Analytics**
   - Revenue charts
   - User growth trends
   - Subscription conversion rates
   - Retention metrics

4. **Bulk Operations**
   - Bulk user imports
   - Bulk role changes
   - Bulk subscription updates

5. **Notification System**
   - Admin notifications
   - User notifications
   - System alerts

6. **Settings Panel**
   - Platform configuration
   - Email templates
   - Feature toggles
   - System maintenance

---

## Technical Details

### Dependencies:
- `cloud_firestore` - Real-time database
- `firebase_auth` - Authentication
- `get_it` - Dependency injection
- `go_router` - Routing
- Material Design - UI components

### State Management:
- StreamBuilder for real-time updates
- FutureBuilder for async data
- StatefulWidget for local state

### Error Handling:
- Try-catch blocks for all operations
- SnackBar notifications for user feedback
- Graceful fallbacks for missing data

---

## Support

For issues or questions regarding admin features:
1. Check the logs for error messages
2. Verify admin role assignment
3. Ensure Firebase rules allow admin operations
4. Contact development team for assistance

---

**Last Updated:** March 11, 2025
**Version:** 1.0