import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_feedback_banner.dart';
import '../../../../app/presentation/widgets/app_metric_tile.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_section.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../../achievements/presentation/models/achievement.dart';
import '../../../achievements/presentation/providers/achievements_provider.dart';
import '../../../achievements/presentation/screens/achievements_screen.dart';
import '../../../goals/presentation/models/workout_goal.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/workout_session.dart';
import '../models/home_dashboard_data.dart';
import '../providers/home_dashboard_provider.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/user_sessions_snapshot_provider.dart';
import '../providers/workout_plan_session_provider.dart';
import '../widgets/exercise_distribution_card.dart';
import '../widgets/home_feature_preview_card.dart';
import '../widgets/home_recent_session_card.dart';
import '../widgets/home_task_surface.dart';
import 'assessment_selection_screen.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'session_detail_screen.dart';
import 'workout_plan_setup_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final dashboardAsync = ref.watch(homeDashboardProvider);
    final dashboardData =
        dashboardAsync.valueOrNull ??
        HomeDashboardData.fallback(
          source: dashboardAsync.hasError
              ? HomeDashboardSource.error
              : HomeDashboardSource.loading,
        );
    final goalsState = ref.watch(goalsProvider).valueOrNull;
    final goalPreview = _trustedGoalPreview(goalsState);
    final achievementsState = ref.watch(achievementsProvider).valueOrNull;
    final achievementPreview = _trustedAchievementPreview(achievementsState);
    final selectedExercise = ref.watch(selectedExerciseProvider);

    void refreshDashboard() {
      ref.invalidate(userSessionsSnapshotProvider);
      ref.invalidate(homeDashboardProvider);
    }

    void openExerciseSelection() {
      ref.read(workoutPlanSessionProvider.notifier).reset();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()),
      );
    }

    void openRecentSession(WorkoutSession session) {
      Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(session: session),
        ),
      ).then((wasDeleted) {
        if (wasDeleted == true && context.mounted) {
          refreshDashboard();
        }
      });
    }

    return AppScaffoldShell(
      title: localizations.workoutAnalysis,
      currentPage: AppDestination.home,
      padding: EdgeInsets.zero,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);

          return SingleChildScrollView(
            padding: layout.pagePadding,
            child: _ResponsiveHomeContent(
              layout: layout,
              selectedExercise: selectedExercise,
              dashboardData: dashboardData,
              goalPreview: goalPreview,
              achievementPreview: achievementPreview,
              onStartAnalysis: () {
                ref.read(workoutPlanSessionProvider.notifier).reset();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => selectedExercise != null
                        ? const CameraPermissionScreen()
                        : const ExerciseSelectionScreen(),
                  ),
                );
              },
              onSelectExercise: openExerciseSelection,
              onOpenWorkoutPlan: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WorkoutPlanSetupScreen(),
                  ),
                );
              },
              onOpenAssessment: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AssessmentSelectionScreen(),
                  ),
                );
              },
              onOpenGoals: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                );
              },
              onOpenAchievements: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                );
              },
              onRetryDashboard: refreshDashboard,
              onOpenRecentSession: openRecentSession,
            ),
          );
        },
      ),
    );
  }
}

class _ResponsiveHomeContent extends StatelessWidget {
  const _ResponsiveHomeContent({
    required this.layout,
    required this.selectedExercise,
    required this.dashboardData,
    required this.goalPreview,
    required this.achievementPreview,
    required this.onStartAnalysis,
    required this.onSelectExercise,
    required this.onOpenWorkoutPlan,
    required this.onOpenAssessment,
    required this.onOpenGoals,
    required this.onOpenAchievements,
    required this.onRetryDashboard,
    required this.onOpenRecentSession,
  });

  final AppLayout layout;
  final ExerciseType? selectedExercise;
  final HomeDashboardData dashboardData;
  final WorkoutGoal? goalPreview;
  final Achievement? achievementPreview;
  final VoidCallback onStartAnalysis;
  final VoidCallback onSelectExercise;
  final VoidCallback onOpenWorkoutPlan;
  final VoidCallback onOpenAssessment;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenAchievements;
  final VoidCallback onRetryDashboard;
  final ValueChanged<WorkoutSession> onOpenRecentSession;

  @override
  Widget build(BuildContext context) {
    final useWideComposition =
        layout.viewportSize.width >= 560 &&
        (layout.isLandscape || layout.isExpanded);

    final progressPanel = _HomeProgressPanel(
      dashboardData: dashboardData,
      goalPreview: goalPreview,
      onOpenGoals: onOpenGoals,
      onRetry: onRetryDashboard,
      onOpenRecentSession: onOpenRecentSession,
    );

    if (!useWideComposition) {
      return Column(
        key: const ValueKey('home-portrait-layout'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeGreetingHeader(),
          SizedBox(height: layout.sectionGap),
          HomeTaskPanel(
            layout: layout,
            selectedExercise: selectedExercise,
            onStartAnalysis: onStartAnalysis,
            onSelectExercise: onSelectExercise,
            onOpenWorkoutPlan: onOpenWorkoutPlan,
            onOpenAssessment: onOpenAssessment,
          ),
          SizedBox(height: layout.panelGap),
          progressPanel,
          SizedBox(height: layout.sectionGap),
          _HomeAchievementPreview(
            achievementPreview: achievementPreview,
            onOpenAchievements: onOpenAchievements,
          ),
          SizedBox(height: layout.sectionGap),
          _HomeDistributionPreview(dashboardData: dashboardData),
        ],
      );
    }

    return Column(
      key: const ValueKey('home-wide-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HomeGreetingHeader(),
        SizedBox(height: layout.panelGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: HomeTaskPanel(
                layout: layout,
                selectedExercise: selectedExercise,
                onStartAnalysis: onStartAnalysis,
                onSelectExercise: onSelectExercise,
                onOpenWorkoutPlan: onOpenWorkoutPlan,
                onOpenAssessment: onOpenAssessment,
              ),
            ),
            SizedBox(width: layout.panelGap),
            Expanded(flex: 5, child: progressPanel),
          ],
        ),
        SizedBox(height: layout.panelGap),
        _HomeAchievementPreview(
          achievementPreview: achievementPreview,
          onOpenAchievements: onOpenAchievements,
        ),
        SizedBox(height: layout.sectionGap),
        _HomeDistributionPreview(dashboardData: dashboardData),
      ],
    );
  }
}

class _HomeProgressPanel extends StatelessWidget {
  const _HomeProgressPanel({
    required this.dashboardData,
    required this.goalPreview,
    required this.onOpenGoals,
    required this.onRetry,
    required this.onOpenRecentSession,
  });

  final HomeDashboardData dashboardData;
  final WorkoutGoal? goalPreview;
  final VoidCallback onOpenGoals;
  final VoidCallback onRetry;
  final ValueChanged<WorkoutSession> onOpenRecentSession;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return AppSection(
      key: const ValueKey('home-progress-panel'),
      title: localizations.homeOverview,
      description: localizations.homeOverviewSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HomeDashboardState(
            data: dashboardData,
            onRetry: onRetry,
            onOpenRecentSession: onOpenRecentSession,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (goalPreview == null)
            HomeFeaturePreviewCard(
              title: localizations.weeklyGoal,
              subtitle: localizations.weeklyGoalEmpty,
              icon: Icons.flag_rounded,
              onTap: onOpenGoals,
            )
          else
            HomeFeaturePreviewCard(
              title: localizations.weeklyGoal,
              subtitle: localizations.goalTitle(
                goalPreview!.id,
                fallback: goalPreview!.title,
              ),
              icon: Icons.flag_rounded,
              progress: goalPreview!.progress,
              trailingText:
                  '${_formatGoalValue(goalPreview!.currentValue)} / ${_formatGoalValue(goalPreview!.targetValue)} ${localizations.goalUnit(goalPreview!.id, fallback: goalPreview!.unit)}',
              onTap: onOpenGoals,
            ),
        ],
      ),
    );
  }
}

class _HomeDashboardState extends StatelessWidget {
  const _HomeDashboardState({
    required this.data,
    required this.onRetry,
    required this.onOpenRecentSession,
  });

  final HomeDashboardData data;
  final VoidCallback onRetry;
  final ValueChanged<WorkoutSession> onOpenRecentSession;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return switch (data.source) {
      HomeDashboardSource.real => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardStats(data: data),
          if (data.latestSession != null) ...[
            const SizedBox(height: AppSpacing.sm),
            HomeRecentSessionCard(
              session: data.latestSession!,
              onTap: () => onOpenRecentSession(data.latestSession!),
            ),
          ],
        ],
      ),
      HomeDashboardSource.loading => AppFeedbackBanner(
        title: localizations.homeOverview,
        message: localizations.loading,
        tone: AppStatusTone.accent,
        icon: Icons.hourglass_top_rounded,
        liveRegion: false,
      ),
      HomeDashboardSource.error => AppFeedbackBanner(
        title: localizations.dataLoadFailed,
        message: localizations.homeDataRetryDescription,
        tone: AppStatusTone.danger,
        actionLabel: localizations.retry,
        onAction: onRetry,
      ),
      HomeDashboardSource.noUser ||
      HomeDashboardSource.empty => const _HomeProgressEmptyCard(),
    };
  }
}

class _HomeAchievementPreview extends StatelessWidget {
  const _HomeAchievementPreview({
    required this.achievementPreview,
    required this.onOpenAchievements,
  });

  final Achievement? achievementPreview;
  final VoidCallback onOpenAchievements;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final preview = achievementPreview;

    if (preview == null) {
      return HomeFeaturePreviewCard(
        title: localizations.achievements,
        subtitle: localizations.achievementsEmptyPreview,
        icon: Icons.emoji_events_rounded,
        onTap: onOpenAchievements,
      );
    }

    return HomeFeaturePreviewCard(
      title: localizations.achievements,
      subtitle: localizations.achievementTitle(
        preview.id,
        fallback: preview.title,
      ),
      icon: Icons.emoji_events_rounded,
      badgeText: preview.isUnlocked ? localizations.open : null,
      progress: preview.normalizedProgress,
      trailingText: localizations.achievementRequirement(
        preview.id,
        fallback: preview.requirementText,
      ),
      onTap: onOpenAchievements,
    );
  }
}

class _HomeDistributionPreview extends StatelessWidget {
  const _HomeDistributionPreview({required this.dashboardData});

  final HomeDashboardData dashboardData;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (dashboardData.source == HomeDashboardSource.real) {
      return ExerciseDistributionCard(
        items: dashboardData.exerciseDistribution,
      );
    }

    return _HomeInsightPlaceholderCard(
      title: localizations.exerciseDistribution,
      subtitle: localizations.exerciseDistributionEmpty,
      icon: Icons.pie_chart_rounded,
    );
  }
}

class _HomeProgressEmptyCard extends StatelessWidget {
  const _HomeProgressEmptyCard();

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
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(
              Icons.insights_rounded,
              color: colors.analysisAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.progressWillAppearHere,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  localizations.firstAnalysisProgressDescription,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _HomeInsightPlaceholderCard extends StatelessWidget {
  const _HomeInsightPlaceholderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return AppSurfaceCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: AppOpacity.subtle),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Icon(icon, color: colors.analysisAccent, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.foreground,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.3,
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

class _DashboardStats extends StatelessWidget {
  const _DashboardStats({required this.data});

  final HomeDashboardData data;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackCards =
            MediaQuery.textScalerOf(context).scale(1) >= 1.6 ||
            constraints.maxWidth < 280;
        final cards = <Widget>[
          AppMetricTile(
            key: const ValueKey('home-total-analyses'),
            label: localizations.totalAnalyses,
            value: data.totalAnalyses.toString(),
            icon: Icons.analytics_outlined,
            tone: AppStatusTone.accent,
          ),
          AppMetricTile(
            key: const ValueKey('home-this-week'),
            label: localizations.thisWeek,
            value: data.thisWeekCount.toString(),
            icon: Icons.calendar_today_rounded,
            tone: AppStatusTone.success,
          ),
        ];

        if (stackCards) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cards.first,
              const SizedBox(height: AppSpacing.xs),
              cards.last,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards.first),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: cards.last),
            ],
          ),
        );
      },
    );
  }
}

WorkoutGoal? _trustedGoalPreview(GoalsState? state) {
  if (state == null || state.isFallback) {
    return null;
  }

  for (final goal in state.goals) {
    if (goal.id != 'three_day_streak') {
      return goal;
    }
  }

  return null;
}

Achievement? _trustedAchievementPreview(AchievementsState? state) {
  if (state == null || state.isFallback) {
    return null;
  }

  for (final achievement in state.achievements) {
    if (achievement.id != 'seven_day_streak') {
      return achievement;
    }
  }

  return null;
}

String _formatGoalValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(1);
}
