import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../application/saved_workout_plan.dart';
import '../../application/workout_engine.dart';
import '../providers/saved_workout_plans_provider.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/workout_plan_session_provider.dart';
import 'camera_permission_screen.dart';

class WorkoutPlanReviewScreen extends ConsumerStatefulWidget {
  const WorkoutPlanReviewScreen({
    super.key,
    required this.plan,
    required this.onSaved,
  });

  final SavedWorkoutPlan plan;
  final VoidCallback onSaved;

  @override
  ConsumerState<WorkoutPlanReviewScreen> createState() =>
      _WorkoutPlanReviewScreenState();
}

class _WorkoutPlanReviewScreenState
    extends ConsumerState<WorkoutPlanReviewScreen> {
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final plan = widget.plan;

    return AppScaffoldShell(
      title: localizations.planSummary,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                AppSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SummaryRow(
                        label: localizations.roundCount,
                        value: plan.rounds.toString(),
                      ),
                      _SummaryRow(
                        label: localizations.exerciseEntries,
                        value: plan.entries.length.toString(),
                      ),
                      _SummaryRow(
                        label: localizations.totalPlannedSets,
                        value: plan.totalSets.toString(),
                      ),
                      _SummaryRow(
                        label: localizations.estimatedRest,
                        value: _formatDuration(plan.estimatedRestDuration),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (
                  var index = 0;
                  index < plan.entries.length;
                  index += 1
                ) ...[
                  _PlanEntrySummary(index: index, entry: plan.entries[index]),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(localizations.editPlan),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('review-save-plan'),
                  onPressed: _isSaving || _isSaved ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isSaved
                              ? Icons.check_circle_outline_rounded
                              : Icons.save_outlined,
                        ),
                  label: Text(
                    _isSaved ? localizations.planSaved : localizations.savePlan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            key: const ValueKey<String>('start-reviewed-plan'),
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(localizations.startPlan),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving || _isSaved) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(savedWorkoutPlansProvider.notifier).save(widget.plan);
      if (!mounted) {
        return;
      }
      widget.onSaved();
      setState(() {
        _isSaving = false;
        _isSaved = true;
      });
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).planSaved)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).planSaveFailed)),
      );
    }
  }

  void _start() {
    final snapshot = ref
        .read(workoutPlanSessionProvider.notifier)
        .start(widget.plan.toWorkoutPlan());
    final firstExercise = snapshot.currentExercise;
    if (firstExercise == null) {
      return;
    }
    ref.read(selectedExerciseProvider.notifier).state = firstExercise;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPermissionScreen()),
    );
  }
}

class _PlanEntrySummary extends StatelessWidget {
  const _PlanEntrySummary({required this.index, required this.entry});

  final int index;
  final SavedWorkoutPlanEntry entry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final target = entry.target.type == WorkoutTargetType.repetitions
        ? localizations.repTargetSummary(entry.target.repetitions!)
        : localizations.holdTargetSummary(entry.target.holdDuration!.inSeconds);
    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.exerciseTitle(entry.exercise.id),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localizations.planEntrySummary(
                    sets: entry.sets,
                    target: target,
                    restSeconds: entry.restAfterSet.inSeconds,
                  ),
                  style: const TextStyle(color: Colors.white60, height: 1.35),
                ),
              ],
            ),
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
