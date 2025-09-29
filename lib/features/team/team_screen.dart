import 'package:brainblot_app/features/team/bloc/team_bloc.dart';
import 'package:brainblot_app/features/team/domain/team.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: BlocBuilder<TeamBloc, TeamState>(
        builder: (context, state) {
          if (state.status == TeamStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final team = state.team;
          if (team == null) {
            return const Center(child: Text('No team found'));
          }
          final members = List<TeamMember>.from(team.members);
          final leaderboard = List<TeamMember>.from(members)..sort((a, b) => a.avgRtMs.compareTo(b.avgRtMs));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(team.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                subtitle: const Text('Team Dashboard'),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  title: Text('Invite Code: ${team.inviteCode}'),
                  subtitle: const Text('Share with your team to join'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Copy',
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: team.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied')));
                        },
                      ),
                      IconButton(
                        tooltip: 'Share',
                        icon: const Icon(Icons.share),
                        onPressed: () => Share.share('Join my team on CogniTrain. Invite code: ${team.inviteCode}'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...members.map((m) => ListTile(
                    leading: CircleAvatar(child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?')),
                    title: Text(m.name),
                    subtitle: Text('Avg RT: ${m.avgRtMs.toStringAsFixed(0)}ms • Acc: ${(m.acc * 100).toStringAsFixed(0)}%'),
                  )),
              const SizedBox(height: 16),
              const Text('Leaderboard (Faster is better)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...leaderboard.asMap().entries.map((e) {
                final rank = e.key + 1; final m = e.value;
                return ListTile(
                  leading: CircleAvatar(child: Text('$rank')),
                  title: Text(m.name),
                  subtitle: Text('Avg RT: ${m.avgRtMs.toStringAsFixed(0)}ms'),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
