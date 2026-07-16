import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/moving_average.dart';
import '../domain/models/analysis_frame.dart';
import '../domain/models/calibration_snapshot.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/range_rep_feedback_code.dart';
import '../domain/range_rep_analysis_engine.dart';
import '../domain/models/session_calibration_baseline.dart';
import '../domain/range_rep_diagnostics.dart';
import '../domain/range_rep_validation_policy.dart';
import 'analysis_frame_builder.dart';
import 'calibration_snapshot_builder.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';
import 'range_rep_blocked_state_builder.dart';
import 'range_rep_frame_policy.dart';
import 'range_rep_rep_outcome_tracker.dart';
import 'range_rep_side_policy.dart';
import 'range_rep_side_stabilizer.dart';
import 'range_rep_threshold_bookkeeper.dart';
import 'range_rep_threshold_resolver.dart';
import 'range_rep_visibility_policy.dart';
import 'session_calibration_baseline_accumulator.dart';
import 'workout_calibration_metrics_builder.dart';
import 'workout_state.dart';

enum RangeRepFeedbackDirectiveKind { engine, code }

class RangeRepFeedbackDirective {
  const RangeRepFeedbackDirective._({required this.kind, this.feedbackCode});

  const RangeRepFeedbackDirective.engine({RangeRepFeedbackCode? feedbackCode})
    : this._(
        kind: RangeRepFeedbackDirectiveKind.engine,
        feedbackCode: feedbackCode,
      );

  const RangeRepFeedbackDirective.code(RangeRepFeedbackCode feedbackCode)
    : this._(
        kind: RangeRepFeedbackDirectiveKind.code,
        feedbackCode: feedbackCode,
      );

  final RangeRepFeedbackDirectiveKind kind;
  final RangeRepFeedbackCode? feedbackCode;

  String resolve({
    required String Function(RangeRepFeedbackCode code) mapFeedbackCode,
    required String fallbackMessage,
  }) {
    switch (kind) {
      case RangeRepFeedbackDirectiveKind.engine:
        final resolvedCode = feedbackCode;
        if (resolvedCode != null) {
          return mapFeedbackCode(resolvedCode);
        }
        return fallbackMessage;
      case RangeRepFeedbackDirectiveKind.code:
        final resolvedCode = feedbackCode;
        if (resolvedCode == null) {
          throw StateError(
            'RangeRepFeedbackDirective.code requires feedbackCode.',
          );
        }
        return mapFeedbackCode(resolvedCode);
    }
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
    required this.feedbackFallbackMessage,
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
  final String feedbackFallbackMessage;
}

class RangeRepCoordinatorDiagnosticsUpdate {
  const RangeRepCoordinatorDiagnosticsUpdate({
    required this.visibilityStatus,
    required this.selectedSideLabel,
    required this.hasActiveRepContext,
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
    this.shouldResetPoseAcceptance = false,
    this.shouldRecordInvalidPoseAcceptance = false,
  });

  final RangeRepCoordinatorStateSnapshot stateSnapshot;
  final RangeRepCoordinatorDiagnosticsUpdate diagnosticsUpdate;
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
  }) : _engine = engine,
       _config = config,
       _rangeRepContract = rangeRepContract,
       _analysisFrameBuilder = analysisFrameBuilder,
       _blockedStateBuilder = blockedStateBuilder,
       _calibrationSnapshotBuilder = calibrationSnapshotBuilder,
       _calibrationMetricsBuilder = calibrationMetricsBuilder,
       _framePolicy = framePolicy,
       _sidePolicy = sidePolicy,
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
             validationPolicy: const RangeRepValidationPolicy(),
           ),
       _sessionCalibrationBaselineAccumulator =
           sessionCalibrationBaselineAccumulator ??
           SessionCalibrationBaselineAccumulator();

  final RangeRepAnalysisEngine _engine;
  final ExerciseConfig _config;
  final RangeRepContract _rangeRepContract;
  final WorkoutAnalysisFrameBuilder _analysisFrameBuilder;
  final RangeRepBlockedStateBuilder _blockedStateBuilder;
  final CalibrationSnapshotBuilder _calibrationSnapshotBuilder;
  final WorkoutCalibrationMetricsBuilder _calibrationMetricsBuilder;
  final RangeRepFramePolicy _framePolicy;
  final RangeRepSidePolicy _sidePolicy;
  final RangeRepSideStabilizer _sideStabilizer;
  final RangeRepVisibilityPolicy _visibilityPolicy;
  final RangeRepThresholdBookkeeper _thresholdBookkeeper;
  final RangeRepRepOutcomeTracker _outcomeTracker;
  final SessionCalibrationBaselineAccumulator
  _sessionCalibrationBaselineAccumulator;
  final MovingAverageFilter _primaryMetricFilter = MovingAverageFilter(
    windowSize: 5,
  );
  final MovingAverageFilter _formMetricFilter = MovingAverageFilter(
    windowSize: 5,
  );
  final MovingAverageFilter _bodyLineFilter = MovingAverageFilter(
    windowSize: 5,
  );
  final MovingAverageFilter _armSupportFilter = MovingAverageFilter(
    windowSize: 5,
  );
  final MovingAverageFilter _legFilter = MovingAverageFilter(windowSize: 5);

  RangeRepSide? _selectedRangeRepSide;
  RangeRepSide? _briefGapFrozenRangeRepSide;
  bool _hasAcceptedPoseForAnalysis = false;
  CalibrationSnapshot? _lastCalibrationSnapshot;
  SessionCalibrationBaseline? _sessionCalibrationBaseline;
  List<PoseLandmark>? _lastPublishedLandmarks;
  double _lastPublishedCurrentAngle = 0.0;
  WorkoutCalibrationMetrics _lastPublishedCalibrationMetrics =
      const WorkoutCalibrationMetrics.rangeRep();

  @override
  RangeRepCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
  }) {
    final preUpdateDiagnostics = _rangeRepDiagnosticsSnapshot();
    final effectiveMetrics = _effectiveMetricsForAnalysis(
      metrics: metrics,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
      preferredRangeRepSide: preferredRangeRepSide,
    );
    final visibilityRunActive = _visibilityPolicy.hasActiveInvalidRun;
    final sideSelection = _selectRangeRepSideForFrame(
      metrics: effectiveMetrics,
      diagnostics: preUpdateDiagnostics,
      visibilityRunActive: visibilityRunActive,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
    );
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
          return RangeRepCoordinatorFrameResult(
            stateSnapshot: _buildBlockedStateSnapshot(
              metrics: effectiveMetrics,
              frameAssessment: frameAssessment,
              freezeSmoothedPreview: true,
              feedbackDirective: _engineFeedbackDirective(),
              currentPhase: _engine.phaseLabel,
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
      final formThresholdResolution = _thresholdBookkeeper.resolve(
        baseThreshold: _config.formThreshold,
        sessionCalibrationBaseline: _sessionCalibrationBaseline,
        selectedRangeRepSide: _rangeRepSideLabel(
          frameAssessment.selection.selectedSide,
        ),
      );
      final engineFrame = _applyFormThresholdResolution(
        analysisFrame,
        formThresholdResolution,
      );
      var recordBriefOcclusionRecovery = false;
      var recordBriefOcclusionAbort = false;
      var recordResync = false;
      var shouldResetPoseAcceptance = false;

      if (didBecomeStableTracking) {
        final gapResumeResult = _resumeBriefVisibilityGap(engineFrame);
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
              repCount: _engine.repCount,
              isFormBad: _engine.isFormBad,
              currentAngle: _lastPublishedCurrentAngle,
              lastRepScore: _engine.lastRepScore,
              lastRepRom: _engine.lastRepRom,
              currentPhase: _engine.phaseLabel,
              calibrationMetrics: _lastPublishedCalibrationMetrics,
              feedbackDirective: _engineFeedbackDirective(),
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
      frameAssessment: frameAssessment,
      preUpdateDiagnostics: preUpdateDiagnostics,
      visibilityAssessment: visibilityAssessment,
      didBecomeStableTracking: didBecomeStableTracking,
      recordBriefOcclusionRecovery: false,
    );
  }

  @override
  RangeRepCoordinatorStateSnapshot handleLifecycleInterruption({
    String? reason,
  }) {
    _resetVisibilityResyncState(
      reason: reason ?? 'lifecycle interruption',
      resetVisibilityPolicy: true,
    );
    return _rememberStateSnapshot(
      landmarks: _lastPublishedLandmarks,
      repCount: _engine.repCount,
      isFormBad: _engine.isFormBad,
      currentAngle: _lastPublishedCurrentAngle,
      lastRepScore: _engine.lastRepScore,
      lastRepRom: _engine.lastRepRom,
      currentPhase: _engine.phaseLabel,
      calibrationMetrics: _lastPublishedCalibrationMetrics,
      feedbackDirective: _engineFeedbackDirective(),
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
      recordBriefOcclusion = _beginBriefVisibilityGap(preUpdateDiagnostics);
    }
    _trackRepContext(
      diagnostics: preUpdateDiagnostics,
      selectedSide: _briefGapFrozenRangeRepSide,
      markCoverageDrop: true,
    );

    if (visibilityAssessment.shouldResync) {
      _resetVisibilityResyncState(reason: visibilityAssessment.resyncReason);
      return RangeRepCoordinatorFrameResult(
        stateSnapshot: _buildBlockedStateSnapshot(
          metrics: metrics,
          frameAssessment: frameAssessment,
          freezeSmoothedPreview: true,
          feedbackDirective: _engineFeedbackDirective(),
          currentPhase: _engine.phaseLabel,
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

    return RangeRepCoordinatorFrameResult(
      stateSnapshot: _buildBlockedStateSnapshot(
        metrics: metrics,
        frameAssessment: frameAssessment,
        freezeSmoothedPreview: true,
        feedbackDirective: const RangeRepFeedbackDirective.code(
          RangeRepFeedbackCode.bodyNotVisible,
        ),
        currentPhase: 'WAITING',
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
    );
    final analysisFrame = _buildAnalysisFrame(
      metrics: metrics,
      selectedMetrics: frameAssessment.selectedMetrics,
    );
    final formThresholdResolution = _thresholdBookkeeper.resolve(
      baseThreshold: _config.formThreshold,
      sessionCalibrationBaseline: _sessionCalibrationBaseline,
      selectedRangeRepSide: selectedSideLabel,
    );
    final engineFrame = _applyFormThresholdResolution(
      analysisFrame,
      formThresholdResolution,
    );
    _engine.update(engineFrame);
    final completedRepCoreData = _consumeCompletedRepCoreData();
    final postUpdateDiagnostics = _rangeRepDiagnosticsSnapshot();
    final didCompleteRep = completedRepCoreData != null;
    _outcomeTracker.activateCompletedRepOutcomeIfAny(
      engineKind: EngineKind.rangeRep,
      analysisKindLabel: EngineKind.rangeRep.name,
      completedRepCoreData: completedRepCoreData,
    );
    _outcomeTracker.resetRepContextIfCycleEnded(
      previousDiagnostics: preUpdateDiagnostics,
      currentDiagnostics: postUpdateDiagnostics,
      didCompleteRep: didCompleteRep,
    );

    final calibrationMetrics = _buildCalibrationMetrics(
      currentFormMetric: analysisFrame.formMetric,
      currentPrimaryMetric: analysisFrame.primaryMetric,
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
      repCount: _engine.repCount,
      isFormBad: _engine.isFormBad,
      currentAngle: _currentAngleForState(analysisFrame),
      lastRepScore: _engine.lastRepScore,
      lastRepRom: _engine.lastRepRom,
      currentPhase: _engine.phaseLabel,
      calibrationMetrics: calibrationMetrics,
      feedbackDirective: _engineFeedbackDirective(),
    );
    _hasAcceptedPoseForAnalysis = true;

    return RangeRepCoordinatorFrameResult(
      stateSnapshot: stateSnapshot,
      diagnosticsUpdate: RangeRepCoordinatorDiagnosticsUpdate(
        visibilityStatus: visibilityAssessment.statusLabel,
        selectedSideLabel: _currentSelectedSideLabelForDiagnostics(),
        hasActiveRepContext: preUpdateDiagnostics.hasRepContext,
        recordAcceptedPoseFrame: true,
        recordPoseReacquisition: didReacquire,
        recordBriefOcclusionRecovery: recordBriefOcclusionRecovery,
      ),
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

    return _sideSelection(metrics, diagnostics: diagnostics);
  }

  RangeRepSideSelection _sideSelection(
    ExerciseMetrics metrics, {
    RangeRepDiagnosticsSnapshot? diagnostics,
  }) {
    final selection = _sidePolicy.select(
      metrics: metrics,
      previousSide: _selectedRangeRepSide,
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
      bodyLineFilter: _bodyLineFilter,
      armSupportFilter: _armSupportFilter,
      legFilter: _legFilter,
    );
  }

  AnalysisFrame _applyFormThresholdResolution(
    AnalysisFrame frame,
    RangeRepThresholdResolution resolution,
  ) {
    final offsetCandidate = resolution.offsetCandidate;
    if (!resolution.isApplied || offsetCandidate == null) {
      return frame;
    }

    return AnalysisFrame(
      primaryMetric: frame.primaryMetric,
      formMetric: frame.formMetric - offsetCandidate,
      bodyLineAngle: frame.bodyLineAngle,
      armSupportAngle: frame.armSupportAngle,
      legExtensionAngle: frame.legExtensionAngle,
    );
  }

  WorkoutCalibrationMetrics _buildCalibrationMetrics({
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
    final diagnostics = _rangeRepDiagnosticsSnapshot();
    final lastBreakdown = diagnostics.lastRepScoreBreakdown;
    final lastValidationResult = _outcomeTracker.lastRangeRepValidationResult;
    final lastSummaryCandidate =
        _outcomeTracker.lastRangeRepRepSummaryCandidate;
    final calibrationSnapshotCandidate = _calibrationSnapshotBuilder
        .buildCandidate(
          engineKind: EngineKind.rangeRep,
          diagnostics: diagnostics,
          currentPrimaryMetric: currentPrimaryMetric,
          currentFormMetric: currentFormMetric,
          hasPrimaryAngle: hasPrimaryAngle,
          hasFormMetric: hasFormMetric,
          isRangeRepFrameValid: isRangeRepFrameValid,
          selectedRangeRepSide: selectedRangeRepSide,
          currentTorsoAngle: currentTorsoAngle,
          currentDepthMetric: currentDepthMetric,
          currentAlignmentMetric: currentAlignmentMetric,
          currentStabilityMetric: currentStabilityMetric,
          currentLockoutMetric: currentLockoutMetric,
          currentBottomControlMetric: currentBottomControlMetric,
        );

    if (calibrationSnapshotCandidate != null) {
      _lastCalibrationSnapshot = calibrationSnapshotCandidate;
      if (_sessionCalibrationBaselineAccumulator.addIfAccepted(
        calibrationSnapshotCandidate,
      )) {
        _sessionCalibrationBaseline =
            _sessionCalibrationBaselineAccumulator.baseline;
      }
    }

    return _calibrationMetricsBuilder.buildRangeRep(
      currentFormMetric: currentFormMetric,
      thresholdValue: thresholdValue,
      diagnostics: diagnostics,
      lastBreakdown: lastBreakdown,
      lastValidationResult: lastValidationResult,
      lastSummaryCandidate: lastSummaryCandidate,
      rangeRepSideHysteresisStatus: _sideStabilizer.hysteresisStatus,
      rangeRepSideConsistencyStatus: _sideStabilizer.consistencyStatus,
      calibrationSnapshot: _lastCalibrationSnapshot,
      calibrationThresholdDecisionCount: _thresholdBookkeeper.decisionCount,
      calibrationThresholdAppliedCount: _thresholdBookkeeper.appliedCount,
      calibrationThresholdNoBaselineCount: _thresholdBookkeeper.noBaselineCount,
      calibrationThresholdInsufficientSamplesCount:
          _thresholdBookkeeper.insufficientSamplesCount,
      calibrationThresholdMissingFormBaselineCount:
          _thresholdBookkeeper.missingFormBaselineCount,
      calibrationThresholdSideMismatchCount:
          _thresholdBookkeeper.sideMismatchCount,
      calibrationThresholdOffsetTooSmallCount:
          _thresholdBookkeeper.offsetTooSmallCount,
      sessionCalibrationBaselineCandidate: _sessionCalibrationBaseline,
      lastRangeRepValidatedRepIndex:
          _outcomeTracker.lastRangeRepValidatedRepIndex,
      rangeRepValidatedCount: _outcomeTracker.rangeRepValidatedCount,
      rangeRepLowConfidenceCount: _outcomeTracker.rangeRepLowConfidenceCount,
      rangeRepInvalidCount: _outcomeTracker.rangeRepInvalidCount,
      baseFormThreshold: baseFormThreshold,
      effectiveFormThreshold: effectiveFormThreshold,
      calibrationThresholdOffsetCandidate: calibrationThresholdOffsetCandidate,
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
    );
  }

  RangeRepDiagnosticsSnapshot _rangeRepDiagnosticsSnapshot() {
    return _engine.diagnosticsSnapshot;
  }

  void _trackRepContext({
    required RangeRepDiagnosticsSnapshot diagnostics,
    required RangeRepSide? selectedSide,
    bool markCoverageDrop = false,
  }) {
    _outcomeTracker.trackRepContext(
      engineKind: EngineKind.rangeRep,
      diagnostics: diagnostics,
      selectedSideLabel: _rangeRepSideLabel(selectedSide),
      markCoverageDrop: markCoverageDrop,
    );
  }

  RangeRepCompletedRepCoreData? _consumeCompletedRepCoreData() {
    return _engine.consumeCompletedRepCoreData();
  }

  void _clearActiveRepContext({String? reason}) {
    _engine.clearActiveRepContext(reason: reason);
  }

  bool _beginBriefVisibilityGap(RangeRepDiagnosticsSnapshot diagnostics) {
    final shouldTrackBriefGap =
        _hasAcceptedPoseForAnalysis ||
        diagnostics.hasRepContext ||
        _selectedRangeRepSide != null;
    if (shouldTrackBriefGap) {
      _briefGapFrozenRangeRepSide = _selectedRangeRepSide;
      _engine.beginBriefVisibilityGap();
    } else if (diagnostics.isAwaitingNeutralConfirmation) {
      _clearActiveRepContext(reason: 'invalid frame while awaiting neutral');
    }

    return shouldTrackBriefGap;
  }

  VisibilityGapResumeResult _resumeBriefVisibilityGap(AnalysisFrame frame) {
    return _engine.resumeAfterBriefVisibilityGap(frame);
  }

  void _resetVisibilityResyncState({
    String? reason,
    bool resetVisibilityPolicy = false,
  }) {
    _clearActiveRepContext(reason: reason);
    _primaryMetricFilter.reset();
    _formMetricFilter.reset();
    _selectedRangeRepSide = null;
    _briefGapFrozenRangeRepSide = null;
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
      sessionCalibrationBaseline: _sessionCalibrationBaseline,
      selectedRangeRepSide: preview.selectedRangeRepSide,
    );
    final calibrationMetrics = _buildCalibrationMetrics(
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
      repCount: _engine.repCount,
      isFormBad: false,
      currentAngle: preview.previewAngle,
      lastRepScore: _engine.lastRepScore,
      lastRepRom: _engine.lastRepRom,
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
      feedbackFallbackMessage: _engine.feedback,
    );
    _lastPublishedLandmarks = landmarks;
    _lastPublishedCurrentAngle = currentAngle;
    _lastPublishedCalibrationMetrics = calibrationMetrics;
    return snapshot;
  }

  RangeRepFeedbackDirective _engineFeedbackDirective() {
    return RangeRepFeedbackDirective.engine(
      feedbackCode: _currentFeedbackCode(),
    );
  }

  RangeRepFeedbackCode? _currentFeedbackCode() {
    return _engine.feedbackCode;
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
