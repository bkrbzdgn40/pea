import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pose_estimation_app/app/theme/app_design_tokens.dart';
import 'package:pose_estimation_app/app/theme/app_motion.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/live_tracking_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/range_rep_outcome_view_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_range_rep_outcome_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_tracking_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

import 'live_analysis_theme.dart';

class LiveCameraStageEffects extends ConsumerWidget {
  const LiveCameraStageEffects({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFormBad = ref.watch(
      workoutControllerProvider.select((state) => state.isFormBad),
    );
    final trackingPhase = ref.watch(
      liveTrackingControllerProvider.select((state) => state.phase),
    );
    final repOutcome = ref.watch(liveRangeRepOutcomeProvider);
    final frameColor = _stageToneColor(
      isFormBad: isFormBad,
      trackingPhase: trackingPhase,
      repOutcome: repOutcome,
    );

    return IgnorePointer(
      child: Stack(
        key: const ValueKey<String>('live-camera-stage-effects'),
        fit: StackFit.expand,
        children: <Widget>[
          const RepaintBoundary(
            key: ValueKey<String>('live-camera-vignette-layer'),
            child: _LiveCameraVignette(),
          ),
          RepaintBoundary(
            key: const ValueKey<String>('live-camera-analysis-frame-layer'),
            child: _LiveCameraAnalysisFrame(
              compact: compact,
              color: frameColor,
              emphasize: repOutcome != null,
            ),
          ),
          if (repOutcome != null)
            RepaintBoundary(
              key: const ValueKey<String>('live-rep-outcome-pulse-layer'),
              child: _LiveRepOutcomePulse(
                key: ValueKey<int>(repOutcome.repIndex),
                color: frameColor,
                compact: compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveCameraAnalysisFrame extends StatelessWidget {
  const _LiveCameraAnalysisFrame({
    required this.compact,
    required this.color,
    required this.emphasize,
  });

  final bool compact;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 7 : 10),
      child: AnimatedContainer(
        key: const ValueKey<String>('live-camera-analysis-frame'),
        duration: AppMotion.resolveDuration(
          context,
          AppMotionDurations.standard,
        ),
        curve: AppMotion.resolveCurve(context, Curves.easeOutCubic),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 20 : 30),
          border: Border.all(
            color: color.withValues(alpha: emphasize ? 0.72 : 0.28),
            width: emphasize ? 1.6 : 1,
          ),
          boxShadow: <BoxShadow>[
            if (emphasize)
              BoxShadow(
                color: color.withValues(alpha: 0.20),
                blurRadius: compact ? 20 : 30,
                spreadRadius: -4,
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveCameraVignette extends StatelessWidget {
  const _LiveCameraVignette();

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey<String>('live-camera-vignette'),
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xA6000000),
                Color(0x08000000),
                Color(0x18000000),
                Color(0xC9000000),
              ],
              stops: <double>[0, 0.25, 0.62, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.88,
              colors: <Color>[
                Colors.transparent,
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.42),
              ],
              stops: const <double>[0.52, 0.78, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveRepOutcomePulse extends StatelessWidget {
  const _LiveRepOutcomePulse({
    super.key,
    required this.color,
    required this.compact,
  });

  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: const ValueKey<String>('live-rep-outcome-pulse'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.resolveDuration(
        context,
        AppMotionDurations.celebration,
      ),
      curve: AppMotion.resolveCurve(context, Curves.easeOutCubic),
      child: Padding(
        padding: EdgeInsets.all(compact ? 5 : 7),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 22 : 32),
            border: Border.all(color: color.withValues(alpha: 0.82), width: 3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: compact ? 34 : 46,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
      builder: (context, progress, child) {
        return Opacity(
          opacity: 1 - progress,
          child: Transform.scale(
            scale: 1 - (progress * (compact ? 0.035 : 0.025)),
            child: child,
          ),
        );
      },
    );
  }
}

Color _stageToneColor({
  required bool isFormBad,
  required LiveTrackingPhase trackingPhase,
  required RangeRepOutcomeViewData? repOutcome,
}) {
  if (repOutcome != null) {
    return switch (repOutcome.tone) {
      RangeRepOutcomeTone.positive => AppColors.success,
      RangeRepOutcomeTone.caution => AppColors.caution,
      RangeRepOutcomeTone.invalid => AppColors.invalid,
    };
  }
  if (trackingPhase == LiveTrackingPhase.repositionRequired) {
    return AppColors.invalid;
  }
  if (trackingPhase != LiveTrackingPhase.tracking || isFormBad) {
    return AppColors.caution;
  }
  return liveHudAccent;
}
