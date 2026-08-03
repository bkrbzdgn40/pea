import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/moving_average.dart';
import '../domain/feedback_arbitration_engine.dart';
import '../domain/legacy_range_rep_scorer.dart';
import '../domain/legacy_range_rep_technique_evaluator.dart';
import '../domain/legacy_range_rep_technique_history_tracker.dart';
import '../domain/models/analysis_frame.dart';
import '../domain/models/analysis_signal_role.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/measurement_confidence_breakdown.dart';
import '../domain/models/range_rep_completed_rep_detection_data.dart';
import '../domain/models/range_rep_confirmed_transition.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/range_rep_engine_frame_result.dart';
import '../domain/models/range_rep_feedback_code.dart';
import '../domain/models/range_rep_technique_assessment.dart';
import '../domain/models/rep_tempo_assessment.dart';
import '../domain/models/rep_score_breakdown.dart';
import '../domain/models/validated_rep_event.dart';
import '../domain/range_rep_analysis_engine.dart';
import '../domain/range_rep_diagnostics.dart';
import '../domain/range_rep_tempo_coaching_policy.dart';
import '../domain/range_rep_validation_policy.dart';
import 'analysis_frame_builder.dart';
import 'calibration_snapshot_builder.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';
import 'range_rep_attempt_processor.dart';
import 'range_rep_blocked_state_builder.dart';
import 'range_rep_calibration_projector.dart';
import 'range_rep_feedback_lifecycle.dart';
import 'range_rep_frame_policy.dart';
import 'range_rep_movement_side_selector.dart';
import 'range_rep_rep_outcome_tracker.dart';
import 'range_rep_rep_scoring_service.dart';
import 'range_rep_side_policy.dart';
import 'range_rep_side_stabilizer.dart';
import 'range_rep_threshold_bookkeeper.dart';
import 'range_rep_threshold_resolver.dart';
import 'range_rep_visibility_policy.dart';
import 'session_calibration_baseline_accumulator.dart';
import 'workout_calibration_metrics_builder.dart';
import 'workout_state.dart';

class RangeRepFeedbackDirective {
  const RangeRepFeedbackDirective.code(this.feedbackCode);

  final RangeRepFeedbackCode feedbackCode;

  String resolve({
    required String Function(RangeRepFeedbackCode code) mapFeedbackCode,
  }) {
    return mapFeedbackCode(feedbackCode);
  }
}

class RangeRepCoordinatorStateSnapshot {
  const RangeRepCoordinatorStateSnapshot({
    required this.landmarks,
    required this.repCount,
    required this.isFormBad,
    required this.currentAngle,
    required this.lastRepScore,
    required this.lastRepRom,
    required this.currentPhase,
    required this.calibrationMetrics,
    required this.feedbackDirective,
    this.techniqueObservations = const <RangeRepTechniqueObservation>[],
  });

  final List<PoseLandmark>? landmarks;
  final int repCount;
  final bool isFormBad;
  final double currentAngle;
  final double lastRepScore;
  final double lastRepRom;
  final String currentPhase;
  final WorkoutCalibrationMetrics calibrationMetrics;
  final RangeRepFeedbackDirective feedbackDirective;
  final List<RangeRepTechniqueObservation> techniqueObservations;
}

class RangeRepCoordinatorDiagnosticsUpdate {
  const RangeRepCoordinatorDiagnosticsUpdate({
    required this.visibilityStatus,
    required this.selectedSideLabel,
    required this.hasActiveRepContext,
    this.confirmedTransitionCode,
    this.confirmedTransitionCodes = const <String>[],
    this.completedRepValidationStatus,
    this.completedRepValidationReasons = const <String>[],
    this.completedRepTempoDiagnosticReasons = const <String>[],
    this.completedRepTempoAssessment,
    this.completedRepMeasurementConfidence,
    this.recordAcceptedPoseFrame = false,
    this.recordPoseReacquisition = false,
    this.recordBriefOcclusion = false,
    this.recordBriefOcclusionRecovery = false,
    this.recordBriefOcclusionAbort = false,
    this.recordResync = false,
  });

  final String visibilityStatus;
  final String? selectedSideLabel;
  final bool hasActiveRepContext;
  final String? confirmedTransitionCode;
  final List<String> confirmedTransitionCodes;
  final String? completedRepValidationStatus;
  final List<String> completedRepValidationReasons;
  final List<String> completedRepTempoDiagnosticReasons;
  final RepTempoAssessment? completedRepTempoAssessment;
  final MeasurementConfidenceBreakdown? completedRepMeasurementConfidence;
  final bool recordAcceptedPoseFrame;
  final bool recordPoseReacquisition;
  final bool recordBriefOcclusion;
  final bool recordBriefOcclusionRecovery;
  final bool recordBriefOcclusionAbort;
  final bool recordResync;
}

class RangeRepCoordinatorFrameResult {
  const RangeRepCoordinatorFrameResult({
    required this.stateSnapshot,
    required this.diagnosticsUpdate,
    this.validatedRepEvent,
    this.shouldResetPoseAcceptance = false,
    this.shouldRecordInvalidPoseAcceptance = false,
  });

  final RangeRepCoordinatorStateSnapshot stateSnapshot;
  final RangeRepCoordinatorDiagnosticsUpdate diagnosticsUpdate;
  final ValidatedRepEvent? validatedRepEvent;
  final bool shouldResetPoseAcceptance;
  final bool shouldRecordInvalidPoseAcceptance;
}

class RangeRepCoordinatorDiagnosticsState {
  const RangeRepCoordinatorDiagnosticsState({
    required this.selectedSideLabel,
    required this.hasActiveRepContext,
  });

  final String? selectedSideLabel;
  final bool hasActiveRepContext;
}

abstract class RangeRepCoordinator {
  RangeRepCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
  });

  RangeRepCoordinatorStateSnapshot handleLifecycleInterruption({
    String? reason,
  });

  RangeRepCoordinatorDiagnosticsState diagnosticsState();
}

class DefaultRangeRepCoordinator implements RangeRepCoordinator {
  DefaultRangeRepCoordinator({
    required RangeRepAnalysisEngine engine,
    required ExerciseConfig config,
    required RangeRepContract rangeRepContract,
    required RangeRepValidationConfig rangeRepValidationConfig,
    LegacyRangeRepScorer scorer = const LegacyRangeRepScorer(),
    RangeRepRepScoringService? repScoringService,
    RangeRepAttemptProcessor? attemptProcessor,
    RangeRepCalibrationProjector? calibrationProjector,
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
    RangeRepMovementSideSelector? movementSideSelector,
    RangeRepSideStabilizer? sideStabilizer,
    RangeRepVisibilityPolicy? visibilityPolicy,
    RangeRepThresholdBookkeeper? thresholdBookkeeper,
    RangeRepRepOutcomeTracker? outcomeTracker,
    SessionCalibrationBaselineAccumulator?
    sessionCalibrationBaselineAccumulator,
  }) : _engine = engine,
       _config = config,
       _rangeRepContract = rangeRepContract,
       _rangeRepValidationConfig = rangeRepValidationConfig,
       _tempoCoachingPolicy = RangeRepTempoCoachingPolicy(
         config: rangeRepValidationConfig.tempoCoachingConfig,
       ),
       _primaryMetricFilter = MovingAverageFilter(
         windowSize: rangeRepContract.primaryMetricSmoothingWindow,
       ),
       _formMetricFilter = MovingAverageFilter(
         windowSize: rangeRepContract.formMetricSmoothingWindow,
       ),
       _bodyLineFilter = MovingAverageFilter(windowSize: 5),
       _armSupportFilter = MovingAverageFilter(windowSize: 5),
       _legFilter = MovingAverageFilter(windowSize: 5),
       _attemptProcessor =
           attemptProcessor ??
           RangeRepAttemptProcessor(
             scoringService:
                 repScoringService ?? RangeRepRepScoringService(scorer: scorer),
           ),
       _techniqueEvaluator = techniqueEvaluator,
       _techniqueHistoryTracker =
           techniqueHistoryTracker ??
           LegacyRangeRepTechniqueHistoryTracker(
             phaseQualityConfig: config.rangeRepPhaseQuality,
           ),
       _analysisFrameBuilder = analysisFrameBuilder,
       _blockedStateBuilder = blockedStateBuilder,
       _calibrationMetricsBuilder = calibrationMetricsBuilder,
       _calibrationProjector =
           calibrationProjector ??
           RangeRepCalibrationProjector(
             snapshotBuilder: calibrationSnapshotBuilder,
             metricsBuilder: calibrationMetricsBuilder,
             baselineAccumulator: sessionCalibrationBaselineAccumulator,
           ),
       _framePolicy = framePolicy,
       _sidePolicy = sidePolicy,
       _movementSideSelector =
           movementSideSelector ?? RangeRepMovementSideSelector(),
       _sideStabilizer = sideStabilizer ?? RangeRepSideStabilizer(),
       _visibilityPolicy = visibilityPolicy ?? RangeRepVisibilityPolicy(),
       _thresholdBookkeeper =
           thresholdBookkeeper ??
           RangeRepThresholdBookkeeper(
             analysisKind: EngineKind.rangeRep.name,
             config: config,
             formThresholdCalibrationPolicy:
                 rangeRepContract.formThresholdCalibrationPolicy,
           ),
       _outcomeTracker =
           outcomeTracker ??
           RangeRepRepOutcomeTracker(
             validationPolicy: RangeRepValidationPolicy(
               config: rangeRepValidationConfig,
             ),
           );

  final RangeRepAnalysisEngine _engine;
  final ExerciseConfig _config;
  final RangeRepContract _rangeRepContract;
  final RangeRepValidationConfig _rangeRepValidationConfig;
  final RangeRepTempoCoachingPolicy _tempoCoachingPolicy;
  final RangeRepAttemptProcessor _attemptProcessor;
  final LegacyRangeRepTechniqueEvaluator _techniqueEvaluator;
  final LegacyRangeRepTechniqueHistoryTracker _techniqueHistoryTracker;
  final FeedbackArbitrationEngine _feedbackArbitrationEngine =
      const FeedbackArbitrationEngine();
  final WorkoutAnalysisFrameBuilder _analysisFrameBuilder;
  final RangeRepBlockedStateBuilder _blockedStateBuilder;
  final WorkoutCalibrationMetricsBuilder _calibrationMetricsBuilder;
  final RangeRepCalibrationProjector _calibrationProjector;
  final RangeRepFramePolicy _framePolicy;
  final RangeRepFeedbackLifecycle _feedbackLifecycle =
      RangeRepFeedbackLifecycle();
  final RangeRepSidePolicy _sidePolicy;
  final RangeRepMovementSideSelector _movementSideSelector;
  final RangeRepSideStabilizer _sideStabilizer;
  final RangeRepVisibilityPolicy _visibilityPolicy;
  final RangeRepThresholdBookkeeper _thresholdBookkeeper;
  final RangeRepRepOutcomeTracker _outcomeTracker;
  final MovingAverageFilter _primaryMetricFilter;
  final MovingAverageFilter _formMetricFilter;
  final MovingAverageFilter _bodyLineFilter;
  final MovingAverageFilter _armSupportFilter;
  final MovingAverageFilter _legFilter;

  RangeRepSide? _selectedRangeRepSide;
  RangeRepSide? _briefGapFrozenRangeRepSide;
  bool _hasAcceptedPoseForAnalysis = false;
  bool _isLifecycleNeutralReacquisitionPending = false;
  List<PoseLandmark>? _lastPublishedLandmarks;
  double _lastPublishedCurrentAngle = 0.0;
  double _lastRepScore = 0.0;
  double _lastAcceptedRepRom = 0.0;
  RepScoreBreakdown? _lastRepScoreBreakdown;
  RangeRepCompletedRepCoreData? _lastCompletedRepCoreData;
  RepTempoAssessment? _lastRepTempoAssessment;
  bool _isFormBad = false;
  RangeRepFeedbackCode _currentFeedbackCode = RangeRepFeedbackCode.awaitNeutral;
  String _feedbackPhaseKey = 'awaitingNeutral';
  DateTime _diagnosticsNow = DateTime.fromMillisecondsSinceEpoch(0);
  WorkoutCalibrationMetrics _lastPublishedCalibrationMetrics =
      const WorkoutCalibrationMetrics.rangeRep();
  RangeRepRepTelemetrySnapshot _lastRepTelemetry =
      const RangeRepRepTelemetrySnapshot();

  @override
  RangeRepCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
  }) {
    _diagnosticsNow = now;
    final preUpdateDiagnostics = _rangeRepDiagnosticsSnapshot();
    final effectiveMetrics = _effectiveMetricsForAnalysis(
      metrics: metrics,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
      preferredRangeRepSide: preferredRangeRepSide,
    );
    final visibilityRunActive = _visibilityPolicy.hasActiveInvalidRun;
    final movementPreferredSide = _movementSideSelector.selectPreferredSide(
      leftMetrics: effectiveMetrics.leftRangeRepMetrics,
      rightMetrics: effectiveMetrics.rightRangeRepMetrics,
      neutralThreshold: _config.thresholdNeutral,
      direction: _rangeRepContract.primaryMetricDirection,
      enabled: _rangeRepContract.automaticSideSelectionEnabled,
    );
    final sideSelection = _selectRangeRepSideForFrame(
      metrics: effectiveMetrics,
      diagnostics: preUpdateDiagnostics,
      visibilityRunActive: visibilityRunActive,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
      preferredRangeRepSide: preferredRangeRepSide,
      movementPreferredSide: movementPreferredSide,
    );
    final previousSelectedSide = _selectedRangeRepSide;
    if (sideSelection.selectedSide != null &&
        sideSelection.selectedSide != previousSelectedSide &&
        !preUpdateDiagnostics.hasRepContext) {
      _resetSideSensitiveFilters();
    }
    final frameAssessment = _frameAssessment(effectiveMetrics, sideSelection);
    final isEngineEligibleFrame =
        isAcceptedPoseFrame && frameAssessment.shouldUpdateEngine;

    if (!isEngineEligibleFrame) {
      return _processInvalidFrame(
        metrics: effectiveMetrics,
        now: now,
        isAcceptedPoseFrame: isAcceptedPoseFrame,
        frameAssessment: frameAssessment,
        preUpdateDiagnostics: preUpdateDiagnostics,
      );
    }

    if (visibilityRunActive && _hasAcceptedPoseForAnalysis) {
      if (didBecomeStableTracking) {
        final recoveryVisibilityAssessment = _recoveryVisibilityAssessment(
          now: now,
        );
        if (recoveryVisibilityAssessment.shouldResync) {
          final selectedSideLabel = _rangeRepSideLabel(
            _briefGapFrozenRangeRepSide ?? _selectedRangeRepSide,
          );
          _visibilityPolicy.reset();
          _resetVisibilityResyncState(
            reason: recoveryVisibilityAssessment.resyncReason,
            resetVisibilityPolicy: false,
          );
          if (_isLifecycleNeutralReacquisitionPending) {
            _setCurrentFeedback(
              RangeRepFeedbackCode.bodyNotVisible,
              phaseKey: 'lifecycle_visibility_blocked',
            );
          }
          final feedbackDirective = _coordinatorFeedbackDirective();
          return RangeRepCoordinatorFrameResult(
            stateSnapshot: _buildBlockedStateSnapshot(
              metrics: effectiveMetrics,
              frameAssessment: frameAssessment,
              freezeSmoothedPreview: true,
              feedbackDirective: feedbackDirective,
              currentPhase: _phaseForLifecycleReacquisition(
                feedbackDirective: feedbackDirective,
                fallback: _engine.phaseLabel,
              ),
              visibilityAssessment: recoveryVisibilityAssessment,
              selectedSideLabel: selectedSideLabel,
            ),
            diagnosticsUpdate: RangeRepCoordinatorDiagnosticsUpdate(
              visibilityStatus: 'hard_resync',
              selectedSideLabel: _currentSelectedSideLabelForDiagnostics(),
              hasActiveRepContext: preUpdateDiagnostics.hasRepContext,
              recordResync: true,
            ),
            shouldResetPoseAcceptance: true,
          );
        }
      }

      final analysisFrame = _buildAnalysisFrame(
        metrics: effectiveMetrics,
        selectedMetrics: frameAssessment.selectedMetrics,
      );
      final adaptedAnalysisFrame = _adaptAnalysisFrameForDetection(
        frame: analysisFrame,
        metrics: effectiveMetrics,
        selectedSide: frameAssessment.selection.selectedSide,
        currentPhase: _engine.phaseLabel,
        hasActiveRepContext: preUpdateDiagnostics.hasRepContext,
      );
      final formThresholdResolution = _thresholdBookkeeper.resolve(
        baseThreshold: _config.formThreshold,
        sessionCalibrationBaseline:
            _calibrationProjector.sessionCalibrationBaseline,
        selectedRangeRepSide: _rangeRepSideLabel(
          frameAssessment.selection.selectedSide,
        ),
      );
      final engineFrame = _applyFormThresholdResolution(
        adaptedAnalysisFrame,
        formThresholdResolution,
      );
      var recordBriefOcclusionRecovery = false;
      var recordBriefOcclusionAbort = false;
      var recordResync = false;
      var shouldResetPoseAcceptance = false;

      if (didBecomeStableTracking) {
        final gapResumeResult = _resumeBriefVisibilityGap(
          engineFrame.primaryMetric,
          observedAt: now,
        );
        if (gapResumeResult.disposition ==
            VisibilityGapResumeDisposition.incompatible) {
          _visibilityPolicy.reset();
          _resetVisibilityResyncState(
            reason: 'brief occlusion incompatible recovery',
            resetVisibilityPolicy: false,
          );
          recordBriefOcclusionAbort = true;
          recordResync = true;
          shouldResetPoseAcceptance = true;
          return RangeRepCoordinatorFrameResult(
            stateSnapshot: _rememberStateSnapshot(
              landmarks: _lastPublishedLandmarks,
              repCount: _outcomeTracker.rangeRepAcceptedCount,
              isFormBad: _isFormBad,
              currentAngle: _lastPublishedCurrentAngle,
              lastRepScore: _lastRepScore,
              lastRepRom: _lastAcceptedRepRom,
              currentPhase: _engine.phaseLabel,
              calibrationMetrics: _lastPublishedCalibrationMetrics,
              feedbackDirective: _coordinatorFeedbackDirective(),
            ),
            diagnosticsUpdate: RangeRepCoordinatorDiagnosticsUpdate(
              visibilityStatus: 'brief_abort',
              selectedSideLabel: _currentSelectedSideLabelForDiagnostics(),
              hasActiveRepContext: preUpdateDiagnostics.hasRepContext,
              recordBriefOcclusionAbort: recordBriefOcclusionAbort,
              recordResync: recordResync,
            ),
            shouldResetPoseAcceptance: shouldResetPoseAcceptance,
          );
        }
        if (gapResumeResult.disposition ==
            VisibilityGapResumeDisposition.compatible) {
          _techniqueHistoryTracker.shiftActivePhaseTiming(
            gapResumeResult.appliedGapDuration,
          );
          recordBriefOcclusionRecovery = true;
        }
      }
      _briefGapFrozenRangeRepSide = null;

      final visibilityAssessment = _visibilityAssessment(
        isInvalidFrame: false,
        now: now,
      );
      if (sideSelection.selectedSide != null &&
          !(visibilityRunActive && _briefGapFrozenRangeRepSide != null)) {
        _selectedRangeRepSide = sideSelection.selectedSide;
      }

      return _processAcceptedFrame(
        metrics: effectiveMetrics,
        now: now,
        frameAssessment: frameAssessment,
        preUpdateDiagnostics: preUpdateDiagnostics,
        visibilityAssessment: visibilityAssessment,
        didBecomeStableTracking: didBecomeStableTracking,
        recordBriefOcclusionRecovery: recordBriefOcclusionRecovery,
      );
    }

    final visibilityAssessment = _visibilityAssessment(
      isInvalidFrame: false,
      now: now,
    );
    if (sideSelection.selectedSide != null &&
        !(visibilityRunActive && _briefGapFrozenRangeRepSide != null)) {
      _selectedRangeRepSide = sideSelection.selectedSide;
    }

    return _processAcceptedFrame(
      metrics: effectiveMetrics,
      now: now,
      frameAssessment: frameAssessment,
      preUpdateDiagnostics: preUpdateDiagnostics,
      visibilityAssessment: visibilityAssessment,
      didBecomeStableTracking: didBecomeStableTracking,
      recordBriefOcclusionRecovery: false,
    );
  }

  /// Exercise-owned adaptation point for the scalar sent to the detection
  /// engine after pose-quality filtering and selected-side resolution.
  ///
  /// The default implementation is identity-only. Production exercise
  /// extensions may override this without duplicating the generic visibility,
  /// lifecycle, validation, and scoring pipeline.
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
    return primaryMetric;
  }

  @override
  RangeRepCoordinatorStateSnapshot handleLifecycleInterruption({
    String? reason,
  }) {
    final shouldStabilizeNeutralReacquisition = _hasAcceptedPoseForAnalysis;
    _resetVisibilityResyncState(
      reason: reason ?? 'lifecycle interruption',
      resetVisibilityPolicy: true,
    );
    _isLifecycleNeutralReacquisitionPending =
        shouldStabilizeNeutralReacquisition;
    return _rememberStateSnapshot(
      landmarks: _lastPublishedLandmarks,
      repCount: _outcomeTracker.rangeRepAcceptedCount,
      isFormBad: _isFormBad,
      currentAngle: _lastPublishedCurrentAngle,
      lastRepScore: _lastRepScore,
      lastRepRom: _lastAcceptedRepRom,
      currentPhase: _engine.phaseLabel,
      calibrationMetrics: _lastPublishedCalibrationMetrics,
      feedbackDirective: _coordinatorFeedbackDirective(),
    );
  }

  @override
  RangeRepCoordinatorDiagnosticsState diagnosticsState() {
    return RangeRepCoordinatorDiagnosticsState(
      selectedSideLabel: _currentSelectedSideLabelForDiagnostics(),
      hasActiveRepContext: _rangeRepDiagnosticsSnapshot().hasRepContext,
    );
  }

  RangeRepCoordinatorFrameResult _processInvalidFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required RangeRepFrameAssessment frameAssessment,
    required RangeRepDiagnosticsSnapshot preUpdateDiagnostics,
  }) {
    if (isAcceptedPoseFrame) {
      // Accepted-but-invalid frames should break stabilization before recovery.
      // The controller keeps the common pose stabilizer owner and executes this.
    }

    final visibilityAssessment = _visibilityAssessment(
      isInvalidFrame: true,
      now: now,
    );
    var recordBriefOcclusion = false;
    if (visibilityAssessment.didStartInvalidRun) {
      recordBriefOcclusion = _beginBriefVisibilityGap(
        preUpdateDiagnostics,
        observedAt: now,
      );
    }
    _trackRepContext(
      diagnostics: preUpdateDiagnostics,
      selectedSide: _briefGapFrozenRangeRepSide,
      markCoverageDrop: true,
    );

    if (visibilityAssessment.shouldResync) {
      _resetVisibilityResyncState(reason: visibilityAssessment.resyncReason);
      if (_isLifecycleNeutralReacquisitionPending) {
        _setCurrentFeedback(
          RangeRepFeedbackCode.bodyNotVisible,
          phaseKey: 'lifecycle_visibility_blocked',
        );
      }
      final feedbackDirective = _coordinatorFeedbackDirective();
      return RangeRepCoordinatorFrameResult(
        stateSnapshot: _buildBlockedStateSnapshot(
          metrics: metrics,
          frameAssessment: frameAssessment,
          freezeSmoothedPreview: true,
          feedbackDirective: feedbackDirective,
          currentPhase: _phaseForLifecycleReacquisition(
            feedbackDirective: feedbackDirective,
            fallback: _engine.phaseLabel,
          ),
          visibilityAssessment: visibilityAssessment,
          selectedSideLabel: _currentSelectedSideLabelForDiagnostics(),
        ),
        diagnosticsUpdate: RangeRepCoordinatorDiagnosticsUpdate(
          visibilityStatus: 'hard_resync',
          selectedSideLabel: _currentSelectedSideLabelForDiagnostics(),
          hasActiveRepContext: preUpdateDiagnostics.hasRepContext,
          recordBriefOcclusion: recordBriefOcclusion,
          recordResync: true,
        ),
        shouldRecordInvalidPoseAcceptance: isAcceptedPoseFrame,
      );
    }

    final blockedFeedback = _isLifecycleNeutralReacquisitionPending
        ? _coordinatorFeedbackDirective()
        : const RangeRepFeedbackDirective.code(
            RangeRepFeedbackCode.bodyNotVisible,
          );
    return RangeRepCoordinatorFrameResult(
      stateSnapshot: _buildBlockedStateSnapshot(
        metrics: metrics,
        frameAssessment: frameAssessment,
        freezeSmoothedPreview: true,
        feedbackDirective: blockedFeedback,
        currentPhase: _phaseForLifecycleReacquisition(
          feedbackDirective: blockedFeedback,
          fallback: 'WAITING',
        ),
        visibilityAssessment: visibilityAssessment,
        selectedSideLabel: _currentSelectedSideLabelForDiagnostics(),
      ),
      diagnosticsUpdate: RangeRepCoordinatorDiagnosticsUpdate(
        visibilityStatus: visibilityAssessment.statusLabel,
        selectedSideLabel: _currentSelectedSideLabelForDiagnostics(),
        hasActiveRepContext: preUpdateDiagnostics.hasRepContext,
        recordBriefOcclusion: recordBriefOcclusion,
      ),
      shouldRecordInvalidPoseAcceptance: isAcceptedPoseFrame,
    );
  }

  RangeRepCoordinatorFrameResult _processAcceptedFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required RangeRepFrameAssessment frameAssessment,
    required RangeRepDiagnosticsSnapshot preUpdateDiagnostics,
    required RangeRepVisibilityAssessment visibilityAssessment,
    required bool didBecomeStableTracking,
    required bool recordBriefOcclusionRecovery,
  }) {
    final selectedFormSignals = frameAssessment.analysisMetrics?.formSignals;
    final selectedSideLabel = _rangeRepSideLabel(
      frameAssessment.selection.selectedSide,
    );
    _trackRepContext(
      diagnostics: preUpdateDiagnostics,
      selectedSide: frameAssessment.selection.selectedSide,
      frameMeasurementConfidence:
          frameAssessment.selectedMetrics?.measurementConfidence,
    );
    final analysisFrame = _buildAnalysisFrame(
      metrics: metrics,
      selectedMetrics: frameAssessment.selectedMetrics,
    );
    final adaptedAnalysisFrame = _adaptAnalysisFrameForDetection(
      frame: analysisFrame,
      metrics: metrics,
      selectedSide: frameAssessment.selection.selectedSide,
      currentPhase: _engine.phaseLabel,
      hasActiveRepContext: preUpdateDiagnostics.hasRepContext,
    );
    final formThresholdResolution = _thresholdBookkeeper.resolve(
      baseThreshold: _config.formThreshold,
      sessionCalibrationBaseline:
          _calibrationProjector.sessionCalibrationBaseline,
      selectedRangeRepSide: selectedSideLabel,
    );
    final engineFrame = _applyFormThresholdResolution(
      adaptedAnalysisFrame,
      formThresholdResolution,
    );
    final usesLegacyFormMetricTechnique = _rangeRepContract.signalHasRole(
      RangeRepSignal.formMetric,
      AnalysisSignalRole.technique,
    );
    final shouldEvaluateTechnique = _rangeRepContract.shouldEvaluateTechnique(
      primaryMetric: engineFrame.primaryMetric,
      activeThreshold: _config.thresholdActive,
      peakThreshold: _config.thresholdPeak,
    );
    final hasTechniqueViolation =
        usesLegacyFormMetricTechnique &&
        shouldEvaluateTechnique &&
        _techniqueEvaluator
            .evaluate(
              formMetric: engineFrame.formMetric,
              formThreshold: _config.formThreshold,
            )
            .hasObservations;
    final engineResult = _engine.updateDetectionFrame(
      primaryMetric: engineFrame.primaryMetric,
      observedAt: now,
    );
    final completedTechniqueData = _techniqueHistoryTracker.recordFrame(
      engineResult: engineResult,
      primaryMetric: engineFrame.primaryMetric,
      formMetric: engineFrame.formMetric,
      hasTechniqueViolation: hasTechniqueViolation,
    );
    final completedCycle = engineResult.completedCycle;
    final completedRepTempoAssessment = completedCycle == null
        ? null
        : _tempoCoachingPolicy.evaluate(
            completedCycle.tempoMeasurementAssessment,
          );
    if (completedRepTempoAssessment != null) {
      _lastRepTempoAssessment = completedRepTempoAssessment;
    }
    final completedRepCoreData = _buildCompletedRepCoreData(
      detectionData:
          completedCycle?.detectionData ??
          engineResult.completedRepDetectionData,
      techniqueData: completedTechniqueData,
      totalRepDuration:
          completedCycle?.completedTempo?.totalRepDuration ??
          engineResult.completedTempo?.totalRepDuration,
    );
    if (completedRepCoreData != null) {
      _lastCompletedRepCoreData = completedRepCoreData;
    }
    final postUpdateDetectionDiagnostics = _engine.detectionDiagnosticsSnapshot;
    final postUpdateTechniqueHistory = _techniqueHistorySnapshotFor(
      postUpdateDetectionDiagnostics,
    );
    final postUpdateDiagnostics = _rangeRepDiagnosticsSnapshotFrom(
      detectionDiagnostics: postUpdateDetectionDiagnostics,
      techniqueHistory: postUpdateTechniqueHistory,
    );
    _applyFeedbackArbitration(
      engineResult: engineResult,
      hasTechniqueViolation: hasTechniqueViolation,
    );
    if (_isLifecycleNeutralReacquisitionPending &&
        engineResult.isArmedAfterUpdate) {
      _isLifecycleNeutralReacquisitionPending = false;
    }
    final didCompleteRep = engineResult.didCompleteRep;
    final completedAttemptResult = _attemptProcessor.processCompleted(
      outcomeTracker: _outcomeTracker,
      completedRepCoreData: completedRepCoreData,
      postUpdateDiagnostics: postUpdateDiagnostics,
      tempoAssessment: completedRepTempoAssessment,
      completedAt: now,
      engineLastRepRom: _engine.lastRepRom,
      config: _config,
      rangeRepContract: _rangeRepContract,
      rangeRepValidationConfig: _rangeRepValidationConfig,
    );
    if (completedAttemptResult != null) {
      _applyAttemptProcessingResult(completedAttemptResult);
    }
    final abortedAttemptResult = completedAttemptResult == null
        ? _attemptProcessor.processShallowAbort(
            outcomeTracker: _outcomeTracker,
            invalidateAbortToNeutralAsInsufficientRom: _rangeRepValidationConfig
                .invalidateAbortToNeutralAsInsufficientRom,
            abortedAttemptData: engineResult.abortedAttemptDetectionData,
            currentFormMetric: engineFrame.formMetric,
            hadFormViolation: hasTechniqueViolation,
            completedAt: now,
          )
        : null;
    if (abortedAttemptResult != null) {
      _applyAttemptProcessingResult(abortedAttemptResult);
    }
    final validatedRepEvent =
        completedAttemptResult?.validatedRepEvent ??
        abortedAttemptResult?.validatedRepEvent;
    _outcomeTracker.resetRepContextIfCycleEnded(
      previousDiagnostics: preUpdateDiagnostics,
      currentDiagnostics: postUpdateDiagnostics,
      didCompleteRep: didCompleteRep,
    );
    _resetAutomaticSideSelectionIfCycleEnded(engineResult);

    final calibrationMetrics = _projectCalibrationMetrics(
      diagnostics: postUpdateDiagnostics,
      currentFormMetric: engineFrame.formMetric,
      currentPrimaryMetric: engineFrame.primaryMetric,
      thresholdValue: formThresholdResolution.effectiveThreshold,
      currentTorsoAngle: selectedFormSignals?.torsoAngle,
      currentDepthMetric: selectedFormSignals?.depthMetric,
      currentAlignmentMetric: selectedFormSignals?.alignmentMetric,
      currentStabilityMetric: selectedFormSignals?.stabilityMetric,
      currentLockoutMetric: selectedFormSignals?.lockoutMetric,
      currentBottomControlMetric: selectedFormSignals?.bottomControlMetric,
      baseFormThreshold: formThresholdResolution.baseThreshold,
      effectiveFormThreshold: formThresholdResolution.effectiveThreshold,
      calibrationThresholdOffsetCandidate:
          formThresholdResolution.offsetCandidate,
      calibrationThresholdOffsetApplied: formThresholdResolution.isApplied,
      calibrationThresholdOffsetFallbackReason:
          formThresholdResolution.decisionReason,
      calibrationThresholdOffsetSampleCount:
          formThresholdResolution.sampleCount,
      calibrationThresholdOffsetBaselineSideLabel:
          formThresholdResolution.baselineSideLabel,
      isRangeRepFrameValid: frameAssessment.isValid,
      hasPrimaryAngle: frameAssessment.hasPrimaryAngle,
      hasFormMetric: frameAssessment.hasFormMetric,
      rangeRepInvalidReason: frameAssessment.invalidReason,
      selectedRangeRepSide: selectedSideLabel,
      rangeRepSideSelectionReason: frameAssessment.selection.debugLabel,
      leftRangeRepCoverage: frameAssessment.selection.leftMetrics.coverageScore,
      rightRangeRepCoverage:
          frameAssessment.selection.rightMetrics.coverageScore,
      leftRangeRepSideConfidence:
          frameAssessment.selection.leftMetrics.sideConfidence,
      rightRangeRepSideConfidence:
          frameAssessment.selection.rightMetrics.sideConfidence,
      rangeRepInvalidFrameStreak: visibilityAssessment.invalidFrameStreak,
      rangeRepInvalidDurationMs:
          visibilityAssessment.invalidDuration.inMilliseconds,
      rangeRepResyncTriggered: visibilityAssessment.hasResyncedCurrentRun,
      rangeRepResyncReason: visibilityAssessment.resyncReason,
      rangeRepVisibilityStatus: visibilityAssessment.statusLabel,
      hasBodyLineAngle: metrics.bodyLineAngle != null,
      hasArmSupportAngle: metrics.armSupportAngle != null,
      hasLegExtensionAngle: metrics.legExtensionAngle != null,
    );

    final didReacquire = didBecomeStableTracking && _hasAcceptedPoseForAnalysis;
    final stateSnapshot = _rememberStateSnapshot(
      landmarks: metrics.landmarks,
      repCount: _outcomeTracker.rangeRepAcceptedCount,
      isFormBad: _isFormBad,
      currentAngle: _currentAngleForState(analysisFrame),
      lastRepScore: _lastRepScore,
      lastRepRom: _lastAcceptedRepRom,
      currentPhase: _engine.phaseLabel,
      calibrationMetrics: calibrationMetrics,
      feedbackDirective: _coordinatorFeedbackDirective(),
    );
    _hasAcceptedPoseForAnalysis = true;

    return RangeRepCoordinatorFrameResult(
      stateSnapshot: stateSnapshot,
      diagnosticsUpdate: RangeRepCoordinatorDiagnosticsUpdate(
        visibilityStatus: visibilityAssessment.statusLabel,
        selectedSideLabel: _currentSelectedSideLabelForDiagnostics(),
        hasActiveRepContext: preUpdateDiagnostics.hasRepContext,
        confirmedTransitionCode: engineResult.confirmedTransition?.type.name,
        confirmedTransitionCodes: engineResult.confirmedTransitions
            .map((transition) => transition.type.name)
            .toList(growable: false),
        completedRepValidationStatus: validatedRepEvent?.validationStatus.name,
        completedRepValidationReasons:
            validatedRepEvent?.validationReasons
                .map((reason) => reason.name)
                .toList(growable: false) ??
            const <String>[],
        completedRepTempoDiagnosticReasons:
            validatedRepEvent?.tempoDiagnosticReasons
                .map((reason) => reason.name)
                .toList(growable: false) ??
            const <String>[],
        completedRepTempoAssessment: completedRepTempoAssessment,
        completedRepMeasurementConfidence:
            validatedRepEvent?.measurementConfidence,
        recordAcceptedPoseFrame: true,
        recordPoseReacquisition: didReacquire,
        recordBriefOcclusionRecovery: recordBriefOcclusionRecovery,
      ),
      validatedRepEvent: validatedRepEvent,
    );
  }

  ExerciseMetrics _effectiveMetricsForAnalysis({
    required ExerciseMetrics metrics,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
  }) {
    if (qualityAcceptedRangeRepSides == null) {
      return metrics;
    }

    return _qualityFilteredMetrics(
      metrics: metrics,
      acceptedSides: qualityAcceptedRangeRepSides,
      preferredSide: preferredRangeRepSide,
    );
  }

  ExerciseMetrics _qualityFilteredMetrics({
    required ExerciseMetrics metrics,
    required Set<RangeRepSide> acceptedSides,
    required RangeRepSide? preferredSide,
  }) {
    final leftMetrics = acceptedSides.contains(RangeRepSide.left)
        ? metrics.leftRangeRepMetrics
        : const RangeRepSideMetrics.unavailable(RangeRepSide.left);
    final rightMetrics = acceptedSides.contains(RangeRepSide.right)
        ? metrics.rightRangeRepMetrics
        : const RangeRepSideMetrics.unavailable(RangeRepSide.right);
    final selectedMetrics = _rangeRepMetricsForSide(
      preferredSide != null && acceptedSides.contains(preferredSide)
          ? preferredSide
          : acceptedSides.contains(RangeRepSide.left)
          ? RangeRepSide.left
          : acceptedSides.contains(RangeRepSide.right)
          ? RangeRepSide.right
          : null,
      leftMetrics: leftMetrics,
      rightMetrics: rightMetrics,
    );

    if (_rangeRepContract.sideMode == RangeRepSideMode.bilateral) {
      return metrics.copyWith(
        leftRangeRepMetrics: leftMetrics,
        rightRangeRepMetrics: rightMetrics,
      );
    }

    return metrics.copyWith(
      primaryAngle: selectedMetrics?.primaryAngle ?? metrics.primaryAngle,
      formMetric: selectedMetrics?.formMetric ?? metrics.formMetric,
      hasPrimaryAngle:
          selectedMetrics?.hasPrimaryAngle ?? metrics.hasPrimaryAngle,
      hasFormMetric: selectedMetrics?.hasFormMetric ?? metrics.hasFormMetric,
      leftRangeRepMetrics: leftMetrics,
      rightRangeRepMetrics: rightMetrics,
    );
  }

  RangeRepSideMetrics? _rangeRepMetricsForSide(
    RangeRepSide? side, {
    required RangeRepSideMetrics leftMetrics,
    required RangeRepSideMetrics rightMetrics,
  }) {
    switch (side) {
      case RangeRepSide.left:
        return leftMetrics;
      case RangeRepSide.right:
        return rightMetrics;
      case null:
        return null;
    }
  }

  RangeRepSideSelection _selectRangeRepSideForFrame({
    required ExerciseMetrics metrics,
    required RangeRepDiagnosticsSnapshot diagnostics,
    required bool visibilityRunActive,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
    required RangeRepSide? movementPreferredSide,
  }) {
    if (_rangeRepContract.sideMode == RangeRepSideMode.bilateral) {
      return RangeRepSideSelection(
        selectedSide: null,
        leftMetrics: metrics.leftRangeRepMetrics,
        rightMetrics: metrics.rightRangeRepMetrics,
        reason: RangeRepSideSelectionReason.bilateralAggregate,
      );
    }

    if (visibilityRunActive && _briefGapFrozenRangeRepSide != null) {
      return _frozenSideSelection(metrics, _briefGapFrozenRangeRepSide!);
    }

    final selectedRangeRepSide = _selectedRangeRepSide;
    final shouldLockToCurrentSide =
        selectedRangeRepSide != null &&
        qualityAcceptedRangeRepSides != null &&
        _shouldLockRangeRepSideSelection(
          selectedSide: selectedRangeRepSide,
          diagnostics: diagnostics,
        ) &&
        !qualityAcceptedRangeRepSides.contains(selectedRangeRepSide);
    if (shouldLockToCurrentSide) {
      return _lockedSideSelection(metrics, selectedRangeRepSide);
    }

    return _sideSelection(
      metrics,
      diagnostics: diagnostics,
      preferredRangeRepSide: preferredRangeRepSide,
      movementPreferredSide: movementPreferredSide,
    );
  }

  RangeRepSideSelection _sideSelection(
    ExerciseMetrics metrics, {
    RangeRepDiagnosticsSnapshot? diagnostics,
    RangeRepSide? preferredRangeRepSide,
    RangeRepSide? movementPreferredSide,
  }) {
    final selection = _sidePolicy.select(
      metrics: metrics,
      previousSide: _selectedRangeRepSide,
      preferredSide: preferredRangeRepSide,
      movementPreferredSide: movementPreferredSide,
      lockPreviousSide: false,
    );
    final resolvedDiagnostics = diagnostics ?? _rangeRepDiagnosticsSnapshot();
    return _sideStabilizer.stabilizeSelection(
      selection: selection,
      currentSide: _selectedRangeRepSide,
      hasActiveRepContext: resolvedDiagnostics.hasRepContext,
    );
  }

  RangeRepSideSelection _lockedSideSelection(
    ExerciseMetrics metrics,
    RangeRepSide side,
  ) {
    return RangeRepSideSelection(
      selectedSide: side,
      leftMetrics: metrics.leftRangeRepMetrics,
      rightMetrics: metrics.rightRangeRepMetrics,
      reason: RangeRepSideSelectionReason.lockedActiveRepSide,
    );
  }

  RangeRepSideSelection _frozenSideSelection(
    ExerciseMetrics metrics,
    RangeRepSide frozenSide,
  ) {
    return _lockedSideSelection(metrics, frozenSide);
  }

  RangeRepFrameAssessment _frameAssessment(
    ExerciseMetrics metrics,
    RangeRepSideSelection selection,
  ) {
    return _framePolicy.assessWithContract(
      metrics: metrics,
      selection: selection,
      contract: _rangeRepContract,
    );
  }

  RangeRepVisibilityAssessment _visibilityAssessment({
    required bool isInvalidFrame,
    required DateTime now,
  }) {
    return _visibilityPolicy.evaluate(isInvalidFrame: isInvalidFrame, now: now);
  }

  RangeRepVisibilityAssessment _recoveryVisibilityAssessment({
    required DateTime now,
  }) {
    return _visibilityPolicy.evaluateRecovery(now: now);
  }

  AnalysisFrame _buildAnalysisFrame({
    required ExerciseMetrics metrics,
    required RangeRepAnalysisMetrics? selectedMetrics,
  }) {
    return _analysisFrameBuilder.build(
      metrics: metrics,
      rangeRepMetrics: selectedMetrics,
      primaryMetricFilter: _primaryMetricFilter,
      formMetricFilter: _formMetricFilter,
      holdSignalFilters: <HoldSignal, MovingAverageFilter>{
        HoldSignal.alignment: _bodyLineFilter,
        HoldSignal.support: _armSupportFilter,
        HoldSignal.extension: _legFilter,
      },
    );
  }

  AnalysisFrame _adaptAnalysisFrameForDetection({
    required AnalysisFrame frame,
    required ExerciseMetrics metrics,
    required RangeRepSide? selectedSide,
    required String currentPhase,
    required bool hasActiveRepContext,
  }) {
    final adaptedPrimaryMetric = adaptPrimaryMetricForDetection(
      metrics: metrics,
      selectedSide: selectedSide,
      primaryMetric: frame.primaryMetric,
      neutralThreshold: _config.thresholdNeutral,
      activeThreshold: _config.thresholdActive,
      currentPhase: currentPhase,
      hasActiveRepContext: hasActiveRepContext,
      now: _diagnosticsNow,
    );
    if (adaptedPrimaryMetric == frame.primaryMetric) {
      return frame;
    }
    return AnalysisFrame(
      primaryMetric: adaptedPrimaryMetric,
      formMetric: frame.formMetric,
      holdSignalValues: frame.holdSignalValues,
    );
  }

  AnalysisFrame _applyFormThresholdResolution(
    AnalysisFrame frame,
    RangeRepThresholdResolution resolution,
  ) {
    // R28 deliberately does not treat a user's initial calibration posture as
    // a trusted measurement-error reference. A correction candidate remains
    // observable in diagnostics, but it cannot rewrite the exercise-owned
    // technique measurement or acceptance threshold without an independent
    // measurement-correction source.
    assert(
      resolution.techniqueAcceptanceThreshold == resolution.baseThreshold,
      'Calibration must not rewrite the technique acceptance threshold.',
    );
    return frame;
  }

  void _applyFeedbackArbitration({
    required RangeRepEngineFrameResult engineResult,
    required bool hasTechniqueViolation,
  }) {
    final wasArmedAtFrameStart = engineResult.wasArmedAtFrameStart;
    final lifecycleCandidate = _lifecycleFeedbackCandidate(engineResult);
    final baseCandidate =
        lifecycleCandidate ??
        (engineResult.isArmedAfterUpdate
            ? _movementFeedbackFor(engineResult)
            : RangeRepFeedbackCode.awaitNeutral);
    final hasFreshCorrectiveCandidate =
        wasArmedAtFrameStart && hasTechniqueViolation;
    final decision = _feedbackArbitrationEngine.arbitrate<RangeRepFeedbackCode>(
      candidates: <FeedbackCandidate<RangeRepFeedbackCode>>[
        FeedbackCandidate<RangeRepFeedbackCode>(
          id: 'range_rep_base_${baseCandidate.code}',
          value: baseCandidate,
          priority: _priorityForRangeRepFeedback(baseCandidate),
        ),
        if (hasFreshCorrectiveCandidate)
          const FeedbackCandidate<RangeRepFeedbackCode>(
            id: 'range_rep_live_form_correction',
            value: RangeRepFeedbackCode.legacyFormThresholdViolation,
            priority: FeedbackPriority.corrective,
          ),
      ],
    );
    final phaseKey = _feedbackPhaseKeyFor(engineResult);
    _currentFeedbackCode = _feedbackLifecycle.resolve(
      now: _diagnosticsNow,
      phaseKey: phaseKey,
      freshCandidate: decision.selectedValue ?? baseCandidate,
      hasFreshCorrectiveCandidate: hasFreshCorrectiveCandidate,
      hasLifecycleTransition: lifecycleCandidate != null,
      retainFreshCorrective:
          _rangeRepContract.techniqueEvaluationPolicy !=
          RangeRepTechniqueEvaluationPolicy.peakWindowOnly,
    );
    _feedbackPhaseKey = phaseKey;
    _isFormBad =
        _currentFeedbackCode.family == RangeRepFeedbackFamily.correctiveCue;
  }

  RangeRepFeedbackCode _movementFeedbackFor(
    RangeRepEngineFrameResult engineResult,
  ) {
    final observedPhases = engineResult.observedRepPhases;
    if (observedPhases.contains(RangeRepPhase.ascending) ||
        observedPhases.contains(RangeRepPhase.peak)) {
      return RangeRepFeedbackCode.ascend;
    }
    if (observedPhases.contains(RangeRepPhase.descending)) {
      return RangeRepFeedbackCode.descend;
    }
    return engineResult.isArmedAfterUpdate
        ? RangeRepFeedbackCode.ready
        : RangeRepFeedbackCode.awaitNeutral;
  }

  String _feedbackPhaseKeyFor(RangeRepEngineFrameResult engineResult) {
    return switch (engineResult.confirmedTransition?.type) {
      RangeRepConfirmedTransitionType.acquireNeutral ||
      RangeRepConfirmedTransitionType.abortToNeutral ||
      RangeRepConfirmedTransitionType.completeRep => 'neutral',
      RangeRepConfirmedTransitionType.startDescending => 'descending',
      RangeRepConfirmedTransitionType.reachPeak => 'peak',
      RangeRepConfirmedTransitionType.startAscending => 'ascending',
      null when engineResult.observedRepPhases.isNotEmpty =>
        engineResult.observedRepPhases.last.name,
      null when !engineResult.isArmedAfterUpdate => 'awaitingNeutral',
      null => _feedbackPhaseKey,
    };
  }

  RangeRepFeedbackCode? _lifecycleFeedbackCandidate(
    RangeRepEngineFrameResult engineResult,
  ) {
    return switch (engineResult.confirmedTransition?.type) {
      null => null,
      RangeRepConfirmedTransitionType.acquireNeutral =>
        RangeRepFeedbackCode.ready,
      RangeRepConfirmedTransitionType.startDescending =>
        RangeRepFeedbackCode.descend,
      RangeRepConfirmedTransitionType.reachPeak => RangeRepFeedbackCode.ascend,
      RangeRepConfirmedTransitionType.startAscending =>
        RangeRepFeedbackCode.ascend,
      RangeRepConfirmedTransitionType.abortToNeutral =>
        RangeRepFeedbackCode.repIncomplete,
      RangeRepConfirmedTransitionType.completeRep =>
        RangeRepFeedbackCode.repCompleted,
    };
  }

  FeedbackPriority _priorityForRangeRepFeedback(RangeRepFeedbackCode code) {
    return switch (code) {
      RangeRepFeedbackCode.awaitNeutral ||
      RangeRepFeedbackCode.ready => FeedbackPriority.status,
      RangeRepFeedbackCode.waitForBody ||
      RangeRepFeedbackCode.bodyNotVisible => FeedbackPriority.systemState,
      RangeRepFeedbackCode.descend ||
      RangeRepFeedbackCode.ascend ||
      RangeRepFeedbackCode.repCompleted ||
      RangeRepFeedbackCode.repIncomplete => FeedbackPriority.movement,
      RangeRepFeedbackCode.legacyFormThresholdViolation ||
      RangeRepFeedbackCode.controlDescent ||
      RangeRepFeedbackCode.controlAscent ||
      RangeRepFeedbackCode.stabilizeTransition ||
      RangeRepFeedbackCode.maintainForm => FeedbackPriority.corrective,
    };
  }

  void _applyAttemptProcessingResult(RangeRepAttemptProcessingResult result) {
    _lastRepScore = result.lastRepScore;
    _lastAcceptedRepRom = result.lastAcceptedRepRom;
    _lastRepScoreBreakdown = result.lastRepScoreBreakdown;
    if (result.shouldClearTempoAssessment) {
      _lastRepTempoAssessment = null;
    }
    _refreshRepTelemetry();
  }

  RangeRepCompletedRepCoreData? _buildCompletedRepCoreData({
    required RangeRepCompletedRepDetectionData? detectionData,
    required LegacyRangeRepCompletedTechniqueData? techniqueData,
    required Duration? totalRepDuration,
  }) {
    if (detectionData == null) {
      return null;
    }
    if (techniqueData == null) {
      throw StateError(
        'Completed range-rep detection requires coordinator technique data.',
      );
    }

    return RangeRepCompletedRepCoreData(
      repIndex: detectionData.repIndex,
      minAngle: detectionData.minAngle,
      startAngle: detectionData.startAngle,
      primaryRom: detectionData.primaryRom,
      worstFormMetric: techniqueData.worstFormMetric,
      descentDuration: detectionData.descentDuration,
      ascentDuration: detectionData.ascentDuration,
      hadFormViolation: techniqueData.hadFormViolation,
      completedPhaseSequence: detectionData.completedPhaseSequence,
      totalRepDuration: totalRepDuration,
    );
  }

  WorkoutCalibrationMetrics _projectCalibrationMetrics({
    required RangeRepDiagnosticsSnapshot diagnostics,
    required double currentFormMetric,
    required double thresholdValue,
    double? currentPrimaryMetric,
    double? baseFormThreshold,
    double? effectiveFormThreshold,
    double? calibrationThresholdOffsetCandidate,
    bool calibrationThresholdOffsetApplied = false,
    String? calibrationThresholdOffsetFallbackReason,
    int? calibrationThresholdOffsetSampleCount,
    String? calibrationThresholdOffsetBaselineSideLabel,
    bool isRangeRepFrameValid = true,
    bool hasPrimaryAngle = false,
    bool hasFormMetric = false,
    RangeRepFrameInvalidReason? rangeRepInvalidReason,
    String? selectedRangeRepSide,
    String? rangeRepSideSelectionReason,
    int leftRangeRepCoverage = 0,
    int rightRangeRepCoverage = 0,
    double? leftRangeRepSideConfidence,
    double? rightRangeRepSideConfidence,
    int rangeRepInvalidFrameStreak = 0,
    int rangeRepInvalidDurationMs = 0,
    bool rangeRepResyncTriggered = false,
    String? rangeRepResyncReason,
    String rangeRepVisibilityStatus = 'stable',
    double? currentBodyLineAngle,
    double? currentArmSupportAngle,
    double? currentLegExtensionAngle,
    double? currentTorsoAngle,
    double? currentDepthMetric,
    double? currentAlignmentMetric,
    double? currentStabilityMetric,
    double? currentLockoutMetric,
    double? currentBottomControlMetric,
    bool hasBodyLineAngle = false,
    bool hasArmSupportAngle = false,
    bool hasLegExtensionAngle = false,
  }) {
    final movementSelectedSide =
        selectedRangeRepSide ==
            _rangeRepSideLabel(_movementSideSelector.confirmedSide)
        ? selectedRangeRepSide
        : null;
    return _calibrationProjector.project(
      RangeRepCalibrationProjectionRequest(
        diagnostics: diagnostics,
        repTelemetry: _lastRepTelemetry,
        currentFormMetric: currentFormMetric,
        thresholdValue: thresholdValue,
        currentPrimaryMetric: currentPrimaryMetric,
        rangeRepSideHysteresisStatus: _sideStabilizer.hysteresisStatus,
        rangeRepSideConsistencyStatus: _sideStabilizer.consistencyStatus,
        calibrationThresholdDecisionCount: _thresholdBookkeeper.decisionCount,
        calibrationThresholdAppliedCount: _thresholdBookkeeper.appliedCount,
        calibrationThresholdNoBaselineCount:
            _thresholdBookkeeper.noBaselineCount,
        calibrationThresholdInsufficientSamplesCount:
            _thresholdBookkeeper.insufficientSamplesCount,
        calibrationThresholdMissingFormBaselineCount:
            _thresholdBookkeeper.missingFormBaselineCount,
        calibrationThresholdSideMismatchCount:
            _thresholdBookkeeper.sideMismatchCount,
        calibrationThresholdOffsetTooSmallCount:
            _thresholdBookkeeper.offsetTooSmallCount,
        baseFormThreshold: baseFormThreshold,
        effectiveFormThreshold: effectiveFormThreshold,
        calibrationThresholdOffsetCandidate:
            calibrationThresholdOffsetCandidate,
        calibrationThresholdOffsetApplied: calibrationThresholdOffsetApplied,
        calibrationThresholdOffsetFallbackReason:
            calibrationThresholdOffsetFallbackReason,
        calibrationThresholdOffsetSampleCount:
            calibrationThresholdOffsetSampleCount,
        calibrationThresholdOffsetBaselineSideLabel:
            calibrationThresholdOffsetBaselineSideLabel,
        isRangeRepFrameValid: isRangeRepFrameValid,
        hasPrimaryAngle: hasPrimaryAngle,
        hasFormMetric: hasFormMetric,
        rangeRepInvalidReason: rangeRepInvalidReason,
        selectedRangeRepSide: selectedRangeRepSide,
        rangeRepSideSelectionReason: rangeRepSideSelectionReason,
        rangeRepAutomaticSideSelectionEnabled:
            _rangeRepContract.automaticSideSelectionEnabled,
        rangeRepMovementSelectedSide: movementSelectedSide,
        leftRangeRepCoverage: leftRangeRepCoverage,
        rightRangeRepCoverage: rightRangeRepCoverage,
        leftRangeRepSideConfidence: leftRangeRepSideConfidence,
        rightRangeRepSideConfidence: rightRangeRepSideConfidence,
        rangeRepInvalidFrameStreak: rangeRepInvalidFrameStreak,
        rangeRepInvalidDurationMs: rangeRepInvalidDurationMs,
        rangeRepResyncTriggered: rangeRepResyncTriggered,
        rangeRepResyncReason: rangeRepResyncReason,
        rangeRepVisibilityStatus: rangeRepVisibilityStatus,
        currentBodyLineAngle: currentBodyLineAngle,
        currentArmSupportAngle: currentArmSupportAngle,
        currentLegExtensionAngle: currentLegExtensionAngle,
        currentTorsoAngle: currentTorsoAngle,
        currentDepthMetric: currentDepthMetric,
        currentAlignmentMetric: currentAlignmentMetric,
        currentStabilityMetric: currentStabilityMetric,
        currentLockoutMetric: currentLockoutMetric,
        currentBottomControlMetric: currentBottomControlMetric,
        hasBodyLineAngle: hasBodyLineAngle,
        hasArmSupportAngle: hasArmSupportAngle,
        hasLegExtensionAngle: hasLegExtensionAngle,
      ),
    );
  }

  void _refreshRepTelemetry() {
    _lastRepTelemetry = _calibrationMetricsBuilder.buildRangeRepRepTelemetry(
      lastBreakdown: _lastRepScoreBreakdown,
      lastValidationResult: _outcomeTracker.lastRangeRepValidationResult,
      lastSummaryCandidate: _outcomeTracker.lastRangeRepRepSummaryCandidate,
      lastTempoAssessment: _lastRepTempoAssessment,
      lastRangeRepValidatedRepIndex:
          _outcomeTracker.lastRangeRepValidatedRepIndex,
      rangeRepValidatedCount: _outcomeTracker.rangeRepValidatedCount,
      rangeRepLowConfidenceCount: _outcomeTracker.rangeRepLowConfidenceCount,
      rangeRepInvalidCount: _outcomeTracker.rangeRepInvalidCount,
    );
  }

  RangeRepDiagnosticsSnapshot _rangeRepDiagnosticsSnapshot() {
    final detectionDiagnostics = _engine.detectionDiagnosticsSnapshot;
    final techniqueHistory = _techniqueHistorySnapshotFor(detectionDiagnostics);
    return _rangeRepDiagnosticsSnapshotFrom(
      detectionDiagnostics: detectionDiagnostics,
      techniqueHistory: techniqueHistory,
    );
  }

  RangeRepDiagnosticsSnapshot _rangeRepDiagnosticsSnapshotFrom({
    required RangeRepDiagnosticsSnapshot detectionDiagnostics,
    required LegacyRangeRepTechniqueHistorySnapshot techniqueHistory,
  }) {
    final phaseQuality = techniqueHistory.phaseQualityTelemetry;
    return RangeRepDiagnosticsSnapshot(
      currentRepWorstBackAngle: techniqueHistory.currentRepWorstFormMetric,
      currentRepHadFormViolation: techniqueHistory.currentRepHadFormViolation,
      phaseGateStatus: detectionDiagnostics.phaseGateStatus,
      hasActiveRepPhase: detectionDiagnostics.hasActiveRepPhase,
      hasPendingTransition: detectionDiagnostics.hasPendingTransition,
      pendingTransitionLabel: detectionDiagnostics.pendingTransitionLabel,
      lastConfirmedTransitionLabel:
          detectionDiagnostics.lastConfirmedTransitionLabel,
      lastRepScoreBreakdown: _lastRepScoreBreakdown,
      lastCompletedRepCoreData: _lastCompletedRepCoreData,
      descendingPhaseQuality: phaseQuality.descendingPhaseQuality,
      peakPhaseQuality: phaseQuality.peakPhaseQuality,
      ascendingPhaseQuality: phaseQuality.ascendingPhaseQuality,
      descendingPhaseAssessment: techniqueHistory.descendingPhaseAssessment,
      peakPhaseAssessment: techniqueHistory.peakPhaseAssessment,
      ascendingPhaseAssessment: techniqueHistory.ascendingPhaseAssessment,
      phaseFeedbackCandidate: techniqueHistory.phaseFeedbackCandidate?.code,
    );
  }

  LegacyRangeRepTechniqueHistorySnapshot _techniqueHistorySnapshotFor(
    RangeRepDiagnosticsSnapshot detectionDiagnostics,
  ) {
    return _techniqueHistoryTracker.snapshot(
      now: _diagnosticsNow,
      preferLastCompletedTelemetry:
          !detectionDiagnostics.hasActiveRepPhase &&
          !detectionDiagnostics.hasPendingTransition,
    );
  }

  void _trackRepContext({
    required RangeRepDiagnosticsSnapshot diagnostics,
    required RangeRepSide? selectedSide,
    bool markCoverageDrop = false,
    MeasurementConfidenceBreakdown? frameMeasurementConfidence,
  }) {
    _outcomeTracker.trackRepContext(
      engineKind: EngineKind.rangeRep,
      diagnostics: diagnostics,
      selectedSideLabel: _rangeRepSideLabel(selectedSide),
      markCoverageDrop: markCoverageDrop,
      frameMeasurementConfidence: frameMeasurementConfidence,
    );
  }

  void _resetAutomaticSideSelectionIfCycleEnded(
    RangeRepEngineFrameResult engineResult,
  ) {
    if (!_rangeRepContract.resetAutomaticSideSelectionAfterCycle) {
      return;
    }

    final didEndCycle =
        engineResult.didCompleteRep ||
        engineResult.repAborted ||
        engineResult.confirmedTransitions.any(
          (transition) =>
              transition.type == RangeRepConfirmedTransitionType.abortToNeutral,
        );
    if (didEndCycle) {
      _movementSideSelector.reset();
    }
  }

  void _clearActiveRepContext({String? reason}) {
    _engine.clearActiveRepContext(reason: reason);
    _techniqueHistoryTracker.clearActiveRepContext();
    _setCurrentFeedback(
      RangeRepFeedbackCode.awaitNeutral,
      phaseKey: 'awaitingNeutral',
    );
  }

  String _phaseForLifecycleReacquisition({
    required RangeRepFeedbackDirective feedbackDirective,
    required String fallback,
  }) {
    if (!_isLifecycleNeutralReacquisitionPending) {
      return fallback;
    }

    return switch (feedbackDirective.feedbackCode) {
      RangeRepFeedbackCode.awaitNeutral => rangeRepAwaitNeutralPhaseLabel,
      RangeRepFeedbackCode.waitForBody ||
      RangeRepFeedbackCode.bodyNotVisible => 'WAITING',
      _ => fallback,
    };
  }

  void _setCurrentFeedback(
    RangeRepFeedbackCode code, {
    required String phaseKey,
  }) {
    _feedbackLifecycle.reset();
    _feedbackPhaseKey = phaseKey;
    _isFormBad = false;
    _currentFeedbackCode = code;
  }

  bool _beginBriefVisibilityGap(
    RangeRepDiagnosticsSnapshot diagnostics, {
    required DateTime observedAt,
  }) {
    final shouldTrackBriefGap =
        _hasAcceptedPoseForAnalysis ||
        diagnostics.hasRepContext ||
        _selectedRangeRepSide != null;
    if (shouldTrackBriefGap) {
      _briefGapFrozenRangeRepSide = _selectedRangeRepSide;
      _engine.beginBriefVisibilityGap(observedAt: observedAt);
    } else if (diagnostics.isAwaitingNeutralConfirmation) {
      _clearActiveRepContext(reason: 'invalid frame while awaiting neutral');
    }

    return shouldTrackBriefGap;
  }

  VisibilityGapResumeResult _resumeBriefVisibilityGap(
    double primaryMetric, {
    required DateTime observedAt,
  }) {
    return _engine.resumeAfterBriefVisibilityGap(
      primaryMetric: primaryMetric,
      observedAt: observedAt,
    );
  }

  void _resetSideSensitiveFilters() {
    _primaryMetricFilter.reset();
    _formMetricFilter.reset();
    _bodyLineFilter.reset();
    _armSupportFilter.reset();
    _legFilter.reset();
  }

  void _resetVisibilityResyncState({
    String? reason,
    bool resetVisibilityPolicy = false,
  }) {
    _clearActiveRepContext(reason: reason);
    _resetSideSensitiveFilters();
    _selectedRangeRepSide = null;
    _briefGapFrozenRangeRepSide = null;
    _movementSideSelector.reset();
    _sideStabilizer.reset();
    _outcomeTracker.resetRepContext();
    if (resetVisibilityPolicy) {
      _visibilityPolicy.reset();
    }
  }

  RangeRepCoordinatorStateSnapshot _buildBlockedStateSnapshot({
    required ExerciseMetrics metrics,
    required RangeRepFrameAssessment frameAssessment,
    required bool freezeSmoothedPreview,
    required RangeRepFeedbackDirective feedbackDirective,
    required String currentPhase,
    required RangeRepVisibilityAssessment visibilityAssessment,
    required String? selectedSideLabel,
  }) {
    final preview = _blockedStateBuilder.buildPreview(
      metrics: metrics,
      assessment: frameAssessment,
      freezeSmoothedPreview: freezeSmoothedPreview,
      primaryMetricFilter: _primaryMetricFilter,
      formMetricFilter: _formMetricFilter,
      fallbackAngle: _lastPublishedCurrentAngle,
      fallbackBackAngle: _lastPublishedCalibrationMetrics.currentBackAngle,
      selectedRangeRepSide: selectedSideLabel,
    );
    final formThresholdResolution = _thresholdBookkeeper.resolve(
      baseThreshold: _config.formThreshold,
      sessionCalibrationBaseline:
          _calibrationProjector.sessionCalibrationBaseline,
      selectedRangeRepSide: preview.selectedRangeRepSide,
    );
    final calibrationMetrics = _projectCalibrationMetrics(
      diagnostics: _rangeRepDiagnosticsSnapshot(),
      currentFormMetric: preview.previewBackAngle,
      currentPrimaryMetric: preview.previewAngle,
      thresholdValue: formThresholdResolution.effectiveThreshold,
      currentTorsoAngle: preview.formSignals?.torsoAngle,
      currentDepthMetric: preview.formSignals?.depthMetric,
      currentAlignmentMetric: preview.formSignals?.alignmentMetric,
      currentStabilityMetric: preview.formSignals?.stabilityMetric,
      currentLockoutMetric: preview.formSignals?.lockoutMetric,
      currentBottomControlMetric: preview.formSignals?.bottomControlMetric,
      baseFormThreshold: formThresholdResolution.baseThreshold,
      effectiveFormThreshold: formThresholdResolution.effectiveThreshold,
      calibrationThresholdOffsetCandidate:
          formThresholdResolution.offsetCandidate,
      calibrationThresholdOffsetApplied: formThresholdResolution.isApplied,
      calibrationThresholdOffsetFallbackReason:
          formThresholdResolution.decisionReason,
      calibrationThresholdOffsetSampleCount:
          formThresholdResolution.sampleCount,
      calibrationThresholdOffsetBaselineSideLabel:
          formThresholdResolution.baselineSideLabel,
      isRangeRepFrameValid: false,
      hasPrimaryAngle: frameAssessment.hasPrimaryAngle,
      hasFormMetric: frameAssessment.hasFormMetric,
      rangeRepInvalidReason: frameAssessment.invalidReason,
      selectedRangeRepSide: preview.selectedRangeRepSide,
      rangeRepSideSelectionReason: frameAssessment.selection.debugLabel,
      leftRangeRepCoverage: frameAssessment.selection.leftMetrics.coverageScore,
      rightRangeRepCoverage:
          frameAssessment.selection.rightMetrics.coverageScore,
      leftRangeRepSideConfidence:
          frameAssessment.selection.leftMetrics.sideConfidence,
      rightRangeRepSideConfidence:
          frameAssessment.selection.rightMetrics.sideConfidence,
      rangeRepInvalidFrameStreak: visibilityAssessment.invalidFrameStreak,
      rangeRepInvalidDurationMs:
          visibilityAssessment.invalidDuration.inMilliseconds,
      rangeRepResyncTriggered: visibilityAssessment.hasResyncedCurrentRun,
      rangeRepResyncReason: visibilityAssessment.resyncReason,
      rangeRepVisibilityStatus: visibilityAssessment.statusLabel,
    );

    return _rememberStateSnapshot(
      landmarks: metrics.landmarks,
      repCount: _outcomeTracker.rangeRepAcceptedCount,
      isFormBad: false,
      currentAngle: preview.previewAngle,
      lastRepScore: _lastRepScore,
      lastRepRom: _lastAcceptedRepRom,
      currentPhase: currentPhase,
      calibrationMetrics: calibrationMetrics,
      feedbackDirective: feedbackDirective,
    );
  }

  RangeRepCoordinatorStateSnapshot _rememberStateSnapshot({
    required List<PoseLandmark>? landmarks,
    required int repCount,
    required bool isFormBad,
    required double currentAngle,
    required double lastRepScore,
    required double lastRepRom,
    required String currentPhase,
    required WorkoutCalibrationMetrics calibrationMetrics,
    required RangeRepFeedbackDirective feedbackDirective,
  }) {
    final snapshot = RangeRepCoordinatorStateSnapshot(
      landmarks: landmarks,
      repCount: repCount,
      isFormBad: isFormBad,
      currentAngle: currentAngle,
      lastRepScore: lastRepScore,
      lastRepRom: lastRepRom,
      currentPhase: currentPhase,
      calibrationMetrics: calibrationMetrics,
      feedbackDirective: feedbackDirective,
    );
    _lastPublishedLandmarks = landmarks;
    _lastPublishedCurrentAngle = currentAngle;
    _lastPublishedCalibrationMetrics = calibrationMetrics;
    return snapshot;
  }

  RangeRepFeedbackDirective _coordinatorFeedbackDirective() {
    return RangeRepFeedbackDirective.code(_currentFeedbackCode);
  }

  double _currentAngleForState(AnalysisFrame frame) {
    return frame.bodyLineAngle ?? frame.primaryMetric;
  }

  String? _currentSelectedSideLabelForDiagnostics() {
    return _rangeRepSideLabel(
      _briefGapFrozenRangeRepSide ?? _selectedRangeRepSide,
    );
  }

  String? _rangeRepSideLabel(RangeRepSide? side) {
    switch (side) {
      case RangeRepSide.left:
        return 'left';
      case RangeRepSide.right:
        return 'right';
      case null:
        return null;
    }
  }

  bool _shouldLockRangeRepSideSelection({
    required RangeRepSide? selectedSide,
    required RangeRepDiagnosticsSnapshot diagnostics,
  }) {
    if (selectedSide == null) {
      return false;
    }

    return diagnostics.hasRepContext;
  }
}
