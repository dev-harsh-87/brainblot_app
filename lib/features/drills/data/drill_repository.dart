import 'dart:async';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

abstract class DrillRepository {
  Stream<List<Drill>> watchAll();
  Future<List<Drill>> fetchAll({String? query, String? category, Difficulty? difficulty});
  Future<List<Drill>> fetchMyDrills({String? query, String? category, Difficulty? difficulty});
  Future<List<Drill>> fetchPublicDrills({String? query, String? category, Difficulty? difficulty});
  Future<List<Drill>> fetchFavoriteDrills({String? query, String? category, Difficulty? difficulty});
  Future<Drill> upsert(Drill drill);
  Future<void> delete(String id);
  Future<void> toggleFavorite(String drillId);
  Future<bool> isFavorite(String drillId);
}

class InMemoryDrillRepository implements DrillRepository {
  final _controller = StreamController<List<Drill>>.broadcast();
  final _items = <Drill>[];
  final _uuid = const Uuid();

  InMemoryDrillRepository() {
    _emit();
  }

  void _emit() => _controller.add(List.unmodifiable(_items));

  @override
  Future<List<Drill>> fetchAll({String? query, String? category, Difficulty? difficulty}) async {
    Iterable<Drill> out = _items;
    if (query != null && query.isNotEmpty) {
      out = out.where((d) => d.name.toLowerCase().contains(query.toLowerCase()));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((d) => d.category == category);
    }
    if (difficulty != null) {
      out = out.where((d) => d.difficulty == difficulty);
    }
    return out.toList(growable: false);
  }

  @override
  Future<Drill> upsert(Drill drill) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User must be logged in to create/update drills');
    }

    final idx = _items.indexWhere((e) => e.id == drill.id);
    if (idx == -1) {
      // Creating new drill - ensure it belongs to current user and is private by default
      final toAdd = drill.id.isEmpty
          ? drill.copyWith(
              id: _uuid.v4(),
              createdBy: currentUserId,
            )
          : drill.copyWith(
              createdBy: currentUserId,
            );
      _items.add(toAdd);
      _emit();
      return toAdd;
    } else {
      // Updating existing drill - verify ownership
      final existingDrill = _items[idx];
      if (existingDrill.createdBy != currentUserId) {
        throw Exception('You can only edit your own drills');
      }
      _items[idx] = drill;
      _emit();
      return drill;
    }
  }

  @override
  Future<void> delete(String id) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User must be logged in to delete drills');
    }

    final drillIndex = _items.indexWhere((e) => e.id == id);
    if (drillIndex != -1) {
      final drill = _items[drillIndex];
      if (drill.createdBy != currentUserId) {
        throw Exception('You can only delete your own drills');
      }
      _items.removeAt(drillIndex);
      _emit();
    }
  }

  @override
  Stream<List<Drill>> watchAll() => _controller.stream;

  @override
  Future<void> toggleFavorite(String drillId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User must be logged in to favorite drills');
    }

    final index = _items.indexWhere((drill) => drill.id == drillId);
    if (index != -1) {
      final drill = _items[index];
      // Users can only favorite their own drills
      if (drill.createdBy == currentUserId) {
        _items[index] = _items[index].copyWith(favorite: !_items[index].favorite);
        _emit();
      }
    }
  }

  @override
  Future<bool> isFavorite(String drillId) async {
    final drill = _items.firstWhereOrNull((drill) => drill.id == drillId);
    return drill?.favorite ?? false;
  }

  @override
  Future<List<Drill>> fetchMyDrills({String? query, String? category, Difficulty? difficulty}) async {
    // Get current user from Firebase Auth
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return [];
    
    Iterable<Drill> out = _items.where((drill) => drill.createdBy == currentUserId);
    
    if (query != null && query.isNotEmpty) {
      out = out.where((d) => d.name.toLowerCase().contains(query.toLowerCase()));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((d) => d.category == category);
    }
    if (difficulty != null) {
      out = out.where((d) => d.difficulty == difficulty);
    }
    return out.toList(growable: false);
  }

  @override
  Future<List<Drill>> fetchPublicDrills({String? query, String? category, Difficulty? difficulty}) async {
    // Get current user from Firebase Auth
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // Only return public drills that are not created by current user
    Iterable<Drill> out = _items.where((drill) =>
        drill.createdBy != currentUserId);
    
    if (query != null && query.isNotEmpty) {
      out = out.where((d) => d.name.toLowerCase().contains(query.toLowerCase()));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((d) => d.category == category);
    }
    if (difficulty != null) {
      out = out.where((d) => d.difficulty == difficulty);
    }
    return out.toList(growable: false);
  }

  @override
  Future<List<Drill>> fetchFavoriteDrills({String? query, String? category, Difficulty? difficulty}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Get current user from Firebase Auth
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return [];
    
    // Return favorite drills that user can see (their own or public ones)
    Iterable<Drill> out = _items.where((drill) => 
        drill.favorite &&
        drill.createdBy == currentUserId);
    
    if (query != null && query.isNotEmpty) {
      out = out.where((d) => d.name.toLowerCase().contains(query.toLowerCase()));
    }
    if (category != null && category.isNotEmpty) {
      out = out.where((d) => d.category == category);
    }
    if (difficulty != null) {
      out = out.where((d) => d.difficulty == difficulty);
    }
    return out.toList(growable: false);
  }

  /// Dispose resources when no longer needed
  void dispose() {
    _controller.close();
  }
}

// Extension to add firstWhereOrNull if not available
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
