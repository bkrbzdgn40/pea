import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/biceps_torso_swing_tracker.dart';
import '../domain/models/range_rep_technique_assessment.dart';
import 'biceps_torso_inclination_measurement.dart';
import 'exercise_metrics.dart';
import 'range_rep_coordinator_base.dart' as base;
import 'range_rep_exercise_analysis_extension.dart';
import 'range_rep_extension_pose_utils.dart';

class BicepsCurlRangeRepExerciseAnalysisExtension
    implements RangeRepExerciseAnalysisExtension, RangeRepPeakEntryGate {
  final BicepsTorsoInclinationMeasurement _torsoMeasurement =
      const BicepsTorsoInclinationMeasurement();
  final BicepsTorsoSwingTracker _torsoSwingTracker = BicepsTorsoSwingTracker();
  final List<RangeRepTechniqueObservation> _techniqueObservations =
      <RangeRepTechniqueObservation>[];

  static const double _maxPeakWristShoulderDistanceRatio = 0.64;

  double? _currentRomDelta;
  double? _latestNeutralAngle;
  double? _currentPeakAngle;
  double? _neutralLeftWristShoulderDistance;
  double? _neutralRightWristShoulderDistance;
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
  bool allowsPeakEntry(ExerciseMetrics metrics) {
    final neutralLeft = _neutralLeftWristShoulderDistance;
    final neutralRight = _neutralRightWristShoulderDistance;
    if (neutralLeft == null || neutralRight == null) {
      return false;
    }

    final distances = _bilateralWristShoulderDistances(metrics);
    if (distances == null) {
      return false;
    }

    final leftRatio = distances.$1 / neutralLeft;
    final rightRatio = distances.$2 / neutralRight;
    return leftRatio <= _maxPeakWristShoulderDistanceRatio &&
        rightRatio <= _maxPeakWristShoulderDistanceRatio;
  }

  @override
  void processFrame({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
    required bool isAcceptedPoseFrame,
  }) {
    if (isAcceptedPoseFrame) {
      _recordNeutralWristShoulderBaseline(metrics: metrics, result: result);
      _recordTechnique(metrics: metrics, result: result);
    }
    _previousPhase = result.stateSnapshot.currentPhase;
  }

  void _recordNeutralWristShoulderBaseline({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
  }) {
    if (result.stateSnapshot.currentPhase != 'NEUTRAL') {
      return;
    }

    final distances = _bilateralWristShoulderDistances(metrics);
    if (distances == null) {
      return;
    }

    _neutralLeftWristShoulderDistance = math.max(
      _neutralLeftWristShoulderDistance ?? 0.0,
      distances.$1,
    );
    _neutralRightWristShoulderDistance = math.max(
      _neutralRightWristShoulderDistance ?? 0.0,
      distances.$2,
    );
  }

  (double, double)? _bilateralWristShoulderDistances(ExerciseMetrics metrics) {
    final pose = poseFromLandmarks(metrics.landmarks);
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    if (leftShoulder == null ||
        leftWrist == null ||
        rightShoulder == null ||
        rightWrist == null) {
      return null;
    }

    return (
      _distance(leftShoulder.x, leftShoulder.y, leftWrist.x, leftWrist.y),
      _distance(rightShoulder.x, rightShoulder.y, rightWrist.x, rightWrist.y),
    );
  }

  double _distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt((dx * dx) + (dy * dy));
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
    _neutralLeftWristShoulderDistance = null;
    _neutralRightWristShoulderDistance = null;
    _previousPhase = null;
    _torsoSwingTracker.resetRep(keepNeutral: false);
    _techniqueObservations.clear();
  }
}
