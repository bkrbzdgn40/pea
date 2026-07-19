import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/legacy_range_rep_scorer.dart';
import '../domain/legacy_range_rep_technique_evaluator.dart';
import '../domain/legacy_range_rep_technique_history_tracker.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/range_rep_technique_assessment.dart';
import '../domain/range_rep_analysis_engine.dart';
import '../domain/range_rep_validation_policy.dart';
import '../domain/squat_torso_drift_tracker.dart';
import 'analysis_frame_builder.dart';
import 'calibration_snapshot_builder.dart';
import 'exercise_metrics.dart';
import 'range_rep_blocked_state_builder.dart';
import 'range_rep_coordinator_base.dart' as base;
import 'range_rep_frame_policy.dart';
import 'range_rep_rep_outcome_tracker.dart';
import 'range_rep_side_policy.dart';
import 'range_rep_side_stabilizer.dart';
import 'range_rep_threshold_bookkeeper.dart';
import 'range_rep_visibility_policy.dart';
import 'session_calibration_baseline_accumulator.dart';
import 'squat_torso_inclination_measurement.dart';
import 'workout_calibration_metrics_builder.dart';

export 'range_rep_coordinator_base.dart' hide DefaultRangeRepCoordinator;

/// Production range-rep coordinator with R15B squat torso-drift observation
/// wiring layered on top of the established coordinator behavior.
class DefaultRangeRepCoordinator extends base.DefaultRangeRepCoordinator {
  DefaultRangeRepCoordinator({
    required RangeRepAnalysisEngine engine,
    required ExerciseConfig config,
    required RangeRepContract rangeRepContract,
    required RangeRepValidationConfig rangeRepValidationConfig,
    LegacyRangeRepScorer scorer = const LegacyRangeRepScorer(),
    LegacyRangeRepTechniqueEvaluator techniqueEvaluator =
        const LegacyRangeRepTechniqueEvaluator(),
    LegacyRangeRepTechniqueHistoryTracker? techniqueHistoryTracker,
    WorkoutAnalysisFrameBuilder analysisFrameBuilder =
        const WorkoutAnalysisFrameBuilder(),
    RangeRepBlockedStateBuilder blockedStateBuilder =
        const RangeRepBlockedStateBuilder(),
    CalibrationSnapshotBuilder calibrationSnapshotBuilder =
        const CalibrationSnapshotBuilder(),
    WorkoutCalibrationMetricsBuilder calibrationMetricsBuilder =
        const WorkoutCalibrationMetricsBuilder(),
    RangeRepFramePolicy framePolicy = const RangeRepFramePolicy(),
    RangeRepSidePolicy sidePolicy = const RangeRepSidePolicy(),
    RangeRepSideStabilizer? sideStabilizer,
    RangeRepVisibilityPolicy? visibilityPolicy,
    RangeRepThresholdBookkeeper? thresholdBookkeeper,
    RangeRepRepOutcomeTracker? outcomeTracker,
    SessionCalibrationBaselineAccumulator?
    sessionCalibrationBaselineAccumulator,
  }) : _isSquat = identical(rangeRepContract, RangeRepContracts.squat),
       super(
         engine: engine,
         config: config,
         rangeRepContract: rangeRepContract,
         rangeRepValidationConfig: rangeRepValidationConfig,
         scorer: scorer,
         techniqueEvaluator: techniqueEvaluator,
         techniqueHistoryTracker: techniqueHistoryTracker,
         analysisFrameBuilder: analysisFrameBuilder,
         blockedStateBuilder: blockedStateBuilder,
         calibrationSnapshotBuilder: calibrationSnapshotBuilder,
         calibrationMetricsBuilder: calibrationMetricsBuilder,
         framePolicy: framePolicy,
         sidePolicy: sidePolicy,
         sideStabilizer: sideStabilizer,
         visibilityPolicy: visibilityPolicy,
         thresholdBookkeeper: thresholdBookkeeper,
         outcomeTracker: outcomeTracker,
         sessionCalibrationBaselineAccumulator:
             sessionCalibrationBaselineAccumulator,
       );

  final bool _isSquat;
  final SquatTorsoInclinationMeasurement _torsoMeasurement =
      const SquatTorsoInclinationMeasurement();
  final SquatTorsoDriftTracker _torsoDriftTracker = SquatTorsoDriftTracker();
  final List<RangeRepTechniqueObservation> _techniqueObservations =
      <RangeRepTechniqueObservation>[];
  String? _previousPhase;

  List<RangeRepTechniqueObservation> get techniqueObservations =>
      List<RangeRepTechniqueObservation>.unmodifiable(_techniqueObservations);

  @override
  base.RangeRepCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
  }) {
    final result = super.processFrame(
      metrics: metrics,
      now: now,
      isAcceptedPoseFrame: isAcceptedPoseFrame,
      didBecomeStableTracking: didBecomeStableTracking,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
      preferredRangeRepSide: preferredRangeRepSide,
    );

    if (_isSquat && isAcceptedPoseFrame) {
      _recordSquatTorsoDrift(metrics: metrics, result: result);
    }
    _previousPhase = result.stateSnapshot.currentPhase;
    return result;
  }

  @override
  base.RangeRepCoordinatorStateSnapshot handleLifecycleInterruption({
    String? reason,
  }) {
    _resetTorsoDrift(clearObservations: true);
    _previousPhase = null;
    return super.handleLifecycleInterruption(reason: reason);
  }

  void _recordSquatTorsoDrift({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
  }) {
    final phase = result.stateSnapshot.currentPhase;
    final side = switch (result.diagnosticsUpdate.selectedSideLabel) {
      'left' => RangeRepSide.left,
      'right' => RangeRepSide.right,
      _ => null,
    };
    final inclination = side == null
        ? null
        : _torsoMeasurement.measure(_poseFrom(metrics.landmarks), side: side);

    if (phase == 'DESCENDING' && _previousPhase != 'DESCENDING') {
      _resetTorsoDrift(clearObservations: true);
    }

    switch (phase) {
      case 'DESCENDING':
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
        if (_previousPhase != 'PEAK') {
          _addObservation(
            _torsoDriftTracker.observeTransition(
              referencePhase: RangeRepTechniquePhase.descending,
              measuredPhase: RangeRepTechniquePhase.peak,
            ),
          );
        }
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

  Pose _poseFrom(List<PoseLandmark> landmarks) {
    return Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        for (final landmark in landmarks) landmark.type: landmark,
      },
    );
  }
}
