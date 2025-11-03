import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:brainblot_app/features/subscription/domain/subscription_request.dart";
import "package:brainblot_app/core/di/injection.dart";
import "package:brainblot_app/core/auth/services/session_management_service.dart";

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
        throw Exception("No authenticated user found");
      }

      // Get current user data
      final userDoc = await _firestore.collection("users").doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception("User document not found");
      }

      final userData = userDoc.data()!;
      final String currentPlan = (userData["subscription"]?["plan"] as String?) ?? "free";

      // Create request
      final request = SubscriptionRequest(
        id: "", // Will be set by Firestore
        userId: currentUser.uid,
        userEmail: currentUser.email ?? "",
        userName: (userData["displayName"] as String?) ?? "Unknown",
        currentPlan: currentPlan,
        requestedPlan: requestedPlan,
        reason: reason,
        status: "pending",
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection("subscription_requests")
          .add(request.toFirestore());

      print("✅ Subscription request created: ${docRef.id}");
      return docRef.id;
    } catch (e) {
      print("❌ Failed to create subscription request: $e");
      rethrow;
    }
  }

  /// Get all pending requests (for admin)
  Stream<List<SubscriptionRequest>> getPendingRequests() {
    return _firestore
        .collection("subscription_requests")
        .where("status", isEqualTo: "pending")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SubscriptionRequest.fromFirestore(doc))
          .toList();
    });
  }

  /// Get all requests (for admin)
  Stream<List<SubscriptionRequest>> getAllRequests() {
    return _firestore
        .collection("subscription_requests")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SubscriptionRequest.fromFirestore(doc))
          .toList();
    });
  }

  /// Get requests for current user
  Stream<List<SubscriptionRequest>> getUserRequests() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection("subscription_requests")
        .where("userId", isEqualTo: currentUser.uid)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SubscriptionRequest.fromFirestore(doc))
          .toList();
    });
  }

  /// Approve a subscription request
  Future<void> approveRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception("No authenticated admin user found");
      }

      // Get admin data
      final adminDoc = await _firestore.collection("users").doc(currentUser.uid).get();
      final adminData = adminDoc.data();

      // Get request data
      final requestDoc = await _firestore
          .collection("subscription_requests")
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception("Request not found");
      }

      final request = SubscriptionRequest.fromFirestore(requestDoc);

      // Define module access based on plan
      List<String> moduleAccess;
      switch (request.requestedPlan) {
        case "free":
          moduleAccess = ["drills", "profile", "stats", "analysis"];
          break;
        case "player":
          moduleAccess = [
            "drills",
            "profile",
            "stats",
            "analysis",
            "admin_drills",
            "admin_programs",
            "programs",
            "multiplayer",
          ];
          break;
        case "institute":
          moduleAccess = [
            "drills",
            "profile",
            "stats",
            "analysis",
            "admin_drills",
            "admin_programs",
            "programs",
            "multiplayer",
            "user_management",
            "team_management",
            "bulk_operations",
          ];
          break;
        default:
          moduleAccess = ["drills", "profile", "stats", "analysis"];
      }

      // Update user's subscription in Firestore
      await _firestore.collection("users").doc(request.userId).update({
        "subscription": {
          "plan": request.requestedPlan,
          "status": "active",
          "moduleAccess": moduleAccess,
        },
        "updatedAt": FieldValue.serverTimestamp(),
      });

      // Update request status
      await _firestore.collection("subscription_requests").doc(requestId).update({
        "status": "approved",
        "adminId": currentUser.uid,
        "adminEmail": currentUser.email,
        "adminName": adminData?["displayName"] ?? "Admin",
        "processedAt": FieldValue.serverTimestamp(),
      });

      print("✅ Subscription request approved and user plan upgraded");
      
      // If the upgraded user is currently logged in, refresh their session
      // The SessionManagementService listens to user document changes,
      // so it will automatically pick up the subscription update via the
      // Firestore snapshot listener. No manual refresh needed.
      // The user document snapshot listener in SessionManagementService
      // at line 62-92 will automatically detect the change and update
      // the session, triggering permission cache clearing at line 74.
      print("📡 User session will be automatically refreshed via Firestore listener");
    } catch (e) {
      print("❌ Failed to approve request: $e");
      rethrow;
    }
  }

  /// Reject a subscription request
  Future<void> rejectRequest(String requestId, String rejectionReason) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception("No authenticated admin user found");
      }

      // Get admin data
      final adminDoc = await _firestore.collection("users").doc(currentUser.uid).get();
      final adminData = adminDoc.data();

      // Update request status
      await _firestore.collection("subscription_requests").doc(requestId).update({
        "status": "rejected",
        "rejectionReason": rejectionReason,
        "adminId": currentUser.uid,
        "adminEmail": currentUser.email,
        "adminName": adminData?["displayName"] ?? "Admin",
        "processedAt": FieldValue.serverTimestamp(),
      });

      print("✅ Subscription request rejected");
    } catch (e) {
      print("❌ Failed to reject request: $e");
      rethrow;
    }
  }

  /// Get count of pending requests
  Future<int> getPendingRequestCount() async {
    try {
      final snapshot = await _firestore
          .collection("subscription_requests")
          .where("status", isEqualTo: "pending")
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print("❌ Failed to get pending request count: $e");
      return 0;
    }
  }

  /// Stream of pending request count
  Stream<int> watchPendingRequestCount() {
    return _firestore
        .collection("subscription_requests")
        .where("status", isEqualTo: "pending")
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}