import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import 'planned_workout_hud_models.dart';
import 'planned_workout_live_hud_cards.dart';
import 'planned_workout_live_hud_side_panel.dart';
import 'planned_workout_live_hud_top_bar.dart';

class PlannedWorkoutLiveHudView extends StatelessWidget {
  const PlannedWorkoutLiveHudView({
    super.key,
    required this.data,
    required this.topInset,
    required this.compact,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
    this.reserveLeadingDeveloperControl = false,
    this.sidePanel = false,
  });

  final PlannedWorkoutLiveHudData data;
  final double topInset;
  final bool compact;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final bool reserveLeadingDeveloperControl;
  final bool sidePanel;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (sidePanel) {
      return PlannedWorkoutSidePanel(
        data: data,
        pauseLabel: localizations.pauseWorkout,
        finishLabel: localizations.endWorkout,
        isFinishing: isFinishing,
        onPause: onPause,
        onFinish: onFinish,
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final horizontalInset = compact ? 12.0 : 16.0;
    final bottomHorizontalInset = compact
        ? 12.0
        : MediaQuery.sizeOf(context).width < 360
        ? 16.0
        : 36.0;
    final topBarLeft = reserveLeadingDeveloperControl
        ? (compact ? 58.0 : 68.0)
        : horizontalInset;

    return Stack(
      key: const ValueKey<String>('planned-workout-live-hud'),
      children: <Widget>[
        Positioned(
          top: topInset + (compact ? 8 : 12),
          left: topBarLeft,
          right: horizontalInset,
          child: PlannedWorkoutTopBar(
            compact: compact,
            exerciseTitle: data.exerciseTitle,
            pauseLabel: localizations.pauseWorkout,
            finishLabel: localizations.endWorkout,
            isFinishing: isFinishing,
            onPause: onPause,
            onFinish: onFinish,
          ),
        ),
        Positioned(
          top: topInset + (compact ? 58 : 82),
          left: horizontalInset,
          right: horizontalInset,
          child: SizedBox(
            height: compact ? 72 : 104,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desiredCardWidth = compact
                    ? (constraints.maxWidth * 0.24).clamp(150.0, 210.0)
                    : (constraints.maxWidth * 0.44).clamp(140.0, 184.0);
                final maximumCardWidth =
                    (constraints.maxWidth - (compact ? 12.0 : 16.0)) / 2;
                final cardWidth =
                    (desiredCardWidth > maximumCardWidth
                            ? maximumCardWidth
                            : desiredCardWidth)
                        .toDouble();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: PlannedWorkoutMetricCard(
                        key: const ValueKey<String>(
                          'planned-workout-primary-metric',
                        ),
                        compact: compact,
                        label: data.primaryLabel,
                        value: data.primaryValue,
                        icon: data.primaryIcon,
                        tone: PlannedWorkoutHudTone.positive,
                        emphasize: true,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: PlannedWorkoutMetricCard(
                        key: const ValueKey<String>(
                          'planned-workout-secondary-metric',
                        ),
                        compact: compact,
                        label: data.secondaryLabel,
                        value: data.secondaryValue,
                        icon: Icons.star_rounded,
                        tone: data.secondaryTone,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Positioned(
          left: bottomHorizontalInset,
          right: bottomHorizontalInset,
          bottom: bottomInset + (compact ? 10 : 18),
          child: compact
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      flex: data.hasFeedback ? 5 : 1,
                      child: PlannedWorkoutProgressCard(
                        data: data,
                        compact: true,
                      ),
                    ),
                    if (data.hasFeedback) ...<Widget>[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: PlannedWorkoutFeedbackCard(
                          data: data,
                          compact: true,
                        ),
                      ),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PlannedWorkoutProgressCard(data: data, compact: false),
                    if (data.hasFeedback) ...<Widget>[
                      const SizedBox(height: 10),
                      PlannedWorkoutFeedbackCard(data: data, compact: false),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
