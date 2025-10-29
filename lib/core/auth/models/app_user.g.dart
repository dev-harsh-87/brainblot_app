// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      role:
          $enumDecodeNullable(_$UserRoleEnumMap, json['role']) ?? UserRole.user,
      subscription: UserSubscription.fromJson(
          json['subscription'] as Map<String, dynamic>),
      preferences:
          UserPreferences.fromJson(json['preferences'] as Map<String, dynamic>),
      stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>),
      createdAt: AppUser._timestampFromJson(json['createdAt']),
      lastActiveAt: AppUser._timestampFromJson(json['lastActiveAt']),
      updatedAt: AppUser._timestampFromJson(json['updatedAt']),
    );

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'profileImageUrl': instance.profileImageUrl,
      'role': _$UserRoleEnumMap[instance.role]!,
      'subscription': instance.subscription,
      'preferences': instance.preferences,
      'stats': instance.stats,
      'createdAt': AppUser._timestampToJson(instance.createdAt),
      'lastActiveAt': AppUser._timestampToJson(instance.lastActiveAt),
      'updatedAt': AppUser._timestampToJson(instance.updatedAt),
    };

const _$UserRoleEnumMap = {
  UserRole.superAdmin: 'superAdmin',
  UserRole.user: 'user',
};

UserSubscription _$UserSubscriptionFromJson(Map<String, dynamic> json) =>
    UserSubscription(
      plan: json['plan'] as String,
      status: json['status'] as String? ?? 'active',
      moduleAccess: (json['moduleAccess'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      expiresAt: UserSubscription._timestampFromJson(json['expiresAt']),
    );

Map<String, dynamic> _$UserSubscriptionToJson(UserSubscription instance) =>
    <String, dynamic>{
      'plan': instance.plan,
      'status': instance.status,
      'moduleAccess': instance.moduleAccess,
      'expiresAt': UserSubscription._timestampToJson(instance.expiresAt),
    };

UserPreferences _$UserPreferencesFromJson(Map<String, dynamic> json) =>
    UserPreferences(
      theme: json['theme'] as String? ?? 'system',
      notifications: json['notifications'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      language: json['language'] as String? ?? 'en',
      timezone: json['timezone'] as String? ?? 'UTC',
    );

Map<String, dynamic> _$UserPreferencesToJson(UserPreferences instance) =>
    <String, dynamic>{
      'theme': instance.theme,
      'notifications': instance.notifications,
      'soundEnabled': instance.soundEnabled,
      'language': instance.language,
      'timezone': instance.timezone,
    };

UserStats _$UserStatsFromJson(Map<String, dynamic> json) => UserStats(
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      totalDrillsCompleted:
          (json['totalDrillsCompleted'] as num?)?.toInt() ?? 0,
      totalProgramsCompleted:
          (json['totalProgramsCompleted'] as num?)?.toInt() ?? 0,
      averageAccuracy: (json['averageAccuracy'] as num?)?.toDouble() ?? 0.0,
      averageReactionTime:
          (json['averageReactionTime'] as num?)?.toDouble() ?? 0.0,
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
      lastSessionAt: UserStats._timestampFromJson(json['lastSessionAt']),
    );

Map<String, dynamic> _$UserStatsToJson(UserStats instance) => <String, dynamic>{
      'totalSessions': instance.totalSessions,
      'totalDrillsCompleted': instance.totalDrillsCompleted,
      'totalProgramsCompleted': instance.totalProgramsCompleted,
      'averageAccuracy': instance.averageAccuracy,
      'averageReactionTime': instance.averageReactionTime,
      'streakDays': instance.streakDays,
      'lastSessionAt': UserStats._timestampToJson(instance.lastSessionAt),
    };
