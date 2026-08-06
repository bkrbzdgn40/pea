import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_plan_session_provider.dart';

import 'live_analysis_theme.dart';
import 'live_hud_mode_control.dart';

class LiveWorkoutTopBarOverlay extends StatelessWidget {
  const LiveWorkoutTopBarOverlay({
    super.key,
    required this.topInset,
    required this.compact,
    required this.reserveLeadingDeveloperControl,
    required this.isFinishing,
    required this.showDetails,
    required this.showFinishAction,
    required this.onPause,
    required this.onFinish,
    required this.onToggleDetails,
  });

  final double topInset;
  final bool compact;
  final bool reserveLeadingDeveloperControl;
  final bool isFinishing;
  final bool showDetails;
  final bool showFinishAction;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final horizontalInset = compact ? 12.0 : 16.0;
    final leftInset = reserveLeadingDeveloperControl
        ? (compact ? 58.0 : 68.0)
        : horizontalInset;

    return Positioned(
      key: const ValueKey<String>('live-workout-top-bar-overlay'),
      top: topInset + (compact ? 8 : 12),
      left: leftInset,
      right: horizontalInset,
      child: _LiveWorkoutTopBar(
        compact: compact,
        isFinishing: isFinishing,
        showDetails: showDetails,
        showFinishAction: showFinishAction,
        onPause: onPause,
        onFinish: onFinish,
        onToggleDetails: onToggleDetails,
      ),
    );
  }
}

class _LiveWorkoutTopBar extends StatelessWidget {
  const _LiveWorkoutTopBar({
    required this.compact,
    required this.isFinishing,
    required this.showDetails,
    required this.showFinishAction,
    required this.onPause,
    required this.onFinish,
    required this.onToggleDetails,
  });

  final bool compact;
  final bool isFinishing;
  final bool showDetails;
  final bool showFinishAction;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return SizedBox(
      key: const ValueKey<String>('live-workout-top-bar'),
      height: compact ? 42 : 54,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: LiveHudActionButton(
                key: const ValueKey<String>('live-pause-button'),
                compact: compact,
                label: localizations.pauseWorkout,
                icon: Icons.pause_rounded,
                accentColor: liveHudAccent,
                onPressed: onPause,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          const Expanded(flex: 3, child: ActiveExerciseTitle()),
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
                      child: LiveHudActionButton(
                        key: const ValueKey<String>('live-finish-button'),
                        compact: compact,
                        label: localizations.finish,
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

class FinishSessionButton extends ConsumerWidget {
  const FinishSessionButton({
    super.key,
    required this.topInset,
    required this.compact,
    required this.isFinishing,
    required this.onFinish,
  });

  final double topInset;
  final bool compact;
  final bool isFinishing;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPlan = ref.watch(
      workoutPlanSessionProvider.select((state) => state.hasPlan),
    );
    final localizations = AppLocalizations.of(context);

    return Positioned(
      top: topInset + (compact ? 8 : 12),
      right: compact ? 10 : 14,
      child: LiveHudActionButton(
        key: const ValueKey<String>('live-finish-button'),
        compact: compact,
        label: hasPlan ? localizations.endWorkout : localizations.finish,
        icon: Icons.stop_rounded,
        accentColor: Colors.white70,
        onPressed: isFinishing ? null : onFinish,
      ),
    );
  }
}

class LiveHudActionButton extends StatelessWidget {
  const LiveHudActionButton({
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
              color: liveHudSurface,
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
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 160 : 220),
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
      ),
    );
  }
}

class ActiveExerciseTitle extends ConsumerWidget {
  const ActiveExerciseTitle({
    super.key,
    this.compact = false,
    this.maxLines = 1,
  });

  final bool compact;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(activeAnalysisExerciseProvider);
    if (exercise == null) {
      return const SizedBox.shrink();
    }

    final title = AppLocalizations.of(context).exerciseTitle(exercise.id);
    final titleText = Text(
      title,
      key: const ValueKey<String>('live-active-exercise-name'),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: compact ? 18 : 25,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
    );

    return Semantics(
      label: title,
      header: true,
      excludeSemantics: true,
      child: maxLines > 1
          ? Center(child: titleText)
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: titleText,
            ),
    );
  }
}
