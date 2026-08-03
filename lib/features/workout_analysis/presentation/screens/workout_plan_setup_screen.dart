import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_ui_primitives.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../application/saved_workout_plan.dart';
import '../controllers/workout_plan_launcher.dart';
import '../providers/saved_workout_plans_provider.dart';
import '../widgets/workout_plan/saved_plans_section.dart';
import '../widgets/workout_plan/workout_plan_builder_sheet.dart';
import 'workout_plan_review_screen.dart';

class WorkoutPlanSetupScreen extends ConsumerStatefulWidget {
  const WorkoutPlanSetupScreen({super.key});

  @override
  ConsumerState<WorkoutPlanSetupScreen> createState() =>
      _WorkoutPlanSetupScreenState();
}

class _WorkoutPlanSetupScreenState
    extends ConsumerState<WorkoutPlanSetupScreen> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final savedPlans = ref.watch(savedWorkoutPlansProvider);

    return AppScaffoldShell(
      title: localizations.plannedWorkout,
      padding: EdgeInsets.zero,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = AppLayout.of(context, constraints: constraints);
          return Padding(
            padding: layout.pagePadding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: ListView(
                  key: const ValueKey<String>('workout-plan-home-scroll'),
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    _PlannedWorkoutHero(onCreate: () => _openPlanBuilder()),
                    SizedBox(height: layout.sectionGap),
                    SavedPlansSection(
                      plans: savedPlans,
                      onDelete: _confirmDeletePlan,
                      onNew: () => _openPlanBuilder(),
                      onReview: _openPlanReview,
                      onEdit: _openPlanBuilder,
                      onStart: _startPlan,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPlanReview(SavedWorkoutPlan plan) async {
    final result = await Navigator.push<WorkoutPlanReviewResult>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutPlanReviewScreen(
          plan: plan,
          initiallySaved: true,
          onSaved: () {},
        ),
      ),
    );
    if (!mounted || result != WorkoutPlanReviewResult.edit) {
      return;
    }
    await _openPlanBuilder(plan);
  }

  void _startPlan(SavedWorkoutPlan plan) {
    launchWorkoutPlan(context: context, ref: ref, plan: plan);
  }

  Future<void> _openPlanBuilder([SavedWorkoutPlan? plan]) async {
    final result = await showModalBottomSheet<WorkoutPlanBuilderResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => WorkoutPlanBuilderSheet(initialPlan: plan),
    );
    if (!mounted || result == null) {
      return;
    }

    if (result.action == WorkoutPlanBuilderAction.start) {
      _startPlan(result.plan);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).planSaved)),
    );
  }

  Future<void> _confirmDeletePlan(SavedWorkoutPlan plan) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deletePlan),
        content: Text(localizations.deletePlanConfirmation(plan.name)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(savedWorkoutPlansProvider.notifier).delete(plan.id);
  }
}

class _PlannedWorkoutHero extends StatelessWidget {
  const _PlannedWorkoutHero({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    return AppSurfaceCard(
      variant: AppSurfaceVariant.accent,
      radius: AppRadii.large,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 620 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.analysisAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.surface),
                  border: Border.all(
                    color: colors.analysisAccent.withValues(alpha: 0.38),
                  ),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: colors.analysisAccent,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                localizations.plannedWorkout,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: AppFontWeights.heavy,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                localizations.plannedWorkoutBuilderIntro,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.foregroundMuted,
                  height: 1.45,
                ),
              ),
            ],
          );
          final action = AppButton(
            key: const ValueKey<String>('new-workout-plan'),
            label: localizations.newPlan,
            icon: Icons.add_rounded,
            expand: stack,
            onPressed: onCreate,
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                copy,
                const SizedBox(height: AppSpacing.lg),
                action,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: copy),
              const SizedBox(width: AppSpacing.xl),
              SizedBox(width: 180, child: action),
            ],
          );
        },
      ),
    );
  }
}
