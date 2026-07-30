import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../providers/workout_plan_session_provider.dart';

class WorkoutPlanSummaryScreen extends ConsumerWidget {
  const WorkoutPlanSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final planState = ref.watch(workoutPlanSessionProvider);
    final snapshot = planState.snapshot;
    if (snapshot == null) {
      return AppScaffoldShell(
        title: localizations.workoutSummary,
        body: Center(
          child: Text(
            localizations.noCompletedPlan,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final summary = snapshot.summary;
    return AppScaffoldShell(
      title: localizations.workoutSummary,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      body: ListView(
        children: [
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((planState.plan?.name ?? '').isNotEmpty) ...[
                  Text(
                    planState.plan!.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  localizations.planCompleted,
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _SummaryRow(
                  label: localizations.completedSets,
                  value: '${summary.completedSets} / ${summary.totalSets}',
                ),
                _SummaryRow(
                  label: localizations.workoutSummaryTotalReps,
                  value: summary.totalRepetitions.toString(),
                ),
                _SummaryRow(
                  label: localizations.workoutSummaryTotalHold,
                  value: _formatDuration(summary.totalHoldDuration),
                ),
                _SummaryRow(
                  label: localizations.totalDuration,
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
                    localizations.exerciseTitle(aggregate.exercise.id),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.workoutAggregateSummary(
                      sets: aggregate.completedSets,
                      reps: aggregate.totalRepetitions,
                      holdDuration: _formatDuration(
                        aggregate.totalHoldDuration,
                      ),
                    ),
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
            child: Text(localizations.returnHome),
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
