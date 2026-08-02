import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'common_frame_pose_pipeline.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';
import 'exercise_metrics_extractor.dart';
import 'pose_quality_policy.dart';
import 'workout_analysis_runtime.dart';
import 'workout_diagnostics.dart';

typedef WorkoutFrameProcessorFactory =
    WorkoutFrameProcessor Function({
      required WorkoutAnalysisRuntime runtime,
      required DateTime Function() clock,
      required WorkoutFrameProcessorCallbacks callbacks,
    });

typedef WorkoutPoseDetectorReader = PoseDetector Function();
typedef WorkoutPauseStateReader = bool Function();

/// Frame classification delivered to the exercise-specific coordinator path.
enum WorkoutPoseFrameKind { noPose, rejected, pendingAcceptance, accepted }

class WorkoutDetectedPoseFrame {
  const WorkoutDetectedPoseFrame({
    required this.metrics,
    required this.kind,
    this.didBecomeStableTracking = false,
    this.qualityAcceptedRangeRepSides,
    this.preferredRangeRepSide,
  });

  final ExerciseMetrics metrics;
  final WorkoutPoseFrameKind kind;
  final bool didBecomeStableTracking;
  final Set<RangeRepSide>? qualityAcceptedRangeRepSides;
  final RangeRepSide? preferredRangeRepSide;
}

class WorkoutFrameProcessorCallbacks {
  const WorkoutFrameProcessorCallbacks({
    required this.onCameraFrameObserved,
    required this.onAnalysisFrameObserved,
    required this.onTrackingResult,
    required this.onDetectedPoseFrame,
  });

  final void Function() onCameraFrameObserved;
  final void Function() onAnalysisFrameObserved;
  final void Function(FramePosePipelineResult result, DateTime observedAt)
  onTrackingResult;
  final void Function(WorkoutDetectedPoseFrame frame, DateTime observedAt)
  onDetectedPoseFrame;
}

enum WorkoutFrameProcessingStatus {
  reentrantDrop,
  throttledDrop,
  paused,
  converterDrop,
  analyzed,
  failed,
}

class WorkoutFrameProcessingOutcome {
  const WorkoutFrameProcessingOutcome._({
    required this.status,
    this.error,
    this.stackTrace,
  });

  const WorkoutFrameProcessingOutcome.reentrantDrop()
    : this._(status: WorkoutFrameProcessingStatus.reentrantDrop);

  const WorkoutFrameProcessingOutcome.throttledDrop()
    : this._(status: WorkoutFrameProcessingStatus.throttledDrop);

  const WorkoutFrameProcessingOutcome.paused()
    : this._(status: WorkoutFrameProcessingStatus.paused);

  const WorkoutFrameProcessingOutcome.converterDrop()
    : this._(status: WorkoutFrameProcessingStatus.converterDrop);

  const WorkoutFrameProcessingOutcome.analyzed()
    : this._(status: WorkoutFrameProcessingStatus.analyzed);

  const WorkoutFrameProcessingOutcome.failed({
    required Object error,
    required StackTrace stackTrace,
  }) : this._(
         status: WorkoutFrameProcessingStatus.failed,
         error: error,
         stackTrace: stackTrace,
       );

  final WorkoutFrameProcessingStatus status;
  final Object? error;
  final StackTrace? stackTrace;
}

/// Owns the family-independent frame orchestration around the pose pipeline.
///
/// The processor deliberately stops at an exercise-neutral detected frame. The
/// controller remains responsible for Riverpod tracking state and for routing
/// the resulting metrics to the range-rep or hold coordinator.
class WorkoutFrameProcessor {
  WorkoutFrameProcessor({
    required WorkoutAnalysisRuntime runtime,
    required DateTime Function() clock,
    required WorkoutFrameProcessorCallbacks callbacks,
    ExerciseMetricsExtractor metricsExtractor =
        const ExerciseMetricsExtractor(),
    PoseQualityPolicy poseQualityPolicy = const PoseQualityPolicy(),
  }) : _runtime = runtime,
       _clock = clock,
       _callbacks = callbacks,
       _metricsExtractor = metricsExtractor,
       _poseQualityPolicy = poseQualityPolicy;

  final WorkoutAnalysisRuntime _runtime;
  final DateTime Function() _clock;
  final WorkoutFrameProcessorCallbacks _callbacks;
  final ExerciseMetricsExtractor _metricsExtractor;
  final PoseQualityPolicy _poseQualityPolicy;

  bool _hasTemporalCameraContext = false;
  int? _temporalSensorOrientation;
  CameraLensDirection? _temporalCameraLensDirection;
  DeviceOrientation? _temporalDeviceOrientation;

  WorkoutFramePosePipeline get _pipeline => _runtime.framePosePipeline;
  WorkoutDiagnosticsAccumulator get _diagnostics =>
      _runtime.diagnosticsReporter.accumulator;
  bool get _diagnosticsEnabled => _runtime.diagnosticsReporter.enabled;

  Future<WorkoutFrameProcessingOutcome> processCameraImage({
    required CameraImage image,
    required int sensorOrientation,
    required CameraLensDirection? cameraLensDirection,
    required DeviceOrientation? deviceOrientation,
    required WorkoutPoseDetectorReader readDetector,
    required WorkoutPauseStateReader isPaused,
  }) async {
    final now = _clock();
    _resetTemporalHistoryIfCameraContextChanged(
      sensorOrientation: sensorOrientation,
      cameraLensDirection: cameraLensDirection,
      deviceOrientation: deviceOrientation,
    );
    if (_diagnosticsEnabled) {
      _diagnostics
        ..recordCameraFrame()
        ..updateCameraRuntimeContext(
          sensorOrientationDegrees: sensorOrientation,
          cameraLensDirection: cameraLensDirection?.name,
          deviceOrientation: deviceOrientation?.name,
        );
    }
    _callbacks.onCameraFrameObserved();

    final schedulingDecision = _pipeline.prepareCameraFrame(now: now);
    if (schedulingDecision == FrameProcessingGateDecision.reentrantDrop) {
      if (_diagnosticsEnabled) {
        _diagnostics.recordReentrantDrop();
      }
      return const WorkoutFrameProcessingOutcome.reentrantDrop();
    }
    if (schedulingDecision == FrameProcessingGateDecision.throttledDrop) {
      if (_diagnosticsEnabled) {
        _diagnostics.recordThrottledFrame();
      }
      return const WorkoutFrameProcessingOutcome.throttledDrop();
    }

    final processingStopwatch = Stopwatch()..start();
    if (_diagnosticsEnabled) {
      _diagnostics.recordAnalysisAttempt();
    }

    try {
      final result = await _pipeline.processCameraFrame(
        image: image,
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        lensDirection: cameraLensDirection,
        detector: readDetector(),
        assessPose: _poseQualityAssessor(),
      );
      if (isPaused()) {
        return const WorkoutFrameProcessingOutcome.paused();
      }
      return _consumePipelineResult(
        result,
        frameCapturedAt: now,
        processingStopwatch: processingStopwatch,
      );
    } catch (error, stackTrace) {
      if (_diagnosticsEnabled) {
        _diagnostics.recordAnalysisException();
        _diagnostics.recordProcessingDuration(processingStopwatch.elapsed);
      }
      return WorkoutFrameProcessingOutcome.failed(
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _pipeline.finishCameraFrame();
    }
  }

  Future<WorkoutFrameProcessingOutcome> processInputImage({
    required InputImage inputImage,
    required WorkoutPoseDetectorReader readDetector,
    required WorkoutPauseStateReader isPaused,
  }) async {
    final now = _clock();
    final processingStopwatch = Stopwatch()..start();
    if (_diagnosticsEnabled) {
      _diagnostics.recordAnalysisAttempt();
    }

    try {
      final result = await _pipeline.processInputImage(
        inputImage: inputImage,
        detector: readDetector(),
        assessPose: _poseQualityAssessor(),
      );
      if (isPaused()) {
        return const WorkoutFrameProcessingOutcome.paused();
      }
      return _consumePipelineResult(
        result,
        frameCapturedAt: now,
        processingStopwatch: processingStopwatch,
      );
    } catch (error, stackTrace) {
      if (_diagnosticsEnabled) {
        _diagnostics.recordAnalysisException();
        _diagnostics.recordProcessingDuration(processingStopwatch.elapsed);
      }
      return WorkoutFrameProcessingOutcome.failed(
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _resetTemporalHistoryIfCameraContextChanged({
    required int sensorOrientation,
    required CameraLensDirection? cameraLensDirection,
    required DeviceOrientation? deviceOrientation,
  }) {
    if (_runtime.engineKind != EngineKind.rangeRep) {
      return;
    }

    final contextChanged =
        _hasTemporalCameraContext &&
        (_temporalSensorOrientation != sensorOrientation ||
            _temporalCameraLensDirection != cameraLensDirection ||
            _temporalDeviceOrientation != deviceOrientation);
    if (contextChanged) {
      _runtime.rangeRepTemporalContinuityTracker?.reset();
    }
    _hasTemporalCameraContext = true;
    _temporalSensorOrientation = sensorOrientation;
    _temporalCameraLensDirection = cameraLensDirection;
    _temporalDeviceOrientation = deviceOrientation;
  }

  WorkoutFrameProcessingOutcome _consumePipelineResult(
    FramePosePipelineResult result, {
    required DateTime frameCapturedAt,
    required Stopwatch processingStopwatch,
  }) {
    final pipelineTimings = result.timings;
    if (_diagnosticsEnabled && pipelineTimings != null) {
      _diagnostics.recordFramePosePipelineDurations(
        conversionDuration: pipelineTimings.conversionDuration,
        poseDetectionDuration: pipelineTimings.poseDetectionDuration,
        candidateEvaluationDuration:
            pipelineTimings.candidateEvaluationDuration,
        totalDuration: pipelineTimings.totalDuration,
      );
    }

    if (result.kind == FramePosePipelineResultKind.converterDrop) {
      if (_diagnosticsEnabled) {
        _diagnostics.recordConverterDrop();
        _diagnostics.recordProcessingDuration(processingStopwatch.elapsed);
      }
      return const WorkoutFrameProcessingOutcome.converterDrop();
    }

    if (result.poseCount != null && _diagnosticsEnabled) {
      _diagnostics.recordPoseCount(result.poseCount!);
    }
    _callbacks.onAnalysisFrameObserved();

    _updatePoseDiagnosticsFromPipelineResult(result);
    _callbacks.onTrackingResult(result, frameCapturedAt);
    if (result.invalidatesRangeRepTemporalHistory) {
      _runtime.rangeRepTemporalContinuityTracker?.reset();
    }
    final detectedFrame = _detectedPoseFrameFromPipelineResult(
      result,
      observedAt: frameCapturedAt,
    );
    _callbacks.onDetectedPoseFrame(detectedFrame, frameCapturedAt);

    if (_diagnosticsEnabled) {
      _diagnostics.recordAnalysisCompleted();
      _diagnostics.recordProcessingDuration(processingStopwatch.elapsed);
    }
    return const WorkoutFrameProcessingOutcome.analyzed();
  }

  void _updatePoseDiagnosticsFromPipelineResult(
    FramePosePipelineResult result,
  ) {
    if (!_diagnosticsEnabled) {
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

  WorkoutDetectedPoseFrame _detectedPoseFrameFromPipelineResult(
    FramePosePipelineResult result, {
    required DateTime observedAt,
  }) {
    switch (result.kind) {
      case FramePosePipelineResultKind.noPose:
        return const WorkoutDetectedPoseFrame(
          metrics: ExerciseMetrics.noPose(),
          kind: WorkoutPoseFrameKind.noPose,
        );
      case FramePosePipelineResultKind.rejected:
        return const WorkoutDetectedPoseFrame(
          metrics: ExerciseMetrics.noPose(),
          kind: WorkoutPoseFrameKind.rejected,
        );
      case FramePosePipelineResultKind.pendingAcceptance:
        return const WorkoutDetectedPoseFrame(
          metrics: ExerciseMetrics.noPose(),
          kind: WorkoutPoseFrameKind.pendingAcceptance,
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
          _runtime.config,
          engineKind: _runtime.engineKind,
          rangeRepContract: _runtime.rangeRepContract,
          holdContract: _runtime.holdContract,
          preparedContext: _runtime.preparedAnalysisContext,
          poseQualityAssessment: selectedAssessment,
          holdSide: _runtime.engineKind == EngineKind.hold
              ? _runtime.requireHoldCoordinator().selectHoldSideForAcceptedPose(
                  selectedAssessment,
                )
              : null,
        );
        final normalizedMetrics = _runtime.primaryMetricNormalizer?.normalize(
          pose: selectedPose,
          metrics: extractedMetrics,
        );
        final baseMetrics = normalizedMetrics ?? extractedMetrics;
        final confidenceMetrics = _runtime.rangeRepTemporalContinuityTracker
            ?.updateMetrics(
              pose: selectedPose,
              metrics: baseMetrics,
              preparedContext: _runtime.preparedAnalysisContext,
              observedAt: observedAt,
            );

        return WorkoutDetectedPoseFrame(
          metrics: confidenceMetrics ?? baseMetrics,
          kind: WorkoutPoseFrameKind.accepted,
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

  PoseQualityAssessor _poseQualityAssessor() {
    final requiredHoldSide = _runtime.engineKind == EngineKind.hold
        ? _runtime.requireHoldCoordinator().requiredHoldSideForAssessment()
        : null;
    return (pose) => _poseQualityPolicy.assessPrepared(
      pose: pose,
      config: _runtime.config,
      preparedContext: _runtime.preparedAnalysisContext,
      requiredHoldSide: requiredHoldSide,
    );
  }
}
