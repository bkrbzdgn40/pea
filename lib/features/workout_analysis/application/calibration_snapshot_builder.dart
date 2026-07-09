import '../domain/models/calibration_snapshot.dart';
import '../domain/range_rep_diagnostics.dart';
import 'engine_kind.dart';

/// Builds calibration snapshot candidates from current range-rep telemetry.
class CalibrationSnapshotBuilder {
  const CalibrationSnapshotBuilder();

  CalibrationSnapshot? buildCandidate({
    required EngineKind engineKind,
    required RangeRepDiagnosticsSnapshot diagnostics,
    required bool isRangeRepFrameValid,
    required bool hasPrimaryAngle,
    required bool hasFormMetric,
    required double currentFormMetric,
    double? currentPrimaryMetric,
    String? selectedRangeRepSide,
    double? currentTorsoAngle,
    double? currentDepthMetric,
    double? currentAlignmentMetric,
    double? currentStabilityMetric,
    double? currentLockoutMetric,
    double? currentBottomControlMetric,
  }) {
    if (engineKind != EngineKind.rangeRep) {
      return null;
    }

    final isStableSnapshotMoment =
        isRangeRepFrameValid &&
        !diagnostics.hasActiveRepPhase &&
        !diagnostics.hasPendingTransition &&
        selectedRangeRepSide != null;

    if (!isStableSnapshotMoment) {
      return null;
    }

    final snapshot = CalibrationSnapshot(
      analysisKind: engineKind.name,
      selectedSideLabel: selectedRangeRepSide,
      primaryMetricBaseline: hasPrimaryAngle ? currentPrimaryMetric : null,
      formMetricBaseline: hasFormMetric ? currentFormMetric : null,
      torsoAngleBaseline: currentTorsoAngle,
      depthMetricBaseline: currentDepthMetric,
      alignmentMetricBaseline: currentAlignmentMetric,
      stabilityMetricBaseline: currentStabilityMetric,
      lockoutMetricBaseline: currentLockoutMetric,
      bottomControlMetricBaseline: currentBottomControlMetric,
      createdAt: DateTime.now(),
    );

    return snapshot.hasAnyBaseline ? snapshot : null;
  }
}
