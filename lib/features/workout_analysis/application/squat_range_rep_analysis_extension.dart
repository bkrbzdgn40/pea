import '../domain/models/range_rep_technique_assessment.dart';
import '../domain/squat_torso_drift_tracker.dart';
import 'exercise_metrics.dart';
import 'range_rep_coordinator_base.dart' as base;
import 'range_rep_exercise_analysis_extension.dart';
import 'range_rep_extension_pose_utils.dart';
import 'squat_hip_depth_measurement.dart';
import 'squat_torso_inclination_measurement.dart';

class SquatRangeRepExerciseAnalysisExtension
    implements RangeRepExerciseAnalysisExtension {
  final SquatTorsoInclinationMeasurement _torsoMeasurement =
      const SquatTorsoInclinationMeasurement();
  final SquatHipDepthMeasurement _hipDepthMeasurement =
      const SquatHipDepthMeasurement();
  final SquatTorsoDriftTracker _torsoDriftTracker = SquatTorsoDriftTracker();
  final List<RangeRepTechniqueObservation> _techniqueObservations =
      <RangeRepTechniqueObservation>[];

  double? _currentHipDepthMetric;
  String? _previousPhase;

  @override
  List<RangeRepTechniqueObservation> get techniqueObservations =>
      List<RangeRepTechniqueObservation>.unmodifiable(_techniqueObservations);

  @override
  double? diagnosticMetric(RangeRepExtensionDiagnostic key) {
    return key == RangeRepExtensionDiagnostic.squatHipDepth
        ? _currentHipDepthMetric
        : null;
  }

  @override
  void processFrame({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
    required bool isAcceptedPoseFrame,
  }) {
    _recordHipDepth(
      metrics: metrics,
      result: result,
      isAcceptedPoseFrame: isAcceptedPoseFrame,
    );
    if (isAcceptedPoseFrame) {
      _recordTorsoDrift(metrics: metrics, result: result);
    }
    _previousPhase = result.stateSnapshot.currentPhase;
  }

  void _recordHipDepth({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
    required bool isAcceptedPoseFrame,
  }) {
    if (!isAcceptedPoseFrame) {
      _currentHipDepthMetric = null;
      return;
    }

    final side = rangeRepSideFromLabel(
      result.diagnosticsUpdate.selectedSideLabel,
    );
    _currentHipDepthMetric = side == null
        ? null
        : _hipDepthMeasurement.measure(
            poseFromLandmarks(metrics.landmarks),
            side: side,
          );
  }

  void _recordTorsoDrift({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
  }) {
    final phase = result.stateSnapshot.currentPhase;
    if (phase == _previousPhase) {
      return;
    }

    final side = rangeRepSideFromLabel(
      result.diagnosticsUpdate.selectedSideLabel,
    );
    final inclination = side == null
        ? null
        : _torsoMeasurement.measure(
            poseFromLandmarks(metrics.landmarks),
            side: side,
          );

    switch (phase) {
      case 'DESCENDING':
        _resetTorsoDrift(clearObservations: true);
        _torsoDriftTracker.record(
          phase: RangeRepTechniquePhase.descending,
          inclinationDegrees: inclination,
        );
        break;
      case 'PEAK':
        _torsoDriftTracker.record(
          phase: RangeRepTechniquePhase.peak,
          inclinationDegrees: inclination,
        );
        _addObservation(
          _torsoDriftTracker.observeTransition(
            referencePhase: RangeRepTechniquePhase.descending,
            measuredPhase: RangeRepTechniquePhase.peak,
          ),
        );
        break;
      case 'ASCENDING':
        _torsoDriftTracker.record(
          phase: RangeRepTechniquePhase.ascending,
          inclinationDegrees: inclination,
        );
        break;
      case 'NEUTRAL':
        if (_previousPhase == 'ASCENDING') {
          _addObservation(
            _torsoDriftTracker.observeTransition(
              referencePhase: RangeRepTechniquePhase.peak,
              measuredPhase: RangeRepTechniquePhase.ascending,
            ),
          );
          _torsoDriftTracker.reset();
        } else if (_previousPhase == 'DESCENDING' || _previousPhase == 'PEAK') {
          _resetTorsoDrift(clearObservations: true);
        }
        break;
    }
  }

  void _addObservation(RangeRepTechniqueObservation? observation) {
    if (observation != null) {
      _techniqueObservations.add(observation);
    }
  }

  void _resetTorsoDrift({required bool clearObservations}) {
    _torsoDriftTracker.reset();
    if (clearObservations) {
      _techniqueObservations.clear();
    }
  }

  @override
  void reset() {
    _currentHipDepthMetric = null;
    _previousPhase = null;
    _resetTorsoDrift(clearObservations: true);
  }
}
