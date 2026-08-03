import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../application/saved_workout_plan.dart';
import '../../application/workout_engine.dart';
import '../controllers/workout_plan_launcher.dart';
import '../providers/saved_workout_plans_provider.dart';

enum WorkoutPlanReviewResult { edit }

class WorkoutPlanReviewScreen extends ConsumerStatefulWidget {
  const WorkoutPlanReviewScreen({
    super.key,
    required this.plan,
    required this.onSaved,
    this.initiallySaved = false,
  });

  final SavedWorkoutPlan plan;
  final VoidCallback onSaved;
  final bool initiallySaved;

  @override
  ConsumerState<WorkoutPlanReviewScreen> createState() =>
      _WorkoutPlanReviewScreenState();
}

class _WorkoutPlanReviewScreenState
    extends ConsumerState<WorkoutPlanReviewScreen> {
  bool _isSaving = false;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.initiallySaved;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final plan = widget.plan;

    return AppScaffoldShell(
      title: localizations.planSummary,
      padding: EdgeInsets.zero,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);
          return Padding(
            padding: layout.pagePadding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: ListView(
                        key: const ValueKey<String>(
                          'workout-plan-review-scroll',
                        ),
                        children: <Widget>[
                          _PlanReviewHero(plan: plan),
                          SizedBox(height: layout.sectionGap),
                          AppSection(
                            title: localizations.exerciseOrder,
                            child: Column(
                              children: <Widget>[
                                for (
                                  var index = 0;
                                  index < plan.entries.length;
                                  index += 1
                                ) ...<Widget>[
                                  _PlanEntrySummary(
                                    index: index,
                                    entry: plan.entries[index],
                                  ),
                                  if (index != plan.entries.length - 1)
                                    const SizedBox(height: AppSpacing.sm),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ReviewActions(
                      isSaving: _isSaving,
                      isSaved: _isSaved,
                      onEdit: () =>
                          Navigator.pop(context, WorkoutPlanReviewResult.edit),
                      onSave: _save,
                      onStart: _start,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
        SnackBar(
          content: Text(AppLocalizations.of(context).planSaved),
          margin: EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            _reviewActionsSnackBarOffset(context),
          ),
        ),
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
    launchWorkoutPlan(context: context, ref: ref, plan: widget.plan);
  }
}

class _PlanReviewHero extends StatelessWidget {
  const _PlanReviewHero({required this.plan});

  final SavedWorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    return AppSurfaceCard(
      variant: AppSurfaceVariant.accent,
      radius: AppRadii.large,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.analysisAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.surface),
                  border: Border.all(
                    color: colors.analysisAccent.withValues(alpha: 0.34),
                  ),
                ),
                child: Icon(
                  Icons.fact_check_rounded,
                  color: colors.analysisAccent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colors.foreground,
                            fontWeight: AppFontWeights.heavy,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      localizations.savedPlanSummary(
                        exercises: plan.entries.length,
                        sets: plan.totalSets,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              AppStatusChip(
                label: '${plan.rounds}× ${localizations.roundCount}',
                tone: AppStatusTone.accent,
                icon: Icons.loop_rounded,
              ),
              AppStatusChip(
                label:
                    '${plan.entries.length} ${localizations.exerciseEntries}',
                tone: AppStatusTone.neutral,
                icon: Icons.view_agenda_outlined,
              ),
              AppStatusChip(
                label: '${plan.totalSets} ${localizations.totalPlannedSets}',
                tone: AppStatusTone.success,
                icon: Icons.checklist_rounded,
              ),
              AppStatusChip(
                label:
                    '${localizations.estimatedRest}: ${_formatDuration(plan.estimatedRestDuration)}',
                tone: AppStatusTone.caution,
                icon: Icons.timer_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({
    required this.isSaving,
    required this.isSaved,
    required this.onEdit,
    required this.onSave,
    required this.onStart,
  });

  final bool isSaving;
  final bool isSaved;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final edit = AppButton(
      key: const ValueKey<String>('review-edit-plan'),
      label: localizations.editPlan,
      icon: Icons.edit_rounded,
      variant: AppButtonVariant.outline,
      expand: true,
      onPressed: onEdit,
    );
    final save = AppButton(
      key: const ValueKey<String>('review-save-plan'),
      label: isSaved ? localizations.planSaved : localizations.savePlan,
      icon: isSaved ? Icons.check_circle_outline_rounded : Icons.save_outlined,
      variant: AppButtonVariant.secondary,
      isLoading: isSaving,
      expand: true,
      onPressed: isSaving || isSaved ? null : onSave,
    );
    final start = AppButton(
      key: const ValueKey<String>('start-reviewed-plan'),
      label: localizations.startPlan,
      icon: Icons.play_arrow_rounded,
      expand: true,
      onPressed: onStart,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 560 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.4;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              start,
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  Expanded(child: edit),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: save),
                ],
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: edit),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: save),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: start),
          ],
        );
      },
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
    final colors = context.semanticColors;
    final target = entry.target.type == WorkoutTargetType.repetitions
        ? localizations.repTargetSummary(entry.target.repetitions!)
        : localizations.holdTargetSummary(entry.target.holdDuration!.inSeconds);
    return AppSurfaceCard(
      variant: AppSurfaceVariant.strong,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.compact),
              border: Border.all(
                color: colors.analysisAccent.withValues(alpha: 0.30),
              ),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colors.analysisAccent,
                fontWeight: AppFontWeights.heavy,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  localizations.exerciseTitle(entry.exercise.id),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  localizations.planEntrySummary(
                    sets: entry.sets,
                    target: target,
                    restSeconds: entry.normalizedRestAfterSet.inSeconds,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _reviewActionsSnackBarOffset(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final availableWidth = mediaQuery.size.width - (AppSpacing.lg * 2);
  final stackActions =
      availableWidth < 560 || mediaQuery.textScaler.scale(1) >= 1.4;
  final actionsHeight = stackActions
      ? (AppTouchTargets.minimum * 2) + AppSpacing.xs
      : AppTouchTargets.minimum;
  return actionsHeight + AppSpacing.md + AppSpacing.xl;
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
