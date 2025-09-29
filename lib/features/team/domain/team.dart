class TeamMember {
  final String id;
  final String name;
  final double avgRtMs;
  final double acc;
  const TeamMember({required this.id, required this.name, required this.avgRtMs, required this.acc});
}

class Team {
  final String id;
  final String name;
  final String inviteCode;
  final List<TeamMember> members;
  const Team({required this.id, required this.name, required this.inviteCode, required this.members});
}
