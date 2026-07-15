import '../../../../core/utils/moving_average.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';
import 'range_rep_frame_policy.dart';
import 'workout_state.dart';

/// Builds the blocked range-rep state without changing preview freeze behavior.
class RangeRepBlockedStateBuilder {
  const RangeRepBlockedStateBuilder();

  RangeRepBlockedPreviewSnapshot buildPreview({
    required ExerciseMetrics metrics,
    required RangeRepFrameAssessment assessment,
    required bool freezeSmoothedPreview,
    required MovingAverageFilter primaryMetricFilter,
    required MovingAverageFilter formMetricFilter,
    required double fallbackAngle,
    required double fallbackBackAngle,
    required String? selectedRangeRepSide,
  }) {
    final selectedMetrics = assessment.selectedMetrics;
    return RangeRepBlockedPreviewSnapshot(
      previewAngle: _previewRangeRepMetric(
        hasSignal: assessment.hasPrimaryAngle,
        value: selectedMetrics?.primaryAngle ?? metrics.primaryAngle,
        filter: primaryMetricFilter,
        fallback: fallbackAngle,
        freezePreview: freezeSmoothedPreview,
      ),
      previewBackAngle: _previewRangeRepMetric(
        hasSignal: assessment.hasFormMetric,
        value: selectedMetrics?.formMetric ?? metrics.formMetric,
        filter: formMetricFilter,
        fallback: fallbackBackAngle,
        freezePreview: freezeSmoothedPreview,
      ),
      formSignals: selectedMetrics?.formSignals,
      selectedRangeRepSide: selectedRangeRepSide,
    );
  }

  WorkoutState build({
    required ExerciseMetrics metrics,
    required RangeRepFrameAssessment assessment,
    required bool freezeSmoothedPreview,
    required MovingAverageFilter primaryMetricFilter,
    required MovingAverageFilter formMetricFilter,
    required WorkoutState currentState,
    required EngineKind analysisKind,
    required double cameraFps,
    required double analysisFps,
    required String? selectedRangeRepSide,
    String? feedbackMessageOverride,
    String currentPhase = 'WAITING',
    required WorkoutCalibrationMetrics Function(
      RangeRepBlockedPreviewSnapshot preview,
    )
    calibrationMetricsBuilder,
  }) {
    final preview = buildPreview(
      metrics: metrics,
      assessment: assessment,
      freezeSmoothedPreview: freezeSmoothedPreview,
      primaryMetricFilter: primaryMetricFilter,
      formMetricFilter: formMetricFilter,
      fallbackAngle: currentState.currentAngle,
      fallbackBackAngle: currentState.calibrationMetrics.currentBackAngle,
      selectedRangeRepSide: selectedRangeRepSide,
    );

    return WorkoutState(
      landmarks: metrics.landmarks,
      analysisKind: analysisKind,
      repCount: currentState.repCount,
      isFormBad: false,
      currentAngle: preview.previewAngle,
      lastRepScore: currentState.lastRepScore,
      lastRepROM: currentState.lastRepROM,
      currentHoldSeconds: currentState.currentHoldSeconds,
      bestHoldSeconds: currentState.bestHoldSeconds,
      isHolding: currentState.isHolding,
      hadHoldFormBreak: currentState.hadHoldFormBreak,
      feedbackMessage: feedbackMessageOverride ?? assessment.feedbackMessage,
      currentPhase: currentPhase,
      cameraFps: cameraFps,
      analysisFps: analysisFps,
      calibrationMetrics: calibrationMetricsBuilder(preview),
    );
  }

  double _previewRangeRepMetric({
    required bool hasSignal,
    required double value,
    required MovingAverageFilter filter,
    required double fallback,
    required bool freezePreview,
  }) {
    if (freezePreview || !hasSignal) {
      return fallback;
    }

    return filter.process(value);
  }
}

class RangeRepBlockedPreviewSnapshot {
  const RangeRepBlockedPreviewSnapshot({
    required this.previewAngle,
    required this.previewBackAngle,
    required this.formSignals,
    required this.selectedRangeRepSide,
  });

  final double previewAngle;
  final double previewBackAngle;
  final RangeRepFormSignals? formSignals;
  final String? selectedRangeRepSide;
}
