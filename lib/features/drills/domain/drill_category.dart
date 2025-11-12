import 'package:cloud_firestore/cloud_firestore.dart';

class DrillCategory {
  final String id;
  final String name;
  final String displayName;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  DrillCategory({
    required this.id,
    required this.name,
    required this.displayName,
    this.order = 0,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    this.createdBy,
  }) : createdAt = createdAt ?? DateTime.now();

  DrillCategory copyWith({
    String? id,
    String? name,
    String? displayName,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) => DrillCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        displayName: displayName ?? this.displayName,
        order: order ?? this.order,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'displayName': displayName,
        'order': order,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'createdBy': createdBy,
      };

  static DrillCategory fromMap(Map<String, dynamic> map) => DrillCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        displayName: map['displayName'] as String,
        order: (map['order'] as int?) ?? 0,
        isActive: (map['isActive'] as bool?) ?? true,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
        createdBy: map['createdBy'] as String?,
      );
}