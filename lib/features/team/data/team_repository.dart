import 'dart:async';
import 'package:brainblot_app/features/team/domain/team.dart';
import 'package:uuid/uuid.dart';

abstract class TeamRepository {
  Stream<Team?> watchTeam();
  Future<void> loadUserTeam();
  Future<void> createTeam(String name, TeamMember creator);
  Future<void> joinTeam(String inviteCode, TeamMember member);
  Future<void> leaveTeam();
  Future<void> updateMemberStats(String memberId, double avgRtMs, double acc);
  Future<void> addMember(TeamMember m);
}

class InMemoryTeamRepository implements TeamRepository {
  final _ctrl = StreamController<Team?>.broadcast();
  Team? _team;
  final _uuid = const Uuid();
  final Map<String, Team> _teams = {}; // Store teams by invite code
  String? _userTeamId;

  @override
  Future<void> loadUserTeam() async {
    // Check if user is already in a team
    if (_userTeamId != null) {
      _team = _teams.values.firstWhere(
        (team) => team.id == _userTeamId,
        orElse: () => _createDefaultTeam(),
      );
    } else {
      // Create a default team for demo purposes
      _team = _createDefaultTeam();
    }
    _emit();
  }

  Team _createDefaultTeam() {
    final team = Team(
      id: _uuid.v4(),
      name: 'Demo Team',
      inviteCode: 'DEMO123',
      members: const [
        TeamMember(id: 'demo1', name: 'Demo Athlete 1', avgRtMs: 310, acc: 0.90),
        TeamMember(id: 'demo2', name: 'Demo Athlete 2', avgRtMs: 295, acc: 0.93),
      ],
    );
    _teams[team.inviteCode] = team;
    return team;
  }

  @override
  Future<void> createTeam(String name, TeamMember creator) async {
    final inviteCode = _generateInviteCode();
    final team = Team(
      id: _uuid.v4(),
      name: name,
      inviteCode: inviteCode,
      members: [creator],
    );
    
    _teams[inviteCode] = team;
    _userTeamId = team.id;
    _team = team;
    _emit();
  }

  @override
  Future<void> joinTeam(String inviteCode, TeamMember member) async {
    final team = _teams[inviteCode];
    if (team == null) {
      throw Exception('Team not found with invite code: $inviteCode');
    }
    
    // Check if user is already in the team
    if (team.members.any((m) => m.id == member.id)) {
      throw Exception('You are already a member of this team');
    }
    
    final updatedMembers = List<TeamMember>.from(team.members)..add(member);
    final updatedTeam = Team(
      id: team.id,
      name: team.name,
      inviteCode: team.inviteCode,
      members: updatedMembers,
    );
    
    _teams[inviteCode] = updatedTeam;
    _userTeamId = team.id;
    _team = updatedTeam;
    _emit();
  }

  @override
  Future<void> leaveTeam() async {
    if (_team == null) return;
    
    final updatedMembers = _team!.members
        .where((m) => m.id != 'current_user')
        .toList();
    
    final updatedTeam = Team(
      id: _team!.id,
      name: _team!.name,
      inviteCode: _team!.inviteCode,
      members: updatedMembers,
    );
    
    _teams[_team!.inviteCode] = updatedTeam;
    _userTeamId = null;
    _team = null;
    _emit();
  }

  @override
  Future<void> updateMemberStats(String memberId, double avgRtMs, double acc) async {
    if (_team == null) return;
    
    final updatedMembers = _team!.members.map((member) {
      if (member.id == memberId) {
        return TeamMember(
          id: member.id,
          name: member.name,
          avgRtMs: avgRtMs,
          acc: acc,
        );
      }
      return member;
    }).toList();
    
    final updatedTeam = Team(
      id: _team!.id,
      name: _team!.name,
      inviteCode: _team!.inviteCode,
      members: updatedMembers,
    );
    
    _teams[_team!.inviteCode] = updatedTeam;
    _team = updatedTeam;
    _emit();
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (index) => chars[random % chars.length]).join();
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
