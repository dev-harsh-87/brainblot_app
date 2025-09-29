import 'package:brainblot_app/features/home/bloc/home_bloc.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          final Drill? recommended = state.recommended;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Quick Start', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  title: Text(recommended?.name ?? 'No recommendation'),
                  subtitle: Text(recommended != null
                      ? '${recommended.category} • ${recommended.difficulty.name} • ${recommended.stimulusTypes.map((e) => e.name).join(', ')}'
                      : 'Create a custom drill to get started'),
                  trailing: FilledButton(
                    onPressed: recommended == null ? null : () => context.go('/drill-runner', extra: recommended),
                    child: const Text('Start'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Recent Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (state.recent.isEmpty)
                const Card(child: ListTile(title: Text('No sessions yet')))
              else
                ...state.recent.map((r) => Card(
                      child: ListTile(
                        title: Text(r.drill.name),
                        subtitle: Text('Acc: ${(r.accuracy * 100).toStringAsFixed(0)}% • Avg RT: ${r.avgReactionMs.toStringAsFixed(0)}ms'),
                      ),
                    )),
              const SizedBox(height: 16),
              const Text('Browse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _NavTile(label: 'Drill Library', icon: Icons.library_books, onTap: () => context.go('/drills')),
                  _NavTile(label: 'Programs', icon: Icons.calendar_today, onTap: () => context.go('/programs')),
                  _NavTile(label: 'Stats', icon: Icons.insights, onTap: () => context.go('/stats')),
                  _NavTile(label: 'Team', icon: Icons.group, onTap: () => context.go('/team')),
                  _NavTile(label: 'Settings', icon: Icons.settings, onTap: () => context.go('/settings')),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _NavTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}
