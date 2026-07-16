import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/moving_average.dart';
import '../domain/hold_analysis_engine.dart';
import '../domain/hold_diagnostics.dart';
import '../domain/models/analysis_frame.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/hold_feedback_code.dart';
import '../domain/models/hold_phase.dart';
import '../domain/models/hold_side.dart';
import 'analysis_frame_builder.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';
import 'hold_side_policy.dart';
import 'hold_side_stabilizer.dart';
import 'pose_quality_policy.dart';
import 'workout_calibration_metrics_builder.dart';
import 'workout_state.dart';

class HoldCoordinatorStateSnapshot {
  const HoldCoordinatorStateSnapshot({
    required this.landmarks,
    required this.isFormBad,
    required this.currentAngle,
    required this.currentHoldSeconds,
    required this.bestHoldSeconds,
    required this.selectedHoldSide,
    required this.isHolding,
    required this.isHoldVisibilitySuspended,
    required this.hadHoldFormBreak,
    required this.holdFeedbackCode,
    required this.holdEnginePhase,
    required this.currentPhase,
    required this.calibrationMetrics,
    required this.feedbackFallbackMessage,
  });

  final List<PoseLandmark>? landmarks;
  final bool isFormBad;
  final double currentAngle;
  final double currentHoldSeconds;
  final double bestHoldSeconds;
  final HoldSide? selectedHoldSide;
  final bool isHolding;
  final bool isHoldVisibilitySuspended;
  final bool hadHoldFormBreak;
  final HoldFeedbackCode? holdFeedbackCode;
  final HoldPhase? holdEnginePhase;
  final String currentPhase;
  final WorkoutCalibrationMetrics calibrationMetrics;
  final String feedbackFallbackMessage;
}

class HoldCoordinatorDiagnosticsUpdate {
  const HoldCoordinatorDiagnosticsUpdate({
    required this.visibilityStatus,
    this.recordAcceptedPoseFrame = false,
    this.recordPoseReacquisition = false,
  });

  final String visibilityStatus;
  final bool recordAcceptedPoseFrame;
  final bool recordPoseReacquisition;
}

class HoldCoordinatorFrameResult {
  const HoldCoordinatorFrameResult({
    required this.stateSnapshot,
    required this.diagnosticsUpdate,
  });

  final HoldCoordinatorStateSnapshot stateSnapshot;
  final HoldCoordinatorDiagnosticsUpdate diagnosticsUpdate;
}

abstract class HoldCoordinator {
  HoldCoordinatorStateSnapshot currentStateSnapshot();

  HoldDiagnosticsSnapshot diagnosticsSnapshot();

  HoldSide? requiredHoldSideForAssessment();

  HoldSide selectHoldSideForAcceptedPose(PoseQualityAssessment assessment);

  HoldCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
  });

  HoldCoordinatorStateSnapshot handleLifecycleInterruption({String? reason});
}

class DefaultHoldCoordinator implements HoldCoordinator {
  DefaultHoldCoordinator({
    required HoldAnalysisEngine engine,
    required ExerciseConfig config,
    WorkoutAnalysisFrameBuilder analysisFrameBuilder =
        const WorkoutAnalysisFrameBuilder(),
    WorkoutCalibrationMetricsBuilder calibrationMetricsBuilder =
        const WorkoutCalibrationMetricsBuilder(),
    HoldSideStabilizer? holdSideStabilizer,
  }) : _engine = engine,
       _config = config,
       _analysisFrameBuilder = analysisFrameBuilder,
       _calibrationMetricsBuilder = calibrationMetricsBuilder,
       _holdSideStabilizer = holdSideStabilizer ?? HoldSideStabilizer();

  final HoldAnalysisEngine _engine;
  final ExerciseConfig _config;
  final WorkoutAnalysisFrameBuilder _analysisFrameBuilder;
  final WorkoutCalibrationMetricsBuilder _calibrationMetricsBuilder;
  final HoldSideStabilizer _holdSideStabilizer;
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

  HoldSide? _selectedHoldSide;
  HoldSide? _briefGapFrozenHoldSide;
  bool _hasAcceptedPoseForAnalysis = false;
  HoldCoordinatorStateSnapshot? _lastPublishedStateSnapshot;

  @override
  HoldCoordinatorStateSnapshot currentStateSnapshot() {
    final snapshot = _lastPublishedStateSnapshot;
    if (snapshot != null) {
      return snapshot;
    }

    final diagnostics = _holdDiagnosticsSnapshot();
    return _rememberStateSnapshot(
      landmarks: null,
      isFormBad: diagnostics.phase == HoldPhase.broken,
      currentAngle: 0.0,
      currentHoldSeconds: diagnostics.currentHoldSeconds,
      bestHoldSeconds: diagnostics.bestHoldSeconds,
      selectedHoldSide: _currentHoldSideForState(),
      isHolding: diagnostics.isHolding,
      isHoldVisibilitySuspended: diagnostics.isVisibilitySuspended,
      hadHoldFormBreak: diagnostics.hadFormBreak,
      holdFeedbackCode: _currentHoldFeedbackCode(),
      holdEnginePhase: diagnostics.phase,
      currentPhase: diagnostics.phase.legacyLabel,
      calibrationMetrics: const WorkoutCalibrationMetrics.hold(),
    );
  }

  @override
  HoldDiagnosticsSnapshot diagnosticsSnapshot() {
    return _holdDiagnosticsSnapshot();
  }

  @override
  HoldSide? requiredHoldSideForAssessment() {
    final selectedHoldSide = _briefGapFrozenHoldSide ?? _selectedHoldSide;
    if (selectedHoldSide == null) {
      return null;
    }

    final diagnostics = _holdDiagnosticsSnapshot();
    if (!shouldLockHoldSideSelection(
      engineKind: EngineKind.hold,
      selectedSide: selectedHoldSide,
      diagnostics: diagnostics,
    )) {
      return null;
    }

    return selectedHoldSide;
  }

  @override
  HoldSide selectHoldSideForAcceptedPose(PoseQualityAssessment assessment) {
    final lockedHoldSide = requiredHoldSideForAssessment();
    if (lockedHoldSide != null) {
      _selectedHoldSide = lockedHoldSide;
      return lockedHoldSide;
    }

    final preferredHoldSide = assessment.preferredHoldSide;
    if (preferredHoldSide == null) {
      throw StateError(
        'Accepted hold pose-quality assessment requires a preferredHoldSide.',
      );
    }

    final previousHoldSide = _selectedHoldSide;
    final selection = _holdSideStabilizer.stabilizeSelection(
      preferredSide: preferredHoldSide,
      acceptedSides: assessment.acceptedHoldSides,
      currentSide: _selectedHoldSide,
    );
    if (previousHoldSide != null &&
        previousHoldSide != selection.selectedSide) {
      _resetHoldMetricFilters();
    }
    _selectedHoldSide = selection.selectedSide;
    return selection.selectedSide;
  }

  @override
  HoldCoordinatorFrameResult processFrame({
    required ExerciseMetrics metrics,
    required DateTime now,
    required bool isAcceptedPoseFrame,
    required bool didBecomeStableTracking,
  }) {
    if (!isAcceptedPoseFrame) {
      return _processInvalidFrame(metrics: metrics);
    }

    return _processAcceptedFrame(
      metrics: metrics,
      didBecomeStableTracking: didBecomeStableTracking,
    );
  }

  @override
  HoldCoordinatorStateSnapshot handleLifecycleInterruption({String? reason}) {
    final publishedState = currentStateSnapshot();
    _engine.interrupt(reason: reason);
    _hasAcceptedPoseForAnalysis = false;
    _resetHoldMetricFilters();
    _resetHoldSideSelection();
    final holdDiagnostics = _holdDiagnosticsSnapshot();
    return _rememberStateSnapshot(
      landmarks: publishedState.landmarks,
      isFormBad: publishedState.isFormBad,
      currentAngle: publishedState.currentAngle,
      currentHoldSeconds: 0,
      bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
      selectedHoldSide: null,
      isHolding: false,
      isHoldVisibilitySuspended: false,
      hadHoldFormBreak: holdDiagnostics.hadFormBreak,
      holdFeedbackCode: _currentHoldFeedbackCode(),
      holdEnginePhase: holdDiagnostics.phase,
      currentPhase: holdDiagnostics.phase.legacyLabel,
      calibrationMetrics: publishedState.calibrationMetrics,
    );
  }

  HoldCoordinatorFrameResult _processInvalidFrame({
    required ExerciseMetrics metrics,
  }) {
    final lockedHoldSide = requiredHoldSideForAssessment();
    if (lockedHoldSide != null) {
      _beginHoldVisibilityGap();
    } else {
      _resetHoldSideSelection();
    }

    final holdDiagnostics = _holdDiagnosticsSnapshot();
    return HoldCoordinatorFrameResult(
      stateSnapshot: _rememberStateSnapshot(
        landmarks: metrics.landmarks,
        isFormBad: false,
        currentAngle: metrics.primaryAngle,
        currentHoldSeconds: holdDiagnostics.isVisibilitySuspended
            ? holdDiagnostics.currentHoldSeconds
            : 0,
        bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
        selectedHoldSide: _currentHoldSideForState(),
        isHolding: false,
        isHoldVisibilitySuspended: holdDiagnostics.isVisibilitySuspended,
        hadHoldFormBreak: holdDiagnostics.hadFormBreak,
        holdFeedbackCode: HoldFeedbackCode.bodyNotVisible,
        holdEnginePhase: holdDiagnostics.phase,
        currentPhase: 'WAITING',
        calibrationMetrics: _buildHoldCalibrationMetrics(
          currentFormMetric: metrics.formMetric,
          thresholdValue: _config.resolvedHoldPosture.bodyLineEntryAngle,
        ),
      ),
      diagnosticsUpdate: const HoldCoordinatorDiagnosticsUpdate(
        visibilityStatus: 'invalid_input',
      ),
    );
  }

  HoldCoordinatorFrameResult _processAcceptedFrame({
    required ExerciseMetrics metrics,
    required bool didBecomeStableTracking,
  }) {
    final publishedState = currentStateSnapshot();
    final preUpdateHoldDiagnostics = _holdDiagnosticsSnapshot();
    final shouldRecordPoseReacquisition =
        didBecomeStableTracking && _hasAcceptedPoseForAnalysis;
    final holdGapResult = _resumeHoldVisibilityGap();

    if (holdGapResult.disposition == HoldVisibilityResumeDisposition.ended) {
      final holdDiagnostics = _holdDiagnosticsSnapshot();
      _resetHoldSideSelection();
      final result = HoldCoordinatorFrameResult(
        stateSnapshot: _rememberStateSnapshot(
          landmarks: metrics.landmarks,
          isFormBad: holdDiagnostics.phase == HoldPhase.broken,
          currentAngle: metrics.primaryAngle,
          currentHoldSeconds: 0,
          bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
          selectedHoldSide: null,
          isHolding: false,
          isHoldVisibilitySuspended: false,
          hadHoldFormBreak: holdDiagnostics.hadFormBreak,
          holdFeedbackCode: _currentHoldFeedbackCode(),
          holdEnginePhase: holdDiagnostics.phase,
          currentPhase: holdDiagnostics.phase.legacyLabel,
          calibrationMetrics: _buildHoldCalibrationMetrics(
            currentFormMetric: metrics.formMetric,
            thresholdValue: holdDiagnostics.bodyLineTargetAngle,
            currentBodyLineAngle: metrics.bodyLineAngle,
            currentArmSupportAngle: metrics.armSupportAngle,
            currentLegExtensionAngle: metrics.legExtensionAngle,
          ),
        ),
        diagnosticsUpdate: HoldCoordinatorDiagnosticsUpdate(
          visibilityStatus: 'stable',
          recordAcceptedPoseFrame: true,
          recordPoseReacquisition: shouldRecordPoseReacquisition,
        ),
      );
      _hasAcceptedPoseForAnalysis = true;
      return result;
    }

    if (holdGapResult.disposition == HoldVisibilityResumeDisposition.resumed ||
        holdGapResult.disposition == HoldVisibilityResumeDisposition.noGap) {
      _briefGapFrozenHoldSide = null;
    }

    if (metrics.hasPose) {
      final analysisFrame = _analysisFrameBuilder.build(
        metrics: metrics,
        primaryMetricFilter: _primaryMetricFilter,
        formMetricFilter: _formMetricFilter,
        bodyLineFilter: _bodyLineFilter,
        armSupportFilter: _armSupportFilter,
        legFilter: _legFilter,
      );
      _engine.update(analysisFrame);
      final holdDiagnostics = _holdDiagnosticsSnapshot();
      if (_didHoldAttemptEndAfterUpdate(
        before: preUpdateHoldDiagnostics,
        after: holdDiagnostics,
      )) {
        _resetHoldSideSelection();
      }

      final result = HoldCoordinatorFrameResult(
        stateSnapshot: _rememberStateSnapshot(
          landmarks: metrics.landmarks,
          isFormBad: holdDiagnostics.phase == HoldPhase.broken,
          currentAngle: _currentAngleForState(analysisFrame),
          currentHoldSeconds: holdDiagnostics.currentHoldSeconds,
          bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
          selectedHoldSide: _currentHoldSideForState(),
          isHolding: holdDiagnostics.isHolding,
          isHoldVisibilitySuspended: holdDiagnostics.isVisibilitySuspended,
          hadHoldFormBreak: holdDiagnostics.hadFormBreak,
          holdFeedbackCode: _currentHoldFeedbackCode(),
          holdEnginePhase: holdDiagnostics.phase,
          currentPhase: holdDiagnostics.phase.legacyLabel,
          calibrationMetrics: _buildHoldCalibrationMetrics(
            currentFormMetric: analysisFrame.formMetric,
            thresholdValue: holdDiagnostics.bodyLineTargetAngle,
            currentBodyLineAngle: analysisFrame.bodyLineAngle,
            currentArmSupportAngle: analysisFrame.armSupportAngle,
            currentLegExtensionAngle: analysisFrame.legExtensionAngle,
          ),
        ),
        diagnosticsUpdate: HoldCoordinatorDiagnosticsUpdate(
          visibilityStatus: 'stable',
          recordAcceptedPoseFrame: true,
          recordPoseReacquisition: shouldRecordPoseReacquisition,
        ),
      );
      _hasAcceptedPoseForAnalysis = true;
      return result;
    }

    final result = HoldCoordinatorFrameResult(
      stateSnapshot: _rememberStateSnapshot(
        landmarks: metrics.landmarks,
        isFormBad: false,
        currentAngle: metrics.primaryAngle,
        currentHoldSeconds: 0,
        bestHoldSeconds: publishedState.bestHoldSeconds,
        selectedHoldSide: _currentHoldSideForState(),
        isHolding: false,
        isHoldVisibilitySuspended: false,
        hadHoldFormBreak: publishedState.hadHoldFormBreak,
        holdFeedbackCode: HoldFeedbackCode.bodyNotVisible,
        holdEnginePhase: _holdDiagnosticsSnapshot().phase,
        currentPhase: 'WAITING',
        calibrationMetrics: _buildHoldCalibrationMetrics(
          currentFormMetric: metrics.formMetric,
          thresholdValue: _config.resolvedHoldPosture.bodyLineEntryAngle,
        ),
      ),
      diagnosticsUpdate: HoldCoordinatorDiagnosticsUpdate(
        visibilityStatus: 'invalid_input',
        recordAcceptedPoseFrame: true,
        recordPoseReacquisition: shouldRecordPoseReacquisition,
      ),
    );
    _hasAcceptedPoseForAnalysis = true;
    return result;
  }

  HoldDiagnosticsSnapshot _holdDiagnosticsSnapshot() {
    return _engine.diagnosticsSnapshot;
  }

  HoldFeedbackCode _currentHoldFeedbackCode() {
    return _engine.feedbackCode;
  }

  HoldSide? _currentHoldSideForState() {
    return _briefGapFrozenHoldSide ?? _selectedHoldSide;
  }

  bool _didHoldAttemptEndAfterUpdate({
    required HoldDiagnosticsSnapshot before,
    required HoldDiagnosticsSnapshot after,
  }) {
    final hadActiveAttempt = before.isHolding || before.isVisibilitySuspended;
    final hasActiveAttempt = after.isHolding || after.isVisibilitySuspended;
    return hadActiveAttempt && !hasActiveAttempt;
  }

  void _resetHoldSideSelection() {
    final hadHoldSideSelection =
        _selectedHoldSide != null || _briefGapFrozenHoldSide != null;
    _selectedHoldSide = null;
    _briefGapFrozenHoldSide = null;
    _holdSideStabilizer.reset();
    if (hadHoldSideSelection) {
      _resetHoldMetricFilters();
    }
  }

  void _resetHoldMetricFilters() {
    _bodyLineFilter.reset();
    _armSupportFilter.reset();
    _legFilter.reset();
  }

  void _beginHoldVisibilityGap() {
    if (_selectedHoldSide != null) {
      _briefGapFrozenHoldSide ??= _selectedHoldSide;
    }
    _engine.beginVisibilityGap();
  }

  HoldVisibilityResumeResult _resumeHoldVisibilityGap() {
    return _engine.resumeAfterVisibilityGap();
  }

  double _currentAngleForState(AnalysisFrame frame) {
    return frame.bodyLineAngle ?? frame.primaryMetric;
  }

  WorkoutCalibrationMetrics _buildHoldCalibrationMetrics({
    required double currentFormMetric,
    required double thresholdValue,
    double? currentBodyLineAngle,
    double? currentArmSupportAngle,
    double? currentLegExtensionAngle,
  }) {
    return _calibrationMetricsBuilder.buildHold(
      currentFormMetric: currentFormMetric,
      thresholdValue: thresholdValue,
      currentBodyLineAngle: currentBodyLineAngle,
      currentArmSupportAngle: currentArmSupportAngle,
      currentLegExtensionAngle: currentLegExtensionAngle,
    );
  }

  HoldCoordinatorStateSnapshot _rememberStateSnapshot({
    required List<PoseLandmark>? landmarks,
    required bool isFormBad,
    required double currentAngle,
    required double currentHoldSeconds,
    required double bestHoldSeconds,
    required HoldSide? selectedHoldSide,
    required bool isHolding,
    required bool isHoldVisibilitySuspended,
    required bool hadHoldFormBreak,
    required HoldFeedbackCode? holdFeedbackCode,
    required HoldPhase? holdEnginePhase,
    required String currentPhase,
    required WorkoutCalibrationMetrics calibrationMetrics,
  }) {
    final snapshot = HoldCoordinatorStateSnapshot(
      landmarks: landmarks,
      isFormBad: isFormBad,
      currentAngle: currentAngle,
      currentHoldSeconds: currentHoldSeconds,
      bestHoldSeconds: bestHoldSeconds,
      selectedHoldSide: selectedHoldSide,
      isHolding: isHolding,
      isHoldVisibilitySuspended: isHoldVisibilitySuspended,
      hadHoldFormBreak: hadHoldFormBreak,
      holdFeedbackCode: holdFeedbackCode,
      holdEnginePhase: holdEnginePhase,
      currentPhase: currentPhase,
      calibrationMetrics: calibrationMetrics,
      feedbackFallbackMessage:
          (holdFeedbackCode ?? HoldFeedbackCode.preparePosition).code,
    );
    _lastPublishedStateSnapshot = snapshot;
    return snapshot;
  }
}
