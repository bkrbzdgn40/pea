import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/localization/app_localizations.dart';
import '../../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../../app/theme/app_design_tokens.dart';
import '../../../../../app/theme/app_semantic_colors.dart';
import '../../../application/saved_workout_plan.dart';
import '../../../application/workout_engine.dart';

class SavedPlansSection extends StatelessWidget {
  const SavedPlansSection({
    super.key,
    required this.plans,
    required this.onDelete,
    required this.onNew,
    required this.onReview,
    required this.onEdit,
    required this.onStart,
  });

  final AsyncValue<List<SavedWorkoutPlan>> plans;
  final ValueChanged<SavedWorkoutPlan> onDelete;
  final VoidCallback onNew;
  final ValueChanged<SavedWorkoutPlan> onReview;
  final ValueChanged<SavedWorkoutPlan> onEdit;
  final ValueChanged<SavedWorkoutPlan> onStart;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AppSection(
      title: localizations.savedPlans,
      description: localizations.plannedWorkoutBuilderIntro,
      trailing: AppButton(
        key: const ValueKey<String>('new-workout-plan-secondary'),
        label: localizations.newPlan,
        icon: Icons.add_rounded,
        variant: AppButtonVariant.secondary,
        onPressed: onNew,
      ),
      child: plans.when(
        data: (items) {
          if (items.isEmpty) {
            return AppSurfaceCard(
              variant: AppSurfaceVariant.muted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(
                    Icons.playlist_add_rounded,
                    size: 44,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    localizations.noSavedPlans,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.semanticColors.foreground,
                      fontWeight: AppFontWeights.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: localizations.newPlan,
                    icon: Icons.add_rounded,
                    expand: true,
                    onPressed: onNew,
                  ),
                ],
              ),
            );
          }
          return Column(
            key: const ValueKey<String>('saved-workout-plan-list'),
            children: <Widget>[
              for (var index = 0; index < items.length; index += 1) ...<Widget>[
                SavedPlanCard(
                  plan: items[index],
                  onReview: () => onReview(items[index]),
                  onEdit: () => onEdit(items[index]),
                  onStart: () => onStart(items[index]),
                  onDelete: () => onDelete(items[index]),
                ),
                if (index != items.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
        loading: () => const AppSurfaceCard(
          variant: AppSurfaceVariant.muted,
          child: LinearProgressIndicator(),
        ),
        error: (_, _) => AppFeedbackBanner(
          message: localizations.savedPlansLoadFailed,
          tone: AppStatusTone.caution,
        ),
      ),
    );
  }
}

class SavedPlanCard extends StatelessWidget {
  const SavedPlanCard({
    super.key,
    required this.plan,
    required this.onReview,
    required this.onEdit,
    required this.onStart,
    required this.onDelete,
  });

  final SavedWorkoutPlan plan;
  final VoidCallback onReview;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    return AppSurfaceCard(
      key: ValueKey<String>('saved-plan-card-${plan.id}'),
      variant: AppSurfaceVariant.strong,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      radius: AppRadii.large,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('load-plan-${plan.id}'),
          onTap: onReview,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.analysisAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.compact),
                        border: Border.all(
                          color: colors.analysisAccent.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: colors.analysisAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            plan.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.foregroundMuted),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      key: ValueKey<String>('plan-menu-${plan.id}'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).moreButtonTooltip,
                      onSelected: (value) {
                        if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (_) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.delete_outline_rounded),
                              const SizedBox(width: AppSpacing.xs),
                              Text(localizations.deletePlan),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
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
                      label: '${plan.totalSets} ${localizations.setCount}',
                      tone: AppStatusTone.success,
                      icon: Icons.checklist_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    key: ValueKey<String>('plan-exercise-strip-${plan.id}'),
                    scrollDirection: Axis.horizontal,
                    itemCount: plan.entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, index) => _PlanExercisePill(
                      index: index,
                      entry: plan.entries[index],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack =
                        constraints.maxWidth < 360 ||
                        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                    final edit = AppButton(
                      key: ValueKey<String>('edit-plan-${plan.id}'),
                      label: localizations.editPlan,
                      icon: Icons.edit_rounded,
                      variant: AppButtonVariant.outline,
                      expand: true,
                      onPressed: onEdit,
                    );
                    final start = AppButton(
                      key: ValueKey<String>('start-plan-${plan.id}'),
                      label: localizations.startPlan,
                      icon: Icons.play_arrow_rounded,
                      expand: true,
                      onPressed: onStart,
                    );
                    if (stack) {
                      return Column(
                        children: <Widget>[
                          start,
                          const SizedBox(height: AppSpacing.xs),
                          edit,
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(child: edit),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: start),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanExercisePill extends StatelessWidget {
  const _PlanExercisePill({required this.index, required this.entry});

  final int index;
  final SavedWorkoutPlanEntry entry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final isHold = entry.target.type == WorkoutTargetType.holdDuration;
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colors.analysisAccent,
                fontSize: 12,
                fontWeight: AppFontWeights.heavy,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            isHold ? Icons.timer_outlined : Icons.repeat_rounded,
            size: 17,
            color: colors.foregroundMuted,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              localizations.exerciseTitle(entry.exercise.id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.foreground,
                fontWeight: AppFontWeights.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
