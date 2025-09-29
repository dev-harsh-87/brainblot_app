import 'dart:async';
import 'package:brainblot_app/features/drills/domain/session_result.dart';

abstract class SessionRepository {
  Future<void> save(SessionResult result);
  Stream<List<SessionResult>> watchAll();
}

class InMemorySessionRepository implements SessionRepository {
  final _items = <SessionResult>[];
  final _controller = StreamController<List<SessionResult>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_items));

  @override
  Future<void> save(SessionResult result) async {
    final i = _items.indexWhere((e) => e.id == result.id);
    if (i == -1) {
      _items.add(result);
    } else {
      _items[i] = result;
    }
    _emit();
  }

  @override
  Stream<List<SessionResult>> watchAll() => _controller.stream;
}
