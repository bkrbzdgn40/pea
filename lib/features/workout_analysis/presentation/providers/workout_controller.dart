import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/moving_average.dart';
import '../../application/analysis_engine_factory.dart';
import '../../application/engine_kind.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_metrics.dart';
import '../../application/exercise_metrics_extractor.dart';
import '../../application/range_rep_frame_policy.dart';
import '../../application/range_rep_side_policy.dart';
import '../../application/range_rep_visibility_policy.dart';
import '../../application/workout_state.dart';
import '../../domain/analysis_engine.dart';
import '../../domain/hold_diagnostics.dart';
import '../../domain/models/analysis_frame.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/range_rep_rep_summary.dart';
import '../../domain/models/range_rep_validation_result.dart';
import '../../domain/range_rep_diagnostics.dart';
import '../../domain/range_rep_validation_policy.dart';
import '../../infrastructure/converters/input_image_converter.dart';
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
  late final MovingAverageFilter _angleFilter;
  late final MovingAverageFilter _backFilter;
  late final MovingAverageFilter _bodyLineFilter;
  late final MovingAverageFilter _armSupportFilter;
  late final MovingAverageFilter _legFilter;
  late final ExerciseConfig _config;
  final AnalysisEngineFactory _engineFactory = const AnalysisEngineFactory();
  final ExerciseCatalog _exerciseCatalog = const ExerciseCatalog();
  final ExerciseMetricsExtractor _metricsExtractor =
      const ExerciseMetricsExtractor();
  final RangeRepFramePolicy _rangeRepFramePolicy = const RangeRepFramePolicy();
  final RangeRepSidePolicy _rangeRepSidePolicy = const RangeRepSidePolicy();
  late final RangeRepVisibilityPolicy _rangeRepVisibilityPolicy;
  final RangeRepValidationPolicy _rangeRepValidationPolicy =
      const RangeRepValidationPolicy();
  final InputImageConverter _inputImageConverter = const InputImageConverter();
  RangeRepSide? _selectedRangeRepSide;
  RangeRepRepSummary? _lastRangeRepRepSummaryCandidate;
  RangeRepValidationResult? _lastRangeRepValidationResult;
  int? _lastRangeRepValidatedRepIndex;
  int _rangeRepValidatedCount = 0;
  int _rangeRepLowConfidenceCount = 0;
  int _rangeRepInvalidCount = 0;
  bool _activeRangeRepHadCoverageDrop = false;
  bool _activeRangeRepSwitchedSideDuringRep = false;
  String? _activeRangeRepSelectedSideLabel;

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
    _config = ref.watch(exerciseConfigProvider).requireValue;
    _engine = _engineFactory.create(engineKind: _engineKind, config: _config);

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
    _rangeRepVisibilityPolicy = RangeRepVisibilityPolicy();
    _resetRangeRepRepSummaryContext(clearCandidate: true);
    _rangeRepValidatedCount = 0;
    _rangeRepLowConfidenceCount = 0;
    _rangeRepInvalidCount = 0;

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
        state = _buildBlockedRangeRepState(
          metrics,
          rangeRepFrameAssessment,
          rangeRepVisibilityAssessment,
          shouldFreezeRangeRepPreview,
        );
        return;
      }

      if (metrics.hasPose) {
        // Raw range-rep form signals are telemetry only; engine inputs stay legacy.
        final selectedFormSignals =
            rangeRepFrameAssessment.selectedMetrics?.formSignals;
        final previousRepCount = state.repCount;
        _trackRangeRepRepContext(
          diagnostics: preUpdateRangeRepDiagnostics,
          selectedSide: rangeRepFrameAssessment.selection.selectedSide,
        );
        // Smooth landmark jitter before feeding the scoring state machine.
        final analysisFrame = _buildAnalysisFrame(
          metrics,
          rangeRepMetrics: rangeRepFrameAssessment.selectedMetrics,
        );
        _engine.update(analysisFrame);
        final postUpdateRangeRepDiagnostics = _rangeRepDiagnosticsSnapshot();
        final didCompleteRep = _engine.repCount > previousRepCount;
        _assembleRangeRepRepSummaryCandidateIfNeeded(
          previousRepCount: previousRepCount,
          diagnostics: postUpdateRangeRepDiagnostics,
        );
        _resetRangeRepRepSummaryContextIfCycleEnded(
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
          feedbackMessage: _engine.feedback,
          currentPhase: _engine.phaseLabel,
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(
            currentFormMetric: analysisFrame.formMetric,
            thresholdValue: _engineKind == EngineKind.hold
                ? holdDiagnostics.bodyLineTargetAngle
                : _config.formThreshold,
            currentBodyLineAngle: analysisFrame.bodyLineAngle,
            currentArmSupportAngle: analysisFrame.armSupportAngle,
            currentLegExtensionAngle: analysisFrame.legExtensionAngle,
            currentTorsoAngle: selectedFormSignals?.torsoAngle,
            currentDepthMetric: selectedFormSignals?.depthMetric,
            currentAlignmentMetric: selectedFormSignals?.alignmentMetric,
            currentStabilityMetric: selectedFormSignals?.stabilityMetric,
            currentLockoutMetric: selectedFormSignals?.lockoutMetric,
            currentBottomControlMetric: selectedFormSignals?.bottomControlMetric,
            isRangeRepFrameValid: rangeRepFrameAssessment.isValid,
            hasPrimaryAngle: rangeRepFrameAssessment.hasPrimaryAngle,
            hasFormMetric: rangeRepFrameAssessment.hasFormMetric,
            rangeRepInvalidReason: rangeRepFrameAssessment.invalidReason,
            selectedRangeRepSide: _rangeRepSideLabel(
              rangeRepFrameAssessment.selection.selectedSide,
            ),
            rangeRepSideSelectionReason:
                rangeRepFrameAssessment.selection.debugLabel,
            leftRangeRepCoverage:
                rangeRepFrameAssessment.selection.leftMetrics.coverageScore,
            rightRangeRepCoverage:
                rangeRepFrameAssessment.selection.rightMetrics.coverageScore,
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
                : _config.formThreshold,
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

    return _rangeRepSidePolicy.select(
      metrics: metrics,
      previousSide: _selectedRangeRepSide,
      lockPreviousSide: _shouldLockRangeRepSideSelection,
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

    return _rangeRepFramePolicy.assess(metrics: metrics, selection: selection);
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

  AnalysisFrame _buildAnalysisFrame(
    ExerciseMetrics metrics, {
    RangeRepSideMetrics? rangeRepMetrics,
  }) {
    final primaryMetric = rangeRepMetrics?.primaryAngle ?? metrics.primaryAngle;
    final formMetric = rangeRepMetrics?.formMetric ?? metrics.formMetric;

    return AnalysisFrame(
      primaryMetric: _angleFilter.process(primaryMetric),
      formMetric: _backFilter.process(formMetric),
      bodyLineAngle: _smoothOptional(metrics.bodyLineAngle, _bodyLineFilter),
      armSupportAngle: _smoothOptional(
        metrics.armSupportAngle,
        _armSupportFilter,
      ),
      legExtensionAngle: _smoothOptional(metrics.legExtensionAngle, _legFilter),
    );
  }

  double? _smoothOptional(double? value, MovingAverageFilter filter) {
    if (value == null) {
      return null;
    }

    return filter.process(value);
  }

  WorkoutState _buildBlockedRangeRepState(
    ExerciseMetrics metrics,
    RangeRepFrameAssessment assessment,
    RangeRepVisibilityAssessment visibilityAssessment,
    bool freezeSmoothedPreview,
  ) {
    final selectedMetrics = assessment.selectedMetrics;
    final formSignals = selectedMetrics?.formSignals;
    final previewAngle = _previewRangeRepMetric(
      assessment.hasPrimaryAngle,
      selectedMetrics?.primaryAngle ?? metrics.primaryAngle,
      _angleFilter,
      state.currentAngle,
      freezeSmoothedPreview,
    );
    final previewBackAngle = _previewRangeRepMetric(
      assessment.hasFormMetric,
      selectedMetrics?.formMetric ?? metrics.formMetric,
      _backFilter,
      state.calibrationMetrics.currentBackAngle,
      freezeSmoothedPreview,
    );

    return WorkoutState(
      landmarks: metrics.landmarks,
      analysisKind: _engineKind,
      repCount: state.repCount,
      isFormBad: false,
      currentAngle: previewAngle,
      lastRepScore: state.lastRepScore,
      lastRepROM: state.lastRepROM,
      currentHoldSeconds: state.currentHoldSeconds,
      bestHoldSeconds: state.bestHoldSeconds,
      isHolding: state.isHolding,
      hadHoldFormBreak: state.hadHoldFormBreak,
      feedbackMessage: assessment.feedbackMessage,
      currentPhase: 'WAITING',
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
      calibrationMetrics: _buildCalibrationMetrics(
        currentFormMetric: previewBackAngle,
        thresholdValue: _config.formThreshold,
        currentTorsoAngle: formSignals?.torsoAngle,
        currentDepthMetric: formSignals?.depthMetric,
        currentAlignmentMetric: formSignals?.alignmentMetric,
        currentStabilityMetric: formSignals?.stabilityMetric,
        currentLockoutMetric: formSignals?.lockoutMetric,
        currentBottomControlMetric: formSignals?.bottomControlMetric,
        isRangeRepFrameValid: false,
        hasPrimaryAngle: assessment.hasPrimaryAngle,
        hasFormMetric: assessment.hasFormMetric,
        rangeRepInvalidReason: assessment.invalidReason,
        selectedRangeRepSide: _rangeRepSideLabel(
          assessment.selection.selectedSide,
        ),
        rangeRepSideSelectionReason: assessment.selection.debugLabel,
        leftRangeRepCoverage: assessment.selection.leftMetrics.coverageScore,
        rightRangeRepCoverage: assessment.selection.rightMetrics.coverageScore,
        rangeRepInvalidFrameStreak: visibilityAssessment.invalidFrameStreak,
        rangeRepInvalidDurationMs:
            visibilityAssessment.invalidDuration.inMilliseconds,
        rangeRepResyncTriggered: visibilityAssessment.hasResyncedCurrentRun,
        rangeRepResyncReason: visibilityAssessment.resyncReason,
        rangeRepVisibilityStatus: visibilityAssessment.statusLabel,
      ),
    );
  }

  double _previewRangeRepMetric(
    bool hasSignal,
    double value,
    MovingAverageFilter filter,
    double fallback,
    bool freezePreview,
  ) {
    if (freezePreview || !hasSignal) {
      return fallback;
    }

    return filter.process(value);
  }

  double _currentAngleForState(AnalysisFrame frame) {
    return frame.bodyLineAngle ?? frame.primaryMetric;
  }

  WorkoutCalibrationMetrics _buildCalibrationMetrics({
    required double currentFormMetric,
    required double thresholdValue,
    bool isRangeRepFrameValid = true,
    bool hasPrimaryAngle = false,
    bool hasFormMetric = false,
    RangeRepFrameInvalidReason? rangeRepInvalidReason,
    String? selectedRangeRepSide,
    String? rangeRepSideSelectionReason,
    int leftRangeRepCoverage = 0,
    int rightRangeRepCoverage = 0,
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
    final lastValidationResult = _lastRangeRepValidationResult;
    final lastSummaryCandidate = _lastRangeRepRepSummaryCandidate;

    // Calibration telemetry surfaces the active engine's current secondary metric.
    return WorkoutCalibrationMetrics(
      currentBackAngle: currentFormMetric,
      formThreshold: thresholdValue,
      isRangeRepFrameValid: isRangeRepFrameValid,
      hasPrimaryAngle: hasPrimaryAngle,
      hasFormMetric: hasFormMetric,
      rangeRepInvalidReason: rangeRepInvalidReason?.debugLabel,
      selectedRangeRepSide: selectedRangeRepSide,
      rangeRepSideSelectionReason: rangeRepSideSelectionReason,
      leftRangeRepCoverage: leftRangeRepCoverage,
      rightRangeRepCoverage: rightRangeRepCoverage,
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
      currentRepWorstBackAngle: diagnostics.currentRepWorstBackAngle,
      currentRepHadFormViolation: diagnostics.currentRepHadFormViolation,
      rangeRepPhaseGateStatus: diagnostics.phaseGateStatus,
      rangeRepPendingTransition: diagnostics.pendingTransitionLabel,
      rangeRepLastConfirmedTransition: diagnostics.lastConfirmedTransitionLabel,
      rangeRepInvalidFrameStreak: rangeRepInvalidFrameStreak,
      rangeRepInvalidDurationMs: rangeRepInvalidDurationMs,
      rangeRepResyncTriggered: rangeRepResyncTriggered,
      rangeRepResyncReason: rangeRepResyncReason,
      rangeRepVisibilityStatus: rangeRepVisibilityStatus,
      descendingPhaseDurationMs: diagnostics.descendingPhaseQuality.hasData
          ? diagnostics.descendingPhaseQuality.durationMs
          : null,
      peakPhaseDurationMs: diagnostics.peakPhaseQuality.hasData
          ? diagnostics.peakPhaseQuality.durationMs
          : null,
      ascendingPhaseDurationMs: diagnostics.ascendingPhaseQuality.hasData
          ? diagnostics.ascendingPhaseQuality.durationMs
          : null,
      descendingPhaseWorstFormMetric:
          diagnostics.descendingPhaseQuality.hasData
          ? diagnostics.descendingPhaseQuality.worstFormMetric
          : null,
      peakPhaseWorstFormMetric: diagnostics.peakPhaseQuality.hasData
          ? diagnostics.peakPhaseQuality.worstFormMetric
          : null,
      ascendingPhaseWorstFormMetric: diagnostics.ascendingPhaseQuality.hasData
          ? diagnostics.ascendingPhaseQuality.worstFormMetric
          : null,
      descendingPhaseHadFormViolation:
          diagnostics.descendingPhaseQuality.hasData
          ? diagnostics.descendingPhaseQuality.hadFormViolation
          : false,
      peakPhaseHadFormViolation: diagnostics.peakPhaseQuality.hasData
          ? diagnostics.peakPhaseQuality.hadFormViolation
          : false,
      ascendingPhaseHadFormViolation: diagnostics.ascendingPhaseQuality.hasData
          ? diagnostics.ascendingPhaseQuality.hadFormViolation
          : false,
      descendingPhaseStatus:
          diagnostics.descendingPhaseAssessment.status.debugLabel,
      peakPhaseStatus: diagnostics.peakPhaseAssessment.status.debugLabel,
      ascendingPhaseStatus: diagnostics.ascendingPhaseAssessment.status.debugLabel,
      descendingPhaseIssues: diagnostics.descendingPhaseAssessment.issues
          .map((issue) => issue.debugLabel)
          .toList(growable: false),
      peakPhaseIssues: diagnostics.peakPhaseAssessment.issues
          .map((issue) => issue.debugLabel)
          .toList(growable: false),
      ascendingPhaseIssues: diagnostics.ascendingPhaseAssessment.issues
          .map((issue) => issue.debugLabel)
          .toList(growable: false),
      phaseQualityPenaltyCandidate: lastBreakdown?.phaseQualityPenaltyCandidate,
      phaseInformedScoreCandidate: lastBreakdown?.phaseInformedScoreCandidate,
      phaseFeedbackCandidate: diagnostics.phaseFeedbackCandidate,
      hasLastRangeRepValidation: lastValidationResult != null,
      lastRangeRepValidationStatus: lastValidationResult?.status.debugLabel,
      lastRangeRepValidationReasons: lastValidationResult == null
          ? const <String>[]
          : lastValidationResult.reasons
                .map((reason) => reason.debugLabel)
                .toList(growable: false),
      lastRangeRepValidatedRepIndex: _lastRangeRepValidatedRepIndex,
      rangeRepValidatedCount: _rangeRepValidatedCount,
      rangeRepLowConfidenceCount: _rangeRepLowConfidenceCount,
      rangeRepInvalidCount: _rangeRepInvalidCount,
      hasLastRangeRepSummary: lastSummaryCandidate != null,
      lastRangeRepSummaryMinAngle: lastSummaryCandidate?.minAngle,
      lastRangeRepSummaryWorstFormMetric:
          lastSummaryCandidate?.worstFormMetric,
      lastRangeRepSummaryDescentMillis:
          lastSummaryCandidate?.descentDuration.inMilliseconds,
      lastRangeRepSummaryAscentMillis:
          lastSummaryCandidate?.ascentDuration.inMilliseconds,
      lastRangeRepSummaryHadFormViolation:
          lastSummaryCandidate?.hadFormViolation ?? false,
      lastRangeRepSummaryHadCoverageDrop:
          lastSummaryCandidate?.hadCoverageDrop ?? false,
      lastRangeRepSummarySwitchedSideDuringRep:
          lastSummaryCandidate?.switchedSideDuringRep ?? false,
      lastRangeRepSummaryCompletedPhaseSequence:
          lastSummaryCandidate?.completedPhaseSequence ?? false,
      lastRangeRepSummarySelectedSideLabel:
          lastSummaryCandidate?.selectedSideLabel,
      hasLastRepBreakdown: lastBreakdown != null,
      lastRepRomScore: lastBreakdown?.romScore ?? 0,
      lastRepDescentScore: lastBreakdown?.descentScore ?? 0,
      lastRepAscentScoreCandidate: lastBreakdown?.ascentScoreCandidate ?? 0,
      lastRepWorstBackAngle: lastBreakdown?.worstBackAngle ?? 0,
      lastRepHadFormViolation: lastBreakdown?.hadFormViolation ?? false,
    );
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
    if (_engineKind != EngineKind.rangeRep ||
        !_isRangeRepRepContextActive(diagnostics)) {
      return;
    }

    if (markCoverageDrop) {
      _activeRangeRepHadCoverageDrop = true;
    }

    final selectedSideLabel = _rangeRepSideLabel(selectedSide);
    if (selectedSideLabel == null) {
      return;
    }

    if (_activeRangeRepSelectedSideLabel != null &&
        _activeRangeRepSelectedSideLabel != selectedSideLabel) {
      _activeRangeRepSwitchedSideDuringRep = true;
    }

    _activeRangeRepSelectedSideLabel = selectedSideLabel;
  }

  void _assembleRangeRepRepSummaryCandidateIfNeeded({
    required int previousRepCount,
    required RangeRepDiagnosticsSnapshot diagnostics,
  }) {
    if (_engineKind != EngineKind.rangeRep ||
        _engine.repCount <= previousRepCount) {
      return;
    }

    final coreData = diagnostics.lastCompletedRepCoreData;
    if (coreData == null) {
      _resetRangeRepRepSummaryContext();
      return;
    }

    final summaryCandidate = RangeRepRepSummary(
      repIndex: coreData.repIndex,
      minAngle: coreData.minAngle,
      worstFormMetric: coreData.worstFormMetric,
      descentDuration: coreData.descentDuration,
      ascentDuration: coreData.ascentDuration,
      hadFormViolation: coreData.hadFormViolation,
      hadCoverageDrop: _activeRangeRepHadCoverageDrop,
      switchedSideDuringRep: _activeRangeRepSwitchedSideDuringRep,
      completedPhaseSequence: coreData.completedPhaseSequence,
      selectedSideLabel: _activeRangeRepSelectedSideLabel,
      analysisKindLabel: _engineKind.name,
    );
    _lastRangeRepRepSummaryCandidate = summaryCandidate;
    _lastRangeRepValidationResult = _rangeRepValidationPolicy.evaluate(
      summaryCandidate,
    );
    _recordRangeRepValidationOutcome(_lastRangeRepValidationResult!);
    _lastRangeRepValidatedRepIndex = summaryCandidate.repIndex;
    _resetRangeRepRepSummaryContext();
  }

  void _recordRangeRepValidationOutcome(RangeRepValidationResult result) {
    switch (result.status) {
      case RangeRepValidationStatus.valid:
        _rangeRepValidatedCount += 1;
        break;
      case RangeRepValidationStatus.lowConfidence:
        _rangeRepLowConfidenceCount += 1;
        break;
      case RangeRepValidationStatus.invalid:
        _rangeRepInvalidCount += 1;
        break;
    }
  }

  void _resetRangeRepRepSummaryContextIfCycleEnded({
    required RangeRepDiagnosticsSnapshot previousDiagnostics,
    required RangeRepDiagnosticsSnapshot currentDiagnostics,
    required bool didCompleteRep,
  }) {
    if (didCompleteRep ||
        !_isRangeRepRepContextActive(previousDiagnostics) ||
        _isRangeRepRepContextActive(currentDiagnostics)) {
      return;
    }

    _resetRangeRepRepSummaryContext();
  }

  void _resetRangeRepRepSummaryContext({bool clearCandidate = false}) {
    _activeRangeRepHadCoverageDrop = false;
    _activeRangeRepSwitchedSideDuringRep = false;
    _activeRangeRepSelectedSideLabel = null;
    if (clearCandidate) {
      _lastRangeRepRepSummaryCandidate = null;
      _lastRangeRepValidationResult = null;
      _lastRangeRepValidatedRepIndex = null;
    }
  }

  bool _isRangeRepRepContextActive(RangeRepDiagnosticsSnapshot diagnostics) {
    return diagnostics.hasActiveRepPhase || diagnostics.hasPendingTransition;
  }

  bool get _shouldLockRangeRepSideSelection {
    return shouldLockRangeRepSideSelection(
      engineKind: _engineKind,
      selectedSide: _selectedRangeRepSide,
      diagnostics: _rangeRepDiagnosticsSnapshot(),
    );
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
    _resetRangeRepRepSummaryContext();
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
