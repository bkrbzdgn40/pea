import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_button.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/user_workout_goal.dart';
import '../../domain/models/workout_goal_template.dart';
import '../models/workout_goal.dart';

class GoalsHeaderCard extends StatelessWidget {
  const GoalsHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.accent,
      padding: AppSpacing.headerSurfacePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: AppOpacity.subtle),
              borderRadius: BorderRadius.circular(AppRadii.compact),
            ),
            child: Icon(
              Icons.flag_rounded,
              color: colors.analysisAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.goalsHeaderTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  localizations.goalsHeaderSubtitle,
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
    final progressPercent = (goal.progress * 100).round();

    return AppSurfaceCard(
      key: const ValueKey<String>('active-goal-card'),
      variant: AppSurfaceVariant.strong,
      borderColor: goal.isCompleted ? colors.success : colors.outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      localizations.userGoalDescription(
                        goal.typeId,
                        fallback: goal.description,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (goal.isCompleted)
                Icon(Icons.check_circle_rounded, color: colors.success, size: 24),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.progressAvailable
                      ? '${_formatValue(goal.currentValue)} / ${_formatValue(goal.targetValue)} ${localizations.userGoalUnit(goal.typeId, fallback: goal.unit)}'
                      : localizations.goalProgressUnavailableShort,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
              ),
              if (goal.progressAvailable)
                Text(
                  '%$progressPercent',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.analysisAccent,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: goal.progressAvailable ? goal.progress : 0,
            minHeight: 7,
            backgroundColor: colors.outlineSubtle,
            color: goal.isCompleted ? colors.success : colors.analysisAccent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
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

    return AppSurfaceCard(
      key: ValueKey<String>('goal-template-${template.type.storageValue}'),
      variant: AppSurfaceVariant.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.analysisAccent.withValues(
                    alpha: AppOpacity.subtle,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(
                  _goalIcon(template.type),
                  color: colors.analysisAccent,
                  size: 22,
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
                      localizations.goalTargetCanChange,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton(
              label: localizations.startGoal,
              variant: AppButtonVariant.ghost,
              onPressed: isSaving ? null : onSelect,
            ),
          ),
        ],
      ),
    );
  }
}

class PausedGoalCard extends StatelessWidget {
  const PausedGoalCard({
    super.key,
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

    return AppSurfaceCard(
      key: ValueKey<String>('paused-goal-${goal.typeId}'),
      variant: AppSurfaceVariant.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.pause_circle_outline_rounded,
                color: colors.foregroundMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  localizations.userGoalTitle(
                    goal.typeId,
                    goal.targetValue,
                    fallback: goal.title,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton(
              label: localizations.resumeGoal,
              variant: AppButtonVariant.ghost,
              onPressed: isSaving ? null : onResume,
            ),
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
