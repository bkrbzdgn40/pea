import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../providers/workout_plan_session_provider.dart';

class WorkoutPlanSummaryScreen extends ConsumerWidget {
  const WorkoutPlanSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(workoutPlanSessionProvider).snapshot;
    if (snapshot == null) {
      return const AppScaffoldShell(
        title: 'Antrenman Özeti',
        body: Center(
          child: Text(
            'Tamamlanmış bir plan bulunamadı.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final summary = snapshot.summary;
    return AppScaffoldShell(
      title: 'Antrenman Özeti',
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      body: ListView(
        children: [
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Plan tamamlandı',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _SummaryRow(
                  label: 'Tamamlanan set',
                  value: '${summary.completedSets} / ${summary.totalSets}',
                ),
                _SummaryRow(
                  label: 'Toplam tekrar',
                  value: summary.totalRepetitions.toString(),
                ),
                _SummaryRow(
                  label: 'Toplam hold',
                  value: _formatDuration(summary.totalHoldDuration),
                ),
                _SummaryRow(
                  label: 'Toplam süre',
                  value: _formatDuration(summary.elapsed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final aggregate in summary.exerciseAggregates.values) ...[
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    aggregate.exercise.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${aggregate.completedSets} set • ${aggregate.totalRepetitions} tekrar • ${_formatDuration(aggregate.totalHoldDuration)} hold',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton(
            onPressed: () {
              ref.read(workoutPlanSessionProvider.notifier).reset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Ana Sayfaya Dön'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white60)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
