import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_button.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../../challenges/domain/models/challenge_metric.dart';
import '../../../challenges/domain/models/challenge_period.dart';
import '../../../challenges/domain/models/medal_tier.dart';
import '../../../workout_analysis/domain/models/exercise_type.dart';
import '../models/challenge_goals_state.dart';

const Color _bronzeColor = Color(0xFFC77A44);
const Color _silverColor = Color(0xFFB8C2CC);
const Color _goldColor = Color(0xFFF2C94C);

class ChallengePeriodSelector extends StatelessWidget {
  const ChallengePeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ChallengePeriod selected;
  final ValueChanged<ChallengePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return Container(
      key: const ValueKey<String>('challenge-period-selector'),
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.compact),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: Wrap(
        spacing: AppSpacing.xxs,
        runSpacing: AppSpacing.xxs,
        children: ChallengePeriod.values
            .map((period) {
              final isSelected = period == selected;
              final label = switch (period) {
                ChallengePeriod.daily => localizations.dailyPeriod,
                ChallengePeriod.weekly => localizations.weeklyPeriod,
                ChallengePeriod.monthly => localizations.monthlyPeriod,
              };
              return Material(
                color: isSelected
                    ? colors.analysisAccent.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.small),
                child: InkWell(
                  key: ValueKey<String>(
                    'challenge-period-${period.storageValue}',
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  onTap: () => onChanged(period),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? colors.foreground
                            : colors.foregroundMuted,
                        fontWeight: isSelected
                            ? AppFontWeights.bold
                            : AppFontWeights.medium,
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class MedalChallengeCard extends StatelessWidget {
  const MedalChallengeCard({
    super.key,
    required this.view,
    required this.onExerciseSelected,
  });

  final ChallengeGoalProgressView view;
  final ValueChanged<ExerciseType> onExerciseSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final progress = view.progress;
    final effectiveTier = view.effectiveTier;
    final displayTier = effectiveTier == MedalTier.none
        ? MedalTier.bronze
        : effectiveTier;
    final medalColor = _medalColor(displayTier);
    final goldTarget = progress.thresholds.gold.toDouble();
    final goldProgress = goldTarget <= 0
        ? 0.0
        : (view.displayValue / goldTarget).clamp(0, 1).toDouble();

    return Container(
      key: const ValueKey<String>('medal-challenge-card'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            medalColor.withValues(alpha: 0.18),
            colors.surfaceStrong,
            colors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: medalColor.withValues(alpha: 0.42)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: medalColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final info = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExerciseSelector(
                      selected: progress.definition.exerciseType,
                      onSelected: onExerciseSelected,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _periodContext(localizations, progress.period),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.foregroundMuted,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _progressLabel(
                        localizations,
                        progress.definition.metric,
                        view.displayValue,
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                  ],
                );

                if (constraints.maxWidth < 330) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MedalEmblem(
                        tier: displayTier,
                        earned: effectiveTier != MedalTier.none,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      info,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MedalEmblem(
                      tier: displayTier,
                      earned: effectiveTier != MedalTier.none,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: info),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _nextMedalMessage(localizations, view),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: view.hasReachedGold
                    ? _goldColor
                    : colors.foregroundMuted,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: goldProgress,
                minHeight: 9,
                backgroundColor: colors.outlineSubtle,
                color: medalColor,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final milestones = <Widget>[
                  _MedalMilestone(
                    tier: MedalTier.bronze,
                    threshold: progress.thresholds.bronze,
                    earned: effectiveTier.rank >= MedalTier.bronze.rank,
                    metric: progress.definition.metric,
                  ),
                  _MedalMilestone(
                    tier: MedalTier.silver,
                    threshold: progress.thresholds.silver,
                    earned: effectiveTier.rank >= MedalTier.silver.rank,
                    metric: progress.definition.metric,
                  ),
                  _MedalMilestone(
                    tier: MedalTier.gold,
                    threshold: progress.thresholds.gold,
                    earned: effectiveTier.rank >= MedalTier.gold.rank,
                    metric: progress.definition.metric,
                  ),
                ];
                if (constraints.maxWidth < 380) {
                  return Column(
                    children: [
                      for (
                        var index = 0;
                        index < milestones.length;
                        index++
                      ) ...[
                        milestones[index],
                        if (index != milestones.length - 1)
                          const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var index = 0; index < milestones.length; index++) ...[
                      Expanded(child: milestones[index]),
                      if (index != milestones.length - 1)
                        const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class NearbyMedalGoalsList extends StatelessWidget {
  const NearbyMedalGoalsList({
    super.key,
    required this.items,
    required this.onSelected,
  });

  final List<ChallengeGoalProgressView> items;
  final ValueChanged<ExerciseType> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    if (items.isEmpty) {
      return AppSurfaceCard(
        key: const ValueKey<String>('nearby-medal-goals-empty'),
        variant: AppSurfaceVariant.muted,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined, color: colors.analysisAccent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                localizations.noNearbyMedalGoals,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.foregroundMuted,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AppSurfaceCard(
      key: const ValueKey<String>('nearby-medal-goals-list'),
      variant: AppSurfaceVariant.muted,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _NearbyGoalRow(
              view: items[index],
              onTap: () =>
                  onSelected(items[index].progress.definition.exerciseType),
            ),
            if (index != items.length - 1)
              Divider(height: 1, color: colors.outlineSubtle),
          ],
        ],
      ),
    );
  }
}

class ChallengeGoalsLoadingCard extends StatelessWidget {
  const ChallengeGoalsLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const ValueKey<String>('challenge-goals-loading'),
      variant: AppSurfaceVariant.muted,
      child: SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: colors.analysisAccent),
        ),
      ),
    );
  }
}

class ChallengeGoalsErrorCard extends StatelessWidget {
  const ChallengeGoalsErrorCard({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const ValueKey<String>('challenge-goals-error'),
      variant: AppSurfaceVariant.muted,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sync_problem_rounded, color: colors.caution),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.medalProgressLoadFailed,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: localizations.retry,
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.ghost,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSelector extends StatelessWidget {
  const _ExerciseSelector({required this.selected, required this.onSelected});

  final ExerciseType selected;
  final ValueChanged<ExerciseType> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return PopupMenuButton<ExerciseType>(
      key: const ValueKey<String>('challenge-exercise-selector'),
      tooltip: localizations.selectExercise,
      onSelected: onSelected,
      itemBuilder: (context) => ExerciseType.values
          .map(
            (exercise) => PopupMenuItem<ExerciseType>(
              value: exercise,
              child: Text(localizations.exerciseTitle(exercise.id)),
            ),
          )
          .toList(growable: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              localizations.exerciseTitle(selected.id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foreground,
                fontWeight: AppFontWeights.heavy,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colors.foregroundMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _MedalEmblem extends StatelessWidget {
  const _MedalEmblem({required this.tier, required this.earned});

  final MedalTier tier;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final medalColor = _medalColor(tier);

    return SizedBox(
      width: 78,
      height: 82,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 44,
            left: 15,
            child: Transform.rotate(
              angle: 0.16,
              child: Container(
                width: 18,
                height: 34,
                decoration: BoxDecoration(
                  color: medalColor.withValues(alpha: earned ? 0.72 : 0.24),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          Positioned(
            top: 44,
            right: 15,
            child: Transform.rotate(
              angle: -0.16,
              child: Container(
                width: 18,
                height: 34,
                decoration: BoxDecoration(
                  color: medalColor.withValues(alpha: earned ? 0.72 : 0.24),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  medalColor.withValues(alpha: earned ? 1 : 0.42),
                  medalColor.withValues(alpha: earned ? 0.62 : 0.18),
                ],
              ),
              border: Border.all(
                color: medalColor.withValues(alpha: earned ? 0.95 : 0.38),
                width: 2,
              ),
              boxShadow: earned
                  ? <BoxShadow>[
                      BoxShadow(
                        color: medalColor.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Icon(
              earned
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_outline_rounded,
              color: earned ? colors.canvas : colors.foregroundMuted,
              size: 31,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedalMilestone extends StatelessWidget {
  const _MedalMilestone({
    required this.tier,
    required this.threshold,
    required this.earned,
    required this.metric,
  });

  final MedalTier tier;
  final int threshold;
  final bool earned;
  final ChallengeMetric metric;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final medalColor = _medalColor(tier);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: earned
            ? medalColor.withValues(alpha: 0.12)
            : colors.surfaceMuted.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(
          color: earned
              ? medalColor.withValues(alpha: 0.42)
              : colors.outlineSubtle,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            earned ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: earned ? medalColor : colors.foregroundSubtle,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tierLabel(localizations, tier),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: earned ? medalColor : colors.foregroundMuted,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
                Text(
                  '$threshold ${_unitLabel(localizations, metric)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.foregroundMuted,
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

class _NearbyGoalRow extends StatelessWidget {
  const _NearbyGoalRow({required this.view, required this.onTap});

  final ChallengeGoalProgressView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final progress = view.progress;
    final nextTier = view.nextTier ?? MedalTier.gold;
    final nextThreshold = view.nextThreshold ?? progress.thresholds.gold;
    final ratio = nextThreshold <= 0
        ? 0.0
        : (view.displayValue / nextThreshold).clamp(0, 1).toDouble();
    final medalColor = _medalColor(nextTier);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: medalColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: medalColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            localizations.exerciseTitle(
                              progress.definition.exerciseType.id,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.foreground,
                                  fontWeight: AppFontWeights.semibold,
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${_formatValue(view.displayValue)} / $nextThreshold',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.foregroundMuted,
                                fontWeight: AppFontWeights.semibold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: colors.outlineSubtle,
                        color: medalColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _tierLabel(localizations, nextTier),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: medalColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_rounded, color: colors.foregroundSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

String _progressLabel(
  AppLocalizations localizations,
  ChallengeMetric metric,
  double value,
) {
  final formatted = _formatValue(value);
  return switch (metric) {
    ChallengeMetric.validRepetitions => localizations.trustedRepProgress(
      formatted,
    ),
    ChallengeMetric.trustedHoldSeconds => localizations.trustedHoldProgress(
      formatted,
    ),
  };
}

String _nextMedalMessage(
  AppLocalizations localizations,
  ChallengeGoalProgressView view,
) {
  if (view.hasReachedGold) {
    return localizations.medalGoldCompleted;
  }
  final nextTier = view.nextTier ?? MedalTier.bronze;
  final remaining = _formatValue(view.remainingToNextTier ?? 0);
  return localizations.medalRemaining(
    _tierLabel(localizations, nextTier),
    remaining,
    _unitLabel(localizations, view.progress.definition.metric),
  );
}

String _periodContext(AppLocalizations localizations, ChallengePeriod period) {
  return switch (period) {
    ChallengePeriod.daily => localizations.todayPeriod,
    ChallengePeriod.weekly => localizations.thisWeekPeriod,
    ChallengePeriod.monthly => localizations.thisMonthPeriod,
  };
}

String _tierLabel(AppLocalizations localizations, MedalTier tier) {
  return switch (tier) {
    MedalTier.none => localizations.medalNotEarned,
    MedalTier.bronze => localizations.bronzeMedal,
    MedalTier.silver => localizations.silverMedal,
    MedalTier.gold => localizations.goldMedal,
  };
}

String _unitLabel(AppLocalizations localizations, ChallengeMetric metric) {
  return switch (metric) {
    ChallengeMetric.validRepetitions => localizations.pick(
      tr: 'tekrar',
      en: 'reps',
    ),
    ChallengeMetric.trustedHoldSeconds => localizations.pick(tr: 'sn', en: 's'),
  };
}

Color _medalColor(MedalTier tier) {
  return switch (tier) {
    MedalTier.none || MedalTier.bronze => _bronzeColor,
    MedalTier.silver => _silverColor,
    MedalTier.gold => _goldColor,
  };
}

String _formatValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
