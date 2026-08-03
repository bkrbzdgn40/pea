import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_section.dart';
import '../../../../app/presentation/widgets/app_status_chip.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/exercise_type.dart';

class HomeGreetingHeader extends StatelessWidget {
  const HomeGreetingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.analysisAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.analysisAccent.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  localizations.cameraBasedAnalysis.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.analysisAccent,
                    fontWeight: AppFontWeights.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.greetingForHour(DateTime.now().hour),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colors.foreground,
              fontWeight: AppFontWeights.heavy,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            localizations.homeReadyPrompt,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.foregroundMuted,
              height: 1.35,
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
        _HomeAnalysisHero(
          selectedExercise: selectedExercise,
          title: primaryTitle,
          subtitle: primarySubtitle,
          onStartAnalysis: onStartAnalysis,
          onSelectExercise: onSelectExercise,
        ),
        SizedBox(height: layout.panelGap),
        AppSection(
          title: localizations.quickFlows,
          child: _HomeSecondaryActions(
            layout: layout,
            onOpenWorkoutPlan: onOpenWorkoutPlan,
            onOpenAssessment: onOpenAssessment,
          ),
        ),
      ],
    );
  }
}

class _HomeAnalysisHero extends StatelessWidget {
  const _HomeAnalysisHero({
    required this.selectedExercise,
    required this.title,
    required this.subtitle,
    required this.onStartAnalysis,
    required this.onSelectExercise,
  });

  final ExerciseType? selectedExercise;
  final String title;
  final String subtitle;
  final VoidCallback onStartAnalysis;
  final VoidCallback onSelectExercise;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong,
            colors.analysisAccent.withValues(alpha: 0.12),
            colors.surface,
          ],
          stops: const [0, 0.58, 1],
        ),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(
          color: colors.analysisAccent.withValues(alpha: AppOpacity.border),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.analysisAccent.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -52,
            top: -58,
            child: IgnorePointer(
              child: Container(
                width: 164,
                height: 164,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.analysisAccent.withValues(alpha: 0.12),
                    width: 24,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: -46,
            child: IgnorePointer(
              child: Icon(
                Icons.accessibility_new_rounded,
                size: 118,
                color: colors.analysisAccent.withValues(alpha: 0.055),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SelectedExerciseSummary(
                  key: const ValueKey('home-selected-exercise'),
                  selectedExercise: selectedExercise,
                  onChangeExercise: onSelectExercise,
                ),
                const SizedBox(height: AppSpacing.lg),
                _HomePrimaryActionCard(
                  title: title,
                  subtitle: subtitle,
                  onTap: onStartAnalysis,
                ),
              ],
            ),
          ),
        ],
      ),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: AppStatusChip(
            label: hasSelection
                ? localizations.selectedExercise(exerciseTitle!)
                : localizations.noExerciseSelected,
            tone: hasSelection ? AppStatusTone.success : AppStatusTone.neutral,
            icon: hasSelection
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        TextButton(
          onPressed: onChangeExercise,
          child: Text(
            hasSelection ? localizations.change : localizations.select,
          ),
        ),
      ],
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
    final colors = context.semanticColors;

    return Material(
      key: const ValueKey('home-primary-action'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.surface),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.analysisAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.surface),
            border: Border.all(
              color: colors.analysisAccent.withValues(alpha: 0.52),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.analysisAccent,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  boxShadow: [
                    BoxShadow(
                      color: colors.analysisAccent.withValues(alpha: 0.28),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 28,
                ),
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
                        height: 1.2,
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
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.arrow_forward_rounded, color: colors.analysisAccent),
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
    final colors = context.semanticColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.surface),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.surface),
            border: Border.all(color: colors.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.foreground.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(icon, color: colors.foregroundMuted, size: 21),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colors.foreground,
                        height: 1.2,
                        fontWeight: AppFontWeights.heavy,
                      ),
                    ),
                    if (showSubtitle) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.foregroundMuted,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                Icons.arrow_outward_rounded,
                size: 18,
                color: colors.foregroundSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
