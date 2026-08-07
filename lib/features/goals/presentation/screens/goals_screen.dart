import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_feedback_banner.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/presentation/widgets/app_section.dart';
import '../../../../app/presentation/widgets/app_state_views.dart';
import '../../../../app/presentation/widgets/async_state_view.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../achievements/presentation/screens/achievements_screen.dart';
import '../../domain/models/user_workout_goal.dart';
import '../../domain/models/workout_goal_template.dart';
import '../models/workout_goal.dart';
import '../providers/goals_provider.dart';
import '../widgets/challenge_goal_cards.dart';
import '../widgets/goal_cards.dart';
import '../widgets/goal_editor_sheet.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final goalsState = ref.watch(goalsProvider);

    return AppScaffoldShell(
      title: localizations.goals,
      currentPage: AppDestination.goals,
      padding: EdgeInsets.zero,
      body: AsyncStateView<GoalsState>(
        value: goalsState,
        errorBuilder: (context, error, stackTrace) => AppErrorView(
          message: localizations.goalsLoadFailed,
          actionLabel: localizations.retry,
          onAction: () => ref.invalidate(goalsProvider),
        ),
        dataBuilder: (context, state) => _GoalsContent(state: state),
      ),
    );
  }
}

class _GoalsContent extends ConsumerWidget {
  const _GoalsContent({required this.state});

  final GoalsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final management = ref.watch(goalManagementControllerProvider);

    if (state.source == GoalsDataSource.noUser) {
      return Padding(
        padding: AppSpacing.pagePadding,
        child: AppEmptyView(
          title: localizations.goalsSignInTitle,
          message: localizations.goalsSignInMessage,
          icon: Icons.person_outline_rounded,
        ),
      );
    }

    if (state.source == GoalsDataSource.error) {
      return Padding(
        padding: AppSpacing.pagePadding,
        child: AppErrorView(
          message: localizations.goalsLoadFailed,
          actionLabel: localizations.retry,
          onAction: () => ref.invalidate(goalsProvider),
        ),
      );
    }

    final activeGoal = state.activeGoal;
    final archivedGoals = state.pausedGoals;
    final configuredTypes = state.goals
        .map((goal) => goal.resolvedType)
        .whereType<WorkoutGoalType>()
        .toSet();
    final availableTemplates = state.templates
        .where(
          (template) =>
              template.type != WorkoutGoalType.averageScore &&
              !configuredTypes.contains(template.type),
        )
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(goalsProvider);
        ref.invalidate(challengeGoalsProvider);
        try {
          await ref.read(goalsProvider.future);
        } catch (error) {
          debugPrint('goals.refresh.personalFailed: $error');
        }
        try {
          await ref.read(challengeGoalsProvider.future);
        } catch (error) {
          debugPrint('goals.refresh.medalsFailed: $error');
        }
      },
      child: ListView(
        key: const PageStorageKey<String>('goals-content'),
        padding: AppSpacing.pagePadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (activeGoal == null)
            AppSection(
              title: localizations.activeGoal,
              child: AppEmptyView(
                key: const ValueKey<String>('no-active-goal'),
                title: localizations.noActiveGoalTitle,
                message: localizations.noActiveGoalMessage,
                icon: Icons.flag_outlined,
              ),
            )
          else
            ActiveGoalCard(
              goal: activeGoal,
              isSaving: management.isSaving,
              onEdit: () => _editGoal(context, ref, activeGoal),
              onPause: () => _pauseGoal(context, ref, activeGoal),
            ),
          if (!state.progressAvailable && state.goals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppFeedbackBanner(
              message: localizations.goalProgressUnavailable,
              tone: AppStatusTone.caution,
              icon: Icons.sync_problem_rounded,
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          const _ChallengeGoalsSection(),
          if (availableTemplates.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            AppSection(
              title: localizations.recommendedGoals,
              description: localizations.recommendedGoalsDescription,
              child: GoalSuggestionsList(
                templates: availableTemplates,
                isSaving: management.isSaving,
                onSelect: (template) => _startTemplate(
                  context,
                  ref,
                  template,
                  activeGoal: activeGoal,
                ),
              ),
            ),
          ],
          if (archivedGoals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            ArchivedGoalsPanel(
              goals: archivedGoals,
              isSaving: management.isSaving,
              onResume: (goal) => _resumeGoal(context, ref, goal),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _startTemplate(
    BuildContext context,
    WidgetRef ref,
    WorkoutGoalTemplate template, {
    required WorkoutGoal? activeGoal,
  }) async {
    final existing = state.goals
        .where((goal) => goal.resolvedType == template.type)
        .firstOrNull;
    final target = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GoalEditorSheet(
        template: template,
        initialValue: existing?.targetValue ?? template.defaultTarget,
        replacesActiveGoal:
            activeGoal != null && activeGoal.resolvedType != template.type,
      ),
    );
    if (target == null || !context.mounted) return;

    await _activateGoal(context, ref, template.type, target);
  }

  Future<void> _editGoal(
    BuildContext context,
    WidgetRef ref,
    WorkoutGoal goal,
  ) async {
    final type = goal.resolvedType;
    if (type == null) return;
    final template = templateForGoalType(type);
    final target = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GoalEditorSheet(
        template: template,
        initialValue: goal.targetValue,
        isEditing: true,
      ),
    );
    if (target == null || !context.mounted) return;

    await _activateGoal(context, ref, type, target);
  }

  Future<void> _resumeGoal(
    BuildContext context,
    WidgetRef ref,
    WorkoutGoal goal,
  ) async {
    final type = goal.resolvedType;
    if (type == null) return;
    await _activateGoal(context, ref, type, goal.targetValue);
  }

  Future<void> _activateGoal(
    BuildContext context,
    WidgetRef ref,
    WorkoutGoalType type,
    double targetValue,
  ) async {
    final success = await ref
        .read(goalManagementControllerProvider.notifier)
        .activateGoal(type: type, targetValue: targetValue);
    if (!context.mounted) return;
    _showResult(
      context,
      success: success,
      successMessage: AppLocalizations.of(context).goalSaved,
    );
  }

  Future<void> _pauseGoal(
    BuildContext context,
    WidgetRef ref,
    WorkoutGoal goal,
  ) async {
    final type = goal.resolvedType;
    if (type == null) return;
    final success = await ref
        .read(goalManagementControllerProvider.notifier)
        .pauseGoal(type);
    if (!context.mounted) return;
    _showResult(
      context,
      success: success,
      successMessage: AppLocalizations.of(context).goalPaused,
    );
  }

  void _showResult(
    BuildContext context, {
    required bool success,
    required String successMessage,
  }) {
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success ? successMessage : localizations.goalSaveFailed,
          ),
        ),
      );
  }
}

class _ChallengeGoalsSection extends ConsumerWidget {
  const _ChallengeGoalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final period = ref.watch(selectedChallengePeriodProvider);
    final challengeState = ref.watch(challengeGoalsProvider);

    return AppSection(
      title: localizations.medalGoals,
      description: localizations.medalGoalsDescription,
      trailing: TextButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AchievementsScreen(
                initialView: AchievementsView.rewardHistory,
              ),
            ),
          );
        },
        icon: const Icon(Icons.history_rounded, size: 18),
        label: Text(localizations.rewardHistoryShort),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ChallengePeriodSelector(
              selected: period,
              onChanged: (value) {
                ref.read(selectedChallengePeriodProvider.notifier).state =
                    value;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          challengeState.when(
            loading: () => const ChallengeGoalsLoadingCard(),
            error: (error, stackTrace) => ChallengeGoalsErrorCard(
              onRetry: () => ref.invalidate(challengeGoalsProvider),
            ),
            data: (state) {
              final selectedExercise =
                  ref.watch(selectedChallengeExerciseProvider) ??
                  state.recommendedFocus.progress.definition.exerciseType;
              final focused = state.viewFor(selectedExercise);
              final nearby = state.nearbyProgresses(
                excluding: focused.progress.definition.exerciseType,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MedalChallengeCard(
                    view: focused,
                    onExerciseSelected: (exercise) {
                      ref
                              .read(selectedChallengeExerciseProvider.notifier)
                              .state =
                          exercise;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    localizations.nearMedalGoals,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: AppFontWeights.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    localizations.nearMedalGoalsDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  NearbyMedalGoalsList(
                    items: nearby,
                    onSelected: (exercise) {
                      ref
                              .read(selectedChallengeExerciseProvider.notifier)
                              .state =
                          exercise;
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
