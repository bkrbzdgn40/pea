import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/monotonic_datetime_clock.dart';

import '../../application/analysis_engine_factory.dart';
import '../../application/common_frame_pose_pipeline.dart';
import '../../application/engine_kind.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_metric_registry.dart';
import '../../application/exercise_metrics.dart';
import '../../application/exercise_metrics_extractor.dart';
import '../../application/exercise_definition_metadata.dart';
import '../../application/feedback_delivery_controller.dart';
import '../../application/hold_coordinator.dart';
import '../../application/pose_acceptance_stabilizer.dart';
import '../../application/pose_quality_policy.dart';
import '../../application/prepared_exercise_analysis_context.dart';
import '../../application/range_rep_coordinator.dart';
import '../../application/range_rep_primary_metric_normalizer.dart';
import '../../application/range_rep_tempo_voice_confirmation_policy.dart';
import '../../application/workout_state.dart';
import '../../application/workout_diagnostics.dart';
import '../../application/workout_live_metrics.dart';
import '../../domain/alternating_rep_engine.dart';
import '../../domain/hold_analysis_engine.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/hold_contract.dart';
import '../../domain/models/hold_feedback_code.dart';
import '../../domain/models/range_rep_contract.dart';
import '../../domain/models/range_rep_feedback_code.dart';
import '../../domain/models/range_rep_validation_result.dart';
import '../../domain/range_rep_analysis_engine.dart';
import '../../domain/range_rep_validation_policy.dart';
import '../mappers/hold_feedback_ui_mapper.dart';
import '../mappers/range_rep_feedback_ui_mapper.dart';
import '../mappers/range_rep_outcome_ui_mapper.dart';
import '../models/workout_live_metric_display_state.dart';
import 'active_analysis_exercise_provider.dart';
import 'live_pause_controller.dart';
import 'live_range_rep_outcome_controller.dart';
import 'live_tracking_controller.dart';
import 'exercise_config_provider.dart';
import 'feedback_delivery_provider.dart';
import 'pose_provider.dart';
import 'settings_provider.dart';

/// Exposes the live workout state produced from camera frames and pose results.
final workoutControllerProvider =
    AutoDisposeNotifierProvider<WorkoutController, WorkoutState>(() {
      return WorkoutController();
    });

final workoutLiveMetricsProvider =
    AutoDisposeNotifierProvider<
      WorkoutLiveMetricsController,
      WorkoutLiveMetricDisplayState
    >(WorkoutLiveMetricsController.new);

class WorkoutLiveMetricsController
    extends AutoDisposeNotifier<WorkoutLiveMetricDisplayState> {
  @override
  WorkoutLiveMetricDisplayState build() {
    // A planned workout can switch exercises without disposing the analysis
    // route. Reset the display projection whenever the active exercise changes.
    ref.watch(activeAnalysisExerciseProvider);
    return WorkoutLiveMetricDisplayState.empty;
  }

  void reset() {
    if (state == WorkoutLiveMetricDisplayState.empty) {
      return;
    }
    state = WorkoutLiveMetricDisplayState.empty;
  }

  void publish({
    int? angleDegrees,
    Duration? tempo,
    int? stabilityScore,
    int? asymmetryScore,
  }) {
    final next = WorkoutLiveMetricDisplayState(
      angleDegrees: angleDegrees,
      tempo: tempo,
      stabilityScore: stabilityScore,
      asymmetryScore: asymmetryScore,
    );
    if (next == state) {
      return;
    }
    state = next;
  }
}

final workoutClockProvider = Provider<DateTime Function()>((ref) {
  final clock = MonotonicDateTimeClock();
  return clock.now;
});

typedef WorkoutFramePosePipelineFactory =
    WorkoutFramePosePipeline Function({
      required PoseAcceptanceStabilizer poseAcceptanceStabilizer,
    });

final workoutFramePosePipelineFactoryProvider =
    Provider<WorkoutFramePosePipelineFactory>((ref) {
      final activeExercise = ref.watch(activeAnalysisExerciseProvider);
      final analysisFrameInterval = activeExercise == null
          ? const Duration(milliseconds: 100)
          : const ExerciseCatalog()
                .definitionFor(activeExercise)
                .analysisFrameInterval;

      return ({required PoseAcceptanceStabilizer poseAcceptanceStabilizer}) {
        return WorkoutFramePosePipeline(
          poseAcceptanceStabilizer: poseAcceptanceStabilizer,
          analysisFrameInterval: analysisFrameInterval,
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
      required HoldContract holdContract,
    });

final holdCoordinatorFactoryProvider = Provider<HoldCoordinatorFactory>((ref) {
  return ({
    required HoldAnalysisEngine engine,
    required ExerciseConfig config,
    required HoldContract holdContract,
  }) {
    return DefaultHoldCoordinator(
      engine: engine,
      config: config,
      holdContract: holdContract,
    );
  };
});

/// Coordinates frame conversion, pose detection, smoothing, and rep state.
class WorkoutController extends AutoDisposeNotifier<WorkoutState> {
  late DateTime _lastFpsCalculationTime;
  int _cameraFrameCount = 0;
  int _analysisFrameCount = 0;
  double _cameraFps = 0.0;
  double _analysisFps = 0.0;

  // Riverpod may rerun build() on the same Notifier instance when watched
  // dependencies change (for example when a planned workout advances from a
  // rep exercise to a hold exercise). These values therefore describe the
  // current analysis build, not immutable lifetime state of the notifier.
  late EngineKind _engineKind;
  late ExerciseType _activeExercise;
  late DateTime Function() _clock;
  late ExerciseConfig _config;
  late RangeRepContract? _rangeRepContract;
  late HoldContract? _holdContract;
  late PreparedExerciseAnalysisContext _preparedAnalysisContext;
  final AnalysisEngineFactory _engineFactory = const AnalysisEngineFactory();
  final ExerciseCatalog _exerciseCatalog = const ExerciseCatalog();
  final ExerciseMetricsExtractor _metricsExtractor =
      const ExerciseMetricsExtractor();
  final PoseQualityPolicy _poseQualityPolicy = const PoseQualityPolicy();
  RangeRepAnalysisEngine? _rangeRepEngine;
  AlternatingRepEngine? _alternatingRepEngine;
  RangeRepCoordinator? _rangeRepCoordinator;
  RangeRepPrimaryMetricNormalizer? _primaryMetricNormalizer;
  HoldCoordinator? _holdCoordinator;
  ExerciseMetrics _lastExerciseMetrics = const ExerciseMetrics.noPose();
  int? _liveMetricsRepCount;
  int? _liveMetricsAlternatingRepCount;
  Duration? _liveMetricsTempo;
  int? _liveMetricsAsymmetryScore;
  late PoseAcceptanceStabilizer _poseAcceptanceStabilizer;
  late WorkoutFramePosePipeline _framePosePipeline;
  late WorkoutDiagnosticsAccumulator _diagnostics;
  late FeedbackDeliveryPort _feedbackDelivery;
  late RangeRepTempoVoiceConfirmationPolicy
  _rangeRepTempoVoiceConfirmationPolicy;

  @override
  WorkoutState build() {
    // Rebuilding analysis dependencies starts a fresh analysis engine/filter
    // state. Riverpod can rerun build() on this same Notifier instance.
    ref.watch(poseDetectorProvider);
    _clock = ref.watch(workoutClockProvider);
    _feedbackDelivery = ref.watch(feedbackDeliveryProvider);
    _feedbackDelivery.reset();
    _rangeRepTempoVoiceConfirmationPolicy =
        RangeRepTempoVoiceConfirmationPolicy();
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
    _lastExerciseMetrics = const ExerciseMetrics.noPose();
    _liveMetricsRepCount = null;
    _liveMetricsAlternatingRepCount = null;
    _liveMetricsTempo = null;
    _liveMetricsAsymmetryScore = null;
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
        _alternatingRepEngine =
            definition.usesAnalysisEngine(ExerciseAnalysisEngine.alternatingRep)
            ? _engineFactory.createAlternatingRep(
                config: _config,
                rangeRepContract: rangeRepContract,
                minimumRom:
                    rangeRepValidationConfig.minAcceptableRomDelta ?? 0.0,
                now: _clock,
              )
            : null;
        _primaryMetricNormalizer = RangeRepPrimaryMetricNormalizer(
          config: _config,
          rangeRepContract: rangeRepContract,
        );
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
        _alternatingRepEngine = null;
        _rangeRepCoordinator = null;
        _primaryMetricNormalizer = null;
        _holdCoordinator = holdCoordinatorFactory(
          engine: holdEngine,
          config: _config,
          holdContract: holdContract,
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

    _preparedAnalysisContext = PreparedExerciseAnalysisContext.resolve(
      config: _config,
      engineKind: _engineKind,
      rangeRepContract: _rangeRepContract,
      holdContract: _holdContract,
    );

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
      exerciseType: _activeExercise.id,
      configAssetPath: definition.analysisConfigAssetPath,
      cameraViewContract: definition.analysisCameraViewContract,
      rangeRepContract: _rangeRepContract,
      holdContract: _holdContract,
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
              holdTechniqueAssessment:
                  initialHoldSnapshot.holdTechniqueAssessment,
              plankHipDeviation: initialHoldSnapshot.plankHipDeviation,
              plankShoulderElbowOffset:
                  initialHoldSnapshot.plankShoulderElbowOffset,
              hollowShoulderElevation:
                  initialHoldSnapshot.hollowShoulderElevation,
              hollowHeelElevation: initialHoldSnapshot.hollowHeelElevation,
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
    int sensorOrientation, {
    CameraLensDirection? cameraLensDirection,
    DeviceOrientation? deviceOrientation,
  }) async {
    final now = _clock();
    if (_isDiagnosticsEnabled) {
      _diagnostics
        ..recordCameraFrame()
        ..updateCameraRuntimeContext(
          sensorOrientationDegrees: sensorOrientation,
          cameraLensDirection: cameraLensDirection?.name,
          deviceOrientation: deviceOrientation?.name,
        );
    }
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

    final processingStopwatch = Stopwatch()..start();
    if (_isDiagnosticsEnabled) _diagnostics.recordAnalysisAttempt();

    try {
      final detector = ref.read(poseDetectorProvider);
      final assessPose = _poseQualityAssessor();
      final result = await _framePosePipeline.processCameraFrame(
        image: image,
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        lensDirection: cameraLensDirection,
        detector: detector,
        assessPose: assessPose,
      );
      if (ref.read(livePauseControllerProvider).isPaused) {
        return;
      }
      _consumeFramePosePipelineResult(
        result,
        frameCapturedAt: now,
        processingStopwatch: processingStopwatch,
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
        _diagnostics.recordProcessingDuration(processingStopwatch.elapsed);
      }
      debugPrint("ANALIZ HATASI: $e");
    } finally {
      _framePosePipeline.finishCameraFrame();
    }
  }

  @visibleForTesting
  Future<void> processInputImageForAnalysis(InputImage inputImage) async {
    final now = _clock();
    final processingStopwatch = Stopwatch()..start();
    if (_isDiagnosticsEnabled) _diagnostics.recordAnalysisAttempt();

    try {
      final detector = ref.read(poseDetectorProvider);
      final assessPose = _poseQualityAssessor();
      final result = await _framePosePipeline.processInputImage(
        inputImage: inputImage,
        detector: detector,
        assessPose: assessPose,
      );
      if (ref.read(livePauseControllerProvider).isPaused) {
        return;
      }
      _consumeFramePosePipelineResult(
        result,
        frameCapturedAt: now,
        processingStopwatch: processingStopwatch,
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
        _diagnostics.recordProcessingDuration(processingStopwatch.elapsed);
      }
      rethrow;
    }
  }

  void _consumeFramePosePipelineResult(
    FramePosePipelineResult result, {
    required DateTime frameCapturedAt,
    required Stopwatch processingStopwatch,
  }) {
    if (result.kind == FramePosePipelineResultKind.converterDrop) {
      if (_isDiagnosticsEnabled) {
        _diagnostics.recordConverterDrop();
        _diagnostics.recordProcessingDuration(processingStopwatch.elapsed);
      }
      return;
    }

    if (result.poseCount != null && _isDiagnosticsEnabled) {
      _diagnostics.recordPoseCount(result.poseCount!);
    }
    _analysisFrameCount++;
    _updateFpsIfNeeded();

    _updatePoseDiagnosticsFromPipelineResult(result);
    _updateLiveTrackingFromPipelineResult(result, now: frameCapturedAt);
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
      _diagnostics.recordProcessingDuration(processingStopwatch.elapsed);
    }
  }

  void _updateLiveTrackingFromPipelineResult(
    FramePosePipelineResult result, {
    required DateTime now,
  }) {
    if (result.kind == FramePosePipelineResultKind.converterDrop) {
      return;
    }

    final previousState = ref.read(liveTrackingControllerProvider);
    final trackingController = ref.read(
      liveTrackingControllerProvider.notifier,
    );
    switch (result.kind) {
      case FramePosePipelineResultKind.noPose:
      case FramePosePipelineResultKind.rejected:
        trackingController.recordInvalidFrame(now: now);
        break;
      case FramePosePipelineResultKind.pendingAcceptance:
        trackingController.recordPendingAcceptance(now: now);
        break;
      case FramePosePipelineResultKind.accepted:
        trackingController.recordAcceptedFrame(now: now);
        break;
      case FramePosePipelineResultKind.converterDrop:
        break;
    }

    final nextState = ref.read(liveTrackingControllerProvider);
    if (previousState.isTracking && !nextState.isTracking) {
      unawaited(_feedbackDelivery.stop());
    } else if (!previousState.isTracking && nextState.isTracking) {
      _feedbackDelivery.reset();
    }
  }

  void _updatePoseDiagnosticsFromPipelineResult(
    FramePosePipelineResult result,
  ) {
    if (!_isDiagnosticsEnabled) {
      return;
    }

    final assessment = result.selectedAssessment;
    if (assessment != null) {
      _diagnostics.recordPoseQualitySample(
        minimumRequiredLikelihood: assessment.minimumRequiredLikelihood,
        meanRequiredLikelihood: assessment.meanRequiredLikelihood,
        qualityScore: assessment.qualityScore,
      );
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

        final extractedMetrics = _metricsExtractor.extract(
          selectedPose,
          _config,
          engineKind: _engineKind,
          rangeRepContract: _rangeRepContract,
          holdContract: _holdContract,
          preparedContext: _preparedAnalysisContext,
          holdSide: _engineKind == EngineKind.hold
              ? _holdCoordinatorOrThrow().selectHoldSideForAcceptedPose(
                  selectedAssessment,
                )
              : null,
        );
        final normalizedMetrics = _primaryMetricNormalizer?.normalize(
          pose: selectedPose,
          metrics: extractedMetrics,
        );

        return _DetectedPoseFrame(
          metrics: normalizedMetrics ?? extractedMetrics,
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
    _lastExerciseMetrics = metrics;
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
    _processAlternatingRepSidecar(
      metrics: metrics,
      observedAt: now,
      isAcceptedPoseFrame: frameKind == _PoseFrameKind.accepted,
    );
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
    final hasCompletedRepOutcome =
        result.diagnosticsUpdate.completedRepValidationStatus != null;
    _publishRangeRepState(
      result.stateSnapshot,
      deliverFeedback: !hasCompletedRepOutcome,
    );
    _publishRangeRepOutcomeIfAny(result);
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

  void _publishRangeRepState(
    RangeRepCoordinatorStateSnapshot snapshot, {
    bool deliverFeedback = true,
  }) {
    final feedbackCode = snapshot.feedbackDirective.feedbackCode;
    final feedbackMessage = _mapRangeRepFeedbackCodeToMessage(feedbackCode);
    state = WorkoutState.rangeRep(
      landmarks: snapshot.landmarks,
      feedbackMessage: feedbackMessage,
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
        techniqueObservations: snapshot.techniqueObservations,
      ),
    );
    _publishRangeRepLiveMetricDisplay(snapshot.repCount);
    if (deliverFeedback &&
        !ref.read(liveTrackingControllerProvider).suppressesExerciseFeedback) {
      unawaited(
        _feedbackDelivery.deliver(
          FeedbackDeliveryCue(
            id: 'range:${feedbackCode.code}',
            message: feedbackMessage,
            kind: _deliveryKindForRangeRepFeedback(feedbackCode),
          ),
        ),
      );
    }
  }

  void _publishRangeRepOutcomeIfAny(RangeRepCoordinatorFrameResult result) {
    final statusCode = result.diagnosticsUpdate.completedRepValidationStatus;
    final repIndex =
        result.stateSnapshot.calibrationMetrics.lastRangeRepValidatedRepIndex;
    if (statusCode == null || repIndex == null) {
      return;
    }

    final status = _rangeRepValidationStatusFromName(statusCode);
    if (status == null) {
      return;
    }

    final reasons = result.diagnosticsUpdate.completedRepValidationReasons
        .map(_rangeRepValidationReasonFromName)
        .whereType<RangeRepValidationReason>()
        .toList(growable: false);
    final outcome = mapRangeRepOutcomeToViewData(
      repIndex: repIndex,
      status: status,
      reasons: reasons,
      localizations: ref.read(appLocalizationsProvider),
    );
    final didShow = ref
        .read(liveRangeRepOutcomeProvider.notifier)
        .show(outcome);
    if (!didShow) {
      return;
    }
    if (ref.read(liveTrackingControllerProvider).suppressesExerciseFeedback) {
      _rangeRepTempoVoiceConfirmationPolicy.reset();
      return;
    }
    if (!_rangeRepTempoVoiceConfirmationPolicy.shouldAnnounce(
      status: status,
      reasons: reasons,
    )) {
      return;
    }

    unawaited(
      _feedbackDelivery.deliver(
        FeedbackDeliveryCue(
          id: outcome.deliveryId,
          message: outcome.message,
          kind: outcome.status == RangeRepValidationStatus.valid
              ? FeedbackDeliveryKind.movement
              : FeedbackDeliveryKind.corrective,
        ),
      ),
    );
  }

  RangeRepValidationStatus? _rangeRepValidationStatusFromName(String name) {
    for (final status in RangeRepValidationStatus.values) {
      if (status.name == name) {
        return status;
      }
    }
    return null;
  }

  RangeRepValidationReason? _rangeRepValidationReasonFromName(String name) {
    for (final reason in RangeRepValidationReason.values) {
      if (reason.name == name) {
        return reason;
      }
    }
    return null;
  }

  void _publishHoldState(HoldCoordinatorStateSnapshot snapshot) {
    final feedbackMessage = _resolveHoldFeedbackMessage(snapshot);
    state = WorkoutState.hold(
      landmarks: snapshot.landmarks,
      feedbackMessage: feedbackMessage,
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
        holdTechniqueAssessment: snapshot.holdTechniqueAssessment,
        plankHipDeviation: snapshot.plankHipDeviation,
        plankShoulderElbowOffset: snapshot.plankShoulderElbowOffset,
        hollowShoulderElevation: snapshot.hollowShoulderElevation,
        hollowHeelElevation: snapshot.hollowHeelElevation,
      ),
    );
    _publishHoldLiveMetricDisplay();
    if (!ref.read(liveTrackingControllerProvider).suppressesExerciseFeedback) {
      unawaited(
        _feedbackDelivery.deliver(
          _holdFeedbackDeliveryCue(snapshot, feedbackMessage: feedbackMessage),
        ),
      );
    }
  }

  void _processAlternatingRepSidecar({
    required ExerciseMetrics metrics,
    required DateTime observedAt,
    required bool isAcceptedPoseFrame,
  }) {
    final engine = _alternatingRepEngine;
    if (engine == null) {
      return;
    }

    if (!isAcceptedPoseFrame) {
      engine.interrupt();
      return;
    }

    final left = metrics.leftRangeRepMetrics;
    final right = metrics.rightRangeRepMetrics;
    engine.update(
      leftPrimaryMetric: left.hasPrimaryAngle ? left.primaryAngle : null,
      rightPrimaryMetric: right.hasPrimaryAngle ? right.primaryAngle : null,
      observedAt: observedAt,
    );
  }

  void _publishRangeRepLiveMetricDisplay(int repCount) {
    final alternatingRepCount = _alternatingRepEngine?.totalRepCount ?? 0;
    if (_liveMetricsRepCount != repCount ||
        _liveMetricsAlternatingRepCount != alternatingRepCount) {
      _liveMetricsRepCount = repCount;
      _liveMetricsAlternatingRepCount = alternatingRepCount;
      _refreshRangeRepSessionMetricDisplay();
    }

    ref
        .read(workoutLiveMetricsProvider.notifier)
        .publish(
          angleDegrees: _roundedPrimaryMovement(),
          tempo: _liveMetricsTempo,
          asymmetryScore: _liveMetricsAsymmetryScore,
        );
  }

  void _refreshRangeRepSessionMetricDisplay() {
    _liveMetricsTempo = null;
    _liveMetricsAsymmetryScore = null;

    // P0.2 quarantine: raw tempo remains on the engine diagnostics surface,
    // but it is intentionally not projected into user-facing live metrics.

    final alternating = _alternatingRepEngine;
    final asymmetryScore =
        alternating?.symmetrySessionSummary.overallAsymmetryScore;
    if (asymmetryScore != null && asymmetryScore.isFinite) {
      _liveMetricsAsymmetryScore = asymmetryScore.round();
    }
  }

  void _publishHoldLiveMetricDisplay() {
    final diagnostics = _holdCoordinatorOrThrow().diagnosticsSnapshot();
    final stability =
        diagnostics.currentStabilityScore ?? diagnostics.sessionStabilityScore;
    final stabilityScore = stability == null || !stability.isFinite
        ? null
        : stability.round();
    ref
        .read(workoutLiveMetricsProvider.notifier)
        .publish(
          angleDegrees: _roundedPrimaryMovement(),
          stabilityScore: stabilityScore,
        );
  }

  int? _roundedPrimaryMovement() {
    if (!_lastExerciseMetrics.hasPrimaryAngle ||
        !_lastExerciseMetrics.primaryAngle.isFinite) {
      return null;
    }
    return _lastExerciseMetrics.primaryAngle.round();
  }

  WorkoutLiveMetricsSnapshot liveMetricsSnapshot() {
    final frameBuilder = ExerciseMetricSnapshotBuilder(
      scope: ExerciseMetricScope.frame,
    );
    if (_lastExerciseMetrics.hasPrimaryAngle) {
      frameBuilder.set(
        ExerciseMetricRegistry.primaryMovement,
        _lastExerciseMetrics.primaryAngle,
      );
    }
    if (_lastExerciseMetrics.hasFormMetric) {
      frameBuilder.set(
        ExerciseMetricRegistry.form,
        _lastExerciseMetrics.formMetric,
      );
    }

    final leftMetrics = _lastExerciseMetrics.leftRangeRepMetrics;
    final rightMetrics = _lastExerciseMetrics.rightRangeRepMetrics;
    if (_alternatingRepEngine != null &&
        leftMetrics.hasPrimaryAngle &&
        rightMetrics.hasPrimaryAngle) {
      frameBuilder.set(
        ExerciseMetricRegistry.symmetry,
        (leftMetrics.primaryAngle - rightMetrics.primaryAngle).abs(),
      );
    }

    final sessionBuilder = ExerciseMetricSnapshotBuilder(
      scope: ExerciseMetricScope.session,
    );
    int? leftRepCount;
    int? rightRepCount;
    if (_engineKind == EngineKind.rangeRep) {
      sessionBuilder.set(
        ExerciseMetricRegistry.repetitionCount,
        state.repCount,
      );

      // P0.2 quarantine: timing is still captured by the engine and persisted
      // per repetition for developer diagnostics, but no tempo aggregate is
      // exposed through the user-facing session snapshot.

      final alternating = _alternatingRepEngine;
      if (alternating != null) {
        final symmetry = alternating.symmetrySessionSummary;
        leftRepCount = symmetry.leftRepCount;
        rightRepCount = symmetry.rightRepCount;
        final romDifference = symmetry.averageRomDifference;
        if (romDifference != null) {
          sessionBuilder.set(ExerciseMetricRegistry.symmetry, romDifference);
        }
        final asymmetryScore = symmetry.overallAsymmetryScore;
        if (asymmetryScore != null) {
          sessionBuilder.set(
            ExerciseMetricRegistry.asymmetryScore,
            asymmetryScore,
          );
        }

        final totalSideReps = symmetry.leftRepCount + symmetry.rightRepCount;
        if (totalSideReps > 0) {
          final weightedRom =
              ((symmetry.leftAverageRom ?? 0) * symmetry.leftRepCount +
                  (symmetry.rightAverageRom ?? 0) * symmetry.rightRepCount) /
              totalSideReps;
          sessionBuilder.set(ExerciseMetricRegistry.rangeOfMotion, weightedRom);
        }
      }
    } else if (_engineKind == EngineKind.hold) {
      sessionBuilder.set(
        ExerciseMetricRegistry.holdDuration,
        Duration(milliseconds: (state.currentHoldSeconds * 1000).round()),
      );
      final holdDiagnostics = _holdCoordinatorOrThrow().diagnosticsSnapshot();
      final currentStability = holdDiagnostics.currentStabilityScore;
      if (currentStability != null) {
        frameBuilder.set(ExerciseMetricRegistry.stability, currentStability);
      }
      final sessionStability = holdDiagnostics.sessionStabilityScore;
      if (sessionStability != null) {
        sessionBuilder.set(ExerciseMetricRegistry.stability, sessionStability);
      }
    }

    return WorkoutLiveMetricsSnapshot(
      frameMetrics: frameBuilder.build(),
      sessionMetrics: sessionBuilder.build(),
      leftRepCount: leftRepCount,
      rightRepCount: rightRepCount,
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
      _diagnostics.recordResync(
        hadActiveRepContext: update.hasActiveRepContext,
      );
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
    final transitionCodes = update.confirmedTransitionCodes.isNotEmpty
        ? update.confirmedTransitionCodes
        : <String>[
            if (update.confirmedTransitionCode != null)
              update.confirmedTransitionCode!,
          ];
    for (final transitionCode in transitionCodes) {
      _diagnostics.recordRangeRepTransition(transitionCode);
    }
    final validationStatus = update.completedRepValidationStatus;
    if (validationStatus != null) {
      _diagnostics.recordRangeRepValidation(
        statusCode: validationStatus,
        reasonCodes: update.completedRepValidationReasons,
        tempoDiagnosticReasonCodes: update.completedRepTempoDiagnosticReasons,
      );
    }
  }

  void _applyHoldDiagnosticsUpdate(HoldCoordinatorDiagnosticsUpdate update) {
    if (!_isDiagnosticsEnabled) {
      return;
    }

    if (update.recordHoldVisibilitySuspend) {
      _diagnostics.recordHoldVisibilitySuspend();
    }
    if (update.recordHoldVisibilityRecovery) {
      _diagnostics.recordHoldVisibilityRecovery(
        update.holdVisibilityGapDuration,
      );
    }
    if (update.recordHoldVisibilityAbort) {
      _diagnostics.recordHoldVisibilityAbort(update.holdVisibilityGapDuration);
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
      final timingDiagnostics =
          _rangeRepEngineOrThrow().detectionDiagnosticsSnapshot;
      _diagnostics.updateRangeRepState(
        repCount: publishedState.repCount,
        currentPhase: publishedState.currentPhase,
        signalRoles: _rangeRepContract!.signalRoles,
        calibrationOffsetDegrees:
            publishedState.calibrationMetrics.calibrationThresholdOffsetApplied
            ? publishedState
                  .calibrationMetrics
                  .calibrationThresholdOffsetCandidate
            : null,
        activeTimingTrace: timingDiagnostics.activeTimingTrace,
        lastEndedTimingTrace: timingDiagnostics.lastEndedTimingTrace,
        nonMonotonicObservationCount:
            timingDiagnostics.nonMonotonicObservationCount,
      );
      return;
    }

    _diagnostics.updateHoldState(
      currentHoldSeconds: publishedState.currentHoldSeconds.round(),
      bestHoldSeconds: publishedState.bestHoldSeconds.round(),
      currentPhase: publishedState.currentPhase,
      isHolding: publishedState.isHolding,
      signalRoles: _holdContract!.signalRoles,
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
    if (_isDiagnosticsEnabled) {
      _diagnostics.recordLivePerformanceSample(
        cameraFps: _cameraFps,
        analysisFps: _analysisFps,
      );
    }

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
    return (pose) => _poseQualityPolicy.assessPrepared(
      pose: pose,
      config: _config,
      preparedContext: _preparedAnalysisContext,
      requiredHoldSide: requiredHoldSide,
    );
  }

  String _mapRangeRepFeedbackCodeToMessage(RangeRepFeedbackCode code) {
    return mapRangeRepFeedbackCodeToMessage(
      code,
      localizations: ref.read(appLocalizationsProvider),
      exerciseType: _activeExercise,
    );
  }

  FeedbackDeliveryKind _deliveryKindForRangeRepFeedback(
    RangeRepFeedbackCode code,
  ) {
    return switch (code) {
      RangeRepFeedbackCode.waitForBody ||
      RangeRepFeedbackCode.bodyNotVisible => FeedbackDeliveryKind.blocking,
      RangeRepFeedbackCode.awaitNeutral ||
      RangeRepFeedbackCode.ready => FeedbackDeliveryKind.status,
      RangeRepFeedbackCode.descend ||
      RangeRepFeedbackCode.ascend ||
      RangeRepFeedbackCode.repCompleted ||
      RangeRepFeedbackCode.repIncomplete => FeedbackDeliveryKind.movement,
      RangeRepFeedbackCode.legacyFormThresholdViolation ||
      RangeRepFeedbackCode.controlDescent ||
      RangeRepFeedbackCode.controlAscent ||
      RangeRepFeedbackCode.stabilizeTransition ||
      RangeRepFeedbackCode.maintainForm => FeedbackDeliveryKind.corrective,
    };
  }

  FeedbackDeliveryCue _holdFeedbackDeliveryCue(
    HoldCoordinatorStateSnapshot snapshot, {
    required String feedbackMessage,
  }) {
    final feedbackCode = snapshot.holdFeedbackCode;
    if (feedbackCode == null) {
      return FeedbackDeliveryCue(
        id: 'hold:fallback:$feedbackMessage',
        message: feedbackMessage,
        kind: FeedbackDeliveryKind.status,
      );
    }

    return FeedbackDeliveryCue(
      id: 'hold:${feedbackCode.code}',
      message: feedbackMessage,
      kind: _deliveryKindForHoldFeedback(feedbackCode),
    );
  }

  FeedbackDeliveryKind _deliveryKindForHoldFeedback(HoldFeedbackCode code) {
    return switch (code) {
      HoldFeedbackCode.bodyNotVisible => FeedbackDeliveryKind.blocking,
      HoldFeedbackCode.preparePosition ||
      HoldFeedbackCode.holdPosition => FeedbackDeliveryKind.status,
      HoldFeedbackCode.alignHips ||
      HoldFeedbackCode.liftHips ||
      HoldFeedbackCode.adjustElbowSupport ||
      HoldFeedbackCode.placeSupportElbowUnderShoulder ||
      HoldFeedbackCode.useForearmSupport ||
      HoldFeedbackCode.extendLegs ||
      HoldFeedbackCode.increaseHollowCompression ||
      HoldFeedbackCode.extendArmsOverhead ||
      HoldFeedbackCode.straightenKnees ||
      HoldFeedbackCode.adjustWallSitDepth ||
      HoldFeedbackCode.alignWallSitTorso ||
      HoldFeedbackCode.correctForm => FeedbackDeliveryKind.corrective,
    };
  }

  void handleManualPause() {
    unawaited(_feedbackDelivery.stop());
    handleLifecycleInterruption(reason: 'manual pause');
  }

  void handleManualResume() {
    _feedbackDelivery.reset();
    _rangeRepTempoVoiceConfirmationPolicy.reset();
    ref.read(liveTrackingControllerProvider.notifier).reset();
  }

  void handleLifecycleInterruption({String? reason}) {
    _rangeRepTempoVoiceConfirmationPolicy.reset();
    ref.read(liveRangeRepOutcomeProvider.notifier).dismiss();
    ref.read(liveTrackingControllerProvider.notifier).reset();
    if (_engineKind == EngineKind.rangeRep) {
      _poseAcceptanceStabilizer.reset();
      _primaryMetricNormalizer?.reset();
      _alternatingRepEngine?.interrupt();
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
      return mapHoldFeedbackCodeToMessage(
        feedbackCode,
        localizations: ref.read(appLocalizationsProvider),
      );
    }

    return mapHoldFeedbackCodeToMessage(
      HoldFeedbackCode.preparePosition,
      localizations: ref.read(appLocalizationsProvider),
    );
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
