import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_calibration_projector.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_frame_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_calibration_metrics_builder.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';

void main() {
  test('stable valid frame publishes and accumulates calibration baseline', () {
    final projector = RangeRepCalibrationProjector();

    final metrics = projector.project(
      _request(
        selectedRangeRepSide: 'left',
        currentPrimaryMetric: 170,
        currentFormMetric: 35,
        hasPrimaryAngle: true,
        hasFormMetric: true,
      ),
    );

    expect(metrics.calibrationSnapshot, isNotNull);
    expect(metrics.calibrationSnapshot!.selectedSideLabel, 'left');
    expect(metrics.calibrationSnapshot!.primaryMetricBaseline, 170);
    expect(metrics.calibrationSnapshot!.formMetricBaseline, 35);
    expect(projector.sessionCalibrationBaseline, isNotNull);
    expect(projector.sessionCalibrationBaseline!.selectedSideLabel, 'left');
    expect(projector.sessionCalibrationBaseline!.sampleCount, 1);
    expect(metrics.sessionCalibrationBaselineCandidate?.sampleCount, 1);
  });

  test(
    'incompatible side keeps the session baseline but updates last snapshot',
    () {
      final projector = RangeRepCalibrationProjector();

      projector.project(
        _request(
          selectedRangeRepSide: 'left',
          currentPrimaryMetric: 170,
          currentFormMetric: 35,
          hasPrimaryAngle: true,
          hasFormMetric: true,
        ),
      );
      final rightMetrics = projector.project(
        _request(
          selectedRangeRepSide: 'right',
          currentPrimaryMetric: 168,
          currentFormMetric: 37,
          hasPrimaryAngle: true,
          hasFormMetric: true,
        ),
      );

      expect(rightMetrics.calibrationSnapshot?.selectedSideLabel, 'right');
      expect(projector.lastCalibrationSnapshot?.selectedSideLabel, 'right');
      expect(projector.sessionCalibrationBaseline?.selectedSideLabel, 'left');
      expect(projector.sessionCalibrationBaseline?.sampleCount, 1);
      expect(
        rightMetrics.sessionCalibrationBaselineCandidate?.selectedSideLabel,
        'left',
      );
    },
  );

  test(
    'invalid frame reuses calibration state and projects invalid metadata',
    () {
      final projector = RangeRepCalibrationProjector();
      projector.project(
        _request(
          selectedRangeRepSide: 'left',
          currentPrimaryMetric: 170,
          currentFormMetric: 35,
          hasPrimaryAngle: true,
          hasFormMetric: true,
        ),
      );

      final invalidMetrics = projector.project(
        _request(
          selectedRangeRepSide: 'left',
          currentFormMetric: 35,
          isRangeRepFrameValid: false,
          hasPrimaryAngle: false,
          hasFormMetric: true,
          rangeRepInvalidReason: RangeRepFrameInvalidReason.missingPrimaryAngle,
          rangeRepInvalidFrameStreak: 3,
          rangeRepInvalidDurationMs: 450,
        ),
      );

      expect(invalidMetrics.isRangeRepFrameValid, isFalse);
      expect(invalidMetrics.rangeRepInvalidReason, 'primary joints missing');
      expect(invalidMetrics.rangeRepInvalidFrameStreak, 3);
      expect(invalidMetrics.rangeRepInvalidDurationMs, 450);
      expect(invalidMetrics.calibrationSnapshot?.selectedSideLabel, 'left');
      expect(
        invalidMetrics.sessionCalibrationBaselineCandidate?.sampleCount,
        1,
      );
    },
  );
}

RangeRepCalibrationProjectionRequest _request({
  required String? selectedRangeRepSide,
  required double currentFormMetric,
  double? currentPrimaryMetric,
  bool isRangeRepFrameValid = true,
  bool hasPrimaryAngle = false,
  bool hasFormMetric = false,
  RangeRepFrameInvalidReason? rangeRepInvalidReason,
  int rangeRepInvalidFrameStreak = 0,
  int rangeRepInvalidDurationMs = 0,
}) {
  return RangeRepCalibrationProjectionRequest(
    diagnostics: const RangeRepDiagnosticsSnapshot(),
    repTelemetry: const RangeRepRepTelemetrySnapshot(),
    currentFormMetric: currentFormMetric,
    thresholdValue: 45,
    currentPrimaryMetric: currentPrimaryMetric,
    rangeRepSideHysteresisStatus: 'stay:left',
    rangeRepSideConsistencyStatus: 'anchor:left',
    calibrationThresholdDecisionCount: 2,
    calibrationThresholdAppliedCount: 1,
    calibrationThresholdNoBaselineCount: 1,
    calibrationThresholdInsufficientSamplesCount: 0,
    calibrationThresholdMissingFormBaselineCount: 0,
    calibrationThresholdSideMismatchCount: 0,
    calibrationThresholdOffsetTooSmallCount: 0,
    baseFormThreshold: 45,
    effectiveFormThreshold: 45,
    isRangeRepFrameValid: isRangeRepFrameValid,
    hasPrimaryAngle: hasPrimaryAngle,
    hasFormMetric: hasFormMetric,
    rangeRepInvalidReason: rangeRepInvalidReason,
    selectedRangeRepSide: selectedRangeRepSide,
    rangeRepSideSelectionReason: 'test',
    rangeRepAutomaticSideSelectionEnabled: true,
    rangeRepMovementSelectedSide: selectedRangeRepSide,
    rangeRepInvalidFrameStreak: rangeRepInvalidFrameStreak,
    rangeRepInvalidDurationMs: rangeRepInvalidDurationMs,
  );
}
