import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../application/saved_workout_plan.dart';
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
  String? _selectedPlanId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final savedPlans = ref.watch(savedWorkoutPlansProvider);
    final selectedPlan = _findSelectedPlan(savedPlans.valueOrNull);

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
                constraints: const BoxConstraints(maxWidth: 980),
                child: ListView(
                  key: const ValueKey<String>('workout-plan-home-scroll'),
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    Text(
                      localizations.plannedWorkoutBuilderIntro,
                      style: const TextStyle(
                        color: Colors.white60,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: layout.sectionGap),
                    SavedPlansSection(
                      plans: savedPlans,
                      selectedPlanId: _selectedPlanId,
                      onSelect: (plan) =>
                          setState(() => _selectedPlanId = plan.id),
                      onDelete: _confirmDeletePlan,
                      onNew: () => _openPlanBuilder(),
                      onReview: selectedPlan == null
                          ? null
                          : () => _openSelectedPlanReview(selectedPlan),
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

  SavedWorkoutPlan? _findSelectedPlan(List<SavedWorkoutPlan>? plans) {
    final selectedPlanId = _selectedPlanId;
    if (selectedPlanId == null || plans == null) {
      return null;
    }
    for (final plan in plans) {
      if (plan.id == selectedPlanId) {
        return plan;
      }
    }
    return null;
  }

  Future<void> _openSelectedPlanReview(SavedWorkoutPlan plan) async {
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
    if (!mounted || result != WorkoutPlanBuilderResult.saved) {
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
    if (mounted && _selectedPlanId == plan.id) {
      setState(() => _selectedPlanId = null);
    }
  }
}
