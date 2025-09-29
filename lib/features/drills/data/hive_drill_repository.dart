import 'dart:async';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveDrillRepository implements DrillRepository {
  final Box _box = Hive.box('drills');
  final _controller = StreamController<List<Drill>>.broadcast();

  HiveDrillRepository() {
    // Emit initial
    _emit();
    // Listen to changes
    _box.watch().listen((_) => _emit());
  }

  void _emit() {
    final items = _box.values
        .whereType<Map>()
        .map((e) => Drill.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    _controller.add(items);
  }

  @override
  Future<List<Drill>> fetchAll({String? query, String? category, Difficulty? difficulty}) async {
    final items = _box.values
        .whereType<Map>()
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

  Future<void> _syncToCloud(Drill drill) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('drills').doc(drill.id).set(drill.toMap());
  }
}
