import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_motion.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_readiness_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/setup_readiness_ui_mapper.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/live_pause_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/setup_readiness_view_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_pause_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/preparation_camera_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/preparation_readiness_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/pose_painter.dart';

class PausedPoseOverlay extends ConsumerWidget {
  const PausedPoseOverlay({
    super.key,
    required this.imageSize,
    required this.isMirrored,
  });

  final Size imageSize;
  final bool isMirrored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landmarks = ref.watch(
      preparationCameraControllerProvider.select((state) => state.landmarks),
    );
    if (landmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: PosePainter(
          landmarks,
          imageSize,
          isFormBad: false,
          isMirrored: isMirrored,
        ),
      ),
    );
  }
}

class LivePauseOverlay extends ConsumerWidget {
  const LivePauseOverlay({
    super.key,
    required this.readinessRequest,
    required this.onResume,
    required this.onCancelResume,
  });

  final SetupReadinessRequest readinessRequest;
  final VoidCallback onResume;
  final VoidCallback onCancelResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pauseState = ref.watch(livePauseControllerProvider);
    if (pauseState.isActive) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);
    final readinessProvider = preparationReadinessStateProvider(
      readinessRequest,
    );
    ref.listen<SetupReadinessSnapshot>(readinessProvider, (_, next) {
      ref.read(livePauseControllerProvider.notifier).updateReadiness(next);
    });
    final readiness = ref.watch(readinessProvider);
    final readinessView = mapSetupReadinessToViewData(
      localizations: localizations,
      readinessSnapshot: readiness,
    );
    final presentation = _livePausePresentation(
      state: pauseState,
      readinessView: readinessView,
      localizations: localizations,
    );

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.46),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 96, 24, 36),
              child: Container(
                key: const ValueKey<String>('live-pause-overlay'),
                constraints: const BoxConstraints(maxWidth: 430),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: presentation.color.withValues(alpha: 0.62),
                    width: 1.4,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 26,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: presentation.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        presentation.icon,
                        color: presentation.color,
                        size: 31,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      presentation.title,
                      key: const ValueKey<String>('live-pause-title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      presentation.message,
                      key: const ValueKey<String>('live-pause-message'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pauseState.isCountingDown) ...<Widget>[
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: AppMotion.resolveDuration(
                          context,
                          AppMotionDurations.fast,
                        ),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Text(
                          '${pauseState.countdownValue ?? ''}',
                          key: ValueKey<String>(
                            'live-resume-countdown-${pauseState.countdownValue}',
                          ),
                          semanticsLabel: localizations
                              .liveResumeCountdownSemantics(
                                pauseState.countdownValue ?? 0,
                              ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (pauseState.phase == LivePausePhase.paused)
                      FilledButton.icon(
                        key: const ValueKey<String>('live-resume-button'),
                        onPressed: onResume,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(localizations.resumeWorkout),
                      )
                    else
                      OutlinedButton.icon(
                        key: const ValueKey<String>(
                          'live-cancel-resume-button',
                        ),
                        onPressed: onCancelResume,
                        icon: const Icon(Icons.pause_rounded),
                        label: Text(localizations.returnToPause),
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

_LivePausePresentation _livePausePresentation({
  required LivePauseState state,
  required SetupReadinessViewData readinessView,
  required AppLocalizations localizations,
}) {
  return switch (state.phase) {
    LivePausePhase.active => _LivePausePresentation(
      title: '',
      message: '',
      color: Colors.greenAccent,
      icon: Icons.play_arrow_rounded,
    ),
    LivePausePhase.paused => _LivePausePresentation(
      title: localizations.workoutPausedTitle,
      message: localizations.workoutPausedMessage,
      color: Colors.cyanAccent,
      icon: Icons.pause_rounded,
    ),
    LivePausePhase.resumeMonitoring => _LivePausePresentation(
      title: localizations.resumeReadinessTitle,
      message: readinessView.message,
      color:
          readinessView.visualState == SetupReadinessVisualState.needsAdjustment
          ? Colors.amberAccent
          : Colors.cyanAccent,
      icon:
          readinessView.visualState == SetupReadinessVisualState.needsAdjustment
          ? Icons.center_focus_weak_rounded
          : Icons.track_changes_rounded,
    ),
    LivePausePhase.resumeCountingDown => _LivePausePresentation(
      title: localizations.resumeCountdownTitle,
      message: localizations.resumeCountdownMessage,
      color: Colors.greenAccent,
      icon: Icons.play_arrow_rounded,
    ),
  };
}

class _LivePausePresentation {
  const _LivePausePresentation({
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
