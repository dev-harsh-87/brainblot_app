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
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          BlocBuilder<TeamBloc, TeamState>(
            builder: (context, state) {
              if (state.isInTeam) {
                return PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'leave') {
                      _showLeaveTeamDialog(context);
                    } else if (value == 'update_stats') {
                      context.read<TeamBloc>().add(const TeamStatsUpdateRequested());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stats updated!')),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'update_stats',
                      child: Text('Update My Stats'),
                    ),
                    const PopupMenuItem(
                      value: 'leave',
                      child: Text('Leave Team'),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<TeamBloc, TeamState>(
        listener: (context, state) {
          if (state.status == TeamStatus.error && state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state.status == TeamStatus.loading || 
              state.status == TeamStatus.joining ||
              state.status == TeamStatus.creating ||
              state.status == TeamStatus.leaving) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final team = state.team;
          if (team == null || !state.isInTeam) {
            return _buildNoTeamView(context);
          }
          
          return _buildTeamView(context, team);
        },
      ),
      floatingActionButton: BlocBuilder<TeamBloc, TeamState>(
        builder: (context, state) {
          if (!state.isInTeam) {
            return FloatingActionButton.extended(
              onPressed: () => _showJoinTeamDialog(context),
              icon: const Icon(Icons.group_add),
              label: const Text('Join Team'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildNoTeamView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Team Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Join a team to compete with friends and track your progress together!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showCreateTeamDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Team'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showJoinTeamDialog(context),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Join Team'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamView(BuildContext context, Team team) {
    final members = List<TeamMember>.from(team.members);
    final leaderboard = List<TeamMember>.from(members)
      ..sort((a, b) => a.avgRtMs.compareTo(b.avgRtMs));
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.groups, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        team.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${team.members.length} members',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.qr_code),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied')),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share),
                  onPressed: () => Share.share(
                    'Join my team on BrainBlot! Invite code: ${team.inviteCode}',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.leaderboard, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Leaderboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              'Faster is better',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...leaderboard.asMap().entries.map((e) {
          final rank = e.key + 1;
          final member = e.value;
          final isCurrentUser = member.id == 'current_user';
          
          return Card(
            color: isCurrentUser ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: rank <= 3 
                  ? (rank == 1 ? Colors.amber : rank == 2 ? Colors.grey : Colors.brown)
                  : Theme.of(context).primaryColor,
                child: Text(
                  '$rank',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              title: Row(
                children: [
                  Text(member.name),
                  if (isCurrentUser) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'You',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                'Avg RT: ${member.avgRtMs.toStringAsFixed(0)}ms • Accuracy: ${(member.acc * 100).toStringAsFixed(1)}%',
              ),
              trailing: rank <= 3 
                ? Icon(
                    Icons.emoji_events,
                    color: rank == 1 ? Colors.amber : rank == 2 ? Colors.grey : Colors.brown,
                  )
                : null,
            ),
          );
        }),
      ],
    );
  }

  void _showCreateTeamDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Team'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Team Name',
            hintText: 'Enter your team name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<TeamBloc>().add(TeamCreateRequested(controller.text.trim()));
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinTeamDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Team'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Invite Code',
            hintText: 'Enter the team invite code',
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<TeamBloc>().add(TeamJoinRequested(controller.text.trim().toUpperCase()));
                Navigator.pop(context);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showLeaveTeamDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Team'),
        content: const Text('Are you sure you want to leave this team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TeamBloc>().add(const TeamLeaveRequested());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
