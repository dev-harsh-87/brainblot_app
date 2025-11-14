class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final String role; // 'admin', 'coach', or 'user'
  final bool isAdmin; // Convenience getter for admin status

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    required this.lastActiveAt,
    this.role = 'user',
  }) : isAdmin = role == 'admin';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Handle Firestore Timestamps or String dates
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      // Handle Firestore Timestamp
      try {
        // Access toDate() method dynamically for Timestamp objects
        return (value as dynamic).toDate() as DateTime;
      } catch (e) {
        return DateTime.now();
      }
    }

    return UserProfile(
      id: json['id'] as String? ?? json['userId'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? json['email'].toString().split('@').first,
      photoUrl: json['photoUrl'] as String? ?? json['profileImageUrl'] as String?,
      createdAt: parseDate(json['createdAt']),
      lastActiveAt: parseDate(json['lastActiveAt']),
      role: json['role'] as String? ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'createdAt': createdAt.toIso8601String(),
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'role': role,
    'is_admin': isAdmin,
  };

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    String? role,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      role: role ?? this.role,
    );
  }
}

class ShareInvitation {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String itemType; // 'drill' or 'program'
  final String itemId;
  final String itemName;
  final ShareInvitationStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  
  const ShareInvitation({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory ShareInvitation.fromJson(Map<String, dynamic> json) => ShareInvitation(
    id: json['id'] as String,
    fromUserId: json['fromUserId'] as String,
    toUserId: json['toUserId'] as String,
    itemType: json['itemType'] as String,
    itemId: json['itemId'] as String,
    itemName: json['itemName'] as String,
    status: ShareInvitationStatus.values.firstWhere(
      (e) => e.name == json['status'],
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    respondedAt: json['respondedAt'] != null 
        ? DateTime.parse(json['respondedAt'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'itemType': itemType,
    'itemId': itemId,
    'itemName': itemName,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
  };
}

enum ShareInvitationStatus {
  pending,
  accepted,
  declined,
  cancelled,
}
