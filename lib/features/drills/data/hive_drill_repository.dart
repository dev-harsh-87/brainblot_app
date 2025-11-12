import 'dart:async';
import 'package:spark_app/features/drills/data/drill_repository.dart';
import 'package:spark_app/features/drills/domain/drill.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveDrillRepository implements DrillRepository {
  final Box<dynamic> _box = Hive.box('drills');
  final _controller = StreamController<List<Drill>>.broadcast();

  HiveDrillRepository() {
    // Emit initial
    _emit();
    // Listen to changes
    _box.watch().listen((_) => _emit());
  }

  void _emit() {
    final items = _box.values
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Drill.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    _controller.add(items);
  }

  @override
  Future<List<Drill>> fetchAll({String? query, String? category, Difficulty? difficulty}) async {
    final items = _box.values
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Drill.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    Iterable<Drill> out = items;
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
    await _box.put(drill.id, drill.toMap());
    await _syncToCloud(drill);
    return drill;
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('drills').doc(id).delete().catchError((_) {});
    }
  }

  @override
  Stream<List<Drill>> watchAll() => _controller.stream;

  @override
  Future<void> toggleFavorite(String drillId) async {
    final drillMap = _box.get(drillId);
    if (drillMap != null && drillMap is Map<dynamic, dynamic>) {
      final drill = Drill.fromMap(Map<String, dynamic>.from(drillMap));
      final updatedDrill = drill.copyWith(favorite: !drill.favorite);
      await _box.put(drillId, updatedDrill.toMap());
      await _syncToCloud(updatedDrill);
    }
  }

  @override
  Future<bool> isFavorite(String drillId) async {
    final drillMap = _box.get(drillId);
    if (drillMap != null && drillMap is Map<dynamic, dynamic>) {
      final drill = Drill.fromMap(Map<String, dynamic>.from(drillMap));
      return drill.favorite;
    }
    return false;
  }

  @override
  Future<List<Drill>> fetchMyDrills({String? query, String? category, Difficulty? difficulty}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final items = _box.values
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Drill.fromMap(Map<String, dynamic>.from(e)))
        .where((drill) => drill.createdBy == user.uid)
        .toList();
    
    Iterable<Drill> out = items;
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
    final user = FirebaseAuth.instance.currentUser;
    
    final items = _box.values
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Drill.fromMap(Map<String, dynamic>.from(e)))
        .where((drill) => drill.createdBy != user?.uid)
        .toList();
    
    Iterable<Drill> out = items;
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
  Future<List<Drill>> fetchAdminDrills({String? query, String? category, Difficulty? difficulty}) async {
    // For Hive implementation, we need to fetch admin user IDs from Firestore
    // This is a simplified implementation that returns empty list
    // In production, you would fetch from Firestore
    return [];
  }

  @override
  Future<List<Drill>> fetchFavoriteDrills({String? query, String? category, Difficulty? difficulty}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    final items = _box.values
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Drill.fromMap(Map<String, dynamic>.from(e)))
        .where((drill) => drill.favorite &&
               drill.createdBy == user.uid,)
        .toList();
    
    Iterable<Drill> out = items;
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

  Future<void> _syncToCloud(Drill drill) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('drills').doc(drill.id).set(drill.toMap());
  }
}
