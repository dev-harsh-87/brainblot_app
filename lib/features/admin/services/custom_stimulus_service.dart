import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:spark_app/features/admin/domain/custom_stimulus.dart';
import 'package:spark_app/features/admin/data/custom_stimulus_repository.dart';

class CustomStimulusService {
  final CustomStimulusRepository _repository = CustomStimulusRepository();
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // Get all custom stimuli
  Future<List<CustomStimulus>> getAllCustomStimuli() async {
    return await _repository.getAllCustomStimuli();
  }

  // Get custom stimuli by type
  Future<List<CustomStimulus>> getCustomStimuliByType(CustomStimulusType type) async {
    return await _repository.getCustomStimuliByType(type);
  }

  // Get custom stimulus by ID
  Future<CustomStimulus?> getCustomStimulusById(String id) async {
    return await _repository.getCustomStimulusById(id);
  }

  // Create new custom stimulus
  Future<String> createCustomStimulus({
    required String name,
    required String description,
    required CustomStimulusType type,
    required List<CustomStimulusItem> items,
    required String createdBy,
  }) async {
    // Validate input
    if (name.trim().isEmpty) {
      throw Exception('Stimulus name cannot be empty');
    }

    if (items.isEmpty) {
      throw Exception('At least one stimulus item is required');
    }

    // Validate items based on type
    _validateStimulusItems(type, items);

    final stimulus = CustomStimulus(
      id: _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      type: type,
      items: items,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return await _repository.createCustomStimulus(stimulus);
  }

  // Update custom stimulus
  Future<void> updateCustomStimulus(CustomStimulus stimulus) async {
    // Validate items based on type
    _validateStimulusItems(stimulus.type, stimulus.items);

    await _repository.updateCustomStimulus(stimulus);
  }

  // Delete custom stimulus
  Future<void> deleteCustomStimulus(String id) async {
    await _repository.deleteCustomStimulus(id);
  }

  // Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  // Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to capture image: $e');
    }
  }

  // Convert image to base64
  Future<String> convertImageToBase64(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);
      return 'data:image/png;base64,$base64String';
    } catch (e) {
      throw Exception('Failed to convert image to base64: $e');
    }
  }

  // Create stimulus item from image
  Future<CustomStimulusItem> createImageStimulusItem({
    required String name,
    required File imageFile,
    required int order,
  }) async {
    final base64Image = await convertImageToBase64(imageFile);
    
    return CustomStimulusItem(
      id: _uuid.v4(),
      name: name.trim(),
      imageBase64: base64Image,
      order: order,
    );
  }

  // Create stimulus item from text
  CustomStimulusItem createTextStimulusItem({
    required String name,
    required String textValue,
    required int order,
  }) {
    return CustomStimulusItem(
      id: _uuid.v4(),
      name: name.trim(),
      textValue: textValue.trim(),
      order: order,
    );
  }

  // Create stimulus item from color
  CustomStimulusItem createColorStimulusItem({
    required String name,
    required Color color,
    required int order,
  }) {
    return CustomStimulusItem(
      id: _uuid.v4(),
      name: name.trim(),
      color: color,
      order: order,
    );
  }

  // Create stimulus item from shape
  CustomStimulusItem createShapeStimulusItem({
    required String name,
    required String shapeType,
    required int order,
  }) {
    return CustomStimulusItem(
      id: _uuid.v4(),
      name: name.trim(),
      shapeType: shapeType,
      order: order,
    );
  }

  // Validate stimulus items based on type
  void _validateStimulusItems(CustomStimulusType type, List<CustomStimulusItem> items) {
    for (final item in items) {
      switch (type) {
        case CustomStimulusType.image:
          if (item.imageBase64 == null || item.imageBase64!.isEmpty) {
            throw Exception('Image stimulus items must have valid image data');
          }
          break;
        case CustomStimulusType.text:
          if (item.textValue == null || item.textValue!.isEmpty) {
            throw Exception('Text stimulus items must have valid text value');
          }
          break;
        case CustomStimulusType.color:
          if (item.color == null) {
            throw Exception('Color stimulus items must have valid color');
          }
          break;
        case CustomStimulusType.shape:
          if (item.shapeType == null || item.shapeType!.isEmpty) {
            throw Exception('Shape stimulus items must have valid shape type');
          }
          break;
      }
    }
  }

  // Get stimulus items sorted by order
  List<CustomStimulusItem> getSortedItems(List<CustomStimulusItem> items) {
    final sortedItems = List<CustomStimulusItem>.from(items);
    sortedItems.sort((a, b) => a.order.compareTo(b.order));
    return sortedItems;
  }

  // Search custom stimuli
  Future<List<CustomStimulus>> searchCustomStimuli(String searchTerm) async {
    return await _repository.searchCustomStimuli(searchTerm);
  }

  // Get custom stimuli stream for real-time updates
  Stream<List<CustomStimulus>> getCustomStimuliStream() {
    return _repository.streamCustomStimuli();
  }

  // Validate stimulus name uniqueness
  Future<bool> isNameUnique(String name, {String? excludeId}) async {
    final allStimuli = await getAllCustomStimuli();
    return !allStimuli.any((stimulus) => 
        stimulus.name.toLowerCase() == name.toLowerCase() && 
        stimulus.id != excludeId);
  }

  // Get stimulus statistics
  Future<Map<String, int>> getStimulusStatistics() async {
    final allStimuli = await getAllCustomStimuli();
    
    final stats = <String, int>{
      'total': allStimuli.length,
      'image': 0,
      'text': 0,
      'color': 0,
      'shape': 0,
    };

    for (final stimulus in allStimuli) {
      stats[stimulus.type.name] = (stats[stimulus.type.name] ?? 0) + 1;
    }

    return stats;
  }
}