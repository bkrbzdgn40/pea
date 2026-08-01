// ignore_for_file: use_super_parameters

import '../domain/legacy_range_rep_scorer.dart';
import '../domain/legacy_range_rep_technique_evaluator.dart';
import '../domain/legacy_range_rep_technique_history_tracker.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/range_rep_technique_assessment.dart';
import '../domain/range_rep_analysis_engine.dart';
import '../domain/range_rep_validation_policy.dart';
import 'analysis_frame_builder.dart';
import 'calibration_snapshot_builder.dart';
import 'exercise_metrics.dart';
import 'range_rep_blocked_state_builder.dart';
import 'range_rep_coordinator_base.dart' as base;
import 'range_rep_exercise_analysis_extension.dart';
import 'range_rep_exercise_analysis_extension_factory.dart';
import 'range_rep_frame_policy.dart';
import 'range_rep_rep_outcome_tracker.dart';
import 'range_rep_side_policy.dart';
import 'range_rep_side_stabilizer.dart';
import 'range_rep_threshold_bookkeeper.dart';
import 'range_rep_visibility_policy.dart';
import 'session_calibration_baseline_accumulator.dart';
import 'workout_calibration_metrics_builder.dart';

export 'range_rep_coordinator_base.dart' hide DefaultRangeRepCoordinator;

/// Production range-rep coordinator.
///
/// Generic frame selection, detection, validation, scoring, and persistence
/// inputs stay in the base coordinator. Exercise-specific biomechanics are
/// delegated to [RangeRepExerciseAnalysisExtension], preventing this class from
/// accumulating one `if (exercise == ...)` branch per new exercise.
class DefaultRangeRepCoordinator extends base.DefaultRangeRepCoordinator {
  DefaultRangeRepCoordinator({
    required RangeRepAnalysisEngine engine,
    required ExerciseConfig config,
    required RangeRepContract rangeRepContract,
    required RangeRepValidationConfig rangeRepValidationConfig,
    RangeRepExerciseAnalysisExtension? exerciseAnalysisExtension,
    RangeRepExerciseAnalysisExtensionFactory exerciseAnalysisExtensionFactory =
        const RangeRepExerciseAnalysisExtensionFactory(),
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
  }) : _rangeRepEngine = engine,
       _exerciseAnalysisExtension =
           exerciseAnalysisExtension ??
           exerciseAnalysisExtensionFactory.create(
             rangeRepContract.extensionProfile,
           ),
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

  final RangeRepAnalysisEngine _rangeRepEngine;
  final RangeRepExerciseAnalysisExtension _exerciseAnalysisExtension;

  List<RangeRepTechniqueObservation> get techniqueObservations =>
      _exerciseAnalysisExtension.techniqueObservations;

  /// Compatibility diagnostic getter for existing push-up UI/tests.
  double? get currentPushUpHipDeviationMetric => _exerciseAnalysisExtension
      .diagnosticMetric(RangeRepExtensionDiagnostic.pushUpHipDeviation);

  /// Compatibility diagnostic getter for existing squat UI/tests.
  double? get currentSquatHipDepthMetric => _exerciseAnalysisExtension
      .diagnosticMetric(RangeRepExtensionDiagnostic.squatHipDepth);

  /// Compatibility diagnostic getter for existing biceps UI/tests.
  double? get currentBicepsRomDelta => _exerciseAnalysisExtension
      .diagnosticMetric(RangeRepExtensionDiagnostic.bicepsRomDelta);

  @override
  double adaptPrimaryMetricForDetection({
    required ExerciseMetrics metrics,
    required RangeRepSide? selectedSide,
    required double primaryMetric,
    required double neutralThreshold,
    required double activeThreshold,
    required String currentPhase,
    required bool hasActiveRepContext,
    required DateTime now,
  }) {
    final extension = _exerciseAnalysisExtension;
    if (selectedSide == null || extension is! RangeRepDetectionFrameAdapter) {
      return primaryMetric;
    }

    return (extension as RangeRepDetectionFrameAdapter).adaptPrimaryMetric(
      RangeRepDetectionFrameContext(
        metrics: metrics,
        selectedSide: selectedSide,
        primaryMetric: primaryMetric,
        neutralThreshold: neutralThreshold,
        activeThreshold: activeThreshold,
        currentPhase: currentPhase,
        hasActiveRepContext: hasActiveRepContext,
        now: now,
      ),
    );
  }

  @override
  base.RangeRepCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
  }) {
    final extension = _exerciseAnalysisExtension;
    _rangeRepEngine.setPeakEntryAllowed(
      extension is RangeRepPeakEntryGate
          ? (extension as RangeRepPeakEntryGate).allowsPeakEntry(metrics)
          : true,
    );

    final result = super.processFrame(
      metrics: metrics,
      now: now,
      isAcceptedPoseFrame: isAcceptedPoseFrame,
      didBecomeStableTracking: didBecomeStableTracking,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
      preferredRangeRepSide: preferredRangeRepSide,
    );

    _exerciseAnalysisExtension.processFrame(
      metrics: metrics,
      result: result,
      isAcceptedPoseFrame: isAcceptedPoseFrame,
    );

    return _withTechniqueObservations(result);
  }

  @override
  base.RangeRepCoordinatorStateSnapshot handleLifecycleInterruption({
    String? reason,
  }) {
    _exerciseAnalysisExtension.reset();
    return super.handleLifecycleInterruption(reason: reason);
  }

  base.RangeRepCoordinatorFrameResult _withTechniqueObservations(
    base.RangeRepCoordinatorFrameResult result,
  ) {
    final snapshot = result.stateSnapshot;
    return base.RangeRepCoordinatorFrameResult(
      stateSnapshot: base.RangeRepCoordinatorStateSnapshot(
        landmarks: snapshot.landmarks,
        repCount: snapshot.repCount,
        isFormBad: snapshot.isFormBad,
        currentAngle: snapshot.currentAngle,
        lastRepScore: snapshot.lastRepScore,
        lastRepRom: snapshot.lastRepRom,
        currentPhase: snapshot.currentPhase,
        calibrationMetrics: snapshot.calibrationMetrics,
        feedbackDirective: snapshot.feedbackDirective,
        techniqueObservations: techniqueObservations,
      ),
      diagnosticsUpdate: result.diagnosticsUpdate,
      validatedRepEvent: result.validatedRepEvent,
      shouldResetPoseAcceptance: result.shouldResetPoseAcceptance,
      shouldRecordInvalidPoseAcceptance:
          result.shouldRecordInvalidPoseAcceptance,
    );
  }
}
