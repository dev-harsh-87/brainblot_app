import 'dart:async';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:uuid/uuid.dart';

abstract class ProgramRepository {
  Stream<List<Program>> watchAll();
  Future<void> setActive(ActiveProgram active);
  Stream<ActiveProgram?> watchActive();
}

class InMemoryProgramRepository implements ProgramRepository {
  final _uuid = const Uuid();
  final _programsCtrl = StreamController<List<Program>>.broadcast();
  final _activeCtrl = StreamController<ActiveProgram?>.broadcast();

  late final List<Program> _programs;
  ActiveProgram? _active;

  InMemoryProgramRepository() {
    _programs = _seedPrograms();
    _emitPrograms();
  }

  List<Program> _seedPrograms() {
    final p1 = Program(
      id: _uuid.v4(),
      name: '4-week Agility Boost',
      category: 'agility',
      totalDays: 28,
      level: 'Beginner',
      days: List.generate(28, (i) => ProgramDay(dayNumber: i + 1, title: 'Day ${i + 1}', description: 'Agility and reaction mix', drillId: null)),
    );
    final p2 = Program(
      id: _uuid.v4(),
      name: 'Soccer: Decision Speed',
      category: 'soccer',
      totalDays: 21,
      level: 'Intermediate',
      days: List.generate(21, (i) => ProgramDay(dayNumber: i + 1, title: 'Day ${i + 1}', description: 'Soccer-specific stimuli', drillId: null)),
    );
    return [p1, p2];
  }

  void _emitPrograms() => _programsCtrl.add(List.unmodifiable(_programs));
  void _emitActive() => _activeCtrl.add(_active);

  @override
  Stream<List<Program>> watchAll() => _programsCtrl.stream;

  @override
  Future<void> setActive(ActiveProgram active) async {
    _active = active;
    _emitActive();
  }

  @override
  Stream<ActiveProgram?> watchActive() => _activeCtrl.stream;
}
