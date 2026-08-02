import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/live_tracking_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_tracking_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/pose_painter.dart';

class WorkoutPoseOverlay extends ConsumerWidget {
  const WorkoutPoseOverlay({
    super.key,
    required this.imageSize,
    required this.isMirrored,
    required this.showDebugLandmarks,
  });

  final Size imageSize;
  final bool isMirrored;
  final bool showDebugLandmarks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pose = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          landmarks: state.landmarks,
          isFormBad: state.isFormBad,
          movementSelectedSide:
              state.calibrationMetrics.rangeRepMovementSelectedSide,
        ),
      ),
    );
    final landmarks = pose.landmarks;
    if (landmarks == null || landmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: PosePainter(
        landmarks,
        imageSize,
        isFormBad: pose.isFormBad,
        isMirrored: isMirrored,
        showDebugLandmarks: showDebugLandmarks,
        emphasizedSide: pose.movementSelectedSide,
      ),
    );
  }
}

class LiveTrackingRecoveryOverlay extends ConsumerWidget {
  const LiveTrackingRecoveryOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(
      liveTrackingControllerProvider.select((state) => state.phase),
    );
    if (phase == LiveTrackingPhase.tracking) {
      return const SizedBox.shrink();
    }

    final presentation = _liveTrackingPresentation(
      phase,
      AppLocalizations.of(context),
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Container(
                key: ValueKey<LiveTrackingPhase>(phase),
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: presentation.color.withValues(alpha: 0.72),
                    width: 1.4,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: presentation.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        presentation.icon,
                        color: presentation.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      presentation.title,
                      key: const ValueKey<String>(
                        'live-tracking-overlay-title',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      presentation.message,
                      key: const ValueKey<String>(
                        'live-tracking-overlay-message',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

_LiveTrackingPresentation _liveTrackingPresentation(
  LiveTrackingPhase phase,
  AppLocalizations localizations,
) {
  return switch (phase) {
    LiveTrackingPhase.tracking => _LiveTrackingPresentation(
      title: '',
      message: '',
      color: Colors.greenAccent,
      icon: Icons.check_rounded,
    ),
    LiveTrackingPhase.temporarilyLost => _LiveTrackingPresentation(
      title: localizations.liveTrackingTemporarilyLostTitle,
      message: localizations.liveTrackingTemporarilyLostMessage,
      color: Colors.amberAccent,
      icon: Icons.visibility_off_outlined,
    ),
    LiveTrackingPhase.repositionRequired => _LiveTrackingPresentation(
      title: localizations.liveTrackingRepositionTitle,
      message: localizations.liveTrackingRepositionMessage,
      color: Colors.orangeAccent,
      icon: Icons.center_focus_weak_rounded,
    ),
    LiveTrackingPhase.reacquiring => _LiveTrackingPresentation(
      title: localizations.liveTrackingReacquiringTitle,
      message: localizations.liveTrackingReacquiringMessage,
      color: Colors.cyanAccent,
      icon: Icons.track_changes_rounded,
    ),
  };
}

class _LiveTrackingPresentation {
  const _LiveTrackingPresentation({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;
}
