import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/moving_average.dart';
import '../../application/analysis_frame_builder.dart';
import '../../application/analysis_engine_factory.dart';
import '../../application/calibration_snapshot_builder.dart';
import '../../application/engine_kind.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_metrics.dart';
import '../../application/exercise_metrics_extractor.dart';
import '../../application/hold_side_policy.dart';
import '../../application/hold_side_stabilizer.dart';
import '../../application/pose_acceptance_stabilizer.dart';
import '../../application/pose_quality_policy.dart';
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
import '../../application/workout_diagnostics.dart';
import '../../domain/analysis_engine.dart';
import '../../domain/hold_diagnostics.dart';
import '../../domain/models/analysis_frame.dart';
import '../../domain/models/calibration_snapshot.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/hold_contract.dart';
import '../../domain/models/hold_side.dart';
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

final workoutClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
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

  return diagnostics.hasRepContext;
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
  late final DateTime Function() _clock;
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
  late final HoldContract? _holdContract;
  final AnalysisEngineFactory _engineFactory = const AnalysisEngineFactory();
  final CalibrationSnapshotBuilder _calibrationSnapshotBuilder =
      const CalibrationSnapshotBuilder();
  final WorkoutCalibrationMetricsBuilder _workoutCalibrationMetricsBuilder =
      const WorkoutCalibrationMetricsBuilder();
  final ExerciseCatalog _exerciseCatalog = const ExerciseCatalog();
  final ExerciseMetricsExtractor _metricsExtractor =
      const ExerciseMetricsExtractor();
  final PoseQualityPolicy _poseQualityPolicy = const PoseQualityPolicy();
  final RangeRepFramePolicy _rangeRepFramePolicy = const RangeRepFramePolicy();
  final RangeRepSidePolicy _rangeRepSidePolicy = const RangeRepSidePolicy();
  late RangeRepThresholdBookkeeper _rangeRepThresholdBookkeeper;
  late final RangeRepVisibilityPolicy _rangeRepVisibilityPolicy;
  late PoseAcceptanceStabilizer _poseAcceptanceStabilizer;
  final RangeRepValidationPolicy _rangeRepValidationPolicy =
      const RangeRepValidationPolicy();
  final InputImageConverter _inputImageConverter = const InputImageConverter();
  RangeRepSide? _selectedRangeRepSide;
  RangeRepSide? _briefGapFrozenRangeRepSide;
  HoldSide? _selectedHoldSide;
  HoldSide? _briefGapFrozenHoldSide;
  bool _hasAcceptedPoseForAnalysis = false;
  late RangeRepSideStabilizer _rangeRepSideStabilizer;
  late HoldSideStabilizer _holdSideStabilizer;
  late RangeRepRepOutcomeTracker _rangeRepRepOutcomeTracker;
  CalibrationSnapshot? _lastCalibrationSnapshot;
  SessionCalibrationBaseline? _sessionCalibrationBaseline;
  late SessionCalibrationBaselineAccumulator
  _sessionCalibrationBaselineAccumulator;
  late WorkoutDiagnosticsAccumulator _diagnostics;

  @override
  WorkoutState build() {
    // Recreating this provider starts a fresh analysis session and filter state.
    ref.watch(poseDetectorProvider);
    _clock = ref.watch(workoutClockProvider);

    final activeExercise = ref.watch(activeAnalysisExerciseProvider);
    if (activeExercise == null) {
      throw StateError('No active analysis exercise selected.');
    }

    final definition = _exerciseCatalog.definitionFor(activeExercise);
    _engineKind = definition.analysisEngineKind;
    _rangeRepContract = _engineKind == EngineKind.rangeRep
        ? definition.analysisRangeRepContract
        : null;
    _holdContract = _engineKind == EngineKind.hold
        ? definition.analysisHoldContract
        : null;
    _config = ref.watch(exerciseConfigProvider).requireValue;
    _engine = _engineFactory.create(
      engineKind: _engineKind,
      config: _config,
      rangeRepContract: _rangeRepContract,
      holdContract: _holdContract,
      now: _clock,
    );

    _angleFilter = MovingAverageFilter(windowSize: 5);
    _backFilter = MovingAverageFilter(windowSize: 5);
    _bodyLineFilter = MovingAverageFilter(windowSize: 5);
    _armSupportFilter = MovingAverageFilter(windowSize: 5);
    _legFilter = MovingAverageFilter(windowSize: 5);

    _lastFpsCalculationTime = _clock();
    _cameraFrameCount = 0;
    _analysisFrameCount = 0;
    _cameraFps = 0.0;
    _analysisFps = 0.0;
    _lastAnalysisStartedAt = null;
    _selectedRangeRepSide = null;
    _briefGapFrozenRangeRepSide = null;
    _selectedHoldSide = null;
    _briefGapFrozenHoldSide = null;
    _hasAcceptedPoseForAnalysis = false;
    _rangeRepSideStabilizer = RangeRepSideStabilizer();
    _holdSideStabilizer = HoldSideStabilizer();
    _rangeRepVisibilityPolicy = RangeRepVisibilityPolicy();
    _poseAcceptanceStabilizer = PoseAcceptanceStabilizer();
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
    _diagnostics = WorkoutDiagnosticsAccumulator(
      sessionStartedAt: _clock(),
      analysisKind: _engineKind.name,
    );

    final initialState = WorkoutState(
      analysisKind: _engineKind,
      feedbackMessage: _resolvedEngineFeedbackMessage(),
      currentPhase: _engine.phaseLabel,
      selectedHoldSide: null,
    );
    _diagnostics.updateWorkoutState(
      repCount: initialState.repCount,
      currentHoldSeconds: initialState.currentHoldSeconds.round(),
      bestHoldSeconds: initialState.bestHoldSeconds.round(),
      currentPhase: initialState.currentPhase,
      isHolding: initialState.isHolding,
    );
    return initialState;
  }

  /// Processes one camera frame and publishes the latest live telemetry.
  Future<void> processCameraImage(
    CameraImage image,
    int sensorOrientation,
  ) async {
    final now = _clock();
    if (_isDiagnosticsEnabled) _diagnostics.recordCameraFrame();
    _cameraFrameCount++;
    _updateFpsIfNeeded();

    if (_isProcessing) {
      if (_isDiagnosticsEnabled) _diagnostics.recordReentrantDrop();
      return;
    }
    // Keep ML Kit work below camera FPS so preview rendering stays responsive.
    if (_lastAnalysisStartedAt != null &&
        now.difference(_lastAnalysisStartedAt!) < _analysisFrameInterval) {
      if (_isDiagnosticsEnabled) _diagnostics.recordThrottledFrame();
      return;
    }

    _lastAnalysisStartedAt = now;
    _isProcessing = true;
    final processingStartedAt = now;
    if (_isDiagnosticsEnabled) _diagnostics.recordAnalysisAttempt();

    try {
      final inputImage = _inputImageConverter.convert(image, sensorOrientation);
      if (inputImage == null) {
        if (_isDiagnosticsEnabled) {
          _diagnostics.recordConverterDrop();
          _diagnostics.recordProcessingDuration(
            DateTime.now().difference(processingStartedAt),
          );
        }
        _isProcessing = false;
        return;
      }
      await _processInputImageForAnalysis(
        inputImage,
        frameCapturedAt: now,
        processingStartedAt: processingStartedAt,
      );
      if (_isDiagnosticsEnabled) {
        _diagnostics.updateLivePerformance(
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
        );
      }
    } catch (e) {
      if (_isDiagnosticsEnabled) {
        _diagnostics.recordAnalysisException();
        _diagnostics.recordProcessingDuration(
          _clock().difference(processingStartedAt),
        );
      }
      debugPrint("ANALIZ HATASI: $e");
    } finally {
      _isProcessing = false;
    }
  }

  @visibleForTesting
  Future<void> processInputImageForAnalysis(InputImage inputImage) async {
    final now = _clock();
    if (_isDiagnosticsEnabled) _diagnostics.recordAnalysisAttempt();

    try {
      await _processInputImageForAnalysis(
        inputImage,
        frameCapturedAt: now,
        processingStartedAt: now,
      );
      if (_isDiagnosticsEnabled) {
        _diagnostics.updateLivePerformance(
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
        );
      }
    } catch (e) {
      if (_isDiagnosticsEnabled) {
        _diagnostics.recordAnalysisException();
        _diagnostics.recordProcessingDuration(_clock().difference(now));
      }
      rethrow;
    }
  }

  Future<void> _processInputImageForAnalysis(
    InputImage inputImage, {
    required DateTime frameCapturedAt,
    required DateTime processingStartedAt,
  }) async {
    final detector = ref.read(poseDetectorProvider);
    final poses = await detector.processImage(inputImage);
    if (_isDiagnosticsEnabled) _diagnostics.recordPoseCount(poses.length);
    _analysisFrameCount++;
    _updateFpsIfNeeded();

    final detectedFrame = _evaluateDetectedPoses(poses);
    _processExerciseMetrics(
      metrics: detectedFrame.metrics,
      now: frameCapturedAt,
      frameKind: detectedFrame.kind,
      didBecomeStableTracking: detectedFrame.didBecomeStableTracking,
      qualityAcceptedRangeRepSides: detectedFrame.qualityAcceptedRangeRepSides,
      preferredRangeRepSide: detectedFrame.preferredRangeRepSide,
    );

    if (_isDiagnosticsEnabled) {
      _diagnostics.recordAnalysisCompleted();
      _diagnostics.recordProcessingDuration(
        _clock().difference(processingStartedAt),
      );
    }
  }

  _DetectedPoseFrame _evaluateDetectedPoses(List<Pose> poses) {
    if (poses.isEmpty) {
      _poseAcceptanceStabilizer.recordInvalidFrame();
      if (_isDiagnosticsEnabled) {
        _diagnostics.updatePoseQualityStatus(status: 'no_pose');
      }
      return const _DetectedPoseFrame(
        metrics: ExerciseMetrics.noPose(),
        kind: _PoseFrameKind.noPose,
      );
    }

    final candidates = <_SelectedPoseCandidate>[];
    final requiredHoldSide = _requiredHoldSideForAssessment();
    for (var index = 0; index < poses.length; index++) {
      final pose = poses[index];
      final assessment = _poseQualityPolicy.assess(
        pose: pose,
        config: _config,
        engineKind: _engineKind,
        rangeRepContract: _rangeRepContract,
        holdContract: _holdContract,
        requiredHoldSide: requiredHoldSide,
      );
      candidates.add(
        _SelectedPoseCandidate(
          detectorIndex: index,
          pose: pose,
          assessment: assessment,
        ),
      );
    }

    final selectedCandidate = _selectDetectedPoseCandidate(candidates);

    if (selectedCandidate == null || !selectedCandidate.assessment.isAccepted) {
      final assessment = selectedCandidate?.assessment;
      _poseAcceptanceStabilizer.recordInvalidFrame();
      if (_isDiagnosticsEnabled && assessment?.rejectionReason != null) {
        final rejectionReason = assessment!.rejectionReason!;
        _diagnostics.recordRejectedPose(
          rejectionReasonCode: rejectionReason.code,
        );
        if (rejectionReason.isLowConfidence) {
          _diagnostics.recordLowConfidencePose();
        }
        if (rejectionReason.isGeometryFailure) {
          _diagnostics.recordInvalidPoseGeometry();
        }
        _diagnostics.updatePoseQualityStatus(
          status: 'rejected',
          lastRejectionReason: rejectionReason.code,
        );
      }
      return const _DetectedPoseFrame(
        metrics: ExerciseMetrics.noPose(),
        kind: _PoseFrameKind.rejected,
      );
    }

    final acceptance = _poseAcceptanceStabilizer.recordAcceptedFrame();
    if (!acceptance.shouldAcceptForAnalysis) {
      if (_isDiagnosticsEnabled) {
        _diagnostics.updatePoseQualityStatus(
          status: 'accepted_pending_stabilization',
        );
      }
      return const _DetectedPoseFrame(
        metrics: ExerciseMetrics.noPose(),
        kind: _PoseFrameKind.pendingAcceptance,
      );
    }

    if (_isDiagnosticsEnabled) {
      _diagnostics.updatePoseQualityStatus(status: 'accepted');
    }

    return _DetectedPoseFrame(
      metrics: _metricsExtractor.extract(
        selectedCandidate.pose,
        _config,
        engineKind: _engineKind,
        rangeRepContract: _rangeRepContract,
        holdContract: _holdContract,
        holdSide: _engineKind == EngineKind.hold
            ? _selectHoldSideForAcceptedPose(selectedCandidate.assessment)
            : null,
      ),
      kind: _PoseFrameKind.accepted,
      didBecomeStableTracking: acceptance.didBecomeStable,
      qualityAcceptedRangeRepSides:
          selectedCandidate.assessment.acceptedRangeRepSides,
      preferredRangeRepSide: selectedCandidate.assessment.preferredRangeRepSide,
    );
  }

  _SelectedPoseCandidate? _selectDetectedPoseCandidate(
    List<_SelectedPoseCandidate> candidates,
  ) {
    if (candidates.isEmpty) {
      return null;
    }

    final acceptedCandidates = candidates
        .where((candidate) => candidate.assessment.isAccepted)
        .toList(growable: false);
    final selectionPool = acceptedCandidates.isNotEmpty
        ? acceptedCandidates
        : candidates;

    return selectionPool.reduce(_preferDetectedPoseCandidate);
  }

  _SelectedPoseCandidate _preferDetectedPoseCandidate(
    _SelectedPoseCandidate current,
    _SelectedPoseCandidate candidate,
  ) {
    final scoreComparison = candidate.assessment.qualityScore.compareTo(
      current.assessment.qualityScore,
    );
    if (scoreComparison > 0) {
      return candidate;
    }
    if (scoreComparison < 0) {
      return current;
    }

    final landmarkComparison = candidate.assessment.acceptedLandmarkCount
        .compareTo(current.assessment.acceptedLandmarkCount);
    if (landmarkComparison > 0) {
      return candidate;
    }
    if (landmarkComparison < 0) {
      return current;
    }

    return candidate.detectorIndex < current.detectorIndex
        ? candidate
        : current;
  }

  bool get _isDiagnosticsEnabled => kDebugMode || kProfileMode;

  WorkoutDiagnosticsSnapshot diagnosticsSnapshot({DateTime? now}) {
    return _diagnostics.snapshot(now: now ?? _clock());
  }

  void resetDiagnostics({DateTime? now}) {
    _diagnostics.reset(now: now ?? _clock(), analysisKind: _engineKind.name);
    if (_isDiagnosticsEnabled) {
      _diagnostics.recordSelectedSide(
        selectedSide: _rangeRepSideLabel(_selectedRangeRepSide),
        hasActiveRepContext: _isRangeRepRepContextActive(
          _rangeRepDiagnosticsSnapshot(),
        ),
      );
      _updateDiagnosticsFromState();
    }
  }

  @visibleForTesting
  void processExerciseMetricsForTesting({
    required ExerciseMetrics metrics,
    required DateTime now,
  }) {
    _processExerciseMetrics(metrics: metrics, now: now);
  }

  void _processExerciseMetrics({
    required ExerciseMetrics metrics,
    required DateTime now,
    _PoseFrameKind frameKind = _PoseFrameKind.accepted,
    bool didBecomeStableTracking = false,
    Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    RangeRepSide? preferredRangeRepSide,
  }) {
    final hadAcceptedPoseForAnalysis = _hasAcceptedPoseForAnalysis;
    final preUpdateRangeRepDiagnostics = _rangeRepDiagnosticsSnapshot();
    final preUpdateHoldDiagnostics = _engineKind == EngineKind.hold
        ? _holdDiagnosticsSnapshot()
        : null;
    final effectiveMetrics = _effectiveMetricsForAnalysis(
      metrics: metrics,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
      preferredRangeRepSide: preferredRangeRepSide,
    );
    final visibilityRunActive =
        _engineKind == EngineKind.rangeRep &&
        _rangeRepVisibilityPolicy.hasActiveInvalidRun;
    final rangeRepSideSelection = _selectRangeRepSideForFrame(
      metrics: effectiveMetrics,
      diagnostics: preUpdateRangeRepDiagnostics,
      visibilityRunActive: visibilityRunActive,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
    );
    final rangeRepFrameAssessment = _rangeRepFrameAssessment(
      effectiveMetrics,
      rangeRepSideSelection,
    );
    final isAcceptedPoseFrame = frameKind == _PoseFrameKind.accepted;
    final isEngineEligibleFrame =
        isAcceptedPoseFrame &&
        (_engineKind != EngineKind.rangeRep ||
            rangeRepFrameAssessment.shouldUpdateEngine);

    if (_engineKind == EngineKind.rangeRep && !isEngineEligibleFrame) {
      if (isAcceptedPoseFrame) {
        _poseAcceptanceStabilizer.recordInvalidFrame();
      }
      final rangeRepVisibilityAssessment = _rangeRepVisibilityAssessment(
        isInvalidFrame: true,
        now: now,
      );
      if (rangeRepVisibilityAssessment.didStartInvalidRun) {
        _beginBriefVisibilityGap(preUpdateRangeRepDiagnostics);
      }
      _trackRangeRepRepContext(
        diagnostics: preUpdateRangeRepDiagnostics,
        selectedSide: _briefGapFrozenRangeRepSide,
        markCoverageDrop: true,
      );
      if (rangeRepVisibilityAssessment.shouldResync) {
        if (_isDiagnosticsEnabled) _diagnostics.recordResync();
        _resetRangeRepVisibilityResyncState(
          reason: rangeRepVisibilityAssessment.resyncReason,
        );
        final selectedRangeRepSide = _rangeRepSideLabel(_selectedRangeRepSide);
        state = _rangeRepBlockedStateBuilder.build(
          metrics: effectiveMetrics,
          assessment: rangeRepFrameAssessment,
          freezeSmoothedPreview: true,
          primaryMetricFilter: _angleFilter,
          formMetricFilter: _backFilter,
          currentState: state,
          analysisKind: _engineKind,
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          selectedRangeRepSide: selectedRangeRepSide,
          feedbackMessageOverride: _resolvedEngineFeedbackMessage(),
          currentPhase: _engine.phaseLabel,
          calibrationMetricsBuilder: (preview) {
            final formThresholdResolution = _rangeRepThresholdBookkeeper
                .resolve(
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
              effectiveFormThreshold:
                  formThresholdResolution.effectiveThreshold,
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
        _recordSelectedSideForDiagnostics(preUpdateRangeRepDiagnostics);
        if (_isDiagnosticsEnabled) {
          _diagnostics.updateVisibilityStatus('hard_resync');
        }
        _updateDiagnosticsFromState();
        return;
      }
      final selectedRangeRepSide = _rangeRepSideLabel(
        _briefGapFrozenRangeRepSide ?? _selectedRangeRepSide,
      );
      state = _rangeRepBlockedStateBuilder.build(
        metrics: effectiveMetrics,
        assessment: rangeRepFrameAssessment,
        freezeSmoothedPreview: true,
        primaryMetricFilter: _angleFilter,
        formMetricFilter: _backFilter,
        currentState: state,
        analysisKind: _engineKind,
        cameraFps: _cameraFps,
        analysisFps: _analysisFps,
        selectedRangeRepSide: selectedRangeRepSide,
        feedbackMessageOverride: mapRangeRepFeedbackCodeToMessage(
          RangeRepFeedbackCode.bodyNotVisible,
        ),
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
            rangeRepVisibilityStatus: rangeRepVisibilityAssessment.statusLabel,
          );
        },
      );
      _recordSelectedSideForDiagnostics(preUpdateRangeRepDiagnostics);
      if (_isDiagnosticsEnabled) {
        _diagnostics.updateVisibilityStatus(
          rangeRepVisibilityAssessment.statusLabel,
        );
      }
      _updateDiagnosticsFromState();
      return;
    }

    if (!isEngineEligibleFrame) {
      if (_engineKind == EngineKind.hold) {
        final lockedHoldSide = _requiredHoldSideForAssessment();
        if (lockedHoldSide != null) {
          _beginHoldVisibilityGap();
        } else {
          _resetHoldSideSelection();
        }
      }
      if (_isDiagnosticsEnabled) {
        _diagnostics.updateVisibilityStatus('invalid_input');
      }
      final holdDiagnostics = _engineKind == EngineKind.hold
          ? _holdDiagnosticsSnapshot()
          : null;
      final formThresholdResolution = _engineKind == EngineKind.rangeRep
          ? _rangeRepThresholdBookkeeper.resolve(
              baseThreshold: _config.formThreshold,
              sessionCalibrationBaseline: _sessionCalibrationBaseline,
              selectedRangeRepSide: null,
            )
          : null;
      state = WorkoutState(
        landmarks: effectiveMetrics.landmarks,
        analysisKind: _engineKind,
        repCount: state.repCount,
        isFormBad: false,
        currentAngle: effectiveMetrics.primaryAngle,
        lastRepScore: state.lastRepScore,
        lastRepROM: state.lastRepROM,
        currentHoldSeconds: holdDiagnostics?.isVisibilitySuspended == true
            ? holdDiagnostics!.currentHoldSeconds
            : 0,
        bestHoldSeconds:
            holdDiagnostics?.bestHoldSeconds ?? state.bestHoldSeconds,
        selectedHoldSide: _currentHoldSideForState(),
        isHolding: false,
        isHoldVisibilitySuspended:
            holdDiagnostics?.isVisibilitySuspended ?? false,
        hadHoldFormBreak:
            holdDiagnostics?.hadFormBreak ?? state.hadHoldFormBreak,
        feedbackMessage: mapRangeRepFeedbackCodeToMessage(
          RangeRepFeedbackCode.bodyNotVisible,
        ),
        currentPhase: "WAITING",
        cameraFps: _cameraFps,
        analysisFps: _analysisFps,
        calibrationMetrics: _buildCalibrationMetrics(
          currentFormMetric: effectiveMetrics.formMetric,
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
      _updateDiagnosticsFromState();
      return;
    }

    if (_engineKind == EngineKind.hold) {
      final holdGapResult = _resumeHoldVisibilityGap();
      if (holdGapResult.disposition == HoldVisibilityResumeDisposition.ended) {
        final holdDiagnostics = _holdDiagnosticsSnapshot();
        _resetHoldSideSelection();
        if (_isDiagnosticsEnabled) {
          if (didBecomeStableTracking && _hasAcceptedPoseForAnalysis) {
            _diagnostics.recordPoseReacquisition();
          }
          _diagnostics.recordAcceptedPoseFrame();
          _diagnostics.updateVisibilityStatus('stable');
        }
        state = WorkoutState(
          landmarks: effectiveMetrics.landmarks,
          analysisKind: _engineKind,
          repCount: _engine.repCount,
          isFormBad: _engine.isFormBad,
          currentAngle: effectiveMetrics.primaryAngle,
          lastRepScore: _engine.lastRepScore,
          lastRepROM: _engine.maxRom,
          currentHoldSeconds: 0,
          bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
          selectedHoldSide: null,
          isHolding: false,
          isHoldVisibilitySuspended: false,
          hadHoldFormBreak: holdDiagnostics.hadFormBreak,
          feedbackMessage: _resolvedEngineFeedbackMessage(),
          currentPhase: _engine.phaseLabel,
          cameraFps: _cameraFps,
          analysisFps: _analysisFps,
          calibrationMetrics: _buildCalibrationMetrics(
            currentFormMetric: effectiveMetrics.formMetric,
            thresholdValue: holdDiagnostics.bodyLineTargetAngle,
            currentBodyLineAngle: effectiveMetrics.bodyLineAngle,
            currentArmSupportAngle: effectiveMetrics.armSupportAngle,
            currentLegExtensionAngle: effectiveMetrics.legExtensionAngle,
          ),
        );
        _hasAcceptedPoseForAnalysis = true;
        _updateDiagnosticsFromState();
        return;
      }

      if (holdGapResult.disposition ==
              HoldVisibilityResumeDisposition.resumed ||
          holdGapResult.disposition == HoldVisibilityResumeDisposition.noGap) {
        _briefGapFrozenHoldSide = null;
      }
    }

    var rangeRepVisibilityAssessment =
        const RangeRepVisibilityAssessment.stable();

    if (_engineKind == EngineKind.rangeRep &&
        visibilityRunActive &&
        hadAcceptedPoseForAnalysis) {
      if (didBecomeStableTracking) {
        final recoveryVisibilityAssessment =
            _rangeRepRecoveryVisibilityAssessment(now: now);
        if (recoveryVisibilityAssessment.shouldResync) {
          if (_isDiagnosticsEnabled) {
            _diagnostics.recordResync();
            _diagnostics.updateVisibilityStatus('hard_resync');
          }
          final selectedRangeRepSide = _rangeRepSideLabel(
            _briefGapFrozenRangeRepSide ?? _selectedRangeRepSide,
          );
          _rangeRepVisibilityPolicy.reset();
          _resetRangeRepVisibilityResyncState(
            reason: recoveryVisibilityAssessment.resyncReason,
            resetPoseAcceptance: true,
            resetVisibilityPolicy: false,
          );
          state = _rangeRepBlockedStateBuilder.build(
            metrics: effectiveMetrics,
            assessment: rangeRepFrameAssessment,
            freezeSmoothedPreview: true,
            primaryMetricFilter: _angleFilter,
            formMetricFilter: _backFilter,
            currentState: state,
            analysisKind: _engineKind,
            cameraFps: _cameraFps,
            analysisFps: _analysisFps,
            selectedRangeRepSide: selectedRangeRepSide,
            feedbackMessageOverride: _resolvedEngineFeedbackMessage(),
            currentPhase: _engine.phaseLabel,
            calibrationMetricsBuilder: (preview) {
              final formThresholdResolution = _rangeRepThresholdBookkeeper
                  .resolve(
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
                effectiveFormThreshold:
                    formThresholdResolution.effectiveThreshold,
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
                rightRangeRepCoverage: rangeRepFrameAssessment
                    .selection
                    .rightMetrics
                    .coverageScore,
                leftRangeRepSideConfidence: rangeRepFrameAssessment
                    .selection
                    .leftMetrics
                    .sideConfidence,
                rightRangeRepSideConfidence: rangeRepFrameAssessment
                    .selection
                    .rightMetrics
                    .sideConfidence,
                rangeRepInvalidFrameStreak:
                    recoveryVisibilityAssessment.invalidFrameStreak,
                rangeRepInvalidDurationMs:
                    recoveryVisibilityAssessment.invalidDuration.inMilliseconds,
                rangeRepResyncTriggered:
                    recoveryVisibilityAssessment.hasResyncedCurrentRun,
                rangeRepResyncReason: recoveryVisibilityAssessment.resyncReason,
                rangeRepVisibilityStatus:
                    recoveryVisibilityAssessment.statusLabel,
              );
            },
          );
          _recordSelectedSideForDiagnostics(preUpdateRangeRepDiagnostics);
          _updateDiagnosticsFromState();
          return;
        }
      }

      final selectedRangeRepSide = _rangeRepSideLabel(
        rangeRepFrameAssessment.selection.selectedSide,
      );
      final analysisFrame = _analysisFrameBuilder.build(
        metrics: effectiveMetrics,
        rangeRepMetrics: rangeRepFrameAssessment.selectedMetrics,
        primaryMetricFilter: _angleFilter,
        formMetricFilter: _backFilter,
        bodyLineFilter: _bodyLineFilter,
        armSupportFilter: _armSupportFilter,
        legFilter: _legFilter,
      );
      final formThresholdResolution = _rangeRepThresholdBookkeeper.resolve(
        baseThreshold: _config.formThreshold,
        sessionCalibrationBaseline: _sessionCalibrationBaseline,
        selectedRangeRepSide: selectedRangeRepSide,
      );
      final engineFrame = _applyFormThresholdResolution(
        analysisFrame,
        formThresholdResolution,
      );
      if (didBecomeStableTracking) {
        final gapResumeResult = _resumeBriefVisibilityGap(engineFrame);
        if (gapResumeResult.disposition ==
            VisibilityGapResumeDisposition.incompatible) {
          if (_isDiagnosticsEnabled) {
            _diagnostics.recordBriefOcclusionAbort();
            _diagnostics.recordResync();
            _diagnostics.updateVisibilityStatus('brief_abort');
          }
          _rangeRepVisibilityPolicy.reset();
          _resetRangeRepVisibilityResyncState(
            reason: 'brief occlusion incompatible recovery',
            resetPoseAcceptance: true,
            resetVisibilityPolicy: false,
          );
          state = state.copyWith(
            repCount: _engine.repCount,
            isFormBad: _engine.isFormBad,
            lastRepScore: _engine.lastRepScore,
            lastRepROM: _engine.maxRom,
            feedbackMessage: _resolvedEngineFeedbackMessage(),
            currentPhase: _engine.phaseLabel,
          );
          _recordSelectedSideForDiagnostics(preUpdateRangeRepDiagnostics);
          _updateDiagnosticsFromState();
          return;
        }
        if (_isDiagnosticsEnabled &&
            gapResumeResult.disposition ==
                VisibilityGapResumeDisposition.compatible) {
          _diagnostics.recordBriefOcclusionRecovery();
        }
      }
      _briefGapFrozenRangeRepSide = null;
    }

    rangeRepVisibilityAssessment = _rangeRepVisibilityAssessment(
      isInvalidFrame: false,
      now: now,
    );

    if (rangeRepSideSelection.selectedSide != null &&
        !(visibilityRunActive && _briefGapFrozenRangeRepSide != null)) {
      _selectedRangeRepSide = rangeRepSideSelection.selectedSide;
    }
    if (_isDiagnosticsEnabled) {
      if (didBecomeStableTracking && _hasAcceptedPoseForAnalysis) {
        _diagnostics.recordPoseReacquisition();
      }
      _diagnostics.recordAcceptedPoseFrame();
      _diagnostics.updateVisibilityStatus(
        rangeRepVisibilityAssessment.statusLabel,
      );
    }

    if (effectiveMetrics.hasPose) {
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
        metrics: effectiveMetrics,
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
      if (_engineKind == EngineKind.hold &&
          _didHoldAttemptEndAfterUpdate(
            before: preUpdateHoldDiagnostics,
            after: holdDiagnostics,
          )) {
        _resetHoldSideSelection();
      }

      state = WorkoutState(
        landmarks: effectiveMetrics.landmarks,
        analysisKind: _engineKind,
        repCount: _engine.repCount,
        isFormBad: _engine.isFormBad,
        currentAngle: _currentAngleForState(analysisFrame),
        lastRepScore: _engine.lastRepScore,
        lastRepROM: _engine.maxRom,
        currentHoldSeconds: holdDiagnostics.currentHoldSeconds,
        bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
        selectedHoldSide: _currentHoldSideForState(),
        isHolding: holdDiagnostics.isHolding,
        isHoldVisibilitySuspended: holdDiagnostics.isVisibilitySuspended,
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
          currentBottomControlMetric: selectedFormSignals?.bottomControlMetric,
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
          hasBodyLineAngle: effectiveMetrics.bodyLineAngle != null,
          hasArmSupportAngle: effectiveMetrics.armSupportAngle != null,
          hasLegExtensionAngle: effectiveMetrics.legExtensionAngle != null,
        ),
      );
      _recordSelectedSideForDiagnostics(preUpdateRangeRepDiagnostics);
      _hasAcceptedPoseForAnalysis = true;
    } else {
      // No-pose frames should not reset session counters or last rep results.
      if (_isDiagnosticsEnabled) {
        _diagnostics.updateVisibilityStatus('invalid_input');
      }
      final formThresholdResolution = _engineKind == EngineKind.rangeRep
          ? _rangeRepThresholdBookkeeper.resolve(
              baseThreshold: _config.formThreshold,
              sessionCalibrationBaseline: _sessionCalibrationBaseline,
              selectedRangeRepSide: null,
            )
          : null;
      state = WorkoutState(
        landmarks: effectiveMetrics.landmarks,
        analysisKind: _engineKind,
        repCount: state.repCount,
        isFormBad: false,
        currentAngle: effectiveMetrics.primaryAngle,
        lastRepScore: state.lastRepScore,
        lastRepROM: state.lastRepROM,
        currentHoldSeconds: 0,
        bestHoldSeconds: state.bestHoldSeconds,
        selectedHoldSide: _currentHoldSideForState(),
        isHolding: false,
        isHoldVisibilitySuspended: false,
        hadHoldFormBreak: state.hadHoldFormBreak,
        feedbackMessage: mapRangeRepFeedbackCodeToMessage(
          RangeRepFeedbackCode.bodyNotVisible,
        ),
        currentPhase: "WAITING",
        cameraFps: _cameraFps,
        analysisFps: _analysisFps,
        calibrationMetrics: _buildCalibrationMetrics(
          currentFormMetric: effectiveMetrics.formMetric,
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
    _updateDiagnosticsFromState();
  }

  void _updateDiagnosticsFromState() {
    if (!_isDiagnosticsEnabled) return;
    _diagnostics.updateLivePerformance(
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
    );
    _diagnostics.updateWorkoutState(
      repCount: state.repCount,
      currentHoldSeconds: state.currentHoldSeconds.round(),
      bestHoldSeconds: state.bestHoldSeconds.round(),
      currentPhase: state.currentPhase,
      isHolding: state.isHolding,
      calibrationOffsetDegrees:
          state.calibrationMetrics.calibrationThresholdOffsetApplied
          ? state.calibrationMetrics.calibrationThresholdOffsetCandidate
          : null,
    );
  }

  void _updateFpsIfNeeded() {
    final now = _clock();
    final elapsedMs = now.difference(_lastFpsCalculationTime).inMilliseconds;

    if (elapsedMs < 1000) return;

    _cameraFps = _cameraFrameCount * 1000 / elapsedMs;
    _analysisFps = _analysisFrameCount * 1000 / elapsedMs;

    _cameraFrameCount = 0;
    _analysisFrameCount = 0;
    _lastFpsCalculationTime = now;

    state = state.copyWith(cameraFps: _cameraFps, analysisFps: _analysisFps);
  }

  ExerciseMetrics _effectiveMetricsForAnalysis({
    required ExerciseMetrics metrics,
    Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    RangeRepSide? preferredRangeRepSide,
  }) {
    if (_engineKind != EngineKind.rangeRep ||
        qualityAcceptedRangeRepSides == null) {
      return metrics;
    }

    return _rangeRepQualityFilteredMetrics(
      metrics: metrics,
      acceptedSides: qualityAcceptedRangeRepSides,
      preferredSide: preferredRangeRepSide,
    );
  }

  HoldSide? _requiredHoldSideForAssessment() {
    if (_engineKind != EngineKind.hold) {
      return null;
    }

    final selectedHoldSide = _briefGapFrozenHoldSide ?? _selectedHoldSide;
    if (selectedHoldSide == null) {
      return null;
    }

    final diagnostics = _holdDiagnosticsSnapshot();
    if (!shouldLockHoldSideSelection(
      engineKind: _engineKind,
      selectedSide: selectedHoldSide,
      diagnostics: diagnostics,
    )) {
      return null;
    }

    return selectedHoldSide;
  }

  HoldSide _selectHoldSideForAcceptedPose(PoseQualityAssessment assessment) {
    if (_engineKind != EngineKind.hold) {
      throw StateError('Hold side selection is only valid for hold analysis.');
    }

    final lockedHoldSide = _requiredHoldSideForAssessment();
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

  HoldSide? _currentHoldSideForState() {
    if (_engineKind != EngineKind.hold) {
      return null;
    }

    return _briefGapFrozenHoldSide ?? _selectedHoldSide;
  }

  bool _didHoldAttemptEndAfterUpdate({
    required HoldDiagnosticsSnapshot? before,
    required HoldDiagnosticsSnapshot after,
  }) {
    if (before == null) {
      return false;
    }

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

  RangeRepSideSelection _selectRangeRepSideForFrame({
    required ExerciseMetrics metrics,
    required RangeRepDiagnosticsSnapshot diagnostics,
    required bool visibilityRunActive,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
  }) {
    if (_engineKind != EngineKind.rangeRep) {
      return _rangeRepSideSelection(metrics, diagnostics: diagnostics);
    }

    if (visibilityRunActive && _briefGapFrozenRangeRepSide != null) {
      return _rangeRepFrozenSideSelection(
        metrics,
        _briefGapFrozenRangeRepSide!,
      );
    }

    final selectedRangeRepSide = _selectedRangeRepSide;
    final shouldLockToCurrentSide =
        selectedRangeRepSide != null &&
        qualityAcceptedRangeRepSides != null &&
        shouldLockRangeRepSideSelection(
          engineKind: _engineKind,
          selectedSide: selectedRangeRepSide,
          diagnostics: diagnostics,
        ) &&
        !qualityAcceptedRangeRepSides.contains(selectedRangeRepSide);
    if (shouldLockToCurrentSide) {
      return _lockedRangeRepSideSelection(metrics, selectedRangeRepSide);
    }

    return _rangeRepSideSelection(metrics, diagnostics: diagnostics);
  }

  ExerciseMetrics _rangeRepQualityFilteredMetrics({
    required ExerciseMetrics metrics,
    required Set<RangeRepSide> acceptedSides,
    RangeRepSide? preferredSide,
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

  RangeRepSideSelection _rangeRepSideSelection(
    ExerciseMetrics metrics, {
    RangeRepDiagnosticsSnapshot? diagnostics,
  }) {
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
    final resolvedDiagnostics = diagnostics ?? _rangeRepDiagnosticsSnapshot();
    return _rangeRepSideStabilizer.stabilizeSelection(
      selection: selection,
      currentSide: _selectedRangeRepSide,
      hasActiveRepContext: _isRangeRepRepContextActive(resolvedDiagnostics),
    );
  }

  RangeRepSideSelection _lockedRangeRepSideSelection(
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

  RangeRepSideSelection _rangeRepFrozenSideSelection(
    ExerciseMetrics metrics,
    RangeRepSide frozenSide,
  ) {
    return _lockedRangeRepSideSelection(metrics, frozenSide);
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

  RangeRepVisibilityAssessment _rangeRepRecoveryVisibilityAssessment({
    required DateTime now,
  }) {
    if (_engineKind != EngineKind.rangeRep) {
      return const RangeRepVisibilityAssessment.stable();
    }

    return _rangeRepVisibilityPolicy.evaluateRecovery(now: now);
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
    return diagnostics.hasRepContext;
  }

  void _clearRangeRepActiveContext({String? reason}) {
    if (_engine is RangeRepResyncControl) {
      (_engine as RangeRepResyncControl).clearActiveRepContext(reason: reason);
    }
  }

  void _beginBriefVisibilityGap(RangeRepDiagnosticsSnapshot diagnostics) {
    final shouldTrackBriefGap =
        _hasAcceptedPoseForAnalysis ||
        diagnostics.hasRepContext ||
        _selectedRangeRepSide != null;
    if (shouldTrackBriefGap) {
      _briefGapFrozenRangeRepSide = _selectedRangeRepSide;
      if (_engine is RangeRepVisibilityGapControl) {
        (_engine as RangeRepVisibilityGapControl).beginBriefVisibilityGap();
      }
    } else if (diagnostics.isAwaitingNeutralConfirmation) {
      _clearRangeRepActiveContext(
        reason: 'invalid frame while awaiting neutral',
      );
    }
    if (_isDiagnosticsEnabled && shouldTrackBriefGap) {
      _diagnostics.recordBriefOcclusion();
    }
  }

  void _beginHoldVisibilityGap() {
    if (_selectedHoldSide != null) {
      _briefGapFrozenHoldSide ??= _selectedHoldSide;
    }
    if (_engine is HoldVisibilityGapControl) {
      (_engine as HoldVisibilityGapControl).beginVisibilityGap();
    }
  }

  HoldVisibilityResumeResult _resumeHoldVisibilityGap() {
    if (_engine is! HoldVisibilityGapControl) {
      return const HoldVisibilityResumeResult(
        disposition: HoldVisibilityResumeDisposition.noGap,
      );
    }

    return (_engine as HoldVisibilityGapControl).resumeAfterVisibilityGap();
  }

  VisibilityGapResumeResult _resumeBriefVisibilityGap(AnalysisFrame frame) {
    if (_engine is! RangeRepVisibilityGapControl) {
      return const VisibilityGapResumeResult(
        disposition: VisibilityGapResumeDisposition.noGap,
      );
    }

    return (_engine as RangeRepVisibilityGapControl)
        .resumeAfterBriefVisibilityGap(frame);
  }

  void _recordSelectedSideForDiagnostics(
    RangeRepDiagnosticsSnapshot diagnostics,
  ) {
    if (!_isDiagnosticsEnabled) {
      return;
    }

    _diagnostics.recordSelectedSide(
      selectedSide: _rangeRepSideLabel(
        _briefGapFrozenRangeRepSide ?? _selectedRangeRepSide,
      ),
      hasActiveRepContext: _isRangeRepRepContextActive(diagnostics),
    );
  }

  void handleLifecycleInterruption({String? reason}) {
    if (_engineKind == EngineKind.rangeRep) {
      _resetRangeRepVisibilityResyncState(
        reason: reason ?? 'lifecycle interruption',
        resetPoseAcceptance: true,
        resetVisibilityPolicy: true,
      );
      state = state.copyWith(
        repCount: _engine.repCount,
        isFormBad: _engine.isFormBad,
        lastRepScore: _engine.lastRepScore,
        lastRepROM: _engine.maxRom,
        feedbackMessage: _resolvedEngineFeedbackMessage(),
        currentPhase: _engine.phaseLabel,
      );
      _updateDiagnosticsFromState();
      return;
    }

    if (_engineKind != EngineKind.hold) {
      return;
    }

    if (_engine is HoldInterruptionControl) {
      (_engine as HoldInterruptionControl).endActiveHoldForInterruption();
    }
    _poseAcceptanceStabilizer.reset();
    _hasAcceptedPoseForAnalysis = false;
    _resetHoldMetricFilters();
    _resetHoldSideSelection();
    final holdDiagnostics = _holdDiagnosticsSnapshot();
    state = state.copyWith(
      currentHoldSeconds: 0,
      bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
      selectedHoldSide: null,
      isHolding: false,
      isHoldVisibilitySuspended: false,
      hadHoldFormBreak: holdDiagnostics.hadFormBreak,
      feedbackMessage: _resolvedEngineFeedbackMessage(),
      currentPhase: _engine.phaseLabel,
    );
    _updateDiagnosticsFromState();
  }

  void _resetHoldMetricFilters() {
    _bodyLineFilter.reset();
    _armSupportFilter.reset();
    _legFilter.reset();
  }

  void _resetRangeRepVisibilityResyncState({
    String? reason,
    bool resetPoseAcceptance = false,
    bool resetVisibilityPolicy = false,
  }) {
    _clearRangeRepActiveContext(reason: reason);
    _angleFilter.reset();
    _backFilter.reset();
    // Force side selection to be reacquired from fresh post-resync coverage.
    _selectedRangeRepSide = null;
    _briefGapFrozenRangeRepSide = null;
    _rangeRepSideStabilizer.reset();
    _rangeRepRepOutcomeTracker.resetRepContext();
    if (resetPoseAcceptance) {
      _poseAcceptanceStabilizer.reset();
    }
    if (resetVisibilityPolicy) {
      _rangeRepVisibilityPolicy.reset();
    }
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

enum _PoseFrameKind { noPose, rejected, pendingAcceptance, accepted }

class _DetectedPoseFrame {
  const _DetectedPoseFrame({
    required this.metrics,
    required this.kind,
    this.didBecomeStableTracking = false,
    this.qualityAcceptedRangeRepSides,
    this.preferredRangeRepSide,
  });

  final ExerciseMetrics metrics;
  final _PoseFrameKind kind;
  final bool didBecomeStableTracking;
  final Set<RangeRepSide>? qualityAcceptedRangeRepSides;
  final RangeRepSide? preferredRangeRepSide;
}

class _SelectedPoseCandidate {
  const _SelectedPoseCandidate({
    required this.detectorIndex,
    required this.pose,
    required this.assessment,
  });

  final int detectorIndex;
  final Pose pose;
  final PoseQualityAssessment assessment;
}
