import 'dart:async';
import 'package:brainblot_app/features/team/domain/team.dart';
import 'package:uuid/uuid.dart';

abstract class TeamRepository {
  Stream<Team?> watchTeam();
  Future<void> createOrLoadDefault();
  Future<void> addMember(TeamMember m);
}

class InMemoryTeamRepository implements TeamRepository {
  final _ctrl = StreamController<Team?>.broadcast();
  Team? _team;
  final _uuid = const Uuid();

  @override
  Future<void> createOrLoadDefault() async {
    if (_team != null) return;
    _team = Team(
      id: _uuid.v4(),
      name: 'My Team',
      inviteCode: 'ABC123',
      members: const [
        TeamMember(id: '1', name: 'Athlete One', avgRtMs: 310, acc: 0.90),
        TeamMember(id: '2', name: 'Athlete Two', avgRtMs: 295, acc: 0.93),
      ],
    );
    _emit();
  }

  void _emit() => _ctrl.add(_team);

  @override
  Stream<Team?> watchTeam() => _ctrl.stream;

  @override
  Future<void> addMember(TeamMember m) async {
    if (_team == null) return;
    final list = List<TeamMember>.from(_team!.members)..add(m);
    _team = Team(id: _team!.id, name: _team!.name, inviteCode: _team!.inviteCode, members: list);
    _emit();
  }
}
