import 'models/range_rep_technique_assessment.dart';

/// Tracks neutral and peak torso inclinations for one bilateral biceps-curl
/// repetition and emits a threshold-free delta observation.
class BicepsTorsoSwingTracker {
  double? _neutralInclination;
  double? _peakInclination;

  void recordNeutral(double? inclinationDegrees) {
    if (inclinationDegrees == null || !inclinationDegrees.isFinite) {
      return;
    }
    // Keep the latest stable neutral value immediately before the rep starts.
    _neutralInclination = inclinationDegrees;
  }

  void recordPeak(double? inclinationDegrees) {
    if (inclinationDegrees == null || !inclinationDegrees.isFinite) {
      return;
    }
    _peakInclination ??= inclinationDegrees;
  }

  RangeRepTechniqueObservation? buildObservation() {
    final neutral = _neutralInclination;
    final peak = _peakInclination;
    if (neutral == null || peak == null) {
      return null;
    }

    return RangeRepTechniqueObservation(
      type: RangeRepTechniqueObservationType.torsoSwing,
      code: 'biceps_torso_swing_observed',
      severity: RangeRepTechniqueSeverity.info,
      phase: RangeRepTechniquePhase.peak,
      referencePhase: RangeRepTechniquePhase.neutral,
      measuredValue: peak,
      referenceValue: neutral,
    );
  }

  void resetRep({bool keepNeutral = true}) {
    if (!keepNeutral) {
      _neutralInclination = null;
    }
    _peakInclination = null;
  }
}
