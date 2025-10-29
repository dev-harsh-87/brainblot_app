// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionPlan _$SubscriptionPlanFromJson(Map<String, dynamic> json) =>
    SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      billingPeriod: json['billingPeriod'] as String? ?? 'monthly',
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      moduleAccess: (json['moduleAccess'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      maxDrills: (json['maxDrills'] as num?)?.toInt() ?? -1,
      maxPrograms: (json['maxPrograms'] as num?)?.toInt() ?? -1,
      isActive: json['isActive'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      createdAt: SubscriptionPlan._timestampFromJson(json['createdAt']),
      updatedAt: SubscriptionPlan._timestampFromJson(json['updatedAt']),
    );

Map<String, dynamic> _$SubscriptionPlanToJson(SubscriptionPlan instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'currency': instance.currency,
      'billingPeriod': instance.billingPeriod,
      'features': instance.features,
      'moduleAccess': instance.moduleAccess,
      'maxDrills': instance.maxDrills,
      'maxPrograms': instance.maxPrograms,
      'isActive': instance.isActive,
      'priority': instance.priority,
      'createdAt': SubscriptionPlan._timestampToJson(instance.createdAt),
      'updatedAt': SubscriptionPlan._timestampToJson(instance.updatedAt),
    };
