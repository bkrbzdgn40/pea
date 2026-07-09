import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/moving_average.dart';
import '../../application/analysis_frame_builder.dart';
import '../../application/analysis_engine_factory.dart';
import '../../application/calibration_snapshot_builder.dart';
import '../../application/engine_kind.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_metrics.dart';
import '../../application/exercise_metrics_extractor.dart';
import '../../application/range_rep_blocked_state_builder.dart';
import '../../application/range_rep_frame_policy.dart';
import '../../application/range_rep_rep_outcome_tracker.dart';
import '../../application/range_rep_side_policy.dart';
import '../../application/range_rep_side_stabilizer.dart';
import '../../application/range_rep_threshold_bookkeeper.dart';
import '../../application/range_rep_threshold_resolver.dart';
import '../../application/range_rep_visibility_policy.dart';
import '../../application/session_calibration_baseline_accumulator.dart';
import '../../application/workout_calibration_metrics_builder.dart';
import '../../application/workout_state.dart';
import '../../domain/analysis_engine.dart';
import '../../domain/hold_diagnostics.dart';
import '../../domain/models/analysis_frame.dart';
import '../../domain/models/calibration_snapshot.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/range_rep_contract.dart';
import '../../domain/models/range_rep_feedback_code.dart';
import '../../domain/models/session_calibration_baseline.dart';
import '../../domain/range_rep_diagnostics.dart';
import '../../domain/range_rep_validation_policy.dart';
import '../../infrastructure/converters/input_image_converter.dart';
import '../mappers/range_rep_feedback_ui_mapper.dart';
import 'active_analysis_exercise_provider.dart';
import 'exercise_config_provider.dart';
import 'pose_provider.dart';

/// Exposes the live workout state produced from camera frames and pose results.
final workoutControllerProvider =
    AutoDisposeNotifierProvider<WorkoutController, WorkoutState>(() {
      return WorkoutController();
    });

@visibleForTesting
bool shouldLockRangeRepSideSelection({
  required EngineKind engineKind,
  required RangeRepSide? selectedSide,
  required RangeRepDiagnosticsSnapshot diagnostics,
}) {
  if (engineKind != EngineKind.rangeRep || selectedSide == null) {
    return false;
  }

  return diagnostics.hasActiveRepPhase || diagnostics.hasPendingTransition;
}

/// Coordinates frame conversion, pose detection, smoothing, and rep state.
class WorkoutController extends AutoDisposeNotifier<WorkoutState> {
  static const Duration _analysisFrameInterval = Duration(milliseconds: 100);

  bool _isProcessing = false;
  DateTime? _lastAnalysisStartedAt;

  DateTime _lastFpsCalculationTime = DateTime.now();
  int _cameraFrameCount = 0;
  int _analysisFrameCount = 0;
  double _cameraFps = 0.0;
  double _analysisFps = 0.0;

  late final AnalysisEngine _engine;
  late final EngineKind _engineKind;
  final WorkoutAnalysisFrameBuilder _analysisFrameBuilder =
      const WorkoutAnalysisFrameBuilder();
  final RangeRepBlockedStateBuilder _rangeRepBlockedStateBuilder =
      const RangeRepBlockedStateBuilder();
  late final MovingAverageFilter _angleFilter;
  late final MovingAverageFilter _backFilter;
  late final MovingAverageFilter _bodyLineFilter;
  late final MovingAverageFilter _armSupportFilter;
  late final MovingAverageFilter _legFilter;
  late final ExerciseConfig _config;
  late final RangeRepContract? _rangeRepContract;
  final AnalysisEngineFactory _engineFactory = const AnalysisEngineFactory();
  final CalibrationSnapshotBuilder _calibrationSnapshotBuilder =
      const CalibrationSnapshotBuilder();
  final WorkoutCalibrationMetricsBuilder _workoutCalibrationMetricsBuilder =
      const WorkoutCalibrationMetricsBuilder();
  final ExerciseCatalog _exerciseCatalog = const ExerciseCatalog();
  final ExerciseMetricsExtractor _metricsExtractor =
      const ExerciseMetricsExtractor();
  final RangeRepFramePolicy _rangeRepFramePolicy = const RangeRepFramePolicy();
  final RangeRepSidePolicy _rangeRepSidePolicy = const RangeRepSidePolicy();
  late RangeRepThresholdBookkeeper _rangeRepThresholdBookkeeper;
  late final RangeRepVisibilityPolicy _rangeRepVisibilityPolicy;
  final RangeRepValidationPolicy _rangeRepValidationPolicy =
      const RangeRepValidationPolicy();
  final InputImageConverter _inputImageConverter = const InputImageConverter();
  RangeRepSide? _selectedRangeRepSide;
  late RangeRepSideStabilizer _rangeRepSideStabilizer;
  late RangeRepRepOutcomeTracker _rangeRepRepOutcomeTracker;
  CalibrationSnapshot? _lastCalibrationSnapshot;
  SessionCalibrationBaseline? _sessionCalibrationBaseline;
  late SessionCalibrationBaselineAccumulator
      _sessionCalibrationBaselineAccumulator;

  @override
  WorkoutState build() {
    // Recreating this provider starts a fresh analysis session and filter state.
    ref.watch(poseDetectorProvider);

    final activeExercise = ref.watch(activeAnalysisExerciseProvider);
    if (activeExercise == null) {
      throw StateError('No active analysis exercise selected.');
    }

    final definition = _exerciseCatalog.definitionFor(activeExercise);
    _engineKind = definition.analysisEngineKind;
    _rangeRepContract = _engineKind == EngineKind.rangeRep
        ? definition.analysisRangeRepContract
        : null;
    _config = ref.watch(exerciseConfigProvider).requireValue;
    _engine = _engineFactory.create(
      engineKind: _engineKind,
      config: _config,
      rangeRepContract: _rangeRepContract,
    );

    _angleFilter = MovingAverageFilter(windowSize: 5);
    _backFilter = MovingAverageFilter(windowSize: 5);
    _bodyLineFilter = MovingAverageFilter(windowSize: 5);
    _armSupportFilter = MovingAverageFilter(windowSize: 5);
    _legFilter = MovingAverageFilter(windowSize: 5);

    _lastFpsCalculationTime = DateTime.now();
    _cameraFrameCount = 0;
    _analysisFrameCount = 0;
    _cameraFps = 0.0;
    _analysisFps = 0.0;
    _lastAnalysisStartedAt = null;
    _selectedRangeRepSide = null;
    _rangeRepSideStabilizer = RangeRepSideStabilizer();
    _rangeRepVisibilityPolicy = RangeRepVisibilityPolicy();
    _rangeRepRepOutcomeTracker = RangeRepRepOutcomeTracker(
      validationPolicy: _rangeRepValidationPolicy,
    );
    _rangeRepThresholdBookkeeper = RangeRepThresholdBookkeeper(
      analysisKind: _engineKind.name,
      config: _config,
    );
    _lastCalibrationSnapshot = null;
    _sessionCalibrationBaseline = null;
    _sessionCalibrationBaselineAccumulator =
        SessionCalibrationBaselineAccumulator();

    return WorkoutState(analysisKind: _engineKind);
  }

  /// Processes one camera frame and publishes the latest live telemetry.
  Future<void> processCameraImage(
    CameraImage image,
    int sensorOrientation,
  ) async {
    final now = DateTime.now();
    _cameraFrameCount++;
    _updateFpsIfNeeded();

    if (_isProcessing) return;
    // Keep ML Kit work below camera FPS so preview rendering stays responsive.
    if (_lastAnalysisStartedAt != null &&
        now.difference(_lastAnalysisStartedAt!) < _analysisFrameInterval) {
      return;
    }

    _lastAnalysisStartedAt = now;
    _isProcessing = true;

    try {
      final inputImage = _inputImageConverter.convert(image, sensorOrientation);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final detector = ref.read(poseDetectorProvider);
      final poses = await detector.processImage(inputImage);
      _analysisFrameCount++;
      _updateFpsIfNeeded();

      final metrics = poses.isNotEmpty
          ? _metricsExtractor.extract(
              poses.first,
              _config,
              engineKind: _engineKind,
            )
          : const ExerciseMetrics.noPose();
      final rangeRepSideSelection = _rangeRepSideSelection(metrics);
      final rangeRepFrameAssessment = _rangeRepFrameAssessment(
        metrics,
        rangeRepSideSelection,
      );
      final rangeRepVisibilityAssessment = _rangeRepVisibilityAssessment(
        isInvalidFrame:
            _engineKind == EngineKind.rangeRep &&
            !rangeRepFrameAssessment.shouldUpdateEngine,
        now: now,
      );
      final preUpdateRangeRepDiagnostics = _rangeRepDiagnosticsSnapshot();
      final shouldFreezeRangeRepPreview =
          _engineKind == EngineKind.rangeRep &&
          !rangeRepFrameAssessment.shouldUpdateEngine &&
          rangeRepVisibilityAssessment.hasResyncedCurrentRun;

      if (rangeRepSideSelection.selectedSide != null &&
          !shouldFreezeRangeRepPreview) {
        _selectedRangeRepSide = rangeRepSideSelection.selectedSide;
      }

      if (_engineKind == EngineKind.rangeRep &&
          !rangeRepFrameAssessment.shouldUpdateEngine) {
        _trackRangeRepRepContext(
          diagnostics: preUpdateRangeRepDiagnostics,
          selectedSide: rangeRepFrameAssessment.selection.selectedSide,
          markCoverageDrop: true,
        );
        if (rangeRepVisibilityAssessment.shouldResync) {
          _resetRangeRepVisibilityResyncState(
            reason: rangeRepVisibilityAssessment.resyncReason,
          );
        }
        final selectedRangeRepSide = _rangeRepSideLabel(
          rangeRepFrameAssessment.selection.selectedSide,
        );
        state = _rangeRepBlockedStateBuilder.build(
          metrics: metrics,
          assessment: rangeRepFrameAssessment,
          freezeSmoothedPreview: shouldFreezeRangeRepPreview,
          primaryMetricFilter: _angleFilter,
          formMetricFilter: _backFilter,
          currentState: state,
          analysisKind: _engineKind,
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          selectedRangeRepSide: selectedRangeRepSide,
          calibrationMetricsBuilder: (preview) {
            final formThresholdResolution = _rangeRepThresholdBookkeeper.resolve(
              baseThreshold: _config.formThreshold,
              sessionCalibrationBaseline: _sessionCalibrationBaseline,
              selectedRangeRepSide: preview.selectedRangeRepSide,
            );

            return _buildCalibrationMetrics(
              currentFormMetric: preview.previewBackAngle,
              currentPrimaryMetric: preview.previewAngle,
              thresholdValue: formThresholdResolution.effectiveThreshold,
              currentTorsoAngle: preview.formSignals?.torsoAngle,
              currentDepthMetric: preview.formSignals?.depthMetric,
              currentAlignmentMetric: preview.formSignals?.alignmentMetric,
              currentStabilityMetric: preview.formSignals?.stabilityMetric,
              currentLockoutMetric: preview.formSignals?.lockoutMetric,
              currentBottomControlMetric:
                  preview.formSignals?.bottomControlMetric,
              baseFormThreshold: formThresholdResolution.baseThreshold,
              effectiveFormThreshold: formThresholdResolution.effectiveThreshold,
              calibrationThresholdOffsetCandidate:
                  formThresholdResolution.offsetCandidate,
              calibrationThresholdOffsetApplied:
                  formThresholdResolution.isApplied,
              calibrationThresholdOffsetFallbackReason:
                  formThresholdResolution.decisionReason,
              calibrationThresholdOffsetSampleCount:
                  formThresholdResolution.sampleCount,
              calibrationThresholdOffsetBaselineSideLabel:
                  formThresholdResolution.baselineSideLabel,
              isRangeRepFrameValid: false,
              hasPrimaryAngle: rangeRepFrameAssessment.hasPrimaryAngle,
              hasFormMetric: rangeRepFrameAssessment.hasFormMetric,
              rangeRepInvalidReason: rangeRepFrameAssessment.invalidReason,
              selectedRangeRepSide: preview.selectedRangeRepSide,
              rangeRepSideSelectionReason:
                  rangeRepFrameAssessment.selection.debugLabel,
              leftRangeRepCoverage:
                  rangeRepFrameAssessment.selection.leftMetrics.coverageScore,
              rightRangeRepCoverage:
                  rangeRepFrameAssessment.selection.rightMetrics.coverageScore,
              leftRangeRepSideConfidence:
                  rangeRepFrameAssessment.selection.leftMetrics.sideConfidence,
              rightRangeRepSideConfidence:
                  rangeRepFrameAssessment.selection.rightMetrics.sideConfidence,
              rangeRepInvalidFrameStreak:
                  rangeRepVisibilityAssessment.invalidFrameStreak,
              rangeRepInvalidDurationMs:
                  rangeRepVisibilityAssessment.invalidDuration.inMilliseconds,
              rangeRepResyncTriggered:
                  rangeRepVisibilityAssessment.hasResyncedCurrentRun,
              rangeRepResyncReason: rangeRepVisibilityAssessment.resyncReason,
              rangeRepVisibilityStatus:
                  rangeRepVisibilityAssessment.statusLabel,
            );
          },
        );
        return;
      }

      if (metrics.hasPose) {
        // Raw range-rep form signals are telemetry only; engine inputs stay legacy.
        final selectedFormSignals =
            rangeRepFrameAssessment.selectedMetrics?.formSignals;
        final selectedRangeRepSide = _rangeRepSideLabel(
          rangeRepFrameAssessment.selection.selectedSide,
        );
        _trackRangeRepRepContext(
          diagnostics: preUpdateRangeRepDiagnostics,
          selectedSide: rangeRepFrameAssessment.selection.selectedSide,
        );
        // Smooth landmark jitter before feeding the scoring state machine.
        final analysisFrame = _analysisFrameBuilder.build(
          metrics: metrics,
          rangeRepMetrics: rangeRepFrameAssessment.selectedMetrics,
          primaryMetricFilter: _angleFilter,
          formMetricFilter: _backFilter,
          bodyLineFilter: _bodyLineFilter,
          armSupportFilter: _armSupportFilter,
          legFilter: _legFilter,
        );
        final formThresholdResolution = _engineKind == EngineKind.rangeRep
            ? _rangeRepThresholdBookkeeper.resolve(
                baseThreshold: _config.formThreshold,
                sessionCalibrationBaseline: _sessionCalibrationBaseline,
                selectedRangeRepSide: selectedRangeRepSide,
              )
            : null;
        final engineFrame = _applyFormThresholdResolution(
          analysisFrame,
          formThresholdResolution,
        );
        _engine.update(engineFrame);
        final completedRepCoreData = _consumeCompletedRepCoreData();
        final postUpdateRangeRepDiagnostics = _rangeRepDiagnosticsSnapshot();
        final didCompleteRep = completedRepCoreData != null;
        _rangeRepRepOutcomeTracker.activateCompletedRepOutcomeIfAny(
          engineKind: _engineKind,
          analysisKindLabel: _engineKind.name,
          completedRepCoreData: completedRepCoreData,
        );
        _rangeRepRepOutcomeTracker.resetRepContextIfCycleEnded(
          previousDiagnostics: preUpdateRangeRepDiagnostics,
          currentDiagnostics: postUpdateRangeRepDiagnostics,
          didCompleteRep: didCompleteRep,
        );
        final holdDiagnostics = _holdDiagnosticsSnapshot();

        state = WorkoutState(
          landmarks: metrics.landmarks,
          analysisKind: _engineKind,
          repCount: _engine.repCount,
          isFormBad: _engine.isFormBad,
          currentAngle: _currentAngleForState(analysisFrame),
          lastRepScore: _engine.lastRepScore,
          lastRepROM: _engine.maxRom,
          currentHoldSeconds: holdDiagnostics.currentHoldSeconds,
          bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
          isHolding: holdDiagnostics.isHolding,
          hadHoldFormBreak: holdDiagnostics.hadFormBreak,
          feedbackMessage: _resolvedEngineFeedbackMessage(),
          currentPhase: _engine.phaseLabel,
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(
            currentFormMetric: analysisFrame.formMetric,
            currentPrimaryMetric: analysisFrame.primaryMetric,
            thresholdValue: _engineKind == EngineKind.hold
                ? holdDiagnostics.bodyLineTargetAngle
                : formThresholdResolution!.effectiveThreshold,
            currentBodyLineAngle: analysisFrame.bodyLineAngle,
            currentArmSupportAngle: analysisFrame.armSupportAngle,
            currentLegExtensionAngle: analysisFrame.legExtensionAngle,
            currentTorsoAngle: selectedFormSignals?.torsoAngle,
            currentDepthMetric: selectedFormSignals?.depthMetric,
            currentAlignmentMetric: selectedFormSignals?.alignmentMetric,
            currentStabilityMetric: selectedFormSignals?.stabilityMetric,
            currentLockoutMetric: selectedFormSignals?.lockoutMetric,
            currentBottomControlMetric:
                selectedFormSignals?.bottomControlMetric,
            baseFormThreshold: formThresholdResolution?.baseThreshold,
            effectiveFormThreshold: formThresholdResolution?.effectiveThreshold,
            calibrationThresholdOffsetCandidate:
                formThresholdResolution?.offsetCandidate,
            calibrationThresholdOffsetApplied:
                formThresholdResolution?.isApplied ?? false,
            calibrationThresholdOffsetFallbackReason:
                formThresholdResolution?.decisionReason,
            calibrationThresholdOffsetSampleCount:
                formThresholdResolution?.sampleCount,
            calibrationThresholdOffsetBaselineSideLabel:
                formThresholdResolution?.baselineSideLabel,
            isRangeRepFrameValid: rangeRepFrameAssessment.isValid,
            hasPrimaryAngle: rangeRepFrameAssessment.hasPrimaryAngle,
            hasFormMetric: rangeRepFrameAssessment.hasFormMetric,
            rangeRepInvalidReason: rangeRepFrameAssessment.invalidReason,
            selectedRangeRepSide: selectedRangeRepSide,
            rangeRepSideSelectionReason:
                rangeRepFrameAssessment.selection.debugLabel,
            leftRangeRepCoverage:
                rangeRepFrameAssessment.selection.leftMetrics.coverageScore,
            rightRangeRepCoverage:
                rangeRepFrameAssessment.selection.rightMetrics.coverageScore,
            leftRangeRepSideConfidence:
                rangeRepFrameAssessment.selection.leftMetrics.sideConfidence,
            rightRangeRepSideConfidence:
                rangeRepFrameAssessment.selection.rightMetrics.sideConfidence,
            rangeRepInvalidFrameStreak:
                rangeRepVisibilityAssessment.invalidFrameStreak,
            rangeRepInvalidDurationMs:
                rangeRepVisibilityAssessment.invalidDuration.inMilliseconds,
            rangeRepResyncTriggered:
                rangeRepVisibilityAssessment.hasResyncedCurrentRun,
            rangeRepResyncReason: rangeRepVisibilityAssessment.resyncReason,
            rangeRepVisibilityStatus: rangeRepVisibilityAssessment.statusLabel,
            hasBodyLineAngle: metrics.bodyLineAngle != null,
            hasArmSupportAngle: metrics.armSupportAngle != null,
            hasLegExtensionAngle: metrics.legExtensionAngle != null,
          ),
        );
      } else {
        // No-pose frames should not reset session counters or last rep results.
        final formThresholdResolution = _engineKind == EngineKind.rangeRep
            ? _rangeRepThresholdBookkeeper.resolve(
                baseThreshold: _config.formThreshold,
                sessionCalibrationBaseline: _sessionCalibrationBaseline,
                selectedRangeRepSide: null,
              )
            : null;
        state = WorkoutState(
          landmarks: metrics.landmarks,
          analysisKind: _engineKind,
          repCount: state.repCount,
          isFormBad: false,
          currentAngle: metrics.primaryAngle,
          lastRepScore: state.lastRepScore,
          lastRepROM: state.lastRepROM,
          currentHoldSeconds: 0,
          bestHoldSeconds: state.bestHoldSeconds,
          isHolding: false,
          hadHoldFormBreak: state.hadHoldFormBreak,
          feedbackMessage: "Vucut Bekleniyor...",
          currentPhase: "WAITING",
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(
            currentFormMetric: metrics.formMetric,
            thresholdValue: _engineKind == EngineKind.hold
                ? _config.resolvedHoldPosture.bodyLineEntryAngle
                : formThresholdResolution!.effectiveThreshold,
            baseFormThreshold: _engineKind == EngineKind.rangeRep
                ? formThresholdResolution?.baseThreshold
                : null,
            effectiveFormThreshold: _engineKind == EngineKind.rangeRep
                ? formThresholdResolution?.effectiveThreshold
                : null,
            calibrationThresholdOffsetCandidate:
                formThresholdResolution?.offsetCandidate,
            calibrationThresholdOffsetApplied:
                formThresholdResolution?.isApplied ?? false,
            calibrationThresholdOffsetFallbackReason:
                formThresholdResolution?.decisionReason,
            calibrationThresholdOffsetSampleCount:
                formThresholdResolution?.sampleCount,
            calibrationThresholdOffsetBaselineSideLabel:
                formThresholdResolution?.baselineSideLabel,
          ),
        );
      }
    } catch (e) {
      debugPrint("ANALIZ HATASI: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _updateFpsIfNeeded() {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastFpsCalculationTime).inMilliseconds;

    if (elapsedMs < 1000) return;

    _cameraFps = _cameraFrameCount * 1000 / elapsedMs;
    _analysisFps = _analysisFrameCount * 1000 / elapsedMs;

    _cameraFrameCount = 0;
    _analysisFrameCount = 0;
    _lastFpsCalculationTime = now;

    state = state.copyWith(cameraFps: _cameraFps, analysisFps: _analysisFps);
  }

  RangeRepSideSelection _rangeRepSideSelection(ExerciseMetrics metrics) {
    if (_engineKind != EngineKind.rangeRep) {
      return const RangeRepSideSelection(
        selectedSide: null,
        leftMetrics: RangeRepSideMetrics.unavailable(RangeRepSide.left),
        rightMetrics: RangeRepSideMetrics.unavailable(RangeRepSide.right),
        reason: RangeRepSideSelectionReason.noAvailableSide,
      );
    }

    final selection = _rangeRepSidePolicy.select(
      metrics: metrics,
      previousSide: _selectedRangeRepSide,
      lockPreviousSide: false,
    );
    final diagnostics = _rangeRepDiagnosticsSnapshot();
    return _rangeRepSideStabilizer.stabilizeSelection(
      selection: selection,
      currentSide: _selectedRangeRepSide,
      hasActiveRepContext: _isRangeRepRepContextActive(diagnostics),
    );
  }

  RangeRepFrameAssessment _rangeRepFrameAssessment(
    ExerciseMetrics metrics,
    RangeRepSideSelection selection,
  ) {
    if (_engineKind != EngineKind.rangeRep) {
      return RangeRepFrameAssessment.valid(
        selection: selection,
        hasPrimaryAngle: metrics.hasPrimaryAngle,
        hasFormMetric: metrics.hasFormMetric,
      );
    }

    return _rangeRepFramePolicy.assessWithContract(
      metrics: metrics,
      selection: selection,
      contract: _rangeRepContract ?? RangeRepContracts.squat,
    );
  }

  RangeRepVisibilityAssessment _rangeRepVisibilityAssessment({
    required bool isInvalidFrame,
    required DateTime now,
  }) {
    if (_engineKind != EngineKind.rangeRep) {
      return const RangeRepVisibilityAssessment.stable();
    }

    return _rangeRepVisibilityPolicy.evaluate(
      isInvalidFrame: isInvalidFrame,
      now: now,
    );
  }

  String _resolvedEngineFeedbackMessage() {
    if (_engineKind == EngineKind.rangeRep &&
        _engine is RangeRepFeedbackSource) {
      final feedbackCode = (_engine as RangeRepFeedbackSource).feedbackCode;
      if (feedbackCode != null) {
        return mapRangeRepFeedbackCodeToMessage(feedbackCode);
      }
    }

    return _engine.feedback;
  }

  double _currentAngleForState(AnalysisFrame frame) {
    return frame.bodyLineAngle ?? frame.primaryMetric;
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
    final lastValidationResult =
        _rangeRepRepOutcomeTracker.lastRangeRepValidationResult;
    final lastSummaryCandidate =
        _rangeRepRepOutcomeTracker.lastRangeRepRepSummaryCandidate;
    final calibrationSnapshotCandidate = _calibrationSnapshotBuilder
        .buildCandidate(
          engineKind: _engineKind,
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
      _updateSessionCalibrationBaseline(calibrationSnapshotCandidate);
    }

    // Calibration telemetry surfaces the active engine's current secondary metric.
    return _workoutCalibrationMetricsBuilder.build(
      currentFormMetric: currentFormMetric,
      thresholdValue: thresholdValue,
      diagnostics: diagnostics,
      lastBreakdown: lastBreakdown,
      lastValidationResult: lastValidationResult,
      lastSummaryCandidate: lastSummaryCandidate,
      rangeRepSideHysteresisStatus: _rangeRepSideStabilizer.hysteresisStatus,
      rangeRepSideConsistencyStatus: _rangeRepSideStabilizer.consistencyStatus,
      calibrationSnapshot: _lastCalibrationSnapshot,
      calibrationThresholdDecisionCount:
          _rangeRepThresholdBookkeeper.decisionCount,
      calibrationThresholdAppliedCount:
          _rangeRepThresholdBookkeeper.appliedCount,
      calibrationThresholdNoBaselineCount:
          _rangeRepThresholdBookkeeper.noBaselineCount,
      calibrationThresholdInsufficientSamplesCount:
          _rangeRepThresholdBookkeeper.insufficientSamplesCount,
      calibrationThresholdMissingFormBaselineCount:
          _rangeRepThresholdBookkeeper.missingFormBaselineCount,
      calibrationThresholdSideMismatchCount:
          _rangeRepThresholdBookkeeper.sideMismatchCount,
      calibrationThresholdOffsetTooSmallCount:
          _rangeRepThresholdBookkeeper.offsetTooSmallCount,
      sessionCalibrationBaselineCandidate: _sessionCalibrationBaseline,
      lastRangeRepValidatedRepIndex:
          _rangeRepRepOutcomeTracker.lastRangeRepValidatedRepIndex,
      rangeRepValidatedCount: _rangeRepRepOutcomeTracker.rangeRepValidatedCount,
      rangeRepLowConfidenceCount:
          _rangeRepRepOutcomeTracker.rangeRepLowConfidenceCount,
      rangeRepInvalidCount: _rangeRepRepOutcomeTracker.rangeRepInvalidCount,
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

  AnalysisFrame _applyFormThresholdResolution(
    AnalysisFrame frame,
    RangeRepThresholdResolution? resolution,
  ) {
    final offsetCandidate = resolution?.offsetCandidate;
    if (resolution == null ||
        !resolution.isApplied ||
        offsetCandidate == null) {
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

  void _updateSessionCalibrationBaseline(CalibrationSnapshot snapshot) {
    if (!_sessionCalibrationBaselineAccumulator.addIfAccepted(snapshot)) {
      return;
    }

    _sessionCalibrationBaseline =
        _sessionCalibrationBaselineAccumulator.baseline;
  }

  RangeRepDiagnosticsSnapshot _rangeRepDiagnosticsSnapshot() {
    if (_engine is RangeRepDiagnostics) {
      return (_engine as RangeRepDiagnostics).diagnosticsSnapshot;
    }

    return const RangeRepDiagnosticsSnapshot();
  }

  void _trackRangeRepRepContext({
    required RangeRepDiagnosticsSnapshot diagnostics,
    required RangeRepSide? selectedSide,
    bool markCoverageDrop = false,
  }) {
    _rangeRepRepOutcomeTracker.trackRepContext(
      engineKind: _engineKind,
      diagnostics: diagnostics,
      selectedSideLabel: _rangeRepSideLabel(selectedSide),
      markCoverageDrop: markCoverageDrop,
    );
  }

  RangeRepCompletedRepCoreData? _consumeCompletedRepCoreData() {
    if (_engine is! RangeRepValidationHook) {
      return null;
    }

    return (_engine as RangeRepValidationHook).consumeCompletedRepCoreData();
  }

  bool _isRangeRepRepContextActive(RangeRepDiagnosticsSnapshot diagnostics) {
    return diagnostics.hasActiveRepPhase || diagnostics.hasPendingTransition;
  }

  void _clearRangeRepActiveContext({String? reason}) {
    if (_engine is RangeRepResyncControl) {
      (_engine as RangeRepResyncControl).clearActiveRepContext(reason: reason);
    }
  }

  void _resetRangeRepVisibilityResyncState({String? reason}) {
    _clearRangeRepActiveContext(reason: reason);
    _angleFilter.reset();
    _backFilter.reset();
    // Force side selection to be reacquired from fresh post-resync coverage.
    _selectedRangeRepSide = null;
    _rangeRepSideStabilizer.reset();
    _rangeRepRepOutcomeTracker.resetRepContext();
  }

  HoldDiagnosticsSnapshot _holdDiagnosticsSnapshot() {
    if (_engine is HoldDiagnostics) {
      return (_engine as HoldDiagnostics).diagnosticsSnapshot;
    }

    return const HoldDiagnosticsSnapshot();
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
}
