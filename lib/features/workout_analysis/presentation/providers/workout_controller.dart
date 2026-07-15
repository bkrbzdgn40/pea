import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/moving_average.dart';
import '../../application/analysis_frame_builder.dart';
import '../../application/analysis_engine_factory.dart';
import '../../application/common_frame_pose_pipeline.dart';
import '../../application/engine_kind.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_metrics.dart';
import '../../application/exercise_metrics_extractor.dart';
import '../../application/hold_side_policy.dart';
import '../../application/hold_side_stabilizer.dart';
import '../../application/pose_acceptance_stabilizer.dart';
import '../../application/pose_quality_policy.dart';
import '../../application/range_rep_coordinator.dart';
import '../../application/workout_calibration_metrics_builder.dart';
import '../../application/workout_state.dart';
import '../../application/workout_diagnostics.dart';
import '../../domain/analysis_engine.dart';
import '../../domain/hold_diagnostics.dart';
import '../../domain/models/analysis_frame.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/hold_feedback_code.dart';
import '../../domain/models/hold_contract.dart';
import '../../domain/models/hold_side.dart';
import '../../domain/models/range_rep_contract.dart';
import '../../domain/models/range_rep_feedback_code.dart';
import '../../domain/range_rep_diagnostics.dart';
import '../mappers/hold_feedback_ui_mapper.dart';
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

typedef WorkoutFramePosePipelineFactory =
    WorkoutFramePosePipeline Function({
      required PoseAcceptanceStabilizer poseAcceptanceStabilizer,
    });

final workoutFramePosePipelineFactoryProvider =
    Provider<WorkoutFramePosePipelineFactory>((ref) {
      return ({required PoseAcceptanceStabilizer poseAcceptanceStabilizer}) {
        return WorkoutFramePosePipeline(
          poseAcceptanceStabilizer: poseAcceptanceStabilizer,
        );
      };
    });

typedef RangeRepCoordinatorFactory =
    RangeRepCoordinator Function({
      required AnalysisEngine engine,
      required ExerciseConfig config,
      required RangeRepContract rangeRepContract,
    });

final rangeRepCoordinatorFactoryProvider = Provider<RangeRepCoordinatorFactory>(
  (ref) {
    return ({
      required AnalysisEngine engine,
      required ExerciseConfig config,
      required RangeRepContract rangeRepContract,
    }) {
      return DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: rangeRepContract,
      );
    };
  },
);

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
  late final MovingAverageFilter _angleFilter;
  late final MovingAverageFilter _backFilter;
  late final MovingAverageFilter _bodyLineFilter;
  late final MovingAverageFilter _armSupportFilter;
  late final MovingAverageFilter _legFilter;
  late final ExerciseConfig _config;
  late final RangeRepContract? _rangeRepContract;
  late final HoldContract? _holdContract;
  final AnalysisEngineFactory _engineFactory = const AnalysisEngineFactory();
  final WorkoutCalibrationMetricsBuilder _workoutCalibrationMetricsBuilder =
      const WorkoutCalibrationMetricsBuilder();
  final ExerciseCatalog _exerciseCatalog = const ExerciseCatalog();
  final ExerciseMetricsExtractor _metricsExtractor =
      const ExerciseMetricsExtractor();
  final PoseQualityPolicy _poseQualityPolicy = const PoseQualityPolicy();
  RangeRepCoordinator? _rangeRepCoordinator;
  late PoseAcceptanceStabilizer _poseAcceptanceStabilizer;
  late WorkoutFramePosePipeline _framePosePipeline;
  HoldSide? _selectedHoldSide;
  HoldSide? _briefGapFrozenHoldSide;
  bool _hasAcceptedHoldPoseForAnalysis = false;
  late HoldSideStabilizer _holdSideStabilizer;
  late WorkoutDiagnosticsAccumulator _diagnostics;

  @override
  WorkoutState build() {
    // Recreating this provider starts a fresh analysis session and filter state.
    ref.watch(poseDetectorProvider);
    _clock = ref.watch(workoutClockProvider);
    final framePosePipelineFactory = ref.watch(
      workoutFramePosePipelineFactoryProvider,
    );
    final rangeRepCoordinatorFactory = ref.watch(
      rangeRepCoordinatorFactoryProvider,
    );

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
    _selectedHoldSide = null;
    _briefGapFrozenHoldSide = null;
    _hasAcceptedHoldPoseForAnalysis = false;
    _holdSideStabilizer = HoldSideStabilizer();
    _poseAcceptanceStabilizer = PoseAcceptanceStabilizer();
    _framePosePipeline = framePosePipelineFactory(
      poseAcceptanceStabilizer: _poseAcceptanceStabilizer,
    );
    _rangeRepCoordinator = _engineKind == EngineKind.rangeRep
        ? rangeRepCoordinatorFactory(
            engine: _engine,
            config: _config,
            rangeRepContract:
                _rangeRepContract ??
                (throw StateError(
                  'Range-rep analysis requires a RangeRepContract.',
                )),
          )
        : null;
    _diagnostics = WorkoutDiagnosticsAccumulator(
      sessionStartedAt: _clock(),
      analysisKind: _engineKind.name,
    );
    final initialHoldDiagnostics = _engineKind == EngineKind.hold
        ? _holdDiagnosticsSnapshot()
        : null;

    final initialState = WorkoutState(
      analysisKind: _engineKind,
      feedbackMessage: _resolvedEngineFeedbackMessage(),
      currentPhase: _engine.phaseLabel,
      selectedHoldSide: null,
      holdFeedbackCode: _currentHoldFeedbackCode(),
      holdEnginePhase: initialHoldDiagnostics?.phase,
    );
    _diagnostics.updateWorkoutState(
      repCount: initialState.repCount,
      currentHoldSeconds: initialState.currentHoldSeconds.round(),
      bestHoldSeconds: initialState.bestHoldSeconds.round(),
      currentPhase: initialState.currentPhase,
      isHolding: initialState.isHolding,
      presentedHoldFeedbackCode: initialState.holdFeedbackCode,
      holdDiagnostics: initialHoldDiagnostics,
      currentHoldSide: initialState.selectedHoldSide,
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

    final schedulingDecision = _framePosePipeline.prepareCameraFrame(now: now);
    if (schedulingDecision == FrameProcessingGateDecision.reentrantDrop) {
      if (_isDiagnosticsEnabled) {
        _diagnostics.recordReentrantDrop();
      }
      return;
    }
    if (schedulingDecision == FrameProcessingGateDecision.throttledDrop) {
      if (_isDiagnosticsEnabled) {
        _diagnostics.recordThrottledFrame();
      }
      return;
    }

    final processingStartedAt = now;
    if (_isDiagnosticsEnabled) _diagnostics.recordAnalysisAttempt();

    try {
      final detector = ref.read(poseDetectorProvider);
      final assessPose = _poseQualityAssessor();
      final result = await _framePosePipeline.processCameraFrame(
        image: image,
        sensorOrientation: sensorOrientation,
        detector: detector,
        assessPose: assessPose,
      );
      _consumeFramePosePipelineResult(
        result,
        frameCapturedAt: now,
        processingStartedAt: processingStartedAt,
      );
      if (_isDiagnosticsEnabled &&
          result.kind != FramePosePipelineResultKind.converterDrop) {
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
      _framePosePipeline.finishCameraFrame();
    }
  }

  @visibleForTesting
  Future<void> processInputImageForAnalysis(InputImage inputImage) async {
    final now = _clock();
    if (_isDiagnosticsEnabled) _diagnostics.recordAnalysisAttempt();

    try {
      final detector = ref.read(poseDetectorProvider);
      final assessPose = _poseQualityAssessor();
      final result = await _framePosePipeline.processInputImage(
        inputImage: inputImage,
        detector: detector,
        assessPose: assessPose,
      );
      _consumeFramePosePipelineResult(
        result,
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

  void _consumeFramePosePipelineResult(
    FramePosePipelineResult result, {
    required DateTime frameCapturedAt,
    required DateTime processingStartedAt,
  }) {
    if (result.kind == FramePosePipelineResultKind.converterDrop) {
      if (_isDiagnosticsEnabled) {
        _diagnostics.recordConverterDrop();
        _diagnostics.recordProcessingDuration(
          DateTime.now().difference(processingStartedAt),
        );
      }
      return;
    }

    if (result.poseCount != null && _isDiagnosticsEnabled) {
      _diagnostics.recordPoseCount(result.poseCount!);
    }
    _analysisFrameCount++;
    _updateFpsIfNeeded();

    _updatePoseDiagnosticsFromPipelineResult(result);
    final detectedFrame = _detectedPoseFrameFromPipelineResult(result);
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

  void _updatePoseDiagnosticsFromPipelineResult(
    FramePosePipelineResult result,
  ) {
    if (!_isDiagnosticsEnabled) {
      return;
    }

    switch (result.kind) {
      case FramePosePipelineResultKind.noPose:
        _diagnostics.updatePoseQualityStatus(status: 'no_pose');
        return;
      case FramePosePipelineResultKind.rejected:
        final rejectionReason = result.selectedAssessment?.rejectionReason;
        if (rejectionReason != null) {
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
        return;
      case FramePosePipelineResultKind.pendingAcceptance:
        _diagnostics.updatePoseQualityStatus(
          status: 'accepted_pending_stabilization',
        );
        return;
      case FramePosePipelineResultKind.accepted:
        _diagnostics.updatePoseQualityStatus(status: 'accepted');
        return;
      case FramePosePipelineResultKind.converterDrop:
        return;
    }
  }

  _DetectedPoseFrame _detectedPoseFrameFromPipelineResult(
    FramePosePipelineResult result,
  ) {
    switch (result.kind) {
      case FramePosePipelineResultKind.noPose:
        return const _DetectedPoseFrame(
          metrics: ExerciseMetrics.noPose(),
          kind: _PoseFrameKind.noPose,
        );
      case FramePosePipelineResultKind.rejected:
        return const _DetectedPoseFrame(
          metrics: ExerciseMetrics.noPose(),
          kind: _PoseFrameKind.rejected,
        );
      case FramePosePipelineResultKind.pendingAcceptance:
        return const _DetectedPoseFrame(
          metrics: ExerciseMetrics.noPose(),
          kind: _PoseFrameKind.pendingAcceptance,
        );
      case FramePosePipelineResultKind.accepted:
        final selectedPose = result.selectedPose;
        final selectedAssessment = result.selectedAssessment;
        if (selectedPose == null || selectedAssessment == null) {
          throw StateError(
            'Accepted frame-pose pipeline result requires pose and assessment.',
          );
        }

        return _DetectedPoseFrame(
          metrics: _metricsExtractor.extract(
            selectedPose,
            _config,
            engineKind: _engineKind,
            rangeRepContract: _rangeRepContract,
            holdContract: _holdContract,
            holdSide: _engineKind == EngineKind.hold
                ? _selectHoldSideForAcceptedPose(selectedAssessment)
                : null,
          ),
          kind: _PoseFrameKind.accepted,
          didBecomeStableTracking: result.didBecomeStableTracking,
          qualityAcceptedRangeRepSides:
              selectedAssessment.acceptedRangeRepSides,
          preferredRangeRepSide: selectedAssessment.preferredRangeRepSide,
        );
      case FramePosePipelineResultKind.converterDrop:
        throw StateError(
          'Converter-drop results must not be mapped to detected frames.',
        );
    }
  }

  bool get _isDiagnosticsEnabled => kDebugMode || kProfileMode;

  WorkoutDiagnosticsSnapshot diagnosticsSnapshot({DateTime? now}) {
    return _diagnostics.snapshot(now: now ?? _clock());
  }

  void resetDiagnostics({DateTime? now}) {
    _diagnostics.reset(now: now ?? _clock(), analysisKind: _engineKind.name);
    if (_isDiagnosticsEnabled) {
      final rangeRepDiagnosticsState = _engineKind == EngineKind.rangeRep
          ? _rangeRepCoordinatorOrThrow().diagnosticsState()
          : const RangeRepCoordinatorDiagnosticsState(
              selectedSideLabel: null,
              hasActiveRepContext: false,
            );
      _diagnostics.recordSelectedSide(
        selectedSide: rangeRepDiagnosticsState.selectedSideLabel,
        hasActiveRepContext: rangeRepDiagnosticsState.hasActiveRepContext,
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
    if (_engineKind == EngineKind.rangeRep) {
      _processRangeRepMetrics(
        metrics: metrics,
        now: now,
        frameKind: frameKind,
        didBecomeStableTracking: didBecomeStableTracking,
        qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
        preferredRangeRepSide: preferredRangeRepSide,
      );
      return;
    }

    final preUpdateHoldDiagnostics = _holdDiagnosticsSnapshot();
    final isAcceptedPoseFrame = frameKind == _PoseFrameKind.accepted;

    if (!isAcceptedPoseFrame) {
      final lockedHoldSide = _requiredHoldSideForAssessment();
      if (lockedHoldSide != null) {
        _beginHoldVisibilityGap();
      } else {
        _resetHoldSideSelection();
      }
      if (_isDiagnosticsEnabled) {
        _diagnostics.updateVisibilityStatus('invalid_input');
      }
      final holdDiagnostics = _holdDiagnosticsSnapshot();
      state = WorkoutState(
        landmarks: metrics.landmarks,
        analysisKind: _engineKind,
        repCount: state.repCount,
        isFormBad: false,
        currentAngle: metrics.primaryAngle,
        lastRepScore: state.lastRepScore,
        lastRepROM: state.lastRepROM,
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
        feedbackMessage: mapHoldFeedbackCodeToMessage(
          HoldFeedbackCode.bodyNotVisible,
        ),
        currentPhase: 'WAITING',
        cameraFps: _cameraFps,
        analysisFps: _analysisFps,
        calibrationMetrics: _buildHoldCalibrationMetrics(
          currentFormMetric: metrics.formMetric,
          thresholdValue: _config.resolvedHoldPosture.bodyLineEntryAngle,
        ),
      );
      _updateDiagnosticsFromState();
      return;
    }

    final holdGapResult = _resumeHoldVisibilityGap();
    if (holdGapResult.disposition == HoldVisibilityResumeDisposition.ended) {
      final holdDiagnostics = _holdDiagnosticsSnapshot();
      _resetHoldSideSelection();
      if (_isDiagnosticsEnabled) {
        if (didBecomeStableTracking && _hasAcceptedHoldPoseForAnalysis) {
          _diagnostics.recordPoseReacquisition();
        }
        _diagnostics.recordAcceptedPoseFrame();
        _diagnostics.updateVisibilityStatus('stable');
      }
      state = WorkoutState(
        landmarks: metrics.landmarks,
        analysisKind: _engineKind,
        repCount: _engine.repCount,
        isFormBad: _engine.isFormBad,
        currentAngle: metrics.primaryAngle,
        lastRepScore: _engine.lastRepScore,
        lastRepROM: _engine.maxRom,
        currentHoldSeconds: 0,
        bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
        selectedHoldSide: null,
        isHolding: false,
        isHoldVisibilitySuspended: false,
        hadHoldFormBreak: holdDiagnostics.hadFormBreak,
        holdFeedbackCode: _currentHoldFeedbackCode(),
        holdEnginePhase: holdDiagnostics.phase,
        feedbackMessage: _resolvedEngineFeedbackMessage(),
        currentPhase: _engine.phaseLabel,
        cameraFps: _cameraFps,
        analysisFps: _analysisFps,
        calibrationMetrics: _buildHoldCalibrationMetrics(
          currentFormMetric: metrics.formMetric,
          thresholdValue: holdDiagnostics.bodyLineTargetAngle,
          currentBodyLineAngle: metrics.bodyLineAngle,
          currentArmSupportAngle: metrics.armSupportAngle,
          currentLegExtensionAngle: metrics.legExtensionAngle,
        ),
      );
      _hasAcceptedHoldPoseForAnalysis = true;
      _updateDiagnosticsFromState();
      return;
    }

    if (holdGapResult.disposition == HoldVisibilityResumeDisposition.resumed ||
        holdGapResult.disposition == HoldVisibilityResumeDisposition.noGap) {
      _briefGapFrozenHoldSide = null;
    }

    if (_isDiagnosticsEnabled) {
      if (didBecomeStableTracking && _hasAcceptedHoldPoseForAnalysis) {
        _diagnostics.recordPoseReacquisition();
      }
      _diagnostics.recordAcceptedPoseFrame();
      _diagnostics.updateVisibilityStatus('stable');
    }

    if (metrics.hasPose) {
      final analysisFrame = _analysisFrameBuilder.build(
        metrics: metrics,
        primaryMetricFilter: _angleFilter,
        formMetricFilter: _backFilter,
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
        selectedHoldSide: _currentHoldSideForState(),
        holdFeedbackCode: _currentHoldFeedbackCode(),
        holdEnginePhase: holdDiagnostics.phase,
        isHolding: holdDiagnostics.isHolding,
        isHoldVisibilitySuspended: holdDiagnostics.isVisibilitySuspended,
        hadHoldFormBreak: holdDiagnostics.hadFormBreak,
        feedbackMessage: _resolvedEngineFeedbackMessage(),
        currentPhase: _engine.phaseLabel,
        cameraFps: _cameraFps,
        analysisFps: _analysisFps,
        calibrationMetrics: _buildHoldCalibrationMetrics(
          currentFormMetric: analysisFrame.formMetric,
          thresholdValue: holdDiagnostics.bodyLineTargetAngle,
          currentBodyLineAngle: analysisFrame.bodyLineAngle,
          currentArmSupportAngle: analysisFrame.armSupportAngle,
          currentLegExtensionAngle: analysisFrame.legExtensionAngle,
        ),
      );
      _hasAcceptedHoldPoseForAnalysis = true;
      _updateDiagnosticsFromState();
      return;
    }

    if (_isDiagnosticsEnabled) {
      _diagnostics.updateVisibilityStatus('invalid_input');
    }
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
      selectedHoldSide: _currentHoldSideForState(),
      holdFeedbackCode: HoldFeedbackCode.bodyNotVisible,
      holdEnginePhase: _holdDiagnosticsSnapshot().phase,
      isHolding: false,
      isHoldVisibilitySuspended: false,
      hadHoldFormBreak: state.hadHoldFormBreak,
      feedbackMessage: mapHoldFeedbackCodeToMessage(
        HoldFeedbackCode.bodyNotVisible,
      ),
      currentPhase: 'WAITING',
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
      calibrationMetrics: _buildHoldCalibrationMetrics(
        currentFormMetric: metrics.formMetric,
        thresholdValue: _config.resolvedHoldPosture.bodyLineEntryAngle,
      ),
    );
    _updateDiagnosticsFromState();
  }

  void _processRangeRepMetrics({
    required ExerciseMetrics metrics,
    required DateTime now,
    required _PoseFrameKind frameKind,
    required bool didBecomeStableTracking,
    required Set<RangeRepSide>? qualityAcceptedRangeRepSides,
    required RangeRepSide? preferredRangeRepSide,
  }) {
    final result = _rangeRepCoordinatorOrThrow().processFrame(
      metrics: metrics,
      now: now,
      isAcceptedPoseFrame: frameKind == _PoseFrameKind.accepted,
      didBecomeStableTracking: didBecomeStableTracking,
      qualityAcceptedRangeRepSides: qualityAcceptedRangeRepSides,
      preferredRangeRepSide: preferredRangeRepSide,
    );
    if (result.shouldRecordInvalidPoseAcceptance) {
      _poseAcceptanceStabilizer.recordInvalidFrame();
    }
    if (result.shouldResetPoseAcceptance) {
      _poseAcceptanceStabilizer.reset();
    }
    _publishRangeRepState(result.stateSnapshot);
    _applyRangeRepDiagnosticsUpdate(result.diagnosticsUpdate);
    _updateDiagnosticsFromState();
  }

  void _publishRangeRepState(RangeRepCoordinatorStateSnapshot snapshot) {
    state = WorkoutState(
      landmarks: snapshot.landmarks,
      analysisKind: _engineKind,
      repCount: snapshot.repCount,
      isFormBad: snapshot.isFormBad,
      currentAngle: snapshot.currentAngle,
      lastRepScore: snapshot.lastRepScore,
      lastRepROM: snapshot.lastRepRom,
      feedbackMessage: snapshot.feedbackDirective.resolve(
        mapFeedbackCode: mapRangeRepFeedbackCodeToMessage,
        fallbackMessage: snapshot.feedbackFallbackMessage,
      ),
      currentPhase: snapshot.currentPhase,
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
      calibrationMetrics: snapshot.calibrationMetrics,
    );
  }

  void _applyRangeRepDiagnosticsUpdate(
    RangeRepCoordinatorDiagnosticsUpdate update,
  ) {
    if (!_isDiagnosticsEnabled) {
      return;
    }

    if (update.recordBriefOcclusion) {
      _diagnostics.recordBriefOcclusion();
    }
    if (update.recordBriefOcclusionRecovery) {
      _diagnostics.recordBriefOcclusionRecovery();
    }
    if (update.recordBriefOcclusionAbort) {
      _diagnostics.recordBriefOcclusionAbort();
    }
    if (update.recordResync) {
      _diagnostics.recordResync();
    }
    if (update.recordPoseReacquisition) {
      _diagnostics.recordPoseReacquisition();
    }
    if (update.recordAcceptedPoseFrame) {
      _diagnostics.recordAcceptedPoseFrame();
    }
    _diagnostics.updateVisibilityStatus(update.visibilityStatus);
    _diagnostics.recordSelectedSide(
      selectedSide: update.selectedSideLabel,
      hasActiveRepContext: update.hasActiveRepContext,
    );
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
      presentedHoldFeedbackCode: state.holdFeedbackCode,
      holdDiagnostics: _engineKind == EngineKind.hold
          ? _holdDiagnosticsSnapshot()
          : null,
      currentHoldSide: _engineKind == EngineKind.hold
          ? state.selectedHoldSide
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

  RangeRepCoordinator _rangeRepCoordinatorOrThrow() {
    final coordinator = _rangeRepCoordinator;
    if (coordinator == null) {
      throw StateError(
        'RangeRepCoordinator is only available during range-rep analysis.',
      );
    }

    return coordinator;
  }

  PoseQualityAssessor _poseQualityAssessor() {
    final requiredHoldSide = _requiredHoldSideForAssessment();
    return (pose) => _poseQualityPolicy.assess(
      pose: pose,
      config: _config,
      engineKind: _engineKind,
      rangeRepContract: _rangeRepContract,
      holdContract: _holdContract,
      requiredHoldSide: requiredHoldSide,
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

  HoldFeedbackCode? _currentHoldFeedbackCode() {
    if (_engineKind != EngineKind.hold) {
      return null;
    }
    if (_engine is! HoldFeedbackSource) {
      throw StateError(
        'Hold analysis engine must implement HoldFeedbackSource.',
      );
    }

    return (_engine as HoldFeedbackSource).feedbackCode;
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

  String _resolvedEngineFeedbackMessage() {
    if (_engineKind == EngineKind.rangeRep &&
        _engine is RangeRepFeedbackSource) {
      final feedbackCode = (_engine as RangeRepFeedbackSource).feedbackCode;
      if (feedbackCode != null) {
        return mapRangeRepFeedbackCodeToMessage(feedbackCode);
      }
    }
    if (_engineKind == EngineKind.hold && _engine is HoldFeedbackSource) {
      return mapHoldFeedbackCodeToMessage(
        (_engine as HoldFeedbackSource).feedbackCode,
      );
    }

    return _engine.feedback;
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
    return _workoutCalibrationMetricsBuilder.build(
      currentFormMetric: currentFormMetric,
      thresholdValue: thresholdValue,
      diagnostics: const RangeRepDiagnosticsSnapshot(),
      lastBreakdown: null,
      lastValidationResult: null,
      lastSummaryCandidate: null,
      rangeRepSideHysteresisStatus: null,
      rangeRepSideConsistencyStatus: null,
      calibrationSnapshot: null,
      calibrationThresholdDecisionCount: 0,
      calibrationThresholdAppliedCount: 0,
      calibrationThresholdNoBaselineCount: 0,
      calibrationThresholdInsufficientSamplesCount: 0,
      calibrationThresholdMissingFormBaselineCount: 0,
      calibrationThresholdSideMismatchCount: 0,
      calibrationThresholdOffsetTooSmallCount: 0,
      sessionCalibrationBaselineCandidate: null,
      lastRangeRepValidatedRepIndex: null,
      rangeRepValidatedCount: 0,
      rangeRepLowConfidenceCount: 0,
      rangeRepInvalidCount: 0,
      currentBodyLineAngle: currentBodyLineAngle,
      currentArmSupportAngle: currentArmSupportAngle,
      currentLegExtensionAngle: currentLegExtensionAngle,
      hasBodyLineAngle: currentBodyLineAngle != null,
      hasArmSupportAngle: currentArmSupportAngle != null,
      hasLegExtensionAngle: currentLegExtensionAngle != null,
    );
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

  void handleLifecycleInterruption({String? reason}) {
    if (_engineKind == EngineKind.rangeRep) {
      _poseAcceptanceStabilizer.reset();
      _publishRangeRepState(
        _rangeRepCoordinatorOrThrow().handleLifecycleInterruption(
          reason: reason ?? 'lifecycle interruption',
        ),
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
    _hasAcceptedHoldPoseForAnalysis = false;
    _resetHoldMetricFilters();
    _resetHoldSideSelection();
    final holdDiagnostics = _holdDiagnosticsSnapshot();
    state = state.copyWith(
      currentHoldSeconds: 0,
      bestHoldSeconds: holdDiagnostics.bestHoldSeconds,
      selectedHoldSide: null,
      holdFeedbackCode: _currentHoldFeedbackCode(),
      holdEnginePhase: holdDiagnostics.phase,
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

  HoldDiagnosticsSnapshot _holdDiagnosticsSnapshot() {
    if (_engine is HoldDiagnostics) {
      return (_engine as HoldDiagnostics).diagnosticsSnapshot;
    }

    return const HoldDiagnosticsSnapshot();
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
