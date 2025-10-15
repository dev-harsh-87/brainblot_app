import 'dart:async';
import 'package:brainblot_app/features/drills/domain/session_result.dart';

abstract class SessionRepository {
  Stream<List<SessionResult>> watchAll();
  Stream<List<SessionResult>> watchByDrill(String drillId);
  Stream<List<SessionResult>> watchByProgram(String programId);
  Future<List<SessionResult>> fetchAll();
  Future<SessionResult?> fetchById(String id);
  Future<SessionResult> save(SessionResult session);
  Future<void> delete(String id);
}

class InMemorySessionRepository implements SessionRepository {
  final _items = <SessionResult>[];
  final _controller = StreamController<List<SessionResult>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_items));

  @override
  Stream<List<SessionResult>> watchAll() => _controller.stream;

  @override
  Stream<List<SessionResult>> watchByDrill(String drillId) {
    return _controller.stream.map((sessions) => 
      sessions.where((session) => session.drill.id == drillId).toList());
  }

  @override
  Stream<List<SessionResult>> watchByProgram(String programId) {
    // For now, return empty since SessionResult doesn't have programId
    // This would need to be implemented when program support is added
    return _controller.stream.map((sessions) => <SessionResult>[]);
  }

  @override
  Future<List<SessionResult>> fetchAll() async {
    return List.unmodifiable(_items);
  }

  @override
  Future<SessionResult?> fetchById(String id) async {
    try {
      return _items.firstWhere((session) => session.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<SessionResult> save(SessionResult session) async {
    final i = _items.indexWhere((e) => e.id == session.id);
    if (i == -1) {
      _items.add(session);
    } else {
      _items[i] = session;
    }
    _emit();
    return session;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((session) => session.id == id);
    _emit();
  }
}
