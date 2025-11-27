import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spark_app/features/subscription/domain/subscription_request.dart';
import 'package:spark_app/core/auth/services/permission_manager.dart';

/// Service for managing subscription upgrade requests
class SubscriptionRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new subscription upgrade request
  Future<String> createUpgradeRequest({
    required String requestedPlan,
    required String reason,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Get current user data
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

      final userData = userDoc.data()!;
      final String currentPlan = (userData['subscription']?['plan'] as String?) ?? 'free';

      // Create request
      final request = SubscriptionRequest(
        id: '', // Will be set by Firestore
        userId: currentUser.uid,
        userEmail: currentUser.email ?? '',
        userName: (userData['displayName'] as String?) ?? 'Unknown',
        currentPlan: currentPlan,
        requestedPlan: requestedPlan,
        reason: reason,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('subscription_requests')
          .add(request.toFirestore());

      print('✅ Subscription request created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Failed to create subscription request: $e');
      rethrow;
    }
  }

  /// Get all pending requests (for admin)
  Stream<List<SubscriptionRequest>> getPendingRequests() {
    return _firestore
        .collection('subscription_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => SubscriptionRequest.fromFirestore(doc))
          .toList();
      
      // Sort in memory to avoid index requirement
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  /// Get all requests (for admin)
  Stream<List<SubscriptionRequest>> getAllRequests() {
    return _firestore
        .collection('subscription_requests')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => SubscriptionRequest.fromFirestore(doc))
          .toList();
      
      // Sort in memory to avoid index requirement
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  /// Get requests for current user
  Stream<List<SubscriptionRequest>> getUserRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('subscription_requests')
        .where('userId', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => SubscriptionRequest.fromFirestore(doc))
          .toList();
      
      // Sort in memory to avoid index requirement
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  /// Approve a subscription request
  Future<void> approveRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated admin user found');
      }

      // Get admin data
      final adminDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final adminData = adminDoc.data();

      // Get request data
      final requestDoc = await _firestore
          .collection('subscription_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final request = SubscriptionRequest.fromFirestore(requestDoc);

      // Get the actual subscription plan from the repository to ensure consistency
      final planDoc = await _firestore
          .collection('subscription_plans')
          .doc(request.requestedPlan)
          .get();

      // ONLY use plans from database - no hardcoded fallbacks
      if (!planDoc.exists) {
        throw Exception("Subscription plan '${request.requestedPlan}' not found in database. Please ensure the plan is created by an admin first.");
      }

      final planData = planDoc.data()!;
      
      // Get module access from plan
      final moduleAccessData = planData['moduleAccess'];
      final moduleAccess = moduleAccessData is List
          ? List<String>.from(moduleAccessData)
          : <String>[];
      
      print("✅ Using plan-defined module access for '${request.requestedPlan}': $moduleAccess");

      // Calculate expiration date based on plan billing period
      final billingPeriod = planData['billingPeriod'] as String? ?? 'monthly';
      final now = DateTime.now();
      
      DateTime? expiresAt;
      switch (billingPeriod) {
        case 'monthly':
          expiresAt = now.add(const Duration(days: 30));
          break;
        case 'yearly':
          expiresAt = now.add(const Duration(days: 365));
          break;
        case 'lifetime':
          expiresAt = null; // No expiration for lifetime plans
          break;
        default:
          expiresAt = now.add(const Duration(days: 30)); // Default to monthly
      }

      // Update user's subscription in Firestore
      // Create complete subscription object to ensure all fields are properly set
      final subscriptionData = {
        'plan': request.requestedPlan,
        'status': 'active',
        'moduleAccess': moduleAccess,
      };

      // Only set expiration if it's not null (lifetime plans don't expire)
      if (expiresAt != null) {
        subscriptionData['expiresAt'] = Timestamp.fromDate(expiresAt);
      }

      final updateData = {
        'subscription': subscriptionData, // Update entire subscription object
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('🔄 Updating user subscription with data: $subscriptionData');
      await _firestore.collection('users').doc(request.userId).update(updateData);
      print('✅ User subscription updated successfully');

      // Update request status
      await _firestore.collection('subscription_requests').doc(requestId).update({
        'status': 'approved',
        'adminId': currentUser.uid,
        'adminEmail': currentUser.email,
        'adminName': adminData?['displayName'] ?? 'Admin',
        'processedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Subscription request approved and user plan upgraded');
      print("📅 Plan expires at: ${expiresAt?.toString() ?? 'Never (lifetime)'}");
      
      // Force permission refresh for all users with this plan
      // This ensures immediate UI updates across all active sessions
      print('🔄 Forcing permission refresh for upgraded user...');
      
      // Wait a moment for Firestore to propagate the changes
      await Future.delayed(const Duration(milliseconds: 500));
      
      // The PermissionManager listens to user document changes via the
      // ComprehensivePermissionService.watchPermissionChanges() stream
      // This will automatically refresh permissions when the user document is updated
      print('📡 User permissions will be automatically refreshed via Firestore listener');
      
      // Also manually refresh permissions for the current user if they are the one being upgraded
      if (currentUser.uid == request.userId) {
        try {
          print('🔄 Manually refreshing current user permissions...');
          await PermissionManager.instance.refreshPermissions();
          print('✅ Current user permissions manually refreshed');
        } catch (e) {
          print('⚠️ Failed to manually refresh current user permissions: $e');
          // Don't throw - the automatic refresh via listener should still work
        }
      }
      
      // Additional step: Force a permission manager refresh for any active sessions
      // by triggering a notification to all listeners
      try {
        print('📢 Broadcasting permission change notification...');
        // This will trigger UI updates across the app
        PermissionManager.instance.notifyListeners();
        print('✅ Permission change notification broadcasted');
      } catch (e) {
        print('⚠️ Failed to broadcast permission change: $e');
      }
    } catch (e) {
      print('❌ Failed to approve request: $e');
      rethrow;
    }
  }

  /// Reject a subscription request
  Future<void> rejectRequest(String requestId, String rejectionReason) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated admin user found');
      }

      // Get admin data
      final adminDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final adminData = adminDoc.data();

      // Update request status
      await _firestore.collection('subscription_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'adminId': currentUser.uid,
        'adminEmail': currentUser.email,
        'adminName': adminData?['displayName'] ?? 'Admin',
        'processedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Subscription request rejected');
    } catch (e) {
      print('❌ Failed to reject request: $e');
      rethrow;
    }
  }

  /// Get count of pending requests
  Future<int> getPendingRequestCount() async {
    try {
      final snapshot = await _firestore
          .collection('subscription_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Failed to get pending request count: $e');
      return 0;
    }
  }

  /// Stream of pending request count
  Stream<int> watchPendingRequestCount() {
    return _firestore
        .collection('subscription_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}