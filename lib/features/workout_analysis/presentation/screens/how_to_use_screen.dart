import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_scaffold_shell.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_motion.dart';
import '../../../../app/theme/app_semantic_colors.dart';

class HowToUseScreen extends StatefulWidget {
  const HowToUseScreen({super.key});

  @override
  State<HowToUseScreen> createState() => _HowToUseScreenState();
}

class _HowToUseScreenState extends State<HowToUseScreen> {
  final Set<String> _expandedStepIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final steps = <_HowToUseStepData>[
      _HowToUseStepData(
        id: '1',
        title: localizations.chooseExerciseStep,
        body: localizations.chooseExerciseStepBody,
        detail: localizations.howToUseStepHintExercise,
        icon: Icons.fitness_center_rounded,
        accent: context.semanticColors.analysisAccent,
      ),
      _HowToUseStepData(
        id: '2',
        title: localizations.placePhoneStep,
        body: localizations.placePhoneStepBody,
        detail: localizations.howToUseStepHintPhone,
        icon: Icons.smartphone_rounded,
        accent: const Color(0xFFFFD54F),
      ),
      _HowToUseStepData(
        id: '3',
        title: localizations.enterFrameStep,
        body: localizations.enterFrameStepBody,
        detail: localizations.howToUseStepHintFrame,
        icon: Icons.accessibility_new_rounded,
        accent: const Color(0xFF7FE7FF),
      ),
      _HowToUseStepData(
        id: '4',
        title: localizations.finishPreparationStep,
        body: localizations.finishPreparationStepBody,
        detail: localizations.howToUseStepHintPreparation,
        icon: Icons.checklist_rounded,
        accent: const Color(0xFFB39DFF),
      ),
      _HowToUseStepData(
        id: '5',
        title: localizations.startAnalysisStep,
        body: localizations.startAnalysisStepBody,
        detail: localizations.howToUseStepHintLive,
        icon: Icons.play_circle_fill_rounded,
        accent: const Color(0xFF5EF0A5),
      ),
      _HowToUseStepData(
        id: '6',
        title: localizations.reviewSummaryStep,
        body: localizations.reviewSummaryStepBody,
        detail: localizations.howToUseStepHintSummary,
        icon: Icons.insights_rounded,
        accent: const Color(0xFFFF9E80),
      ),
    ];

    return AppScaffoldShell(
      title: localizations.howToUse,
      currentPage: AppDestination.howToUse,
      padding: EdgeInsets.zero,
      maxContentWidth: 760,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _HowToUseCardLayout.resolve(
            context: context,
            constraints: constraints,
            itemCount: steps.length,
          );

          return ListView.builder(
            key: const ValueKey<String>('how-to-use-scroll'),
            padding: EdgeInsets.zero,
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isExpanded = _expandedStepIds.contains(step.id);

              return _HowToUseStepSlot(
                key: ValueKey<String>('how-to-use-step-${step.id}'),
                topInset: layout.topInsetFor(index),
                bottomInset: layout.bottomInsetFor(index),
                child: _ExpandableHowToStepCard(
                  index: index,
                  collapsedHeight: layout.cardHeight,
                  lockCollapsedHeight: layout.lockCollapsedHeight,
                  isExpanded: isExpanded,
                  onToggle: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedStepIds.remove(step.id);
                      } else {
                        _expandedStepIds.add(step.id);
                      }
                    });
                  },
                  data: step,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HowToUseCardLayout {
  const _HowToUseCardLayout({
    required this.cardHeight,
    required this.gap,
    required this.itemCount,
    required this.lockCollapsedHeight,
  });

  static const double _minimumCardHeight = 66;
  static const double _surfaceVerticalBorderExtent = 2;
  static const double _preferredGap = AppSpacing.xs;
  static const double _topPadding = 10;
  static const double _bottomPadding = 14;

  final double cardHeight;
  final double gap;
  final int itemCount;
  final bool lockCollapsedHeight;

  double topInsetFor(int index) {
    return index == 0 ? _topPadding : gap / 2;
  }

  double bottomInsetFor(int index) {
    return index == itemCount - 1 ? _bottomPadding : gap / 2;
  }

  static _HowToUseCardLayout resolve({
    required BuildContext context,
    required BoxConstraints constraints,
    required int itemCount,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final usesLargeText = mediaQuery.textScaler.scale(1) > 1.2;
    final gapCount = itemCount - 1;
    final reservedSpace =
        _topPadding + _bottomPadding + gapCount * _preferredGap;
    final naturalHeight = (constraints.maxHeight - reservedSpace) / itemCount;
    final canLockCollapsedHeight =
        !usesLargeText && naturalHeight >= _minimumCardHeight;

    return _HowToUseCardLayout(
      cardHeight: canLockCollapsedHeight
          ? naturalHeight - _surfaceVerticalBorderExtent
          : _minimumCardHeight,
      gap: _preferredGap,
      itemCount: itemCount,
      lockCollapsedHeight: canLockCollapsedHeight,
    );
  }
}

class _HowToUseStepSlot extends StatelessWidget {
  const _HowToUseStepSlot({
    super.key,
    required this.topInset,
    required this.bottomInset,
    required this.child,
  });

  final double topInset;
  final double bottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motionDuration = AppMotion.resolveDuration(
      context,
      AppMotionDurations.deliberate,
    );
    final motionCurve = AppMotion.resolveCurve(
      context,
      AppMotionCurves.emphasized,
    );

    return Padding(
      padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
      child: AnimatedSize(
        duration: motionDuration,
        curve: motionCurve,
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }
}

class _ExpandableHowToStepCard extends StatefulWidget {
  const _ExpandableHowToStepCard({
    required this.index,
    required this.collapsedHeight,
    required this.lockCollapsedHeight,
    required this.isExpanded,
    required this.onToggle,
    required this.data,
  });

  final int index;
  final double collapsedHeight;
  final bool lockCollapsedHeight;
  final bool isExpanded;
  final VoidCallback onToggle;
  final _HowToUseStepData data;

  @override
  State<_ExpandableHowToStepCard> createState() =>
      _ExpandableHowToStepCardState();
}

class _ExpandableHowToStepCardState extends State<_ExpandableHowToStepCard> {
  Timer? _entranceTimer;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _entranceTimer = Timer(
      Duration(milliseconds: 110 + widget.index * 120),
      () {
        if (mounted) {
          setState(() => _isVisible = true);
        }
      },
    );
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final motionDuration = AppMotion.resolveDuration(
      context,
      AppMotionDurations.deliberate,
    );
    final motionCurve = AppMotion.resolveCurve(
      context,
      AppMotionCurves.emphasized,
    );

    final shouldShow = _isVisible || AppMotion.prefersReducedMotion(context);

    return AnimatedSlide(
      offset: shouldShow ? Offset.zero : const Offset(0, 0.14),
      duration: motionDuration,
      curve: motionCurve,
      child: AnimatedOpacity(
        opacity: shouldShow ? 1 : 0,
        duration: motionDuration,
        curve: motionCurve,
        child: AppSurfaceCard(
          key: ValueKey<String>('how-to-use-step-${widget.data.id}-surface'),
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          borderColor: widget.isExpanded
              ? widget.data.accent.withValues(alpha: 0.46)
              : colors.outlineSubtle,
          child: Semantics(
            button: true,
            label: '${widget.data.id}. ${widget.data.title}',
            hint: widget.isExpanded
                ? localizationsCollapseStep(context)
                : localizationsExpandStep(context),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey<String>(
                  'how-to-use-step-${widget.data.id}-toggle',
                ),
                onTap: widget.onToggle,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      key: ValueKey<String>(
                        'how-to-use-step-${widget.data.id}-header',
                      ),
                      constraints: widget.lockCollapsedHeight
                          ? BoxConstraints.tightFor(
                              height: widget.collapsedHeight,
                            )
                          : BoxConstraints(minHeight: widget.collapsedHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            _StepIllustration(data: widget.data),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                widget.data.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.foreground,
                                      fontWeight: AppFontWeights.bold,
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _StepNumberPill(
                              key: ValueKey<String>(
                                'how-to-use-step-${widget.data.id}-number',
                              ),
                              number: widget.data.id,
                              color: widget.data.accent,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            AnimatedRotation(
                              turns: widget.isExpanded ? 0.5 : 0,
                              duration: motionDuration,
                              curve: motionCurve,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.isExpanded)
                      _ExpandedStepDetails(data: widget.data),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String localizationsExpandStep(BuildContext context) {
    return AppLocalizations.of(context).howToUseExpandStep;
  }

  String localizationsCollapseStep(BuildContext context) {
    return AppLocalizations.of(context).howToUseCollapseStep;
  }
}

class _ExpandedStepDetails extends StatelessWidget {
  const _ExpandedStepDetails({required this.data});

  final _HowToUseStepData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Padding(
      key: ValueKey<String>('how-to-use-step-${data.id}-details'),
      padding: const EdgeInsets.only(
        left: 58,
        top: AppSpacing.sm,
        right: AppSpacing.xs,
        bottom: AppSpacing.xxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: data.accent.withValues(alpha: 0.20)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foregroundMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.tips_and_updates_outlined,
                  color: data.accent,
                  size: 17,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  data.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.foregroundSubtle,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepIllustration extends StatelessWidget {
  const _StepIllustration({required this.data});

  final _HowToUseStepData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.compact),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.accent.withValues(alpha: 0.30),
            data.accent.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: data.accent.withValues(alpha: 0.30)),
      ),
      child: Icon(data.icon, color: data.accent, size: 23),
    );
  }
}

class _StepNumberPill extends StatelessWidget {
  const _StepNumberPill({super.key, required this.number, required this.color});

  static const double dimension = 36;

  final String number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Center(
          child: Text(
            number,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: AppFontWeights.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _HowToUseStepData {
  const _HowToUseStepData({
    required this.id,
    required this.title,
    required this.body,
    required this.detail,
    required this.icon,
    required this.accent,
  });

  final String id;
  final String title;
  final String body;
  final String detail;
  final IconData icon;
  final Color accent;
}
