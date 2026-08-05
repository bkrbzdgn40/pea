import 'package:flutter/material.dart';

import 'live_analysis/live_hud_mode_control.dart';
import 'planned_workout_hud_theme.dart';

class PlannedWorkoutTopBar extends StatelessWidget {
  const PlannedWorkoutTopBar({
    super.key,
    required this.compact,
    required this.exerciseTitle,
    required this.pauseLabel,
    required this.finishLabel,
    required this.isFinishing,
    required this.showDetails,
    required this.showFinishAction,
    required this.onPause,
    required this.onFinish,
    required this.onToggleDetails,
  });

  final bool compact;
  final String exerciseTitle;
  final String pauseLabel;
  final String finishLabel;
  final bool isFinishing;
  final bool showDetails;
  final bool showFinishAction;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 42 : 54,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PlannedWorkoutActionButton(
                key: const ValueKey<String>('live-pause-button'),
                compact: compact,
                label: pauseLabel,
                icon: Icons.pause_rounded,
                accentColor: plannedHudAccent,
                onPressed: onPause,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          Expanded(
            flex: 3,
            child: Semantics(
              header: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  exerciseTitle,
                  key: const ValueKey<String>('planned-workout-exercise-title'),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 18 : 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          Expanded(
            flex: showFinishAction ? 6 : 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LiveHudModeControl(
                    compact: compact,
                    showDetails: showDetails,
                    onPressed: onToggleDetails,
                  ),
                  if (showFinishAction) ...<Widget>[
                    SizedBox(width: compact ? 6 : 8),
                    Flexible(
                      child: PlannedWorkoutActionButton(
                        key: const ValueKey<String>(
                          'planned-workout-finish-button',
                        ),
                        compact: compact,
                        label: finishLabel,
                        icon: Icons.stop_rounded,
                        accentColor: Colors.white70,
                        onPressed: isFinishing ? null : onFinish,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlannedWorkoutActionButton extends StatelessWidget {
  const PlannedWorkoutActionButton({
    super.key,
    required this.compact,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
  });

  final bool compact;
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 7 : 10,
            ),
            decoration: BoxDecoration(
              color: plannedHudSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: accentColor.withValues(
                  alpha: onPressed == null ? 0.18 : 0.48,
                ),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: compact ? 24 : 30,
                  height: compact ? 24 : 30,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: onPressed == null ? Colors.white30 : accentColor,
                    size: compact ? 15 : 18,
                  ),
                ),
                SizedBox(width: compact ? 7 : 9),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: onPressed == null
                            ? Colors.white38
                            : Colors.white,
                        fontSize: compact ? 12 : 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
