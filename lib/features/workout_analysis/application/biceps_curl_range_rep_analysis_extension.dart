import '../domain/biceps_torso_swing_tracker.dart';
import '../domain/models/range_rep_technique_assessment.dart';
import 'biceps_torso_inclination_measurement.dart';
import 'exercise_metrics.dart';
import 'range_rep_coordinator_base.dart' as base;
import 'range_rep_exercise_analysis_extension.dart';
import 'range_rep_extension_pose_utils.dart';

class BicepsCurlRangeRepExerciseAnalysisExtension
    implements RangeRepExerciseAnalysisExtension {
  final BicepsTorsoInclinationMeasurement _torsoMeasurement =
      const BicepsTorsoInclinationMeasurement();
  final BicepsTorsoSwingTracker _torsoSwingTracker = BicepsTorsoSwingTracker();
  final List<RangeRepTechniqueObservation> _techniqueObservations =
      <RangeRepTechniqueObservation>[];

  double? _currentRomDelta;
  double? _latestNeutralAngle;
  double? _currentPeakAngle;
  String? _previousPhase;

  @override
  List<RangeRepTechniqueObservation> get techniqueObservations =>
      List<RangeRepTechniqueObservation>.unmodifiable(_techniqueObservations);

  @override
  double? diagnosticMetric(RangeRepExtensionDiagnostic key) {
    return key == RangeRepExtensionDiagnostic.bicepsRomDelta
        ? _currentRomDelta
        : null;
  }

  @override
  void processFrame({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
    required bool isAcceptedPoseFrame,
  }) {
    if (isAcceptedPoseFrame) {
      _recordTechnique(metrics: metrics, result: result);
    }
    _previousPhase = result.stateSnapshot.currentPhase;
  }

  void _recordTechnique({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
  }) {
    final phase = result.stateSnapshot.currentPhase;
    final pose = poseFromLandmarks(metrics.landmarks);
    final torsoInclination = _torsoMeasurement.measureBilateral(pose);
    final primaryAngle =
        metrics.bilateralRangeRepMetrics?.hasPrimaryAngle == true
        ? metrics.bilateralRangeRepMetrics!.primaryAngle
        : null;

    if (phase == 'NEUTRAL') {
      if (_previousPhase == 'ASCENDING') {
        final start = _latestNeutralAngle;
        final peak = _currentPeakAngle;
        if (start != null && peak != null) {
          _currentRomDelta = (start - peak).clamp(0.0, 180.0).toDouble();
        }
        _torsoSwingTracker.resetRep();
        _currentPeakAngle = null;
      }
      if (primaryAngle != null) {
        _latestNeutralAngle = primaryAngle;
      }
      _torsoSwingTracker.recordNeutral(torsoInclination);
      return;
    }

    if (phase == 'DESCENDING' && _previousPhase != 'DESCENDING') {
      _techniqueObservations.clear();
      _currentRomDelta = null;
      _currentPeakAngle = null;
      _torsoSwingTracker.resetRep();
    }

    if (phase == 'PEAK' && _previousPhase != 'PEAK') {
      if (primaryAngle != null) {
        _currentPeakAngle = primaryAngle;
        final start = _latestNeutralAngle;
        if (start != null) {
          _currentRomDelta = (start - primaryAngle)
              .clamp(0.0, 180.0)
              .toDouble();
        }
      }
      _torsoSwingTracker.recordPeak(torsoInclination);
      _addObservation(_torsoSwingTracker.buildObservation());
    }
  }

  void _addObservation(RangeRepTechniqueObservation? observation) {
    if (observation != null) {
      _techniqueObservations.add(observation);
    }
  }

  @override
  void reset() {
    _currentRomDelta = null;
    _latestNeutralAngle = null;
    _currentPeakAngle = null;
    _previousPhase = null;
    _torsoSwingTracker.resetRep(keepNeutral: false);
    _techniqueObservations.clear();
  }
}
