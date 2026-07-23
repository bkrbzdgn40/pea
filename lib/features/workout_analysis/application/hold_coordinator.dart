import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/moving_average.dart';
import '../domain/hold_analysis_engine.dart';
import '../domain/hold_diagnostics.dart';
import '../domain/models/analysis_frame.dart';
import '../domain/models/exercise_config.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/hold_feedback_code.dart';
import '../domain/models/hold_phase.dart';
import '../domain/models/hold_signal_validity.dart';
import '../domain/models/hold_signal_values.dart';
import '../domain/models/hold_side.dart';
import '../domain/models/hold_technique_assessment.dart';
import '../domain/plank_technique_analyzer.dart';
import 'analysis_frame_builder.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';
import 'hold_side_policy.dart';
import 'hold_side_stabilizer.dart';
import 'hollow_hold_limb_elevation_measurement.dart';
import 'plank_hip_deviation_measurement.dart';
import 'plank_shoulder_elbow_offset_measurement.dart';
import 'pose_quality_policy.dart';
import 'side_plank_support_stacking_measurement.dart';
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
    this.holdTechniqueAssessment = HoldTechniqueAssessment.empty,
    this.plankHipDeviation,
    this.plankShoulderElbowOffset,
    this.hollowShoulderElevation,
    this.hollowHeelElevation,
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
  final HoldTechniqueAssessment holdTechniqueAssessment;
  final double? plankHipDeviation;
  final double? plankShoulderElbowOffset;
  final double? hollowShoulderElevation;
  final double? hollowHeelElevation;
}

class HoldCoordinatorDiagnosticsUpdate {
  const HoldCoordinatorDiagnosticsUpdate({
    required this.visibilityStatus,
    this.recordAcceptedPoseFrame = false,
    this.recordPoseReacquisition = false,
    this.recordHoldVisibilitySuspend = false,
    this.recordHoldVisibilityRecovery = false,
    this.recordHoldVisibilityAbort = false,
    this.holdVisibilityGapDuration = Duration.zero,
  });

  final String visibilityStatus;
  final bool recordAcceptedPoseFrame;
  final bool recordPoseReacquisition;
  final bool recordHoldVisibilitySuspend;
  final bool recordHoldVisibilityRecovery;
  final bool recordHoldVisibilityAbort;
  final Duration holdVisibilityGapDuration;
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
    required HoldContract holdContract,
    WorkoutAnalysisFrameBuilder analysisFrameBuilder =
        const WorkoutAnalysisFrameBuilder(),
    WorkoutCalibrationMetricsBuilder calibrationMetricsBuilder =
        const WorkoutCalibrationMetricsBuilder(),
    HoldSideStabilizer? holdSideStabilizer,
  }) : _engine = engine,
       _holdContract = holdContract,
       _config = config,
       _analysisFrameBuilder = analysisFrameBuilder,
       _calibrationMetricsBuilder = calibrationMetricsBuilder,
       _holdSideStabilizer = holdSideStabilizer ?? HoldSideStabilizer();

  final HoldAnalysisEngine _engine;
  final HoldContract _holdContract;
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
  final Map<HoldSignal, MovingAverageFilter> _holdSignalFilters =
      <HoldSignal, MovingAverageFilter>{
        for (final signal in HoldSignal.values)
          signal: MovingAverageFilter(
            windowSize: signal == HoldSignal.supportStacking ? 1 : 5,
          ),
      };

  final PlankHipDeviationMeasurement _plankHipDeviationMeasurement =
      const PlankHipDeviationMeasurement();
  final PlankShoulderElbowOffsetMeasurement
  _plankShoulderElbowOffsetMeasurement =
      const PlankShoulderElbowOffsetMeasurement();
  final SidePlankSupportStackingMeasurement
  _sidePlankSupportStackingMeasurement =
      const SidePlankSupportStackingMeasurement();
  final PlankTechniqueAnalyzer _plankTechniqueAnalyzer =
      const PlankTechniqueAnalyzer();
  final HollowHoldLimbElevationMeasurement _hollowHoldLimbElevationMeasurement =
      const HollowHoldLimbElevationMeasurement();
  double? _currentPlankHipDeviationMetric;
  double? _currentPlankShoulderElbowOffsetMetric;
  double? _currentHollowShoulderElevationMetric;
  double? _currentHollowHeelElevationMetric;
  HoldTechniqueAssessment _holdTechniqueAssessment =
      HoldTechniqueAssessment.empty;

  /// Latest normalized plank hip-line deviation. This is the primary plank
  /// technique measurement and is not a pose-acceptance or hold-validity gate.
  double? get currentPlankHipDeviationMetric => _currentPlankHipDeviationMetric;

  /// Latest normalized side-view shoulder/elbow stacking offset.
  double? get currentPlankShoulderElbowOffsetMetric =>
      _currentPlankShoulderElbowOffsetMetric;

  HoldTechniqueAssessment get holdTechniqueAssessment =>
      _holdTechniqueAssessment;

  double? get currentHollowShoulderElevationMetric =>
      _currentHollowShoulderElevationMetric;

  double? get currentHollowHeelElevationMetric =>
      _currentHollowHeelElevationMetric;

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
    _resetExerciseSpecificTechnique();
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
    _resetExerciseSpecificTechnique();
    final lockedHoldSide = requiredHoldSideForAssessment();
    final didBeginHoldVisibilityGap = lockedHoldSide != null
        ? _beginHoldVisibilityGap()
        : false;
    if (lockedHoldSide == null) {
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
          targetSignalValues: holdDiagnostics.targetSignalValues,
        ),
      ),
      diagnosticsUpdate: HoldCoordinatorDiagnosticsUpdate(
        visibilityStatus: 'invalid_input',
        recordHoldVisibilitySuspend: didBeginHoldVisibilityGap,
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
            currentSignalValues: metrics.holdSignalValues,
            targetSignalValues: holdDiagnostics.targetSignalValues,
          ),
        ),
        diagnosticsUpdate: HoldCoordinatorDiagnosticsUpdate(
          visibilityStatus: 'stable',
          recordAcceptedPoseFrame: true,
          recordPoseReacquisition: shouldRecordPoseReacquisition,
          recordHoldVisibilityAbort: true,
          holdVisibilityGapDuration: holdGapResult.gapDuration,
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
      final engineMetrics = _withExerciseSpecificHoldSignals(metrics);
      final analysisFrame = _analysisFrameBuilder.build(
        metrics: engineMetrics,
        primaryMetricFilter: _primaryMetricFilter,
        formMetricFilter: _formMetricFilter,
        holdSignalFilters: _holdSignalFilters,
      );
      _engine.update(analysisFrame);
      final holdDiagnostics = _holdDiagnosticsSnapshot();
      _updateExerciseSpecificTechnique(metrics: engineMetrics);
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
            currentSignalValues: analysisFrame.holdSignalValues,
            targetSignalValues: holdDiagnostics.targetSignalValues,
            signalValidity: holdDiagnostics.signalValidity,
          ),
        ),
        diagnosticsUpdate: HoldCoordinatorDiagnosticsUpdate(
          visibilityStatus: 'stable',
          recordAcceptedPoseFrame: true,
          recordPoseReacquisition: shouldRecordPoseReacquisition,
          recordHoldVisibilityRecovery:
              holdGapResult.disposition ==
              HoldVisibilityResumeDisposition.resumed,
          holdVisibilityGapDuration: holdGapResult.gapDuration,
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
          targetSignalValues: _holdDiagnosticsSnapshot().targetSignalValues,
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

  ExerciseMetrics _withExerciseSpecificHoldSignals(ExerciseMetrics metrics) {
    if (_holdContract.family != HoldAnalysisFamily.sidePlank) {
      return metrics;
    }

    final side = _currentHoldSideForState();
    if (side == null) {
      return metrics;
    }

    final pose = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        for (final landmark in metrics.landmarks) landmark.type: landmark,
      },
    );
    final supportStacking = _sidePlankSupportStackingMeasurement.measure(
      pose,
      side: side,
      referenceSide: _configHoldReferenceSide(),
    );

    return metrics.copyWith(
      holdSignalValues: metrics.holdSignalValues.mergedWith(
        <HoldSignal, double?>{HoldSignal.supportStacking: supportStacking},
      ),
    );
  }

  void _updateExerciseSpecificTechnique({required ExerciseMetrics metrics}) {
    final side = _currentHoldSideForState();
    if (side == null) {
      _resetExerciseSpecificTechnique();
      return;
    }

    final pose = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        for (final landmark in metrics.landmarks) landmark.type: landmark,
      },
    );
    final referenceSide = _configHoldReferenceSide();

    switch (_holdContract.family) {
      case HoldAnalysisFamily.plank:
        _currentHollowShoulderElevationMetric = null;
        _currentHollowHeelElevationMetric = null;
        _currentPlankHipDeviationMetric = _plankHipDeviationMeasurement.measure(
          pose,
          side: side,
          referenceSide: referenceSide,
        );
        _currentPlankShoulderElbowOffsetMetric =
            _plankShoulderElbowOffsetMeasurement.measure(
              pose,
              side: side,
              referenceSide: referenceSide,
            );

        _holdTechniqueAssessment = _plankTechniqueAnalyzer.assess(
          hipDeviation: _currentPlankHipDeviationMetric,
          shoulderElbowOffset: _currentPlankShoulderElbowOffsetMetric,
          kneeExtensionAngle: metrics.holdSignalValues.valueFor(
            HoldSignal.extension,
          ),
          legacySignalValidity: _holdDiagnosticsSnapshot().signalValidity,
        );
        break;
      case HoldAnalysisFamily.hollowHold:
        _currentPlankHipDeviationMetric = null;
        _currentPlankShoulderElbowOffsetMetric = null;
        _holdTechniqueAssessment = HoldTechniqueAssessment.empty;
        final measurements = _hollowHoldLimbElevationMeasurement.measure(
          pose,
          side: side,
          referenceSide: referenceSide,
        );
        final variation = _holdContract.hollowHoldVariation;
        _currentHollowShoulderElevationMetric =
            variation?.usesShoulderElevation == true
            ? measurements.shoulderElevation
            : null;
        _currentHollowHeelElevationMetric = variation?.usesHeelElevation == true
            ? measurements.heelElevation
            : null;
        break;
      case HoldAnalysisFamily.sidePlank:
        _resetExerciseSpecificTechnique();
        break;
      case HoldAnalysisFamily.wallSit:
        _resetExerciseSpecificTechnique();
        break;
    }
  }

  HoldSide _configHoldReferenceSide() {
    return _config.holdSignals?.referenceSide ?? HoldSide.left;
  }

  void _resetExerciseSpecificTechnique() {
    _currentPlankHipDeviationMetric = null;
    _currentPlankShoulderElbowOffsetMetric = null;
    _currentHollowShoulderElevationMetric = null;
    _currentHollowHeelElevationMetric = null;
    _holdTechniqueAssessment = HoldTechniqueAssessment.empty;
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
    for (final filter in _holdSignalFilters.values) {
      filter.reset();
    }
  }

  bool _beginHoldVisibilityGap() {
    final wasSuspended = _holdDiagnosticsSnapshot().isVisibilitySuspended;
    if (_selectedHoldSide != null) {
      _briefGapFrozenHoldSide ??= _selectedHoldSide;
    }
    _engine.beginVisibilityGap();
    return !wasSuspended && _holdDiagnosticsSnapshot().isVisibilitySuspended;
  }

  HoldVisibilityResumeResult _resumeHoldVisibilityGap() {
    return _engine.resumeAfterVisibilityGap();
  }

  double _currentAngleForState(AnalysisFrame frame) {
    return frame.bodyLineAngle ?? frame.primaryMetric;
  }

  WorkoutCalibrationMetrics _buildHoldCalibrationMetrics({
    required double currentFormMetric,
    HoldSignalValues? currentSignalValues,
    HoldSignalValues? targetSignalValues,
    HoldSignalValidity? signalValidity,
  }) {
    return _calibrationMetricsBuilder.buildHold(
      currentFormMetric: currentFormMetric,
      currentSignalValues: currentSignalValues,
      targetSignalValues: targetSignalValues,
      signalValidity: signalValidity,
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
      holdTechniqueAssessment: _holdTechniqueAssessment,
      plankHipDeviation: _currentPlankHipDeviationMetric,
      plankShoulderElbowOffset: _currentPlankShoulderElbowOffsetMetric,
      hollowShoulderElevation: _currentHollowShoulderElevationMetric,
      hollowHeelElevation: _currentHollowHeelElevationMetric,
    );
    _lastPublishedStateSnapshot = snapshot;
    return snapshot;
  }
}
