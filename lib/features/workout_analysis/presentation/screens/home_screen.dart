import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../achievements/presentation/models/achievement.dart';
import '../../../achievements/presentation/providers/achievements_provider.dart';
import '../../../achievements/presentation/screens/achievements_screen.dart';
import '../../../goals/presentation/models/workout_goal.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../domain/models/exercise_type.dart';
import '../models/home_dashboard_data.dart';
import '../providers/home_dashboard_provider.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/workout_plan_session_provider.dart';
import '../widgets/exercise_distribution_card.dart';
import '../widgets/home_feature_preview_card.dart';
import '../widgets/home_task_surface.dart';
import 'assessment_selection_screen.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'workout_plan_setup_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final dashboardData =
        ref.watch(homeDashboardProvider).valueOrNull ??
        HomeDashboardData.fallback();
    final hasDashboardData = dashboardData.source == HomeDashboardSource.real;
    final goalsState = ref.watch(goalsProvider).valueOrNull;
    final goalPreview = _trustedGoalPreview(goalsState);
    final achievementsState = ref.watch(achievementsProvider).valueOrNull;
    final achievementPreview = _trustedAchievementPreview(achievementsState);
    final selectedExercise = ref.watch(selectedExerciseProvider);

    void openExerciseSelection() {
      ref.read(workoutPlanSessionProvider.notifier).reset();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()),
      );
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
              hasDashboardData: hasDashboardData,
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
    required this.hasDashboardData,
    required this.goalPreview,
    required this.achievementPreview,
    required this.onStartAnalysis,
    required this.onSelectExercise,
    required this.onOpenWorkoutPlan,
    required this.onOpenAssessment,
    required this.onOpenGoals,
    required this.onOpenAchievements,
  });

  final AppLayout layout;
  final ExerciseType? selectedExercise;
  final HomeDashboardData dashboardData;
  final bool hasDashboardData;
  final WorkoutGoal? goalPreview;
  final Achievement? achievementPreview;
  final VoidCallback onStartAnalysis;
  final VoidCallback onSelectExercise;
  final VoidCallback onOpenWorkoutPlan;
  final VoidCallback onOpenAssessment;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenAchievements;

  @override
  Widget build(BuildContext context) {
    final useWideComposition =
        layout.viewportSize.width >= 560 &&
        (layout.isLandscape || layout.isExpanded);

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
          _HomeProgressPanel(
            dashboardData: dashboardData,
            hasDashboardData: hasDashboardData,
            goalPreview: goalPreview,
            onOpenGoals: onOpenGoals,
          ),
          SizedBox(height: layout.sectionGap),
          _HomeAchievementPreview(
            achievementPreview: achievementPreview,
            onOpenAchievements: onOpenAchievements,
          ),
          SizedBox(height: layout.sectionGap),
          _HomeDistributionPreview(
            dashboardData: dashboardData,
            hasDashboardData: hasDashboardData,
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('home-wide-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            Expanded(
              flex: 5,
              child: _HomeProgressPanel(
                dashboardData: dashboardData,
                hasDashboardData: hasDashboardData,
                goalPreview: goalPreview,
                onOpenGoals: onOpenGoals,
              ),
            ),
          ],
        ),
        SizedBox(height: layout.panelGap),
        _HomeAchievementPreview(
          achievementPreview: achievementPreview,
          onOpenAchievements: onOpenAchievements,
        ),
        SizedBox(height: layout.sectionGap),
        _HomeDistributionPreview(
          dashboardData: dashboardData,
          hasDashboardData: hasDashboardData,
        ),
      ],
    );
  }
}

class _HomeProgressPanel extends StatelessWidget {
  const _HomeProgressPanel({
    required this.dashboardData,
    required this.hasDashboardData,
    required this.goalPreview,
    required this.onOpenGoals,
  });

  final HomeDashboardData dashboardData;
  final bool hasDashboardData;
  final WorkoutGoal? goalPreview;
  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Column(
      key: const ValueKey('home-progress-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasDashboardData)
          _DashboardStats(data: dashboardData)
        else
          const _HomeProgressEmptyCard(),
        const SizedBox(height: 12),
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
    );
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
  const _HomeDistributionPreview({
    required this.dashboardData,
    required this.hasDashboardData,
  });

  final HomeDashboardData dashboardData;
  final bool hasDashboardData;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (hasDashboardData) {
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

    return AppSurfaceCard(
      padding: AppSpacing.headerSurfacePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.insights_rounded,
            color: Colors.greenAccent,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.progressWillAppearHere,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  localizations.firstAnalysisProgressDescription,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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
    return AppSurfaceCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.greenAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
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
        const spacing = 10.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _DashboardStatCard(
              label: localizations.totalAnalyses,
              value: data.totalAnalyses.toString(),
            ),
            _DashboardStatCard(
              label: localizations.thisWeek,
              value: data.thisWeekCount.toString(),
            ),
          ].map((card) => SizedBox(width: cardWidth, child: card)).toList(),
        );
      },
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
