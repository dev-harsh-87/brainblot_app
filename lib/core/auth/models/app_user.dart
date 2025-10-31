import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brainblot_app/core/auth/models/user_role.dart';

part 'app_user.g.dart';

/// Application user model with subscription integration
@JsonSerializable()
class AppUser extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String? profileImageUrl;
  final UserRole role;
  final UserSubscription subscription;
  final UserPreferences preferences;
  final UserStats stats;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime? createdAt;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime? lastActiveAt;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime? updatedAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
    this.role = UserRole.user,
    required this.subscription,
    required this.preferences,
    required this.stats,
    this.createdAt,
    this.lastActiveAt,
    this.updatedAt,
  });

  static DateTime? _timestampFromJson(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  static dynamic _timestampToJson(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  Map<String, dynamic> toJson() => _$AppUserToJson(this);

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'role': role.value,
      'subscription': subscription.toJson(),
      'preferences': preferences.toJson(),
      'stats': stats.toJson(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? profileImageUrl,
    UserRole? role,
    UserSubscription? subscription,
    UserPreferences? preferences,
    UserStats? stats,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      subscription: subscription ?? this.subscription,
      preferences: preferences ?? this.preferences,
      stats: stats ?? this.stats,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool hasModuleAccess(String module) {
    return subscription.hasModuleAccess(module);
  }

  bool canAccessAdminContent() {
    return subscription.plan == 'player' ||
           subscription.plan == 'institute' ||
           role.isAdmin();
  }

  bool canCreatePrograms() {
    return subscription.plan == 'player' ||
           subscription.plan == 'institute' ||
           role.isAdmin();
  }

  bool canManageUsers() {
    return subscription.plan == 'institute' || role.isAdmin();
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        profileImageUrl,
        role,
        subscription,
        preferences,
        stats,
        createdAt,
        lastActiveAt,
        updatedAt,
      ];
}

/// User subscription details
@JsonSerializable()
class UserSubscription extends Equatable {
  final String plan;
  final String status;
  final List<String> moduleAccess;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime? expiresAt;

  const UserSubscription({
    required this.plan,
    this.status = 'active',
    this.moduleAccess = const [],
    this.expiresAt,
  });

  static DateTime? _timestampFromJson(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  static dynamic _timestampToJson(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }

  factory UserSubscription.fromJson(Map<String, dynamic> json) =>
      _$UserSubscriptionFromJson(json);

  Map<String, dynamic> toJson() => _$UserSubscriptionToJson(this);

  factory UserSubscription.free() => const UserSubscription(
        plan: 'free',
        status: 'active',
        moduleAccess: ['drills', 'profile', 'stats', 'analysis'],
      );

  factory UserSubscription.player() => const UserSubscription(
        plan: 'player',
        status: 'active',
        moduleAccess: [
          'drills',
          'profile',
          'stats',
          'analysis',
          'admin_drills',
          'admin_programs',
          'programs',
          'multiplayer',
        ],
      );

  factory UserSubscription.institute() => const UserSubscription(
        plan: 'institute',
        status: 'active',
        moduleAccess: [
          'drills',
          'profile',
          'stats',
          'analysis',
          'admin_drills',
          'admin_programs',
          'programs',
          'multiplayer',
          'user_management',
          'team_management',
          'bulk_operations',
        ],
      );

  bool hasModuleAccess(String module) {
    return moduleAccess.contains(module);
  }

  bool isActive() {
    if (status != 'active') return false;
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  UserSubscription copyWith({
    String? plan,
    String? status,
    List<String>? moduleAccess,
    DateTime? expiresAt,
  }) {
    return UserSubscription(
      plan: plan ?? this.plan,
      status: status ?? this.status,
      moduleAccess: moduleAccess ?? this.moduleAccess,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  List<Object?> get props => [plan, status, moduleAccess, expiresAt];
}

/// User preferences
@JsonSerializable()
class UserPreferences extends Equatable {
  final String theme;
  final bool notifications;
  final bool soundEnabled;
  final String language;
  final String timezone;

  const UserPreferences({
    this.theme = 'system',
    this.notifications = true,
    this.soundEnabled = true,
    this.language = 'en',
    this.timezone = 'UTC',
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$UserPreferencesToJson(this);

  UserPreferences copyWith({
    String? theme,
    bool? notifications,
    bool? soundEnabled,
    String? language,
    String? timezone,
  }) {
    return UserPreferences(
      theme: theme ?? this.theme,
      notifications: notifications ?? this.notifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
    );
  }

  @override
  List<Object?> get props => [theme, notifications, soundEnabled, language, timezone];
}

/// User statistics
@JsonSerializable()
class UserStats extends Equatable {
  final int totalSessions;
  final int totalDrillsCompleted;
  final int totalProgramsCompleted;
  final double averageAccuracy;
  final double averageReactionTime;
  final int streakDays;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime? lastSessionAt;

  const UserStats({
    this.totalSessions = 0,
    this.totalDrillsCompleted = 0,
    this.totalProgramsCompleted = 0,
    this.averageAccuracy = 0.0,
    this.averageReactionTime = 0.0,
    this.streakDays = 0,
    this.lastSessionAt,
  });

  static DateTime? _timestampFromJson(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  static dynamic _timestampToJson(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);

  Map<String, dynamic> toJson() => _$UserStatsToJson(this);

  UserStats copyWith({
    int? totalSessions,
    int? totalDrillsCompleted,
    int? totalProgramsCompleted,
    double? averageAccuracy,
    double? averageReactionTime,
    int? streakDays,
    DateTime? lastSessionAt,
  }) {
    return UserStats(
      totalSessions: totalSessions ?? this.totalSessions,
      totalDrillsCompleted: totalDrillsCompleted ?? this.totalDrillsCompleted,
      totalProgramsCompleted: totalProgramsCompleted ?? this.totalProgramsCompleted,
      averageAccuracy: averageAccuracy ?? this.averageAccuracy,
      averageReactionTime: averageReactionTime ?? this.averageReactionTime,
      streakDays: streakDays ?? this.streakDays,
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
    );
  }

  @override
  List<Object?> get props => [
        totalSessions,
        totalDrillsCompleted,
        totalProgramsCompleted,
        averageAccuracy,
        averageReactionTime,
        streakDays,
        lastSessionAt,
      ];
}