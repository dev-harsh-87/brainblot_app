import 'dart:async';
import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveSessionRepository implements SessionRepository {
  final Box _box = Hive.box('sessions');
  final _controller = StreamController<List<SessionResult>>.broadcast();

  HiveSessionRepository() {
    _emit();
    _box.watch().listen((_) => _emit());
  }

  void _emit() {
    final items = _box.values
        .whereType<Map>()
        .map((e) => SessionResult.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    // Sort newest first
    items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    _controller.add(items);
  }

  @override
  Future<void> save(SessionResult result) async {
    await _box.put(result.id, result.toMap());
    await _syncToCloud(result);
  }

  @override
  Stream<List<SessionResult>> watchAll() => _controller.stream;

  Future<void> _syncToCloud(SessionResult result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(result.id)
        .set(result.toMap());
  }
}
