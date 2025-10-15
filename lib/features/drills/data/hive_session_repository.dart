import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:brainblot_app/features/drills/data/session_repository.dart';
import 'package:brainblot_app/features/drills/domain/session_result.dart';

class HiveSessionRepository implements SessionRepository {
  final Box<dynamic> _box = Hive.box('sessions');
  final _controller = StreamController<List<SessionResult>>.broadcast();

  HiveSessionRepository() {
    _emit();
    _box.watch().listen((_) => _emit());
  }


  void _emit() {
    final items = _box.values
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => SessionResult.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    _controller.add(items);
  }

  @override
  Stream<List<SessionResult>> watchAll() => _controller.stream;

  @override
  Stream<List<SessionResult>> watchByDrill(String drillId) {
    return _controller.stream.map((sessions) => 
      sessions.where((session) => session.drill.id == drillId).toList(),);
  }

  @override
  Stream<List<SessionResult>> watchByProgram(String programId) {
    // For now, return empty since SessionResult doesn't have programId
    // This would need to be implemented when program support is added
    return _controller.stream.map((sessions) => <SessionResult>[]);
  }

  @override
  Future<List<SessionResult>> fetchAll() async {
    final items = _box.values
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => SessionResult.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return items;
  }

  @override
  Future<SessionResult?> fetchById(String id) async {
    final sessionMap = _box.get(id);
    if (sessionMap != null && sessionMap is Map<dynamic, dynamic>) {
      return SessionResult.fromMap(Map<String, dynamic>.from(sessionMap));
    }
    return null;
  }

  @override
  Future<SessionResult> save(SessionResult session) async {
    await _box.put(session.id, session.toMap());
    await _syncToCloud(session);
    return session;
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(id)
          .delete()
          .catchError((_) {});
    }
  }

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
