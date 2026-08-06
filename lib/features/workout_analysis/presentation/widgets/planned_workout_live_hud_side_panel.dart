import 'package:flutter/material.dart';

import 'planned_workout_hud_models.dart';
import 'planned_workout_hud_theme.dart';
import 'planned_workout_live_hud_cards.dart';
import 'planned_workout_live_hud_top_bar.dart';

class PlannedWorkoutSidePanel extends StatelessWidget {
  const PlannedWorkoutSidePanel({
    super.key,
    required this.data,
    required this.pauseLabel,
    required this.finishLabel,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
  });

  final PlannedWorkoutLiveHudData data;
  final String pauseLabel;
  final String finishLabel;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useStackedLayout = constraints.maxWidth < 320 || textScale >= 1.5;

        return ColoredBox(
          key: const ValueKey<String>('planned-workout-live-hud'),
          color: const Color(0xF0161B20),
          child: SafeArea(
            left: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (useStackedLayout)
                    PlannedWorkoutSidePanelHeader(
                      exerciseTitle: data.exerciseTitle,
                      pauseLabel: pauseLabel,
                      finishLabel: finishLabel,
                      isFinishing: isFinishing,
                      onPause: onPause,
                      onFinish: onFinish,
                    )
                  else
                    PlannedWorkoutTopBar(
                      compact: true,
                      exerciseTitle: data.exerciseTitle,
                      pauseLabel: pauseLabel,
                      finishLabel: finishLabel,
                      isFinishing: isFinishing,
                      onPause: onPause,
                      onFinish: onFinish,
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey<String>(
                        'planned-workout-side-panel-scroll',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (useStackedLayout)
                            Column(
                              key: const ValueKey<String>(
                                'planned-workout-stacked-metrics',
                              ),
                              children: <Widget>[
                                SizedBox(
                                  height: 86,
                                  child: PlannedWorkoutMetricCard(
                                    key: const ValueKey<String>(
                                      'planned-workout-primary-metric',
                                    ),
                                    compact: true,
                                    label: data.primaryLabel,
                                    value: data.primaryValue,
                                    icon: data.primaryIcon,
                                    tone: PlannedWorkoutHudTone.positive,
                                    emphasize: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 86,
                                  child: PlannedWorkoutMetricCard(
                                    key: const ValueKey<String>(
                                      'planned-workout-secondary-metric',
                                    ),
                                    compact: true,
                                    label: data.secondaryLabel,
                                    value: data.secondaryValue,
                                    icon: Icons.star_rounded,
                                    tone: data.secondaryTone,
                                  ),
                                ),
                              ],
                            )
                          else
                            SizedBox(
                              height: 78,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Expanded(
                                    flex: 3,
                                    child: PlannedWorkoutMetricCard(
                                      key: const ValueKey<String>(
                                        'planned-workout-primary-metric',
                                      ),
                                      compact: true,
                                      label: data.primaryLabel,
                                      value: data.primaryValue,
                                      icon: data.primaryIcon,
                                      tone: PlannedWorkoutHudTone.positive,
                                      emphasize: true,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: PlannedWorkoutMetricCard(
                                      key: const ValueKey<String>(
                                        'planned-workout-secondary-metric',
                                      ),
                                      compact: true,
                                      label: data.secondaryLabel,
                                      value: data.secondaryValue,
                                      icon: Icons.star_rounded,
                                      tone: data.secondaryTone,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (data.hasFeedback) ...<Widget>[
                            const SizedBox(height: 8),
                            PlannedWorkoutFeedbackCard(
                              data: data,
                              compact: true,
                            ),
                          ],
                          const SizedBox(height: 8),
                          PlannedWorkoutProgressCard(
                            data: data,
                            compact: true,
                            stackedHeader: useStackedLayout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class PlannedWorkoutSidePanelHeader extends StatelessWidget {
  const PlannedWorkoutSidePanelHeader({
    super.key,
    required this.exerciseTitle,
    required this.pauseLabel,
    required this.finishLabel,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
  });

  final String exerciseTitle;
  final String pauseLabel;
  final String finishLabel;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('planned-workout-stacked-header'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            exerciseTitle,
            key: const ValueKey<String>('planned-workout-exercise-title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: PlannedWorkoutActionButton(
                key: const ValueKey<String>('live-pause-button'),
                compact: true,
                label: pauseLabel,
                icon: Icons.pause_rounded,
                accentColor: plannedHudAccent,
                onPressed: onPause,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PlannedWorkoutActionButton(
                key: const ValueKey<String>('planned-workout-finish-button'),
                compact: true,
                label: finishLabel,
                icon: Icons.stop_rounded,
                accentColor: Colors.white70,
                onPressed: isFinishing ? null : onFinish,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
