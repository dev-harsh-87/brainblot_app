// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionRequest _$SubscriptionRequestFromJson(Map<String, dynamic> json) =>
    SubscriptionRequest(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userEmail: json['userEmail'] as String,
      userName: json['userName'] as String,
      currentPlan: json['currentPlan'] as String,
      requestedPlan: json['requestedPlan'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String? ?? 'pending',
      adminId: json['adminId'] as String?,
      adminEmail: json['adminEmail'] as String?,
      adminName: json['adminName'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt:
          SubscriptionRequest._timestampFromJsonRequired(json['createdAt']),
      processedAt: SubscriptionRequest._timestampFromJson(json['processedAt']),
    );

Map<String, dynamic> _$SubscriptionRequestToJson(
        SubscriptionRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'userEmail': instance.userEmail,
      'userName': instance.userName,
      'currentPlan': instance.currentPlan,
      'requestedPlan': instance.requestedPlan,
      'reason': instance.reason,
      'status': instance.status,
      'adminId': instance.adminId,
      'adminEmail': instance.adminEmail,
      'adminName': instance.adminName,
      'rejectionReason': instance.rejectionReason,
      'createdAt': SubscriptionRequest._timestampToJson(instance.createdAt),
      'processedAt': SubscriptionRequest._timestampToJson(instance.processedAt),
    };
