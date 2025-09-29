import 'package:brainblot_app/core/di/injection.dart';
import 'package:brainblot_app/features/drills/bloc/drill_library_bloc.dart';
import 'package:brainblot_app/features/drills/data/drill_repository.dart';
import 'package:brainblot_app/features/drills/domain/drill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DrillLibraryScreen extends StatelessWidget {
  const DrillLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drill Library')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/drill-builder');
          if (result is Drill) {
            await getIt<DrillRepository>().upsert(result);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search drills',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => context.read<DrillLibraryBloc>().add(DrillLibraryQueryChanged(v)),
                  ),
                ),
                const SizedBox(width: 12),
                _CategoryFilter(),
                const SizedBox(width: 12),
                _DifficultyFilter(),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<DrillLibraryBloc, DrillLibraryState>(
              builder: (context, state) {
                if (state.status == DrillLibraryStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = state.items;
                if (items.isEmpty) {
                  return const Center(child: Text('No drills found'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (_, i) {
                    final d = items[i];
                    return ListTile(
                      title: Text(d.name),
                      subtitle: Text('${d.category} • ${d.difficulty.name} • ${d.stimulusTypes.map((e) => e.name).join(', ')}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/drill-detail', extra: d),
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: items.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final List<String> categories = const [
    '',
    'fitness',
    'soccer',
    'basketball',
    'hockey',
    'tennis',
    'volleyball',
    'football',
    'lacrosse',
    'physiotherapy',
    'agility',
  ];
  _CategoryFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        isDense: true,
        value: '',
        items: categories
            .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.isEmpty ? 'All' : c),
                ))
            .toList(),
        onChanged: (v) => context.read<DrillLibraryBloc>().add(DrillLibraryFilterChanged(category: v)),
        decoration: const InputDecoration(labelText: 'Sport'),
      ),
    );
  }
}

class _DifficultyFilter extends StatelessWidget {
  const _DifficultyFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<Difficulty?>(
        isDense: true,
        value: null,
        items: [
          const DropdownMenuItem<Difficulty?>(value: null, child: Text('All')),
          ...Difficulty.values.map((d) => DropdownMenuItem<Difficulty?>(value: d, child: Text(d.name)))
        ],
        onChanged: (v) => context.read<DrillLibraryBloc>().add(DrillLibraryFilterChanged(difficulty: v)),
        decoration: const InputDecoration(labelText: 'Difficulty'),
      ),
    );
  }
}
