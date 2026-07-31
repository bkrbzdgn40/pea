import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../domain/models/exercise_type.dart';

class HomeGreetingHeader extends StatelessWidget {
  const HomeGreetingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.greetingForHour(DateTime.now().hour),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            localizations.homeReadyPrompt,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeTaskPanel extends StatelessWidget {
  const HomeTaskPanel({
    super.key,
    required this.layout,
    required this.selectedExercise,
    required this.onStartAnalysis,
    required this.onSelectExercise,
    required this.onOpenWorkoutPlan,
    required this.onOpenAssessment,
  });

  final AppLayout layout;
  final ExerciseType? selectedExercise;
  final VoidCallback onStartAnalysis;
  final VoidCallback onSelectExercise;
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

    return Column(
      key: const ValueKey('home-task-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectedExerciseSummary(
          key: const ValueKey('home-selected-exercise'),
          selectedExercise: selectedExercise,
          onChangeExercise: onSelectExercise,
        ),
        SizedBox(height: layout.sectionGap),
        _HomePrimaryActionCard(
          title: primaryTitle,
          subtitle: primarySubtitle,
          onTap: onStartAnalysis,
        ),
        SizedBox(height: layout.sectionGap),
        _HomeSecondaryActions(
          layout: layout,
          onOpenWorkoutPlan: onOpenWorkoutPlan,
          onOpenAssessment: onOpenAssessment,
        ),
      ],
    );
  }
}

class _SelectedExerciseSummary extends StatelessWidget {
  const _SelectedExerciseSummary({
    super.key,
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
              borderRadius: BorderRadius.circular(AppRadii.small),
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
          const SizedBox(width: 8),
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

class _HomePrimaryActionCard extends StatelessWidget {
  const _HomePrimaryActionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('home-primary-action'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.surface),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.surface),
            border: Border.all(
              color: Colors.greenAccent.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.greenAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.greenAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSecondaryActions extends StatelessWidget {
  const _HomeSecondaryActions({
    required this.layout,
    required this.onOpenWorkoutPlan,
    required this.onOpenAssessment,
  });

  final AppLayout layout;
  final VoidCallback onOpenWorkoutPlan;
  final VoidCallback onOpenAssessment;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions = layout.hasLargeText || constraints.maxWidth < 300;
        final cards = <Widget>[
          _HomeSecondaryActionCard(
            key: const ValueKey('home-planned-workout-action'),
            icon: Icons.fitness_center_rounded,
            title: localizations.plannedWorkout,
            subtitle: localizations.plannedWorkoutSubtitle,
            showSubtitle: !layout.isCompact,
            onTap: onOpenWorkoutPlan,
          ),
          _HomeSecondaryActionCard(
            key: const ValueKey('home-assessment-action'),
            icon: Icons.monitor_heart_rounded,
            title: localizations.assessment,
            subtitle: localizations.assessmentSubtitle,
            showSubtitle: !layout.isCompact,
            onTap: onOpenAssessment,
          ),
        ];

        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cards.first,
              SizedBox(height: layout.sectionGap),
              cards.last,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards.first),
            SizedBox(width: layout.sectionGap),
            Expanded(child: cards.last),
          ],
        );
      },
    );
  }
}

class _HomeSecondaryActionCard extends StatelessWidget {
  const _HomeSecondaryActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.showSubtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showSubtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.surface),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(AppRadii.surface),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white70.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(icon, color: Colors.white70, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (showSubtitle) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
