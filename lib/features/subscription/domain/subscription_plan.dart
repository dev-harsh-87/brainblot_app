import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'subscription_plan.g.dart';

/// Subscription plan model for managing different tiers of access
@JsonSerializable()
class SubscriptionPlan extends Equatable {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String billingPeriod; // monthly, yearly, lifetime
  final List<String> features;
  final List<String> moduleAccess;
  final int maxDrills;
  final int maxPrograms;
  final bool isActive;
  final int priority;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime? createdAt;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime? updatedAt;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.currency = 'USD',
    this.billingPeriod = 'monthly',
    this.features = const [],
    this.moduleAccess = const [],
    this.maxDrills = -1, // -1 means unlimited
    this.maxPrograms = -1,
    this.isActive = true,
    this.priority = 0,
    this.createdAt,
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

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPlanFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionPlanToJson(this);

  factory SubscriptionPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionPlan.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  SubscriptionPlan copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? currency,
    String? billingPeriod,
    List<String>? features,
    List<String>? moduleAccess,
    int? maxDrills,
    int? maxPrograms,
    bool? isActive,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      features: features ?? this.features,
      moduleAccess: moduleAccess ?? this.moduleAccess,
      maxDrills: maxDrills ?? this.maxDrills,
      maxPrograms: maxPrograms ?? this.maxPrograms,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        price,
        currency,
        billingPeriod,
        features,
        moduleAccess,
        maxDrills,
        maxPrograms,
        isActive,
        priority,
        createdAt,
        updatedAt,
      ];

  /// Predefined plan templates
  static SubscriptionPlan get freePlan => const SubscriptionPlan(
        id: 'free',
        name: 'Free',
        description: 'Basic access to drill management, profile, and analysis',
        price: 0,
        features: [
          'Drill module access',
          'Profile management',
          'Basic analytics and stats',
          'Create own drills',
        ],
        moduleAccess: [
          'drills',
          'profile',
          'stats',
          'analysis',
        ],
        maxDrills: -1, // Unlimited own drills
        maxPrograms: 0, // No programs
        priority: 0,
      );

  static SubscriptionPlan get playerPlan => const SubscriptionPlan(
        id: 'player',
        name: 'Player',
        description: 'Access to admin drills, programs, and multiple modules',
        price: 9.99,
        billingPeriod: 'monthly',
        features: [
          'All Free plan features',
          'Access admin-created drills',
          'Access admin-created programs',
          'Create own programs',
          'Multiple module access',
          'Advanced analytics',
        ],
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
        maxDrills: -1,
        maxPrograms: -1,
        priority: 10,
      );

  static SubscriptionPlan get institutePlan => const SubscriptionPlan(
        id: 'institute',
        name: 'Institute',
        description: 'Full access with user management capabilities',
        price: 49.99,
        billingPeriod: 'monthly',
        features: [
          'All Player plan features',
          'Create and manage users',
          'User analytics dashboard',
          'Bulk operations',
          'Team management',
          'Priority support',
        ],
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
        maxDrills: -1,
        maxPrograms: -1,
        priority: 20,
      );
}