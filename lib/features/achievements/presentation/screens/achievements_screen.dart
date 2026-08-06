import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_header_list_view.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/presentation/widgets/async_state_view.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../models/achievement.dart';
import '../providers/achievements_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

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
        errorBuilder: (context, error, stackTrace) =>
            AppErrorView(message: localizations.achievementsLoadFailed),
        dataBuilder: (context, state) => _AchievementsList(state: state),
      ),
    );
  }
}

class _AchievementsList extends StatelessWidget {
  const _AchievementsList({required this.state});

  final AchievementsState state;

  @override
  Widget build(BuildContext context) {
    final visibleAchievements = state.isFallback
        ? <Achievement>[]
        : state.achievements
              .where((achievement) => achievement.id != 'seven_day_streak')
              .toList();

    return AppHeaderListView<Achievement>(
      header: const _AchievementsHeaderCard(),
      items: visibleAchievements,
      emptyState: _AchievementsEmptyState(source: state.source),
      itemBuilder: (context, achievement) =>
          _AchievementCard(achievement: achievement),
    );
  }
}

class _AchievementsHeaderCard extends StatelessWidget {
  const _AchievementsHeaderCard();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return AppSurfaceCard(
      padding: AppSpacing.headerSurfacePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Colors.greenAccent,
            size: 34,
          ),
          const SizedBox(height: 14),
          Text(
            localizations.achievementsHeaderTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.achievementsHeaderSubtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsEmptyState extends StatelessWidget {
  const _AchievementsEmptyState({required this.source});

  final AchievementsDataSource source;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final message = localizations.achievementsEmptyMessage(
      source == AchievementsDataSource.error,
    );

    return AppEmptyView(message: message, icon: Icons.emoji_events_outlined);
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final foregroundColor = achievement.isUnlocked
        ? Colors.greenAccent
        : Colors.white54;
    final textColor = achievement.isUnlocked ? Colors.white : Colors.white60;
    final progressPercent = (achievement.normalizedProgress * 100).round();

    return Opacity(
      opacity: achievement.isUnlocked ? 1 : 0.78,
      child: AppSurfaceCard(
        borderColor: achievement.isUnlocked
            ? AppColors.accent
            : AppColors.surfaceBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: foregroundColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    achievement.isUnlocked
                        ? Icons.emoji_events_rounded
                        : Icons.lock_outline_rounded,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.achievementTitle(
                          achievement.id,
                          fallback: achievement.title,
                        ),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localizations.achievementRequirement(
                          achievement.id,
                          fallback: achievement.requirementText,
                        ),
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  achievement.isUnlocked
                      ? localizations.open
                      : localizations.locked,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              localizations.achievementDescription(
                achievement.id,
                fallback: achievement.description,
              ),
              style: TextStyle(color: textColor, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: achievement.normalizedProgress,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    color: foregroundColor,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '%$progressPercent',
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
