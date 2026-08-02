import '../domain/models/hold_contract.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/range_rep_analysis_engine.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';
import 'hold_coordinator.dart';
import 'range_rep_coordinator.dart';
import 'workout_diagnostics.dart';
import 'workout_state.dart';

/// Owns diagnostics policy and the complex projection from runtime state.
///
/// Low-level frame counters remain available through [accumulator] during the
/// staged controller refactor. Coordinator and published-state interpretation
/// belongs here so the controller does not encode diagnostics semantics.
class WorkoutDiagnosticsReporter {
  WorkoutDiagnosticsReporter({
    required this.enabled,
    required WorkoutDiagnosticsAccumulator accumulator,
  }) : _accumulator = accumulator;

  final bool enabled;
  final WorkoutDiagnosticsAccumulator _accumulator;

  WorkoutDiagnosticsAccumulator get accumulator => _accumulator;

  WorkoutDiagnosticsSnapshot snapshot({required DateTime now}) {
    return _accumulator.snapshot(now: now);
  }

  void reset({required DateTime now, required String analysisKind}) {
    _accumulator.reset(now: now, analysisKind: analysisKind);
  }

  void applyRangeRepCoordinatorUpdate(
    RangeRepCoordinatorDiagnosticsUpdate update,
  ) {
    if (!enabled) {
      return;
    }

    if (update.recordBriefOcclusion) {
      _accumulator.recordBriefOcclusion();
    }
    if (update.recordBriefOcclusionRecovery) {
      _accumulator.recordBriefOcclusionRecovery();
    }
    if (update.recordBriefOcclusionAbort) {
      _accumulator.recordBriefOcclusionAbort();
    }
    if (update.recordResync) {
      _accumulator.recordResync(
        hadActiveRepContext: update.hasActiveRepContext,
      );
    }
    if (update.recordPoseReacquisition) {
      _accumulator.recordPoseReacquisition();
    }
    if (update.recordAcceptedPoseFrame) {
      _accumulator.recordAcceptedPoseFrame();
    }
    _accumulator.updateVisibilityStatus(update.visibilityStatus);
    _accumulator.recordSelectedSide(
      selectedSide: update.selectedSideLabel,
      hasActiveRepContext: update.hasActiveRepContext,
    );
    final transitionCodes = update.confirmedTransitionCodes.isNotEmpty
        ? update.confirmedTransitionCodes
        : <String>[
            if (update.confirmedTransitionCode != null)
              update.confirmedTransitionCode!,
          ];
    for (final transitionCode in transitionCodes) {
      _accumulator.recordRangeRepTransition(transitionCode);
    }
    final validationStatus = update.completedRepValidationStatus;
    if (validationStatus != null) {
      _accumulator.recordRangeRepValidation(
        statusCode: validationStatus,
        reasonCodes: update.completedRepValidationReasons,
        tempoDiagnosticReasonCodes: update.completedRepTempoDiagnosticReasons,
        measurementConfidence: update.completedRepMeasurementConfidence,
      );
    }
  }

  void applyHoldCoordinatorUpdate(HoldCoordinatorDiagnosticsUpdate update) {
    if (!enabled) {
      return;
    }

    if (update.recordHoldVisibilitySuspend) {
      _accumulator.recordHoldVisibilitySuspend();
    }
    if (update.recordHoldVisibilityRecovery) {
      _accumulator.recordHoldVisibilityRecovery(
        update.holdVisibilityGapDuration,
      );
    }
    if (update.recordHoldVisibilityAbort) {
      _accumulator.recordHoldVisibilityAbort(update.holdVisibilityGapDuration);
    }
    if (update.recordPoseReacquisition) {
      _accumulator.recordPoseReacquisition();
    }
    if (update.recordAcceptedPoseFrame) {
      _accumulator.recordAcceptedPoseFrame();
    }
    _accumulator.updateVisibilityStatus(update.visibilityStatus);
  }

  void updateFromPublishedState({
    required WorkoutState publishedState,
    required EngineKind engineKind,
    required double cameraFps,
    required double analysisFps,
    required ExerciseMetrics lastExerciseMetrics,
    RangeRepAnalysisEngine? rangeRepEngine,
    RangeRepContract? rangeRepContract,
    HoldCoordinator? holdCoordinator,
    HoldContract? holdContract,
  }) {
    if (!enabled) {
      return;
    }

    _accumulator.updateLivePerformance(
      cameraFps: cameraFps,
      analysisFps: analysisFps,
    );
    if (engineKind == EngineKind.rangeRep) {
      final engine = rangeRepEngine;
      final contract = rangeRepContract;
      if (engine == null || contract == null) {
        throw StateError(
          'Range-rep diagnostics require an engine and contract.',
        );
      }
      final timingDiagnostics = engine.detectionDiagnosticsSnapshot;
      _accumulator.updateRangeRepState(
        repCount: publishedState.repCount,
        currentPhase: publishedState.currentPhase,
        signalRoles: contract.signalRoles,
        calibrationOffsetDegrees:
            publishedState.calibrationMetrics.calibrationThresholdOffsetApplied
            ? publishedState
                  .calibrationMetrics
                  .calibrationThresholdOffsetCandidate
            : null,
        activeTimingTrace: timingDiagnostics.activeTimingTrace,
        lastEndedTimingTrace: timingDiagnostics.lastEndedTimingTrace,
        lastTempoMeasurementAssessment:
            timingDiagnostics.lastTempoMeasurementAssessment,
        nonMonotonicObservationCount:
            timingDiagnostics.nonMonotonicObservationCount,
        currentLeftMeasurementConfidence:
            lastExerciseMetrics.leftRangeRepMetrics.measurementConfidence,
        currentRightMeasurementConfidence:
            lastExerciseMetrics.rightRangeRepMetrics.measurementConfidence,
      );
      return;
    }

    final coordinator = holdCoordinator;
    final contract = holdContract;
    if (coordinator == null || contract == null) {
      throw StateError('Hold diagnostics require a coordinator and contract.');
    }
    _accumulator.updateHoldState(
      currentHoldSeconds: publishedState.currentHoldSeconds.round(),
      bestHoldSeconds: publishedState.bestHoldSeconds.round(),
      currentPhase: publishedState.currentPhase,
      isHolding: publishedState.isHolding,
      signalRoles: contract.signalRoles,
      presentedHoldFeedbackCode: publishedState.holdFeedbackCode,
      holdDiagnostics: coordinator.diagnosticsSnapshot(),
      currentHoldSide: publishedState.selectedHoldSide,
      currentSignalValues:
          publishedState.calibrationMetrics.currentHoldSignalValues,
      targetSignalValues:
          publishedState.calibrationMetrics.targetHoldSignalValues,
      signalValidity: publishedState.calibrationMetrics.holdSignalValidity,
    );
  }
}
