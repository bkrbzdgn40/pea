import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../../core/utils/monotonic_datetime_clock.dart';

import '../../application/common_frame_pose_pipeline.dart';
import '../../application/engine_kind.dart';
import '../../application/exercise_catalog.dart';
import '../../application/exercise_metric_registry.dart';
import '../../application/exercise_metrics.dart';
import '../../application/exercise_metrics_extractor.dart';
import '../../application/feedback_delivery_controller.dart';
import '../../application/hold_coordinator.dart';
import '../../application/pose_acceptance_stabilizer.dart';
import '../../application/pose_quality_policy.dart';
import '../../application/prepared_exercise_analysis_context.dart';
import '../../application/range_rep_coordinator.dart';
import '../../application/range_rep_primary_metric_normalizer.dart';
import '../../application/range_rep_tempo_voice_confirmation_policy.dart';
import '../../application/range_rep_temporal_continuity_tracker.dart';
import '../../application/validated_rep_event_tracker.dart';
import '../../application/workout_state.dart';
import '../../application/workout_analysis_runtime.dart';
import '../../application/workout_diagnostics.dart';
import '../../application/workout_state_projector.dart';
import '../../application/workout_live_metrics.dart';
import '../../domain/hold_analysis_engine.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/hold_contract.dart';
import '../../domain/models/hold_feedback_code.dart';
import '../../domain/models/range_rep_contract.dart';
import '../../domain/models/range_rep_feedback_code.dart';
import '../../domain/models/range_rep_validation_result.dart';
import '../../domain/models/validated_rep_event.dart';
import '../../domain/range_rep_analysis_engine.dart';
import '../../domain/range_rep_validation_policy.dart';
import '../../domain/tempo_engine.dart';
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
          collectStageTimings: kDebugMode || kProfileMode,
        );
      };
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

final workoutAnalysisRuntimeFactoryProvider =
    Provider<WorkoutAnalysisRuntimeFactory>((ref) {
      return const WorkoutAnalysisRuntimeFactory();
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
  late WorkoutAnalysisRuntime _runtime;
  late DateTime Function() _clock;
  final ExerciseMetricsExtractor _metricsExtractor =
      const ExerciseMetricsExtractor();
  final PoseQualityPolicy _poseQualityPolicy = const PoseQualityPolicy();
  final WorkoutStateProjector _stateProjector = const WorkoutStateProjector();
  bool _hasTemporalCameraContext = false;
  int? _temporalSensorOrientation;
  CameraLensDirection? _temporalCameraLensDirection;
  DeviceOrientation? _temporalDeviceOrientation;
  ExerciseMetrics _lastExerciseMetrics = const ExerciseMetrics.noPose();
  int? _liveMetricsRepCount;
  int? _liveMetricsAlternatingRepCount;
  Duration? _liveMetricsTempo;
  int? _liveMetricsAsymmetryScore;
  final TempoSessionAccumulator _eligibleTempoSessionAccumulator =
      TempoSessionAccumulator();
  int? _lastRecordedTempoRepIndex;
  late FeedbackDeliveryPort _feedbackDelivery;
  late RangeRepTempoVoiceConfirmationPolicy
  _rangeRepTempoVoiceConfirmationPolicy;

  EngineKind get _engineKind => _runtime.engineKind;
  ExerciseType get _activeExercise => _runtime.activeExercise;
  ExerciseConfig get _config => _runtime.config;
  RangeRepContract? get _rangeRepContract => _runtime.rangeRepContract;
  HoldContract? get _holdContract => _runtime.holdContract;
  PreparedExerciseAnalysisContext get _preparedAnalysisContext =>
      _runtime.preparedAnalysisContext;
  RangeRepAnalysisEngine? get _rangeRepEngine => _runtime.rangeRepEngine;
  ValidatedRepEventTracker? get _validatedRepEventTracker =>
      _runtime.validatedRepEventTracker;
  RangeRepCoordinator? get _rangeRepCoordinator => _runtime.rangeRepCoordinator;
  RangeRepPrimaryMetricNormalizer? get _primaryMetricNormalizer =>
      _runtime.primaryMetricNormalizer;
  RangeRepTemporalContinuityTracker? get _rangeRepTemporalContinuityTracker =>
      _runtime.rangeRepTemporalContinuityTracker;
  HoldCoordinator? get _holdCoordinator => _runtime.holdCoordinator;
  PoseAcceptanceStabilizer get _poseAcceptanceStabilizer =>
      _runtime.poseAcceptanceStabilizer;
  WorkoutFramePosePipeline get _framePosePipeline => _runtime.framePosePipeline;
  WorkoutDiagnosticsAccumulator get _diagnostics =>
      _runtime.diagnosticsReporter.accumulator;

  @override
  WorkoutState build() {
    // Rebuilding analysis dependencies starts a fresh analysis engine/filter
    // state. Riverpod can rerun build() on this same Notifier instance.
    ref.watch(poseDetectorProvider);
    _clock = ref.watch(workoutClockProvider);
    _feedbackDelivery = ref.watch(feedbackDeliveryProvider);
    _feedbackDelivery.reset();
    _rangeRepTempoVoiceConfirmationPolicy =
        RangeRepTempoVoiceConfirmationPolicy(tempoAnnouncementsEnabled: true);
    _eligibleTempoSessionAccumulator.reset();
    _lastRecordedTempoRepIndex = null;
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
    final config = ref.watch(exerciseConfigProvider).requireValue;
    final runtimeFactory = ref.watch(workoutAnalysisRuntimeFactoryProvider);

    _lastExerciseMetrics = const ExerciseMetrics.noPose();
    _liveMetricsRepCount = null;
    _liveMetricsAlternatingRepCount = null;
    _liveMetricsTempo = null;
    _liveMetricsAsymmetryScore = null;
    _hasTemporalCameraContext = false;
    _temporalSensorOrientation = null;
    _temporalCameraLensDirection = null;
    _temporalDeviceOrientation = null;

    _runtime = runtimeFactory.create(
      activeExercise: activeExercise,
      config: config,
      clock: _clock,
      framePosePipelineFactory: framePosePipelineFactory,
      rangeRepCoordinatorFactory: rangeRepCoordinatorFactory,
      holdCoordinatorFactory: holdCoordinatorFactory,
      diagnosticsEnabled: kDebugMode || kProfileMode,
    );
    _lastFpsCalculationTime = _runtime.fpsWindowStartedAt;
    _cameraFrameCount = 0;
    _analysisFrameCount = 0;
    _cameraFps = 0.0;
    _analysisFps = 0.0;

    final initialHoldSnapshot = _engineKind == EngineKind.hold
        ? _holdCoordinatorOrThrow().currentStateSnapshot()
        : null;
    final initialState = _engineKind == EngineKind.hold
        ? _stateProjector.initialHold(
            snapshot: initialHoldSnapshot!,
            feedbackMessage: _resolveHoldFeedbackMessage(initialHoldSnapshot),
          )
        : _stateProjector.initialRangeRep(
            feedbackMessage: _mapRangeRepFeedbackCodeToMessage(
              RangeRepFeedbackCode.awaitNeutral,
            ),
            currentPhase: _rangeRepEngineOrThrow().phaseLabel,
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
    _resetTemporalHistoryIfCameraContextChanged(
      sensorOrientation: sensorOrientation,
      cameraLensDirection: cameraLensDirection,
      deviceOrientation: deviceOrientation,
    );
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

  void _resetTemporalHistoryIfCameraContextChanged({
    required int sensorOrientation,
    required CameraLensDirection? cameraLensDirection,
    required DeviceOrientation? deviceOrientation,
  }) {
    if (_engineKind != EngineKind.rangeRep) {
      return;
    }

    final contextChanged =
        _hasTemporalCameraContext &&
        (_temporalSensorOrientation != sensorOrientation ||
            _temporalCameraLensDirection != cameraLensDirection ||
            _temporalDeviceOrientation != deviceOrientation);
    if (contextChanged) {
      _rangeRepTemporalContinuityTracker?.reset();
    }
    _hasTemporalCameraContext = true;
    _temporalSensorOrientation = sensorOrientation;
    _temporalCameraLensDirection = cameraLensDirection;
    _temporalDeviceOrientation = deviceOrientation;
  }

  void _consumeFramePosePipelineResult(
    FramePosePipelineResult result, {
    required DateTime frameCapturedAt,
    required Stopwatch processingStopwatch,
  }) {
    final pipelineTimings = result.timings;
    if (_isDiagnosticsEnabled && pipelineTimings != null) {
      _diagnostics.recordFramePosePipelineDurations(
        conversionDuration: pipelineTimings.conversionDuration,
        poseDetectionDuration: pipelineTimings.poseDetectionDuration,
        candidateEvaluationDuration:
            pipelineTimings.candidateEvaluationDuration,
        totalDuration: pipelineTimings.totalDuration,
      );
    }

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
    if (result.invalidatesRangeRepTemporalHistory) {
      _rangeRepTemporalContinuityTracker?.reset();
    }
    final detectedFrame = _detectedPoseFrameFromPipelineResult(
      result,
      observedAt: frameCapturedAt,
    );
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
    FramePosePipelineResult result, {
    required DateTime observedAt,
  }) {
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
          poseQualityAssessment: selectedAssessment,
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
        final baseMetrics = normalizedMetrics ?? extractedMetrics;
        final confidenceMetrics = _rangeRepTemporalContinuityTracker
            ?.updateMetrics(
              pose: selectedPose,
              metrics: baseMetrics,
              preparedContext: _preparedAnalysisContext,
              observedAt: observedAt,
            );

        return _DetectedPoseFrame(
          metrics: confidenceMetrics ?? baseMetrics,
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

  bool get _isDiagnosticsEnabled => _runtime.diagnosticsReporter.enabled;

  WorkoutDiagnosticsSnapshot diagnosticsSnapshot({DateTime? now}) {
    return _runtime.diagnosticsReporter.snapshot(now: now ?? _clock());
  }

  void resetDiagnostics({DateTime? now}) {
    _runtime.diagnosticsReporter.reset(
      now: now ?? _clock(),
      analysisKind: _engineKind.name,
    );
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
      _rangeRepTemporalContinuityTracker?.reset();
    }
    if (result.diagnosticsUpdate.visibilityStatus == 'hard_resync') {
      _rangeRepTemporalContinuityTracker?.reset();
    }
    final hasCompletedRepOutcome =
        result.diagnosticsUpdate.completedRepValidationStatus != null;
    final validatedRepEvent = result.validatedRepEvent?.copyWith(
      exerciseType: _activeExercise.id,
    );
    _recordValidatedRepEvent(validatedRepEvent);
    _publishRangeRepState(
      result.stateSnapshot,
      validatedRepEvent: validatedRepEvent,
      deliverFeedback: !hasCompletedRepOutcome,
    );
    _publishRangeRepOutcomeIfAny(result, validatedRepEvent: validatedRepEvent);
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
    ValidatedRepEvent? validatedRepEvent,
    bool deliverFeedback = true,
  }) {
    final feedbackCode = snapshot.feedbackDirective.feedbackCode;
    final feedbackMessage = _mapRangeRepFeedbackCodeToMessage(feedbackCode);
    state = _stateProjector.rangeRep(
      snapshot: snapshot,
      feedbackMessage: feedbackMessage,
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
      validatedRepEvent: validatedRepEvent,
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

  void _publishRangeRepOutcomeIfAny(
    RangeRepCoordinatorFrameResult result, {
    required ValidatedRepEvent? validatedRepEvent,
  }) {
    final event = validatedRepEvent;
    if (event == null) {
      return;
    }

    final status = event.validationStatus;
    final reasons = event.validationReasons;
    final tempoAssessment = event.tempoAssessment;
    if (event.countsTowardReps &&
        tempoAssessment?.isAvailable == true &&
        _lastRecordedTempoRepIndex != event.attemptIndex) {
      final measuredTempo = tempoAssessment!.measurement.measuredTempo;
      if (measuredTempo != null) {
        _eligibleTempoSessionAccumulator.record(measuredTempo);
        _lastRecordedTempoRepIndex = event.attemptIndex;
        _liveMetricsTempo = measuredTempo.totalRepDuration;
        _refreshRangeRepSessionMetricDisplay();
        _publishRangeRepLiveMetricDisplay(result.stateSnapshot.repCount);
      }
    }
    final outcome = mapRangeRepOutcomeToViewData(
      repIndex: event.attemptIndex,
      status: status,
      reasons: reasons,
      localizations: ref.read(appLocalizationsProvider),
      exerciseType: _activeExercise,
      tempoAssessment: tempoAssessment,
      measurementConfidence: event.measurementConfidence,
      towardPeakIsEccentric:
          _rangeRepContract?.towardPeakMuscleAction ==
          RangeRepTowardPeakMuscleAction.eccentric,
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
      tempoAssessment: tempoAssessment,
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

  void _recordValidatedRepEvent(ValidatedRepEvent? event) {
    if (event == null) {
      return;
    }
    final tracker = _validatedRepEventTracker;
    if (tracker == null) {
      return;
    }
    tracker.record(event);
  }

  void _publishHoldState(HoldCoordinatorStateSnapshot snapshot) {
    final feedbackMessage = _resolveHoldFeedbackMessage(snapshot);
    state = _stateProjector.hold(
      snapshot: snapshot,
      feedbackMessage: feedbackMessage,
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
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

  void _publishRangeRepLiveMetricDisplay(int repCount) {
    final alternatingRepCount = _validatedRepEventTracker?.totalRepCount ?? 0;
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
    _liveMetricsAsymmetryScore = null;

    final alternating = _validatedRepEventTracker;
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
    if (_validatedRepEventTracker != null &&
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

      final tempoSummary = _eligibleTempoSessionAccumulator.summary;
      if (tempoSummary.repCount > 0) {
        sessionBuilder.set(
          ExerciseMetricRegistry.tempo,
          tempoSummary.averageRepDuration,
        );
      }

      final alternating = _validatedRepEventTracker;
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

        final totalRomSamples =
            alternating.leftRomSampleCount + alternating.rightRomSampleCount;
        if (totalRomSamples > 0) {
          final weightedRom =
              ((symmetry.leftAverageRom ?? 0) * alternating.leftRomSampleCount +
                  (symmetry.rightAverageRom ?? 0) *
                      alternating.rightRomSampleCount) /
              totalRomSamples;
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
      tempoConsistencyScore:
          _eligibleTempoSessionAccumulator.summary.repCount > 0
          ? _eligibleTempoSessionAccumulator.summary.consistencyScore
          : null,
      fastestRepDuration: _eligibleTempoSessionAccumulator.summary.repCount > 0
          ? _eligibleTempoSessionAccumulator.summary.fastestRepDuration
          : null,
      slowestRepDuration: _eligibleTempoSessionAccumulator.summary.repCount > 0
          ? _eligibleTempoSessionAccumulator.summary.slowestRepDuration
          : null,
    );
  }

  void _applyRangeRepDiagnosticsUpdate(
    RangeRepCoordinatorDiagnosticsUpdate update,
  ) {
    _runtime.diagnosticsReporter.applyRangeRepCoordinatorUpdate(update);
  }

  void _applyHoldDiagnosticsUpdate(HoldCoordinatorDiagnosticsUpdate update) {
    _runtime.diagnosticsReporter.applyHoldCoordinatorUpdate(update);
  }

  void _updateDiagnosticsFromState() {
    _updateDiagnosticsFromPublishedState(state);
  }

  void _updateDiagnosticsFromPublishedState(WorkoutState publishedState) {
    _runtime.diagnosticsReporter.updateFromPublishedState(
      publishedState: publishedState,
      engineKind: _engineKind,
      cameraFps: _cameraFps,
      analysisFps: _analysisFps,
      lastExerciseMetrics: _lastExerciseMetrics,
      rangeRepEngine: _rangeRepEngine,
      rangeRepContract: _rangeRepContract,
      holdCoordinator: _holdCoordinator,
      holdContract: _holdContract,
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
    return _runtime.requireRangeRepCoordinator();
  }

  RangeRepAnalysisEngine _rangeRepEngineOrThrow() {
    return _runtime.requireRangeRepEngine();
  }

  HoldCoordinator _holdCoordinatorOrThrow() {
    return _runtime.requireHoldCoordinator();
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
      _rangeRepTemporalContinuityTracker?.reset();
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
