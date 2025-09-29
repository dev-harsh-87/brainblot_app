import 'package:brainblot_app/features/programs/bloc/programs_bloc.dart';
import 'package:brainblot_app/features/programs/domain/program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      body: BlocBuilder<ProgramsBloc, ProgramsState>(
        builder: (context, state) {
          if (state.status == ProgramsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Active Program', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (state.active == null)
                const Card(child: ListTile(title: Text('None'), subtitle: Text('Activate a program below')))
              else
                _ProgramCard(
                  program: state.programs.firstWhere((p) => p.id == state.active!.programId, orElse: () => state.programs.first),
                  onActivate: null,
                ),
              const SizedBox(height: 24),
              const Text('Browse Programs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...state.programs.map((p) => _ProgramCard(
                    program: p,
                    onActivate: () => context.read<ProgramsBloc>().add(ProgramsActivateRequested(p)),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Program program;
  final VoidCallback? onActivate;
  const _ProgramCard({required this.program, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(program.name),
        subtitle: Text('${program.totalDays} days • ${program.level} • ${program.category}'),
        trailing: onActivate != null ? FilledButton(onPressed: onActivate, child: const Text('Activate')) : const Icon(Icons.check_circle, color: Colors.green),
        onTap: () {},
      ),
    );
  }
}
