# Subscription Request System Flow

## Overview
This document describes how the subscription request and upgrade system works, including automatic session refresh after plan upgrades.

## System Architecture

### 1. User Requests Upgrade
**File**: `lib/features/subscription/ui/subscription_screen.dart`
- User views available plans and their current plan
- User can see their past subscription requests with statuses (pending/approved/rejected)
- User clicks "Request [Plan Name]" button
- Dialog opens requesting reason for upgrade
- `SubscriptionRequestService().createUpgradeRequest()` is called

### 2. Request Creation
**File**: `lib/features/subscription/services/subscription_request_service.dart`
- Creates a new document in `subscription_requests` collection
- Status is set to "pending"
- Request includes: userId, userEmail, userName, currentPlan, requestedPlan, reason

### 3. Admin Reviews Request
**File**: `lib/features/admin/enhanced_admin_dashboard_screen.dart`
- Admin sees list of pending requests
- Admin can approve or reject requests
- On approval: `SubscriptionRequestService().approveRequest()` is called
- On rejection: `SubscriptionRequestService().rejectRequest()` is called

### 4. Plan Upgrade (Approval Flow)
**File**: `lib/features/subscription/services/subscription_request_service.dart` (lines 162-186)

When admin approves:
1. **Firestore Update**: User document is updated with new subscription plan and moduleAccess
   ```dart
   await _firestore.collection("users").doc(request.userId).update({
     "subscription": {
       "plan": request.requestedPlan,
       "status": "active",
       "moduleAccess": moduleAccess,
     },
     "updatedAt": FieldValue.serverTimestamp(),
   });
   ```

2. **Request Status Update**: Request document is marked as "approved"

3. **Automatic Session Refresh**: This happens automatically via Firestore listeners

### 5. Session Refresh (Automatic)
**File**: `lib/core/auth/services/session_management_service.dart` (lines 62-92)

The SessionManagementService has a **real-time listener** on the user document:

```dart
_userSubscription = _firestore
    .collection("users")
    .doc(firebaseUser.uid)
    .snapshots()
    .listen((doc) {
  if (doc.exists && doc.data() != null) {
    _currentSession = AppUser.fromFirestore(doc);
    _notifySessionListeners(_currentSession);
    
    // Clear permission cache when session updates
    if (_permissionService != null) {
      _permissionService!.clearCache();
    }
  }
});
```

**Key Points**:
- Listens to ALL changes to the user document
- When subscription is updated, the listener fires automatically
- Session is refreshed with new subscription data
- Permission cache is cleared
- Session listeners are notified

### 6. Feature Access Check
**File**: `lib/core/auth/services/permission_service.dart` (lines 144-165)

When checking module access:

```dart
Future<bool> hasModuleAccess(String module) async {
  final user = _auth.currentUser;
  if (user == null) return false;

  // Fetches FRESH data from Firestore every time
  final doc = await _firestore.collection("users").doc(user.uid).get();
  final subscription = doc.data()!['subscription'];
  final moduleAccess = subscription['moduleAccess'];
  
  return moduleAccess.contains(module);
}
```

**Key Points**:
- Always fetches fresh data from Firestore
- No caching on module access checks
- Ensures user gets immediate access after upgrade

### 7. Route Guards
**File**: `lib/core/auth/guards/role_guard.dart`

Uses `FutureBuilder` to check access:
- Calls `permissionService.hasModuleAccess(moduleAccess!)`
- Gets fresh data from Firestore
- Shows access denied or grants access based on current permissions

## Complete Flow Example

### User Perspective:
1. User on "Free" plan wants to access "programs" module
2. Route guard blocks access (moduleAccess doesn't include "programs")
3. User goes to subscription screen
4. User sees their current plan and available plans
5. User requests upgrade to "Player" plan with reason
6. Request submitted - user sees it in "pending" status

### Admin Perspective:
7. Admin logs in and sees pending request in dashboard
8. Admin reviews request details
9. Admin approves request

### System Automatic Actions:
10. Firestore user document updated with new plan
11. SessionManagementService listener detects change
12. Session refreshed with new subscription
13. Permission cache cleared

### User Access:
14. User navigates to programs screen
15. Route guard checks access
16. `hasModuleAccess("programs")` fetches fresh data from Firestore
17. User now has "programs" in moduleAccess
18. Access granted! ✅

## Why It Works

1. **Real-time Firestore Listeners**: The session service listens to user document changes in real-time
2. **No Caching on Access Checks**: Module access checks always fetch fresh data
3. **Automatic Cache Clearing**: When session updates, permission cache is cleared
4. **FutureBuilder Re-evaluation**: Route guards use FutureBuilder which re-evaluates when navigating

## Troubleshooting

If a user doesn't get access after upgrade:

1. **Check Firestore**: Verify user document has updated subscription
2. **Check Session**: User might need to refresh the page/app
3. **Check Module Access**: Verify the plan includes the required module
4. **Check Route Guards**: Ensure route guards are checking the correct module name

## Module Access by Plan

### Free Plan
- drills
- profile
- stats  
- analysis

### Player Plan
- drills
- profile
- stats
- analysis
- admin_drills
- admin_programs
- programs
- multiplayer

### Institute Plan
- All modules including:
  - user_management
  - team_management
  - bulk_operations

## Files Modified in This Fix

1. `lib/features/subscription/ui/subscription_screen.dart`
   - Added StreamBuilder to display user's subscription requests
   - Shows request status (pending/approved/rejected)
   - Shows rejection reason if rejected
   - Shows admin who processed the request

2. `lib/features/subscription/services/subscription_request_service.dart`
   - Added documentation about automatic session refresh
   - Clarified that no manual refresh is needed

3. `lib/core/auth/guards/role_guard.dart`
   - Cleaned up syntax issues
   - Guards already fetch fresh data on each check

## Testing the Flow

1. Create test user with Free plan
2. Try to access a premium feature (should be blocked)
3. Submit upgrade request from subscription screen
4. Admin approves request
5. User should immediately see their request status change to "approved"
6. User can now access the premium feature without reloading