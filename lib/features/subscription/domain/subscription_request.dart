import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'subscription_request.g.dart';

/// Subscription upgrade request model
@JsonSerializable()
class SubscriptionRequest extends Equatable {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String currentPlan;
  final String requestedPlan;
  final String reason;
  final String status; // pending, approved, rejected
  final String? adminId;
  final String? adminEmail;
  final String? adminName;
  final String? rejectionReason;
  @JsonKey(fromJson: _timestampFromJsonRequired, toJson: _timestampToJson)
  final DateTime createdAt;
  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  final DateTime? processedAt;

  const SubscriptionRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.currentPlan,
    required this.requestedPlan,
    required this.reason,
    this.status = 'pending',
    this.adminId,
    this.adminEmail,
    this.adminName,
    this.rejectionReason,
    required this.createdAt,
    this.processedAt,
  });

  static DateTime? _timestampFromJson(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  static DateTime _timestampFromJsonRequired(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.now();
  }

  static dynamic _timestampToJson(DateTime? dateTime) {
    if (dateTime == null) return null;
    return Timestamp.fromDate(dateTime);
  }

  factory SubscriptionRequest.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionRequestToJson(this);

  factory SubscriptionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionRequest.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }

  SubscriptionRequest copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? userName,
    String? currentPlan,
    String? requestedPlan,
    String? reason,
    String? status,
    String? adminId,
    String? adminEmail,
    String? adminName,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? processedAt,
  }) {
    return SubscriptionRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      currentPlan: currentPlan ?? this.currentPlan,
      requestedPlan: requestedPlan ?? this.requestedPlan,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      adminId: adminId ?? this.adminId,
      adminEmail: adminEmail ?? this.adminEmail,
      adminName: adminName ?? this.adminName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  @override
  List<Object?> get props => [
        id,
        userId,
        userEmail,
        userName,
        currentPlan,
        requestedPlan,
        reason,
        status,
        adminId,
        adminEmail,
        adminName,
        rejectionReason,
        createdAt,
        processedAt,
      ];
}