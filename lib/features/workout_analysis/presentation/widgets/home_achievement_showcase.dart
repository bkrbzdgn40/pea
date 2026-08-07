import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../../rewards/domain/models/achievement_reward.dart';
import '../../../rewards/presentation/widgets/reward_marks.dart';
import '../providers/home_achievement_showcase_provider.dart';

class HomeAchievementShowcase extends ConsumerWidget {
  const HomeAchievementShowcase({
    super.key,
    required this.onOpenAchievements,
    this.spacingBefore = 0,
  });

  final VoidCallback onOpenAchievements;
  final double spacingBefore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeAchievementShowcaseProvider);
    final cachedData = state.valueOrNull;
    if (cachedData != null) {
      return Padding(
        padding: EdgeInsets.only(top: spacingBefore),
        child: _ShowcaseCard(
          rewards: cachedData.rewards,
          onOpenAchievements: onOpenAchievements,
        ),
      );
    }

    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (data) => const SizedBox.shrink(),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({
    required this.rewards,
    required this.onOpenAchievements,
  });

  final List<AchievementReward> rewards;
  final VoidCallback onOpenAchievements;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return Semantics(
      button: true,
      container: true,
      label: localizations.homeAchievementShowcaseOpen,
      child: AppSurfaceCard(
        key: const ValueKey('home-achievement-showcase'),
        padding: EdgeInsets.zero,
        variant: AppSurfaceVariant.muted,
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenAchievements,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.analysisAccent.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.analysisAccent.withValues(
                              alpha: 0.24,
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.workspace_premium_rounded,
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
                              localizations.homeAchievementShowcaseTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.foreground,
                                    fontWeight: AppFontWeights.bold,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              rewards.isEmpty
                                  ? localizations.homeAchievementShowcaseEmpty
                                  : localizations
                                        .homeAchievementShowcaseSubtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.foregroundMuted,
                                    height: 1.3,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.foregroundSubtle,
                      ),
                    ],
                  ),
                  if (rewards.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ShowcaseRewards(rewards: rewards),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShowcaseRewards extends StatelessWidget {
  const _ShowcaseRewards({required this.rewards});

  final List<AchievementReward> rewards;

  @override
  Widget build(BuildContext context) {
    final visible = rewards.take(homeAchievementShowcaseLimit).toList();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var index = 0; index < visible.length; index++)
            _AchievementBadgeSymbol(
              reward: visible[index],
              emphasized: index == 0,
            ),
        ],
      ),
    );
  }
}

class _AchievementBadgeSymbol extends StatelessWidget {
  const _AchievementBadgeSymbol({
    required this.reward,
    required this.emphasized,
  });

  final AchievementReward reward;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final title = localizations.achievementTitle(reward.achievementId);
    final accent = achievementAccentForId(reward.achievementId);

    return Semantics(
      key: ValueKey('home-achievement-badge-${reward.achievementId}'),
      image: true,
      label: title,
      child: Tooltip(
        message: title,
        child: SizedBox.square(
          dimension: emphasized ? 72 : 64,
          child: Center(
            child: AchievementBadgeMark(
              achievementId: reward.achievementId,
              accent: accent,
              secret: isSecretAchievementId(reward.achievementId),
              emphasized: emphasized,
            ),
          ),
        ),
      ),
    );
  }
}
