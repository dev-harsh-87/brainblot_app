# Subscription Request System - Implementation Guide

## Already Completed ✅

1. **Model Created**: `lib/features/subscription/domain/subscription_request.dart`
2. **Service Created**: `lib/features/subscription/services/subscription_request_service.dart`
3. **Database Schema**: Firestore collection `subscription_requests`

## What Needs to be Done

### Step 1: Create Plan Requests Management Screen

Create file: `lib/features/admin/ui/plan_requests_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:brainblot_app/features/subscription/domain/subscription_request.dart';
import 'package:brainblot_app/features/subscription/services/subscription_request_service.dart';
import 'package:brainblot_app/core/theme/app_theme.dart';

class PlanRequestsScreen extends StatefulWidget {
  const PlanRequestsScreen({super.key});

  @override
  State<PlanRequestsScreen> createState() => _PlanRequestsScreenState();
}

class _PlanRequestsScreenState extends State<PlanRequestsScreen> {
  final _requestService = SubscriptionRequestService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Plan Requests"),
        elevation: 0,
      ),
      body: StreamBuilder<List<SubscriptionRequest>>(
        stream: _requestService.getAllRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No plan requests yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _buildRequestCard(requests[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(SubscriptionRequest request) {
    Color statusColor;
    IconData statusIcon;
    
    switch (request.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Text(
                    request.userName[0].toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        request.userEmail,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        request.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildPlanBadge(request.currentPlan),
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 4),
                      _buildPlanBadge(request.requestedPlan, isTarget: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reason: ${request.reason}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ],
              ),
            ),
            if (request.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveRequest(request),
                      icon: const Icon(Icons.check),
                      label: const Text("Approve"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectRequest(request),
                      icon: const Icon(Icons.close),
                      label: const Text("Reject"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (request.isRejected && request.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rejection Reason: ${request.rejectionReason}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanBadge(String plan, {bool isTarget = false}) {
    Color color;
    switch (plan) {
      case 'free':
        color = Colors.grey;
        break;
      case 'player':
        color = Colors.blue;
        break;
      case 'institute':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTarget ? color : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        plan.toUpperCase(),
        style: TextStyle(
          color: isTarget ? Colors.white : color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _approveRequest(SubscriptionRequest request) async {
    try {
      await _requestService.approveRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Request approved - ${request.userName}'s plan upgraded to ${request.requestedPlan}"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to approve: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(SubscriptionRequest request) async {
    final reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Request"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Explain why this request is rejected...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (result == true && reasonController.text.isNotEmpty) {
      try {
        await _requestService.rejectRequest(request.id, reasonController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Request rejected"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to reject: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
```

### Step 2: Update Admin Dashboard

In `lib/features/admin/enhanced_admin_dashboard_screen.dart`:

**Find and REPLACE the "Permissions" card** (around line 290-300) with:

```dart
_buildAdminCard(
  context,
  "Plan Requests",
  Icons.request_page,
  Colors.purple,
  () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlanRequestsScreen(),
      ),
    );
  },
),
```

**And REPLACE the "Permissions" quick action** (around line 396-403) with:

```dart
_buildQuickAction(
  context,
  title: "Plan Requests",
  description: "Review subscription upgrade requests",
  icon: Icons.request_page,
  color: Colors.purple,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PlanRequestsScreen(),
      ),
    );
  },
),
```

**Add the import** at the top:
```dart
import 'package:brainblot_app/features/admin/ui/plan_requests_screen.dart';
```

### Step 3: Add Request Button for Users

In the subscription screen where users view their plan, add a "Request Upgrade" button that calls:

```dart
await SubscriptionRequestService().createUpgradeRequest(
  requestedPlan: selectedPlan, // "player" or "institute"
  reason: userReason, // from text field
);
```

## Testing

1. Login as regular user
2. Request plan upgrade
3. Login as admin
4. Go to Admin Dashboard → Plan Requests
5. Approve or reject the request
6. User's plan should auto-upgrade on approval

## Database Security Rules

Add to Firestore rules:

```
match /subscription_requests/{requestId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
  allow update: if hasAdminRole();
  allow delete: if hasAdminRole();
}
```

All the backend logic is complete and working! Just need to add these UI screens.