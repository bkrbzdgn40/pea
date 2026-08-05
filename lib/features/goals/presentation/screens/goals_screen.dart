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
import '../../domain/models/user_workout_goal.dart';
import '../../domain/models/workout_goal_template.dart';
import '../models/workout_goal.dart';
import '../providers/goals_provider.dart';
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
      showDrawer: false,
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
    final pausedGoals = state.pausedGoals;
    final configuredTypes = state.goals
        .map((goal) => goal.resolvedType)
        .whereType<WorkoutGoalType>()
        .toSet();
    final availableTemplates = state.templates
        .where((template) => !configuredTypes.contains(template.type))
        .toList(growable: false);

    return ListView(
      key: const PageStorageKey<String>('goals-content'),
      padding: AppSpacing.pagePadding,
      children: [
        const GoalsHeaderCard(),
        if (!state.progressAvailable && state.goals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppFeedbackBanner(
            message: localizations.goalProgressUnavailable,
            tone: AppStatusTone.caution,
            icon: Icons.sync_problem_rounded,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          title: localizations.activeGoal,
          description: activeGoal == null
              ? null
              : localizations.activeGoalDescription,
          child: activeGoal == null
              ? AppEmptyView(
                  key: const ValueKey<String>('no-active-goal'),
                  title: localizations.noActiveGoalTitle,
                  message: localizations.noActiveGoalMessage,
                  icon: Icons.flag_outlined,
                )
              : ActiveGoalCard(
                  goal: activeGoal,
                  isSaving: management.isSaving,
                  onEdit: () => _editGoal(context, ref, activeGoal),
                  onPause: () => _pauseGoal(context, ref, activeGoal),
                ),
        ),
        if (availableTemplates.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          AppSection(
            title: localizations.suggestedGoals,
            description: localizations.suggestedGoalsDescription,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < availableTemplates.length;
                  index++
                ) ...[
                  GoalTemplateCard(
                    template: availableTemplates[index],
                    isSaving: management.isSaving,
                    onSelect: () => _startTemplate(
                      context,
                      ref,
                      availableTemplates[index],
                      activeGoal: activeGoal,
                    ),
                  ),
                  if (index != availableTemplates.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
        if (pausedGoals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          AppSection(
            title: localizations.pausedGoals,
            description: localizations.pausedGoalsDescription,
            child: Column(
              children: [
                for (var index = 0; index < pausedGoals.length; index++) ...[
                  PausedGoalCard(
                    goal: pausedGoals[index],
                    isSaving: management.isSaving,
                    onResume: () =>
                        _resumeGoal(context, ref, pausedGoals[index]),
                  ),
                  if (index != pausedGoals.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
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

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
