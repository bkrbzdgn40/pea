import 'package:flutter/material.dart';

import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_motion.dart';

import 'planned_workout_hud_models.dart';
import 'planned_workout_hud_theme.dart';

class PlannedWorkoutMetricCard extends StatelessWidget {
  const PlannedWorkoutMetricCard({
    super.key,
    required this.compact,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.emphasize = false,
  });

  final bool compact;
  final String label;
  final String value;
  final IconData icon;
  final PlannedWorkoutHudTone tone;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final accentColor = plannedHudToneColor(tone);
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.resolveDuration(context, AppMotionDurations.fast),
        curve: AppMotion.resolveCurve(context, Curves.easeOut),
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: compact ? 8 : 12,
        ),
        decoration: plannedSurfaceDecoration(
          accentColor: accentColor,
          strong: emphasize,
          radius: compact ? 18 : 25,
          surfaceColor: emphasize
              ? plannedHudMetricSurfaceStrong
              : plannedHudMetricSurface,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: compact ? 28 : 34,
              height: compact ? 28 : 34,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: compact ? 16 : 20),
            ),
            SizedBox(width: compact ? 6 : 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: AnimatedSwitcher(
                          duration: AppMotion.resolveDuration(
                            context,
                            AppMotionDurations.fast,
                          ),
                          child: Text(
                            value,
                            key: ValueKey<String>(value),
                            maxLines: 1,
                            style: TextStyle(
                              color: tone == PlannedWorkoutHudTone.muted
                                  ? Colors.white54
                                  : Colors.white,
                              fontSize: compact ? 25 : 36,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tone == PlannedWorkoutHudTone.muted
                          ? Colors.white38
                          : Colors.white70,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlannedWorkoutProgressCard extends StatelessWidget {
  const PlannedWorkoutProgressCard({
    super.key,
    required this.data,
    required this.compact,
    this.stackedHeader = false,
  });

  final PlannedWorkoutLiveHudData data;
  final bool compact;
  final bool stackedHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('planned-workout-progress-card'),
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 9 : 12,
        compact ? 12 : 16,
        compact ? 9 : 12,
      ),
      decoration: plannedSurfaceDecoration(
        accentColor: plannedHudAccent,
        radius: compact ? 18 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (stackedHeader)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.bar_chart_rounded,
                      color: plannedHudAccent,
                      size: compact ? 18 : 22,
                    ),
                    SizedBox(width: compact ? 7 : 9),
                    Expanded(
                      child: Text(
                        data.progressLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data.progressValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: plannedHudAccent,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            )
          else
            Row(
              children: <Widget>[
                Icon(
                  Icons.bar_chart_rounded,
                  color: plannedHudAccent,
                  size: compact ? 18 : 22,
                ),
                SizedBox(width: compact ? 7 : 9),
                Expanded(
                  child: Text(
                    data.progressLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 12 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  data.progressValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: plannedHudAccent,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          SizedBox(height: compact ? 6 : 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: data.progress.clamp(0.0, 1.0).toDouble(),
              minHeight: compact ? 5 : 7,
              color: plannedHudAccent,
              backgroundColor: Colors.white12,
            ),
          ),
          if (data.sideLabel != null) ...<Widget>[
            SizedBox(height: compact ? 6 : 8),
            Row(
              children: <Widget>[
                Icon(
                  Icons.directions_walk_rounded,
                  color: Colors.white.withValues(alpha: 0.60),
                  size: compact ? 14 : 17,
                ),
                SizedBox(width: compact ? 5 : 7),
                Expanded(
                  child: Text(
                    data.sideLabel!,
                    key: const ValueKey<String>(
                      'planned-workout-side-indicator',
                    ),
                    maxLines: stackedHeader ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class PlannedWorkoutFeedbackCard extends StatelessWidget {
  const PlannedWorkoutFeedbackCard({
    super.key,
    required this.data,
    required this.compact,
  });

  final PlannedWorkoutLiveHudData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accentColor = plannedHudToneColor(data.feedbackTone);
    return AnimatedContainer(
      key: const ValueKey<String>('planned-workout-feedback-card'),
      duration: AppMotion.resolveDuration(context, AppMotionDurations.standard),
      curve: AppMotion.resolveCurve(context, Curves.easeOut),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 9 : 13,
      ),
      decoration: plannedSurfaceDecoration(
        accentColor: accentColor,
        strong: true,
        radius: compact ? 18 : 24,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 38 : 50,
            height: compact ? 38 : 50,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.8),
                width: compact ? 1.2 : 1.5,
              ),
            ),
            child: Icon(
              data.feedbackIcon,
              color: accentColor,
              size: compact ? 23 : 30,
            ),
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.feedbackTitle!,
                  key: const ValueKey<String>('live-analysis-status-line'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 15 : 21,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: compact ? 3 : 5),
                Text(
                  data.feedbackMessage!,
                  key: const ValueKey<String>(
                    'planned-workout-feedback-message',
                  ),
                  maxLines: compact ? 2 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: compact ? 12 : 14,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (data.feedbackMeasurementConfidenceLabel !=
                    null) ...<Widget>[
                  SizedBox(height: compact ? 3 : 5),
                  Text(
                    data.feedbackMeasurementConfidenceLabel!,
                    key: const ValueKey<String>(
                      'planned-workout-measurement-confidence',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: compact ? 10 : 11,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
