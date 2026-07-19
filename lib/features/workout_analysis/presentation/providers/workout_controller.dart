import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../application/analysis_engine_factory.dart';
import '../../application/common_frame_pose_pipeline.dart';
import '../../application/engine_kind.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_metrics.dart';
import '../../application/exercise_metrics_extractor.dart';
import '../../application/hold_coordinator.dart';
import '../../application/pose_acceptance_stabilizer.dart';
import '../../application/pose_quality_policy.dart';
import '../../application/range_rep_coordinator.dart';
import '../../application/workout_state.dart';
import '../../application/workout_diagnostics.dart';
import '../../domain/hold_analysis_engine.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/hold_contract.dart';
import '../../domain/models/range_rep_contract.dart';
import '../../domain/models/range_rep_feedback_code.dart';
import '../../domain/range_rep_analysis_engine.dart';
import '../../domain/range_rep_validation_policy.dart';
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
      required RangeRepAnalysisEngine engine,
      required ExerciseConfig config,
      required RangeRepContract rangeRepContract,
      required RangeRepValidationConfig rangeRepValidationConfig,
    });

final rangeRepCoordinatorFactoryProvider = Provider<RangeRepCoordinatorFactory>(
  (ref) {
    return ({
      required RangeRepAnalysisEngine engine,
      required ExerciseConfig config,
      required RangeRepContract rangeRepContract,
      required RangeRepValidationConfig rangeRepValidationConfig,
    }) {
      return DefaultRangeRepCoordinator(
        engine: engine,
        config: config,
        rangeRepContract: rangeRepContract,
        rangeRepValidationConfig: rangeRepValidationConfig,
      );
    };
  },
);

typedef HoldCoordinatorFactory =
    HoldCoordinator Function({
      required HoldAnalysisEngine engine,
      required ExerciseConfig config,
    });

final holdCoordinatorFactoryProvider = Provider<HoldCoordinatorFactory>((ref) {
  return ({
    required HoldAnalysisEngine engine,
    required ExerciseConfig config,
  }) {
    return DefaultHoldCoordinator(engine: engine, config: config);
  };
});

/// Coordinates frame conversion, pose detection, smoothing, and rep state.
class WorkoutController extends AutoDisposeNotifier<WorkoutState> {
  DateTime _lastFpsCalculationTime = DateTime.now();
  int _cameraFrameCount = 0;
  int _analysisFrameCount = 0;
  double _cameraFps = 0.0;
  double _analysisFps = 0.0;

  late final EngineKind _engineKind;
  late final ExerciseType _activeExercise;
  late final DateTime Function() _clock;
  late final ExerciseConfig _config;
  late final RangeRepContract? _rangeRepContract;
  late final HoldContract? _holdContract;
  final AnalysisEngineFactory _engineFactory = const AnalysisEngineFactory();
  final ExerciseCatalog _exerciseCatalog = const ExerciseCatalog();
  final ExerciseMetricsExtractor _metricsExtractor =
      const ExerciseMetricsExtractor();
  final PoseQualityPolicy _poseQualityPolicy = const PoseQualityPolicy();
  RangeRepAnalysisEngine? _rangeRepEngine;
  RangeRepCoordinator? _rangeRepCoordinator;
  HoldCoordinator? _holdCoordinator;
  late PoseAcceptanceStabilizer _poseAcceptanceStabilizer;
  late WorkoutFramePosePipeline _framePosePipeline;
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
    final holdCoordinatorFactory = ref.watch(holdCoordinatorFactoryProvider);

    final activeExercise = ref.watch(activeAnalysisExerciseProvider);
    if (activeExercise == null) {
      throw StateError('No active analysis exercise selected.');
    }
    _activeExercise = activeExercise;

    final definition = _exerciseCatalog.definitionFor(activeExercise);
    _engineKind = definition.analysisEngineKind;
    _rangeRepContract = _engineKind == EngineKind.rangeRep
        ? definition.analysisRangeRepContract
        : null;
    _holdContract = _engineKind == EngineKind.hold
        ? definition.analysisHoldContract
        : null;
    _config = ref.watch(exerciseConfigProvider).requireValue;
    switch (_engineKind) {
      case EngineKind.rangeRep:
        final rangeRepContract =
            _rangeRepContract ??
            (throw StateError(
              'Range-rep analysis requires a RangeRepContract.',
            ));
        final rangeRepValidationConfig =
            definition.analysisRangeRepValidationConfig;
        final rangeRepEngine = _engineFactory.createRangeRep(
          config: _config,
          rangeRepContract: rangeRepContract,
          now: _clock,
        );
        _rangeRepEngine = rangeRepEngine;
        _rangeRepCoordinator = rangeRepCoordinatorFactory(
          engine: rangeRepEngine,
          config: _config,
          rangeRepContract: rangeRepContract,
          rangeRepValidationConfig: rangeRepValidationConfig,
        );
        _holdCoordinator = null;
        break;
      case EngineKind.hold:
        final holdContract =
            _holdContract ??
            (throw StateError('Hold analysis requires a HoldContract.'));
        final holdEngine = _engineFactory.createHold(
          config: _config,
          holdContract: holdContract,
          now: _clock,
        );
        _rangeRepEngine = null;
        _rangeRepCoordinator = null;
        _holdCoordinator = holdCoordinatorFactory(
          engine: holdEngine,
          config: _config,
        );
        break;
      case EngineKind.alternatingRep:
        _engineFactory.create(
          engineKind: _engineKind,
          config: _config,
          rangeRepContract: _rangeRepContract,
          holdContract: _holdContract,
          now: _clock,
        );
        throw StateError('Unreachable alternatingRep analysis wiring path.');
    }

    _lastFpsCalculationTime = _clock();
    _cameraFrameCount = 0;
    _analysisFrameCount = 0;
    _cameraFps = 0.0;
    _analysisFps = 0.0;
    _poseAcceptanceStabilizer = PoseAcceptanceStabilizer();
    _framePosePipeline = framePosePipelineFactory(
      poseAcceptanceStabilizer: _poseAcceptanceStabilizer,
    );
    _diagnostics = WorkoutDiagnosticsAccumulator(
      sessionStartedAt: _clock(),
      analysisKind: _engineKind.name,
    );
    final initialHoldSnapshot = _engineKind == EngineKind.hold
        ? _holdCoordinatorOrThrow().currentStateSnapshot()
        : null;

    final initialState = _engineKind == EngineKind.hold
        ? WorkoutState.hold(
            feedbackMessage: _resolveHoldFeedbackMessage(initialHoldSnapshot!),
            analysis: HoldWorkoutAnalysisState(
              isFormBad: initialHoldSnapshot.isFormBad,
              currentAngle: initialHoldSnapshot.currentAngle,
              currentHoldSeconds: initialHoldSnapshot.currentHoldSeconds,
              bestHoldSeconds: initialHoldSnapshot.bestHoldSeconds,
              selectedHoldSide: initialHoldSnapshot.selectedHoldSide,
              holdFeedbackCode: initialHoldSnapshot.holdFeedbackCode,
              holdEnginePhase: initialHoldSnapshot.holdEnginePhase,
              isHolding: initialHoldSnapshot.isHolding,
              isHoldVisibilitySuspended:
                  initialHoldSnapshot.isHoldVisibilitySuspended,
              hadHoldFormBreak: initialHoldSnapshot.hadHoldFormBreak,
              currentPhase: initialHoldSnapshot.currentPhase,
              calibrationMetrics: initialHoldSnapshot.calibrationMetrics,
            ),
          )
        : WorkoutState.rangeRep(
            feedbackMessage: _mapRangeRepFeedbackCodeToMessage(
              RangeRepFeedbackCode.awaitNeutral,
            ),
            analysis: RangeRepWorkoutAnalysisState(
              currentPhase: _rangeRepEngineOrThrow().phaseLabel,
            ),
          );
    _updateDiagnosticsFromPublishedState(initialState);
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
                ? _holdCoordinatorOrThrow().selectHoldSideForAcceptedPose(
                    selectedAssessment,
                  )
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
      if (_engineKind == EngineKind.rangeRep) {
        final rangeRepDiagnosticsState = _rangeRepCoordinatorOrThrow()
            .diagnosticsState();
        _diagnostics.recordSelectedSide(
          selectedSide: rangeRepDiagnosticsState.selectedSideLabel,
          hasActiveRepContext: rangeRepDiagnosticsState.hasActiveRepContext,
        );
      }
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

    _processHoldMetrics(
      metrics: metrics,
      now: now,
      frameKind: frameKind,
      didBecomeStableTracking: didBecomeStableTracking,
    );
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

  void _processHoldMetrics({
    required ExerciseMetrics metrics,
    required DateTime now,
    required _PoseFrameKind frameKind,
    required bool didBecomeStableTracking,
  }) {
    final result = _holdCoordinatorOrThrow().processFrame(
      metrics: metrics,
      now: now,
      isAcceptedPoseFrame: frameKind == _PoseFrameKind.accepted,
      didBecomeStableTracking: didBecomeStableTracking,
    );
    _publishHoldState(result.stateSnapshot);
    _applyHoldDiagnosticsUpdate(result.diagnosticsUpdate);
    _updateDiagnosticsFromState();
  }

  void _publishRangeRepState(RangeRepCoordinatorStateSnapshot snapshot) {
    state = WorkoutState.rangeRep(
      landmarks: snapshot.landmarks,
      feedbackMessage: snapshot.feedbackDirective.resolve(
        mapFeedbackCode: _mapRangeRepFeedbackCodeToMessage,
      ),
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
      analysis: RangeRepWorkoutAnalysisState(
        repCount: snapshot.repCount,
        isFormBad: snapshot.isFormBad,
        currentAngle: snapshot.currentAngle,
        lastRepScore: snapshot.lastRepScore,
        lastRepRom: snapshot.lastRepRom,
        currentPhase: snapshot.currentPhase,
        calibrationMetrics: snapshot.calibrationMetrics,
      ),
    );
  }

  void _publishHoldState(HoldCoordinatorStateSnapshot snapshot) {
    state = WorkoutState.hold(
      landmarks: snapshot.landmarks,
      feedbackMessage: _resolveHoldFeedbackMessage(snapshot),
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
      analysis: HoldWorkoutAnalysisState(
        isFormBad: snapshot.isFormBad,
        currentAngle: snapshot.currentAngle,
        currentHoldSeconds: snapshot.currentHoldSeconds,
        bestHoldSeconds: snapshot.bestHoldSeconds,
        selectedHoldSide: snapshot.selectedHoldSide,
        holdFeedbackCode: snapshot.holdFeedbackCode,
        holdEnginePhase: snapshot.holdEnginePhase,
        isHolding: snapshot.isHolding,
        isHoldVisibilitySuspended: snapshot.isHoldVisibilitySuspended,
        hadHoldFormBreak: snapshot.hadHoldFormBreak,
        currentPhase: snapshot.currentPhase,
        calibrationMetrics: snapshot.calibrationMetrics,
      ),
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

  void _applyHoldDiagnosticsUpdate(HoldCoordinatorDiagnosticsUpdate update) {
    if (!_isDiagnosticsEnabled) {
      return;
    }

    if (update.recordPoseReacquisition) {
      _diagnostics.recordPoseReacquisition();
    }
    if (update.recordAcceptedPoseFrame) {
      _diagnostics.recordAcceptedPoseFrame();
    }
    _diagnostics.updateVisibilityStatus(update.visibilityStatus);
  }

  void _updateDiagnosticsFromState() {
    _updateDiagnosticsFromPublishedState(state);
  }

  void _updateDiagnosticsFromPublishedState(WorkoutState publishedState) {
    if (!_isDiagnosticsEnabled) return;
    _diagnostics.updateLivePerformance(
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
    );
    if (_engineKind == EngineKind.rangeRep) {
      _diagnostics.updateRangeRepState(
        repCount: publishedState.repCount,
        currentPhase: publishedState.currentPhase,
        calibrationOffsetDegrees:
            publishedState.calibrationMetrics.calibrationThresholdOffsetApplied
            ? publishedState
                  .calibrationMetrics
                  .calibrationThresholdOffsetCandidate
            : null,
      );
      return;
    }

    _diagnostics.updateHoldState(
      currentHoldSeconds: publishedState.currentHoldSeconds.round(),
      bestHoldSeconds: publishedState.bestHoldSeconds.round(),
      currentPhase: publishedState.currentPhase,
      isHolding: publishedState.isHolding,
      presentedHoldFeedbackCode: publishedState.holdFeedbackCode,
      holdDiagnostics: _holdCoordinatorOrThrow().diagnosticsSnapshot(),
      currentHoldSide: publishedState.selectedHoldSide,
      currentSignalValues:
          publishedState.calibrationMetrics.currentHoldSignalValues,
      targetSignalValues:
          publishedState.calibrationMetrics.targetHoldSignalValues,
      signalValidity: publishedState.calibrationMetrics.holdSignalValidity,
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

  RangeRepAnalysisEngine _rangeRepEngineOrThrow() {
    final engine = _rangeRepEngine;
    if (engine == null) {
      throw StateError(
        'RangeRepAnalysisEngine is only available during range-rep analysis.',
      );
    }

    return engine;
  }

  HoldCoordinator _holdCoordinatorOrThrow() {
    final coordinator = _holdCoordinator;
    if (coordinator == null) {
      throw StateError(
        'HoldCoordinator is only available during hold analysis.',
      );
    }

    return coordinator;
  }

  PoseQualityAssessor _poseQualityAssessor() {
    final requiredHoldSide = _engineKind == EngineKind.hold
        ? _holdCoordinatorOrThrow().requiredHoldSideForAssessment()
        : null;
    return (pose) => _poseQualityPolicy.assess(
      pose: pose,
      config: _config,
      engineKind: _engineKind,
      rangeRepContract: _rangeRepContract,
      holdContract: _holdContract,
      requiredHoldSide: requiredHoldSide,
    );
  }

  String _mapRangeRepFeedbackCodeToMessage(RangeRepFeedbackCode code) {
    return mapRangeRepFeedbackCodeToMessage(
      code,
      exerciseType: _activeExercise,
    );
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

    _poseAcceptanceStabilizer.reset();
    _publishHoldState(
      _holdCoordinatorOrThrow().handleLifecycleInterruption(
        reason: reason ?? 'lifecycle interruption',
      ),
    );
    _updateDiagnosticsFromState();
  }

  String _resolveHoldFeedbackMessage(HoldCoordinatorStateSnapshot snapshot) {
    final feedbackCode = snapshot.holdFeedbackCode;
    if (feedbackCode != null) {
      return mapHoldFeedbackCodeToMessage(feedbackCode);
    }

    return snapshot.feedbackFallbackMessage;
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
