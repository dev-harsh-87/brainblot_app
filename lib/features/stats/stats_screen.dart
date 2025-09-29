import 'package:brainblot_app/features/stats/bloc/stats_bloc.dart';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw_widgets;
import 'package:printing/printing.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats & Progress'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.table_view),
            onPressed: () => _exportCsv(context),
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _exportPdf(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<StatsBloc, StatsState>(
          builder: (context, state) {
            if (state.status == StatsStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final sessions = state.sessions;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reaction Time (ms)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          spots: [
                            for (int i = 0; i < sessions.length; i++) FlSpot(i.toDouble(), sessions[i].avgReactionMs.toDouble()),
                          ],
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Recent Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => ListTile(
                      title: Text(sessions[i].drill.name),
                      subtitle: Text('Avg RT: ${sessions[i].avgReactionMs.toStringAsFixed(0)}ms • Acc: ${(sessions[i].accuracy * 100).toStringAsFixed(0)}%'),
                    ),
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  void _exportCsv(BuildContext context) {
    final sessions = context.read<StatsBloc>().state.sessions;
    final rows = <List<dynamic>>[
      ['Session ID', 'Drill', 'Start', 'End', 'Avg RT (ms)', 'Accuracy'],
      ...sessions.map((s) => [
            s.id,
            s.drill.name,
            s.startedAt.toIso8601String(),
            s.endedAt.toIso8601String(),
            s.avgReactionMs.toStringAsFixed(0),
            (s.accuracy * 100).toStringAsFixed(1),
          ])
    ];
    final csv = const ListToCsvConverter().convert(rows);
    Printing.sharePdf(bytes: Uint8List.fromList(csv.codeUnits), filename: 'stats.csv');
  }

  Future<void> _exportPdf(BuildContext context) async {
    final sessions = context.read<StatsBloc>().state.sessions;
    final doc = pw_widgets.Document();
    doc.addPage(
      pw_widgets.Page(
        build: (ctx) => pw_widgets.Column(
          crossAxisAlignment: pw_widgets.CrossAxisAlignment.start,
          children: [
            pw_widgets.Text('Stats Report', style: pw_widgets.TextStyle(fontSize: 24)),
            pw_widgets.SizedBox(height: 12),
            pw_widgets.Table.fromTextArray(
              headers: ['Drill', 'Avg RT (ms)', 'Accuracy %'],
              data: [
                for (final s in sessions) [s.drill.name, s.avgReactionMs.toStringAsFixed(0), (s.accuracy * 100).toStringAsFixed(1)],
              ],
            )
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
