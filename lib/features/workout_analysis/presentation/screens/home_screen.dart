import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../achievements/presentation/models/achievement.dart';
import '../../../achievements/presentation/providers/achievements_provider.dart';
import '../../../achievements/presentation/screens/achievements_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
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
import 'assessment_selection_screen.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'guide_screen.dart';
import 'session_history_screen.dart';
import 'workout_plan_setup_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final dashboardData =
        ref.watch(homeDashboardProvider).valueOrNull ??
        HomeDashboardData.fallback();
    // Fallback data powers placeholders, but metric cards only show real sessions.
    final hasDashboardData = dashboardData.source == HomeDashboardSource.real;
    final goalsState = ref.watch(goalsProvider).valueOrNull;
    final goalPreview = _trustedGoalPreview(goalsState);
    final achievementsState = ref.watch(achievementsProvider).valueOrNull;
    final achievementPreview = _trustedAchievementPreview(achievementsState);
    final selectedExercise = ref.watch(selectedExerciseProvider);

    return AppScaffoldShell(
      title: localizations.workoutAnalysis,
      currentPage: AppDestination.home,
      padding: EdgeInsets.zero,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen()),
            );
          },
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HomeGreetingCard(),
            const SizedBox(height: 14),
            _HomeActionGrid(
              selectedExercise: selectedExercise,
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
              onSelectExercise: () {
                ref.read(workoutPlanSessionProvider.notifier).reset();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExerciseSelectionScreen(),
                  ),
                );
              },
              onOpenGuide: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GuideScreen()),
                );
              },
              onOpenHistory: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SessionHistoryScreen(),
                  ),
                );
              },
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
            ),
            const SizedBox(height: 16),
            if (hasDashboardData)
              _DashboardStats(data: dashboardData)
            else
              const _HomeProgressEmptyCard(),
            const SizedBox(height: 14),
            if (goalPreview == null)
              HomeFeaturePreviewCard(
                title: localizations.weeklyGoal,
                subtitle: localizations.weeklyGoalEmpty,
                icon: Icons.flag_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  );
                },
              )
            else
              HomeFeaturePreviewCard(
                title: localizations.weeklyGoal,
                subtitle: localizations.goalTitle(
                  goalPreview.id,
                  fallback: goalPreview.title,
                ),
                icon: Icons.flag_rounded,
                progress: goalPreview.progress,
                trailingText:
                    '${_formatGoalValue(goalPreview.currentValue)} / ${_formatGoalValue(goalPreview.targetValue)} ${localizations.goalUnit(goalPreview.id, fallback: goalPreview.unit)}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  );
                },
              ),
            const SizedBox(height: 14),
            if (achievementPreview == null)
              HomeFeaturePreviewCard(
                title: localizations.achievements,
                subtitle: localizations.achievementsEmptyPreview,
                icon: Icons.emoji_events_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AchievementsScreen(),
                    ),
                  );
                },
              )
            else
              HomeFeaturePreviewCard(
                title: localizations.achievements,
                subtitle: localizations.achievementTitle(
                  achievementPreview.id,
                  fallback: achievementPreview.title,
                ),
                icon: Icons.emoji_events_rounded,
                badgeText: achievementPreview.isUnlocked
                    ? localizations.open
                    : null,
                progress: achievementPreview.normalizedProgress,
                trailingText: localizations.achievementRequirement(
                  achievementPreview.id,
                  fallback: achievementPreview.requirementText,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AchievementsScreen(),
                    ),
                  );
                },
              ),
            const SizedBox(height: 14),
            if (hasDashboardData)
              ExerciseDistributionCard(
                items: dashboardData.exerciseDistribution,
              )
            else
              _HomeInsightPlaceholderCard(
                title: localizations.exerciseDistribution,
                subtitle: localizations.exerciseDistributionEmpty,
                icon: Icons.pie_chart_rounded,
              ),
            const SizedBox(height: 14),
            HomeFeaturePreviewCard(
              title: localizations.aiCoach,
              subtitle: localizations.aiCoachComingSoonDescription,
              icon: Icons.auto_awesome_rounded,
              badgeText: localizations.comingSoon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeGreetingCard extends StatelessWidget {
  const _HomeGreetingCard();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final greeting = _HomeGreetingData.current(localizations);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      radius: 18,
      borderColor: greeting.accentColor.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: greeting.accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: greeting.accentColor.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(greeting.icon, color: greeting.accentColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  localizations.homeReadyPrompt,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
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

class _HomeGreetingData {
  const _HomeGreetingData({
    required this.title,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final IconData icon;
  final Color accentColor;

  static _HomeGreetingData current(AppLocalizations localizations) {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return _HomeGreetingData(
        title: localizations.greetingForHour(hour),
        icon: Icons.wb_sunny_rounded,
        accentColor: Color(0xFFFFD54F),
      );
    }

    if (hour >= 12 && hour < 17) {
      return _HomeGreetingData(
        title: localizations.greetingForHour(hour),
        icon: Icons.sunny,
        accentColor: Color(0xFFFFA726),
      );
    }

    if (hour >= 17 && hour < 22) {
      return _HomeGreetingData(
        title: localizations.greetingForHour(hour),
        icon: Icons.wb_twilight_rounded,
        accentColor: Color(0xFFAB47BC),
      );
    }

    return _HomeGreetingData(
      title: localizations.greetingForHour(hour),
      icon: Icons.nightlight_round,
      accentColor: Color(0xFF5C6BC0),
    );
  }
}

class _HomeActionGrid extends StatelessWidget {
  const _HomeActionGrid({
    required this.selectedExercise,
    required this.onStartAnalysis,
    required this.onSelectExercise,
    required this.onOpenGuide,
    required this.onOpenHistory,
    required this.onOpenWorkoutPlan,
    required this.onOpenAssessment,
  });

  final ExerciseType? selectedExercise;
  final VoidCallback onStartAnalysis;
  final VoidCallback onSelectExercise;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenWorkoutPlan;
  final VoidCallback onOpenAssessment;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final exerciseTitle = selectedExercise == null
        ? null
        : localizations.exerciseTitle(selectedExercise!.id);
    final primaryTitle = selectedExercise == null
        ? localizations.chooseExerciseAndStart
        : localizations.startExerciseAnalysis(exerciseTitle!);
    final primarySubtitle = selectedExercise == null
        ? localizations.chooseExerciseFirstStep
        : localizations.continueToPreparation;
    final selectionTitle = selectedExercise == null
        ? localizations.selectExercise
        : localizations.changeExercise;
    final selectionSubtitle = selectedExercise == null
        ? localizations.viewSupportedExercises
        : localizations.chooseDifferentAnalysis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectedExerciseSummary(
          selectedExercise: selectedExercise,
          onChangeExercise: onSelectExercise,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final cardWidth = (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _HomeActionCard(
                  icon: Icons.play_arrow_rounded,
                  title: primaryTitle,
                  subtitle: primarySubtitle,
                  isPrimary: true,
                  onTap: onStartAnalysis,
                ),
                _HomeActionCard(
                  icon: selectedExercise == null
                      ? Icons.directions_run_rounded
                      : Icons.swap_horiz_rounded,
                  title: selectionTitle,
                  subtitle: selectionSubtitle,
                  onTap: onSelectExercise,
                ),
                _HomeActionCard(
                  icon: Icons.menu_book_rounded,
                  title: localizations.exerciseGuide,
                  subtitle: localizations.techniqueTipsAndMistakes,
                  onTap: onOpenGuide,
                ),
                _HomeActionCard(
                  icon: Icons.history_rounded,
                  title: localizations.sessionHistory,
                  subtitle: localizations.savedAnalyses,
                  onTap: onOpenHistory,
                ),
                _HomeActionCard(
                  icon: Icons.fitness_center_rounded,
                  title: localizations.plannedWorkout,
                  subtitle: localizations.plannedWorkoutSubtitle,
                  onTap: onOpenWorkoutPlan,
                ),
                _HomeActionCard(
                  icon: Icons.monitor_heart_rounded,
                  title: localizations.assessment,
                  subtitle: localizations.assessmentSubtitle,
                  onTap: onOpenAssessment,
                ),
              ].map((card) => SizedBox(width: cardWidth, child: card)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _SelectedExerciseSummary extends StatelessWidget {
  const _SelectedExerciseSummary({
    required this.selectedExercise,
    required this.onChangeExercise,
  });

  final ExerciseType? selectedExercise;
  final VoidCallback onChangeExercise;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final hasSelection = selectedExercise != null;
    final exerciseTitle = selectedExercise == null
        ? null
        : localizations.exerciseTitle(selectedExercise!.id);

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      borderColor: hasSelection
          ? Colors.greenAccent.withValues(alpha: 0.35)
          : AppColors.surfaceBorder,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (hasSelection ? Colors.greenAccent : Colors.white70)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasSelection
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              color: hasSelection ? Colors.greenAccent : Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSelection
                      ? localizations.selectedExercise(exerciseTitle!)
                      : localizations.noExerciseSelected,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasSelection
                      ? localizations.quickStartUsesSelection
                      : localizations.quickStartNeedsSelection,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onChangeExercise,
            child: Text(
              hasSelection ? localizations.change : localizations.select,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final accentColor = isPrimary ? Colors.greenAccent : Colors.white70;
    final backgroundColor = isPrimary
        ? Colors.greenAccent.withValues(alpha: 0.13)
        : AppColors.primarySurface;
    final borderColor = isPrimary
        ? Colors.greenAccent.withValues(alpha: 0.5)
        : AppColors.surfaceBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.surface),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadii.surface),
            border: Border.all(color: borderColor),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(height: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
