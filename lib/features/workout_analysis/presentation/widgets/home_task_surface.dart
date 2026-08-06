import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_section.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../../domain/models/exercise_type.dart';

const Duration _homeGreetingEntranceDuration = Duration(milliseconds: 1200);

enum _GreetingPeriod { morning, afternoon, evening, night }

_GreetingPeriod _resolveGreetingPeriod(int hour) {
  if (hour >= 5 && hour < 12) {
    return _GreetingPeriod.morning;
  }
  if (hour >= 12 && hour < 17) {
    return _GreetingPeriod.afternoon;
  }
  if (hour >= 17 && hour < 22) {
    return _GreetingPeriod.evening;
  }
  return _GreetingPeriod.night;
}

class _GreetingPalette {
  const _GreetingPalette({
    required this.start,
    required this.end,
    required this.foreground,
    required this.accent,
    required this.icon,
  });

  final Color start;
  final Color end;
  final Color foreground;
  final Color accent;
  final IconData icon;

  static _GreetingPalette forPeriod(_GreetingPeriod period) {
    return switch (period) {
      _GreetingPeriod.morning => const _GreetingPalette(
        start: Color(0xFFFFF2A6),
        end: Color(0xFFFFC83D),
        foreground: Color(0xFF3D2B00),
        accent: Color(0xFFFF8F00),
        icon: Icons.wb_sunny_rounded,
      ),
      _GreetingPeriod.afternoon => const _GreetingPalette(
        start: Color(0xFFFFC46B),
        end: Color(0xFFFF7A45),
        foreground: Color(0xFF3C1808),
        accent: Color(0xFFFFF0C7),
        icon: Icons.light_mode_rounded,
      ),
      _GreetingPeriod.evening => const _GreetingPalette(
        start: Color(0xFF6948A8),
        end: Color(0xFFE06F78),
        foreground: Colors.white,
        accent: Color(0xFFFFD39B),
        icon: Icons.wb_twilight_rounded,
      ),
      _GreetingPeriod.night => const _GreetingPalette(
        start: Color(0xFF101B39),
        end: Color(0xFF35275F),
        foreground: Colors.white,
        accent: Color(0xFFB9D7FF),
        icon: Icons.dark_mode_rounded,
      ),
    };
  }
}

class HomeHowToUseAction extends StatelessWidget {
  const HomeHowToUseAction({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;
    final mediaQuery = MediaQuery.of(context);
    final useIconOnly =
        mediaQuery.size.width < 430 || mediaQuery.textScaler.scale(14) >= 20;

    final backgroundColor = colors.surfaceStrong.withValues(alpha: 0.72);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
    );

    if (useIconOnly) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: IconButton(
          key: const ValueKey('home-how-to-use-action'),
          tooltip: localizations.howToUse,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            foregroundColor: colors.foreground,
            backgroundColor: backgroundColor,
            side: BorderSide(color: colors.outlineSubtle),
            shape: shape,
          ),
          icon: const Icon(Icons.help_outline_rounded),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: TextButton.icon(
        key: const ValueKey('home-how-to-use-action'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.foreground,
          backgroundColor: backgroundColor,
          side: BorderSide(color: colors.outlineSubtle),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        icon: const Icon(Icons.help_outline_rounded, size: 19),
        label: Text(
          localizations.howToUse,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class HomeGreetingHeader extends StatefulWidget {
  const HomeGreetingHeader({super.key, this.hour});

  final int? hour;

  @override
  State<HomeGreetingHeader> createState() => _HomeGreetingHeaderState();
}

class _HomeGreetingHeaderState extends State<HomeGreetingHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _homeGreetingEntranceDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotionCurves.emphasized,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationStarted) {
      return;
    }
    _animationStarted = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final hour = widget.hour ?? DateTime.now().hour;
    final period = _resolveGreetingPeriod(hour);
    final palette = _GreetingPalette.forPeriod(period);
    final phaseName = period.name;

    return Semantics(
      container: true,
      label:
          '${localizations.greetingForHour(hour)}. '
          '${localizations.homeGreetingPromptForHour(hour)}',
      child: Container(
        key: ValueKey('home-greeting-$phaseName'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.start, palette.end],
          ),
          borderRadius: BorderRadius.circular(AppRadii.large),
          boxShadow: [
            BoxShadow(
              color: palette.end.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -34,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final progress = _animation.value;
                    return Transform.rotate(
                      angle: (progress - 1) * 0.32,
                      child: Transform.scale(
                        scale: 0.78 + progress * 0.22,
                        child: Opacity(
                          key: const ValueKey('home-greeting-symbol-opacity'),
                          opacity: 0.35 + progress * 0.65,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    key: const ValueKey('home-greeting-symbol'),
                    width: 142,
                    height: 142,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.foreground.withValues(alpha: 0.16),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      palette.icon,
                      color: palette.accent,
                      size: 78,
                      shadows: [
                        Shadow(
                          color: palette.accent.withValues(alpha: 0.55),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 102,
              bottom: 20,
              child: _GreetingSparkle(
                color: palette.foreground.withValues(alpha: 0.30),
                size: 8,
              ),
            ),
            Positioned(
              right: 34,
              bottom: 16,
              child: _GreetingSparkle(
                color: palette.accent.withValues(alpha: 0.75),
                size: 12,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 118),
                child: FractionallySizedBox(
                  widthFactor: 0.76,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.greetingForHour(hour),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: palette.foreground,
                              fontWeight: AppFontWeights.heavy,
                              height: 1.02,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        localizations.homeGreetingPromptForHour(hour),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.foreground.withValues(alpha: 0.78),
                          height: 1.35,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingSparkle extends StatelessWidget {
  const _GreetingSparkle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Icon(Icons.auto_awesome_rounded, color: color, size: size),
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
    final primaryTitle = localizations.homeStartAnalysis;
    final primarySubtitle = selectedExercise == null
        ? localizations.homeStartChooseExercise
        : localizations.homeStartSelectedExercise(exerciseTitle!);

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
          spacing: AppSpacing.xs,
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
    final colors = context.semanticColors;
    final hasSelection = selectedExercise != null;
    final exerciseTitle = selectedExercise == null
        ? localizations.noExerciseSelected
        : localizations.exerciseTitle(selectedExercise!.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChangeExercise,
        borderRadius: BorderRadius.circular(AppRadii.compact),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceStrong.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadii.compact),
            border: Border.all(color: colors.outlineSubtle),
          ),
          child: Row(
            children: [
              Icon(
                hasSelection
                    ? Icons.fitness_center_rounded
                    : Icons.add_circle_outline_rounded,
                color: colors.analysisAccent,
                size: 21,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasSelection
                          ? localizations.selectedExercise(exerciseTitle)
                          : exerciseTitle,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.bold,
                      ),
                    ),
                    if (hasSelection) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        localizations.change,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.analysisAccent,
                          fontWeight: AppFontWeights.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right_rounded, color: colors.foregroundSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePrimaryActionCard extends StatefulWidget {
  const _HomePrimaryActionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_HomePrimaryActionCard> createState() => _HomePrimaryActionCardState();
}

class _HomePrimaryActionCardState extends State<_HomePrimaryActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotionDurations.celebration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotionCurves.emphasized,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationStarted) {
      return;
    }
    _animationStarted = true;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return Semantics(
      button: true,
      label: widget.title,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final progress = _animation.value;
          final rotation = progress * math.pi * 2;

          return Transform.scale(
            scale: 0.985 + progress * 0.015,
            child: Container(
              key: const ValueKey('home-primary-action'),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: SweepGradient(
                  transform: GradientRotation(rotation),
                  colors: [
                    colors.analysisAccent.withValues(alpha: 0.30),
                    colors.analysisAccent,
                    colors.foreground,
                    colors.analysisAccent,
                    colors.analysisAccent.withValues(alpha: 0.30),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadii.large),
                boxShadow: [
                  BoxShadow(
                    color: colors.analysisAccent.withValues(
                      alpha: 0.10 + progress * 0.20,
                    ),
                    blurRadius: 18 + progress * 16,
                    spreadRadius: progress * 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: colors.surfaceStrong,
                borderRadius: BorderRadius.circular(AppRadii.large - 2),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onTap,
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.analysisAccent.withValues(alpha: 0.18),
                          colors.surfaceStrong,
                          colors.analysisAccent.withValues(alpha: 0.08),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.analysisAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.analysisAccent.withValues(
                                  alpha: 0.42,
                                ),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: colors.foreground,
                                      height: 1.1,
                                      fontWeight: AppFontWeights.heavy,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                widget.subtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colors.foregroundMuted,
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.analysisAccent.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.analysisAccent.withValues(
                                alpha: AppOpacity.strongBorder,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: colors.analysisAccent,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _HomeSecondaryActionKind { planned, assessment }

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
        final stackActions = layout.hasLargeText || constraints.maxWidth < 560;
        final useCompactStackedCards = stackActions && !layout.hasLargeText;
        final fixedCardHeight = layout.hasLargeText
            ? null
            : (useCompactStackedCards || layout.isCompact ? 68.0 : 92.0);
        final showCardSubtitles = !useCompactStackedCards && !layout.isCompact;
        final cards = <Widget>[
          _HomeSecondaryActionCard(
            key: const ValueKey('home-planned-workout-action'),
            kind: _HomeSecondaryActionKind.planned,
            icon: Icons.fitness_center_rounded,
            title: localizations.plannedWorkout,
            subtitle: localizations.plannedWorkoutSubtitle,
            showSubtitle: showCardSubtitles,
            height: fixedCardHeight,
            onTap: onOpenWorkoutPlan,
          ),
          _HomeSecondaryActionCard(
            key: const ValueKey('home-assessment-action'),
            kind: _HomeSecondaryActionKind.assessment,
            icon: Icons.center_focus_strong_rounded,
            title: localizations.assessment,
            subtitle: localizations.assessmentSubtitle,
            showSubtitle: showCardSubtitles,
            height: fixedCardHeight,
            onTap: onOpenAssessment,
          ),
        ];

        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cards.first,
              const SizedBox(height: AppSpacing.xs),
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
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.showSubtitle,
    required this.height,
    required this.onTap,
  });

  final _HomeSecondaryActionKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showSubtitle;
  final double? height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final accent = switch (kind) {
      _HomeSecondaryActionKind.planned => colors.analysisAccent,
      _HomeSecondaryActionKind.assessment => Color.lerp(
        colors.analysisAccent,
        const Color(0xFF7AB8FF),
        0.72,
      )!,
    };

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.large),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.large),
          child: SizedBox(
            height: height,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.22),
                    colors.surfaceStrong,
                    accent.withValues(alpha: 0.07),
                  ],
                  stops: const [0, 0.58, 1],
                ),
                borderRadius: BorderRadius.circular(AppRadii.large),
                border: Border.all(
                  color: accent.withValues(alpha: AppOpacity.strongBorder),
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.11),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -12,
                    bottom: -14,
                    child: IgnorePointer(
                      child: Icon(
                        icon,
                        size: 82,
                        color: accent.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accent, accent.withValues(alpha: 0.58)],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadii.compact,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.30),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.black, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.foreground,
                                      height: 1.08,
                                      fontWeight: AppFontWeights.heavy,
                                    ),
                              ),
                              if (showSubtitle) ...[
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.foregroundMuted,
                                        height: 1.22,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(
                                alpha: AppOpacity.strongBorder,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_outward_rounded,
                            color: accent,
                            size: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
