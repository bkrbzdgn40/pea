import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_button.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/user_workout_goal.dart';
import '../../domain/models/workout_goal_template.dart';
import '../models/workout_goal.dart';

class ActiveGoalCard extends StatelessWidget {
  const ActiveGoalCard({
    super.key,
    required this.goal,
    required this.isSaving,
    required this.onEdit,
    required this.onPause,
  });

  final WorkoutGoal goal;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final unit = localizations.userGoalUnit(goal.typeId, fallback: goal.unit);
    final remaining = (goal.targetValue - goal.currentValue)
        .clamp(0, double.infinity)
        .toDouble();

    return Container(
      key: const ValueKey<String>('active-goal-card'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.analysisAccent.withValues(alpha: 0.20),
            colors.surfaceStrong,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(
          color: colors.analysisAccent.withValues(alpha: 0.48),
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -32,
            end: -18,
            child: IgnorePointer(
              child: Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.analysisAccent.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: goal.isCompleted
                            ? colors.success
                            : colors.analysisAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        localizations.activeGoal,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.foregroundMuted,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  localizations.userGoalTitle(
                    goal.typeId,
                    goal.targetValue,
                    fallback: goal.title,
                  ),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _formatValue(goal.currentValue),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: colors.foreground,
                                  fontWeight: AppFontWeights.heavy,
                                ),
                          ),
                          TextSpan(
                            text: ' / ${_formatValue(goal.targetValue)} $unit',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: colors.foregroundMuted,
                                  fontWeight: AppFontWeights.semibold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (goal.progressAvailable)
                      Text(
                        goal.isCompleted
                            ? localizations.goalCompleted
                            : localizations.goalRemaining(
                                _formatValue(remaining),
                                unit,
                              ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: goal.isCompleted
                              ? colors.success
                              : colors.foregroundMuted,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    value: goal.progressAvailable ? goal.progress : 0,
                    minHeight: 8,
                    backgroundColor: colors.outlineSubtle,
                    color: goal.isCompleted
                        ? colors.success
                        : colors.analysisAccent,
                  ),
                ),
                if (!goal.progressAvailable) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    localizations.goalProgressUnavailableShort,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.caution),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppButton(
                      label: localizations.editGoal,
                      icon: Icons.edit_outlined,
                      variant: AppButtonVariant.outline,
                      onPressed: isSaving ? null : onEdit,
                    ),
                    AppButton(
                      label: localizations.pauseGoal,
                      icon: Icons.pause_rounded,
                      variant: AppButtonVariant.ghost,
                      onPressed: isSaving ? null : onPause,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GoalSuggestionsList extends StatelessWidget {
  const GoalSuggestionsList({
    super.key,
    required this.templates,
    required this.isSaving,
    required this.onSelect,
  });

  final List<WorkoutGoalTemplate> templates;
  final bool isSaving;
  final ValueChanged<WorkoutGoalTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.muted,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < templates.length; index++) ...[
            GoalTemplateCard(
              template: templates[index],
              isSaving: isSaving,
              onSelect: () => onSelect(templates[index]),
            ),
            if (index != templates.length - 1)
              Divider(height: 1, color: colors.outlineSubtle),
          ],
        ],
      ),
    );
  }
}

class GoalTemplateCard extends StatelessWidget {
  const GoalTemplateCard({
    super.key,
    required this.template,
    required this.isSaving,
    required this.onSelect,
  });

  final WorkoutGoalTemplate template;
  final bool isSaving;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return Material(
      key: ValueKey<String>('goal-template-${template.type.storageValue}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: isSaving ? null : onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.analysisAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(
                  _goalIcon(template.type),
                  color: colors.analysisAccent,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.userGoalTitle(
                        template.type.storageValue,
                        template.defaultTarget,
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      localizations.userGoalDescription(
                        template.type.storageValue,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.foregroundMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.add_circle_outline_rounded,
                color: isSaving
                    ? colors.foregroundSubtle
                    : colors.analysisAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArchivedGoalsPanel extends StatelessWidget {
  const ArchivedGoalsPanel({
    super.key,
    required this.goals,
    required this.isSaving,
    required this.onResume,
  });

  final List<WorkoutGoal> goals;
  final bool isSaving;
  final ValueChanged<WorkoutGoal> onResume;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const ValueKey<String>('archived-goals-panel'),
      variant: AppSurfaceVariant.muted,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const PageStorageKey<String>('archived-goals-expansion-tile'),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          leading: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.foreground.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: colors.foregroundMuted,
              size: 20,
            ),
          ),
          title: Text(
            localizations.completedAndPausedGoals,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.bold,
            ),
          ),
          subtitle: Text(
            '${goals.length}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.foregroundMuted),
          ),
          children: [
            Divider(height: 1, color: colors.outlineSubtle),
            for (final goal in goals)
              _ArchivedGoalRow(
                goal: goal,
                isSaving: isSaving,
                onResume: () => onResume(goal),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedGoalRow extends StatelessWidget {
  const _ArchivedGoalRow({
    required this.goal,
    required this.isSaving,
    required this.onResume,
  });

  final WorkoutGoal goal;
  final bool isSaving;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final completed = goal.isCompleted;

    return Padding(
      key: ValueKey<String>('paused-goal-${goal.typeId}'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            color: completed ? colors.success : colors.foregroundMuted,
            size: 21,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.userGoalTitle(
                    goal.typeId,
                    goal.targetValue,
                    fallback: goal.title,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                Text(
                  completed
                      ? localizations.completedGoalStatus
                      : localizations.pausedGoalStatus,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: completed ? colors.success : colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: isSaving ? null : onResume,
            child: Text(localizations.resumeGoal),
          ),
        ],
      ),
    );
  }
}

IconData _goalIcon(WorkoutGoalType type) {
  return switch (type) {
    WorkoutGoalType.weeklySessions => Icons.calendar_today_rounded,
    WorkoutGoalType.weeklyReps => Icons.repeat_rounded,
    WorkoutGoalType.averageScore => Icons.insights_rounded,
  };
}

String _formatValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
