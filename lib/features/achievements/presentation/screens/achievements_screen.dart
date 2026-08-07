import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_section.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/presentation/widgets/async_state_view.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../../challenges/domain/models/challenge_metric.dart';
import '../../../challenges/domain/models/challenge_period.dart';
import '../../../rewards/domain/models/achievement_reward.dart';
import '../../../rewards/domain/models/challenge_medal_reward.dart';
import '../../../rewards/domain/models/user_reward.dart';
import '../../../rewards/presentation/widgets/reward_marks.dart';
import '../models/achievement.dart';
import '../providers/achievements_provider.dart';

enum AchievementsView { achievements, rewardHistory }

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({
    super.key,
    this.initialView = AchievementsView.achievements,
  });

  final AchievementsView initialView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final achievementsState = ref.watch(achievementsProvider);

    return AppScaffoldShell(
      title: localizations.achievements,
      currentPage: AppDestination.achievements,
      padding: EdgeInsets.zero,
      body: AsyncStateView<AchievementsState>(
        value: achievementsState,
        errorBuilder: (context, error, stackTrace) => AppErrorView(
          message: localizations.achievementsLoadFailed,
          actionLabel: localizations.retry,
          onAction: () => ref.invalidate(achievementsProvider),
        ),
        dataBuilder: (context, state) {
          if (state.source == AchievementsDataSource.noUser) {
            return Padding(
              padding: AppSpacing.pagePadding,
              child: AppEmptyView(
                title: localizations.achievementsSignInTitle,
                message: localizations.achievementsSignInMessage,
                icon: Icons.person_outline_rounded,
              ),
            );
          }
          if (state.source == AchievementsDataSource.error) {
            return Padding(
              padding: AppSpacing.pagePadding,
              child: AppErrorView(
                message: localizations.achievementsLoadFailed,
                actionLabel: localizations.retry,
                onAction: () => ref.invalidate(achievementsProvider),
              ),
            );
          }
          return _AchievementsContent(state: state, initialView: initialView);
        },
      ),
    );
  }
}

enum _RewardKindFilter { all, medals, achievements }

class _AchievementsContent extends ConsumerStatefulWidget {
  const _AchievementsContent({required this.state, required this.initialView});

  final AchievementsState state;
  final AchievementsView initialView;

  @override
  ConsumerState<_AchievementsContent> createState() =>
      _AchievementsContentState();
}

class _AchievementsContentState extends ConsumerState<_AchievementsContent> {
  late AchievementsView _view;

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
  }

  _RewardKindFilter _historyFilter = _RewardKindFilter.all;
  ChallengePeriod? _periodFilter;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(achievementsProvider);
        try {
          await ref.read(achievementsProvider.future);
        } catch (_) {
          // The screen already owns the retry/error presentation.
        }
      },
      child: ListView(
        key: const PageStorageKey<String>('achievements-content'),
        padding: AppSpacing.pagePadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _RewardOverviewCard(state: state),
          const SizedBox(height: AppSpacing.lg),
          _ViewSwitcher(
            selected: _view,
            onChanged: (value) => setState(() => _view = value),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (_view == AchievementsView.achievements)
            _buildAchievements(context, state)
          else
            _buildHistory(context, state),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildAchievements(BuildContext context, AchievementsState state) {
    final localizations = AppLocalizations.of(context);
    final earned = state.earnedAchievements;
    final next = state.nextAchievement;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSection(
          title: localizations.earnedAchievementsTitle(earned.length),
          description: localizations.earnedAchievementsDescription,
          child: earned.isEmpty
              ? AppSurfaceCard(
                  variant: AppSurfaceVariant.muted,
                  child: _InlineEmptyState(
                    icon: Icons.workspace_premium_outlined,
                    title: localizations.noEarnedAchievementsTitle,
                    message: localizations.noEarnedAchievementsMessage,
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < earned.length; index++) ...[
                      _EarnedAchievementCard(achievement: earned[index]),
                      if (index != earned.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppSection(
          title: localizations.nextAchievementTitle,
          description: localizations.nextAchievementDescription,
          child: next == null
              ? AppSurfaceCard(
                  variant: AppSurfaceVariant.accent,
                  child: _InlineEmptyState(
                    icon: Icons.auto_awesome_rounded,
                    title: localizations.allVisibleAchievementsCompleted,
                    message: localizations.moreAchievementsHint,
                  ),
                )
              : _NextAchievementCard(achievement: next),
        ),
        const SizedBox(height: AppSpacing.lg),
        _DiscoveryHint(message: localizations.moreAchievementsHint),
      ],
    );
  }

  Widget _buildHistory(BuildContext context, AchievementsState state) {
    final localizations = AppLocalizations.of(context);
    final filtered = state.rewards.where(_matchesHistoryFilter).toList();

    return AppSection(
      title: localizations.rewardHistoryTab,
      description: localizations.rewardHistoryDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HistoryFilters(
            selected: _historyFilter,
            selectedPeriod: _periodFilter,
            onKindChanged: (value) {
              setState(() {
                _historyFilter = value;
                if (value != _RewardKindFilter.medals) {
                  _periodFilter = null;
                }
              });
            },
            onPeriodChanged: (value) {
              setState(() => _periodFilter = value);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          if (state.rewards.isEmpty)
            AppSurfaceCard(
              variant: AppSurfaceVariant.muted,
              child: _InlineEmptyState(
                icon: Icons.history_toggle_off_rounded,
                title: localizations.rewardHistoryEmptyTitle,
                message: localizations.rewardHistoryEmptyMessage,
              ),
            )
          else if (filtered.isEmpty)
            AppSurfaceCard(
              variant: AppSurfaceVariant.muted,
              child: _InlineEmptyState(
                icon: Icons.filter_alt_off_rounded,
                title: localizations.noRewardsForFilter,
                message: localizations.rewardHistoryDescription,
              ),
            )
          else
            _RewardTimeline(rewards: filtered),
        ],
      ),
    );
  }

  bool _matchesHistoryFilter(UserReward reward) {
    switch (_historyFilter) {
      case _RewardKindFilter.all:
        return true;
      case _RewardKindFilter.achievements:
        return reward is AchievementReward;
      case _RewardKindFilter.medals:
        if (reward is! ChallengeMedalReward) {
          return false;
        }
        return _periodFilter == null || reward.period == _periodFilter;
    }
  }
}

class _RewardOverviewCard extends StatelessWidget {
  const _RewardOverviewCard({required this.state});

  final AchievementsState state;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final earnedCount = state.earnedAchievements.length;

    return Container(
      key: const ValueKey<String>('reward-overview-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.analysisAccent.withValues(alpha: 0.18),
            AppColors.achievementExplore.withValues(alpha: 0.10),
            colors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(
          color: colors.analysisAccent.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.analysisAccent.withValues(alpha: 0.14),
              border: Border.all(
                color: colors.analysisAccent.withValues(alpha: 0.42),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.emoji_events_rounded,
              color: colors.analysisAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.achievementsOverviewTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  localizations.achievementsOverviewSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  localizations.rewardsOverviewCount(
                    earnedCount,
                    state.medalCount,
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.analysisAccent,
                    fontWeight: AppFontWeights.bold,
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

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.selected, required this.onChanged});

  final AchievementsView selected;
  final ValueChanged<AchievementsView> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.compact),
        border: Border.all(color: colors.outlineSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ViewSwitchButton(
              key: const ValueKey<String>('achievements-view-button'),
              label: localizations.achievementsTab,
              icon: Icons.workspace_premium_rounded,
              selected: selected == AchievementsView.achievements,
              onTap: () => onChanged(AchievementsView.achievements),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: _ViewSwitchButton(
              key: const ValueKey<String>('reward-history-view-button'),
              label: localizations.rewardHistoryTab,
              icon: Icons.history_rounded,
              selected: selected == AchievementsView.rewardHistory,
              onTap: () => onChanged(AchievementsView.rewardHistory),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewSwitchButton extends StatelessWidget {
  const _ViewSwitchButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final foreground = selected ? colors.foreground : colors.foregroundMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? colors.analysisAccent.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.small),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTouchTargets.minimum,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: foreground, size: 19),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? AppFontWeights.bold
                              : AppFontWeights.medium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EarnedAchievementCard extends StatelessWidget {
  const _EarnedAchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final accent = achievementAccentForId(achievement.id);
    final earnedAt = achievement.unlockedAtUtc;
    final dateLabel = earnedAt == null
        ? localizations.recentlyEarned
        : MaterialLocalizations.of(
            context,
          ).formatMediumDate(earnedAt.toLocal());
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    Widget buildCopy({required bool stackedHeader}) {
      final title = Text(
        localizations.achievementTitle(
          achievement.id,
          fallback: achievement.title,
        ),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: colors.foreground,
          fontWeight: AppFontWeights.bold,
        ),
      );
      final date = Text(
        dateLabel,
        textAlign: stackedHeader ? TextAlign.start : TextAlign.end,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.foregroundSubtle),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stackedHeader) ...[
            title,
            const SizedBox(height: AppSpacing.xxs),
            date,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.sm),
                date,
              ],
            ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            localizations.achievementDescription(
              achievement.id,
              fallback: achievement.description,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foregroundMuted,
              height: 1.35,
            ),
          ),
          if (achievement.isSecret) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.secretAchievement,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: AppFontWeights.bold,
              ),
            ),
          ],
        ],
      );
    }

    return AppSurfaceCard(
      key: ValueKey<String>('achievement-earned-${achievement.id}'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedLayout =
              constraints.maxWidth < 260 ||
              (textScale >= 1.2 && constraints.maxWidth < 320);

          if (useStackedLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AchievementBadgeMark(
                  achievementId: achievement.id,
                  accent: accent,
                  secret: achievement.isSecret,
                ),
                const SizedBox(height: AppSpacing.sm),
                buildCopy(stackedHeader: true),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AchievementBadgeMark(
                achievementId: achievement.id,
                accent: accent,
                secret: achievement.isSecret,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: buildCopy(stackedHeader: false)),
            ],
          );
        },
      ),
    );
  }
}

class _NextAchievementCard extends StatelessWidget {
  const _NextAchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final accent = achievementAccentForId(achievement.id);
    final current = achievement.current.clamp(0, achievement.target).toInt();
    final target = achievement.target;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    final achievementCopy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.achievementTitle(
            achievement.id,
            fallback: achievement.title,
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.foreground,
            fontWeight: AppFontWeights.heavy,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          localizations.achievementDescription(
            achievement.id,
            fallback: achievement.description,
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.foregroundMuted,
            height: 1.35,
          ),
        ),
      ],
    );

    return AppSurfaceCard(
      key: const ValueKey<String>('next-achievement-card'),
      color: accent.withValues(alpha: 0.075),
      borderColor: accent.withValues(alpha: 0.36),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedLayout =
              constraints.maxWidth < 280 ||
              (textScale >= 1.2 && constraints.maxWidth < 340);
          final remainingLabel = Text(
            localizations.achievementRemaining(achievement.id, current, target),
            textAlign: useStackedLayout ? TextAlign.start : TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: accent,
              fontWeight: AppFontWeights.semibold,
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (useStackedLayout) ...[
                AchievementBadgeMark(
                  achievementId: achievement.id,
                  accent: accent,
                  secret: achievement.isSecret,
                  emphasized: true,
                ),
                const SizedBox(height: AppSpacing.md),
                achievementCopy,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AchievementBadgeMark(
                      achievementId: achievement.id,
                      accent: accent,
                      secret: achievement.isSecret,
                      emphasized: true,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: achievementCopy),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              if (useStackedLayout) ...[
                Text(
                  '$current / $target',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                remainingLabel,
              ] else
                Row(
                  children: [
                    Text(
                      '$current / $target',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: remainingLabel,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedRewardProgress(
                value: achievement.normalizedProgress,
                backgroundColor: colors.outlineSubtle,
                color: accent,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiscoveryHint extends StatelessWidget {
  const _DiscoveryHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Row(
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 17,
          color: colors.foregroundSubtle,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.foregroundSubtle),
          ),
        ),
      ],
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.selected,
    required this.selectedPeriod,
    required this.onKindChanged,
    required this.onPeriodChanged,
  });

  final _RewardKindFilter selected;
  final ChallengePeriod? selectedPeriod;
  final ValueChanged<_RewardKindFilter> onKindChanged;
  final ValueChanged<ChallengePeriod?> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _HistoryFilterChip(
              key: const ValueKey<String>('reward-filter-all'),
              label: localizations.allRewards,
              selected: selected == _RewardKindFilter.all,
              onTap: () => onKindChanged(_RewardKindFilter.all),
            ),
            _HistoryFilterChip(
              key: const ValueKey<String>('reward-filter-medals'),
              label: localizations.medalsOnly,
              selected: selected == _RewardKindFilter.medals,
              onTap: () => onKindChanged(_RewardKindFilter.medals),
            ),
            _HistoryFilterChip(
              key: const ValueKey<String>('reward-filter-achievements'),
              label: localizations.achievementsOnly,
              selected: selected == _RewardKindFilter.achievements,
              onTap: () => onKindChanged(_RewardKindFilter.achievements),
            ),
          ],
        ),
        if (selected == _RewardKindFilter.medals) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _HistoryFilterChip(
                key: const ValueKey<String>('reward-period-all'),
                label: localizations.allRewards,
                selected: selectedPeriod == null,
                compact: true,
                onTap: () => onPeriodChanged(null),
              ),
              for (final period in ChallengePeriod.values)
                _HistoryFilterChip(
                  key: ValueKey<String>('reward-period-${period.storageValue}'),
                  label: localizations.rewardPeriodContext(period.storageValue),
                  selected: selectedPeriod == period,
                  compact: true,
                  onTap: () => onPeriodChanged(period),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? colors.analysisAccent.withValues(alpha: 0.13)
              : colors.surfaceMuted,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected
                  ? colors.analysisAccent.withValues(alpha: 0.5)
                  : colors.outlineSubtle,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppTouchTargets.minimum,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.sm : AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colors.analysisAccent
                          : colors.foregroundMuted,
                      fontWeight: selected
                          ? AppFontWeights.bold
                          : AppFontWeights.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardTimeline extends StatelessWidget {
  const _RewardTimeline({required this.rewards});

  final List<UserReward> rewards;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? previousMonthKey;

    for (final reward in rewards) {
      final localDate = reward.historyAtUtc.toLocal();
      final monthKey = '${localDate.year}-${localDate.month}';
      if (monthKey != previousMonthKey) {
        if (children.isNotEmpty) {
          children.add(const SizedBox(height: AppSpacing.lg));
        }
        children.add(_MonthHeader(date: localDate));
        children.add(const SizedBox(height: AppSpacing.sm));
        previousMonthKey = monthKey;
      } else {
        children.add(const SizedBox(height: AppSpacing.sm));
      }
      children.add(_RewardHistoryCard(reward: reward));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Text(
      MaterialLocalizations.of(context).formatMonthYear(date),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: colors.foreground,
        fontWeight: AppFontWeights.bold,
      ),
    );
  }
}

class _RewardHistoryCard extends StatelessWidget {
  const _RewardHistoryCard({required this.reward});

  final UserReward reward;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(reward.historyAtUtc.toLocal());
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return AppSurfaceCard(
      key: ValueKey<String>('reward-history-${reward.id}'),
      variant: AppSurfaceVariant.muted,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useStackedLayout =
              constraints.maxWidth < 270 ||
              (textScale >= 1.3 && constraints.maxWidth < 360);
          final dateWidget = Text(
            date,
            textAlign: useStackedLayout ? TextAlign.start : TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.foregroundSubtle),
          );

          if (useStackedLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rewardMark(context, reward),
                const SizedBox(height: AppSpacing.sm),
                _rewardCopy(context, reward),
                const SizedBox(height: AppSpacing.xs),
                dateWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rewardMark(context, reward),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _rewardCopy(context, reward)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: dateWidget),
            ],
          );
        },
      ),
    );
  }

  Widget _rewardMark(BuildContext context, UserReward reward) {
    if (reward is ChallengeMedalReward) {
      return MedalBadgeMark(tier: reward.highestTier);
    }
    final achievement = reward as AchievementReward;
    return AchievementBadgeMark(
      achievementId: achievement.achievementId,
      accent: achievementAccentForId(achievement.achievementId),
      secret: isSecretAchievementId(achievement.achievementId),
    );
  }

  Widget _rewardCopy(BuildContext context, UserReward reward) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    if (reward is AchievementReward) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.achievementRewardLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: achievementAccentForId(reward.achievementId),
              fontWeight: AppFontWeights.bold,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            localizations.achievementTitle(reward.achievementId),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            localizations.achievementDescription(reward.achievementId),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.foregroundMuted,
              height: 1.3,
            ),
          ),
          if (reward.isBackfilled) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.backfilledRewardLabel,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.foregroundSubtle),
            ),
          ],
        ],
      );
    }

    final medal = reward as ChallengeMedalReward;
    final medalLabel = medalLabelForTier(localizations, medal.highestTier);
    final periodLabel = localizations.rewardPeriodContext(
      medal.period.storageValue,
    );
    final progress = medal.metric == ChallengeMetric.validRepetitions
        ? localizations.trustedRepProgress(
            medal.progressValueAtHighestTier.round().toString(),
          )
        : localizations.trustedHoldProgress(
            _formatRewardNumber(medal.progressValueAtHighestTier),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          medalLabel.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: medalColorForTier(medal.highestTier),
            fontWeight: AppFontWeights.bold,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          localizations.medalRewardTitle(
            localizations.exerciseTitle(medal.exerciseType.id),
            periodLabel,
            medalLabel,
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colors.foreground,
            fontWeight: AppFontWeights.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${_medalPeriodWindowLabel(context, medal)} · $progress',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.foregroundMuted),
        ),
      ],
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.foregroundSubtle, size: 24),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.foregroundMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _medalPeriodWindowLabel(
  BuildContext context,
  ChallengeMedalReward reward,
) {
  final material = MaterialLocalizations.of(context);
  final localizations = AppLocalizations.of(context);
  switch (reward.period) {
    case ChallengePeriod.daily:
      return material.formatMediumDate(DateTime.parse(reward.periodKey));
    case ChallengePeriod.weekly:
      final start = material.formatMediumDate(DateTime.parse(reward.periodKey));
      return localizations.rewardWeekStarting(start);
    case ChallengePeriod.monthly:
      return material.formatMonthYear(DateTime.parse('${reward.periodKey}-01'));
  }
}

String _formatRewardNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
