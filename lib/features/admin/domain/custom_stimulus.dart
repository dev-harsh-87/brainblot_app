import 'package:flutter/material.dart';

enum CustomStimulusType { image, text, shape, color }

class CustomStimulus {
  final String id;
  final String name;
  final String description;
  final CustomStimulusType type;
  final List<CustomStimulusItem> items;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const CustomStimulus({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.items,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  CustomStimulus copyWith({
    String? id,
    String? name,
    String? description,
    CustomStimulusType? type,
    List<CustomStimulusItem>? items,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return CustomStimulus(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      items: items ?? this.items,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'items': items.map((item) => item.toJson()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory CustomStimulus.fromJson(Map<String, dynamic> json) {
    return CustomStimulus(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: CustomStimulusType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CustomStimulusType.image,
      ),
      items: (json['items'] as List<dynamic>)
          .map((item) => CustomStimulusItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class CustomStimulusItem {
  final String id;
  final String name;
  final String? imageBase64; // For image stimuli
  final String? textValue; // For text stimuli
  final Color? color; // For color stimuli
  final String? shapeType; // For shape stimuli
  final int order;

  const CustomStimulusItem({
    required this.id,
    required this.name,
    this.imageBase64,
    this.textValue,
    this.color,
    this.shapeType,
    required this.order,
  });

  CustomStimulusItem copyWith({
    String? id,
    String? name,
    String? imageBase64,
    String? textValue,
    Color? color,
    String? shapeType,
    int? order,
  }) {
    return CustomStimulusItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imageBase64: imageBase64 ?? this.imageBase64,
      textValue: textValue ?? this.textValue,
      color: color ?? this.color,
      shapeType: shapeType ?? this.shapeType,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageBase64': imageBase64,
      'textValue': textValue,
      'color': color?.value,
      'shapeType': shapeType,
      'order': order,
    };
  }

  factory CustomStimulusItem.fromJson(Map<String, dynamic> json) {
    return CustomStimulusItem(
      id: json['id'] as String,
      name: json['name'] as String,
      imageBase64: json['imageBase64'] as String?,
      textValue: json['textValue'] as String?,
      color: json['color'] != null ? Color(json['color'] as int) : null,
      shapeType: json['shapeType'] as String?,
      order: json['order'] as int,
    );
  }
}