import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_quality_policy.dart' show PoseQualityAssessment;
import 'pose_acceptance_stabilizer.dart';
import '../infrastructure/converters/input_image_converter.dart';

enum FrameProcessingGateDecision { proceed, reentrantDrop, throttledDrop }

enum FramePosePipelineResultKind {
  converterDrop,
  noPose,
  rejected,
  pendingAcceptance,
  accepted,
}

typedef PoseQualityAssessor = PoseQualityAssessment Function(Pose pose);

/// Debug/profile-only timing data for one frame-pose pipeline execution.
///
/// A null stage means that stage did not run. Camera conversion is absent when
/// [WorkoutFramePosePipeline.processInputImage] is used directly, while pose
/// detection and candidate evaluation are absent for converter drops.
class FramePosePipelineTimings {
  const FramePosePipelineTimings({
    this.conversionDuration,
    this.poseDetectionDuration,
    this.candidateEvaluationDuration,
    required this.totalDuration,
  });

  final Duration? conversionDuration;
  final Duration? poseDetectionDuration;
  final Duration? candidateEvaluationDuration;
  final Duration totalDuration;
}

class FramePosePipelineResult {
  const FramePosePipelineResult._({
    required this.kind,
    required this.poseCount,
    this.selectedPose,
    this.selectedAssessment,
    this.didBecomeStableTracking = false,
    this.timings,
  });

  const FramePosePipelineResult.converterDrop({
    FramePosePipelineTimings? timings,
  }) : this._(
         kind: FramePosePipelineResultKind.converterDrop,
         poseCount: null,
         timings: timings,
       );

  const FramePosePipelineResult.noPose({
    required int poseCount,
    FramePosePipelineTimings? timings,
  }) : this._(
         kind: FramePosePipelineResultKind.noPose,
         poseCount: poseCount,
         timings: timings,
       );

  const FramePosePipelineResult.rejected({
    required int poseCount,
    required PoseQualityAssessment? selectedAssessment,
    FramePosePipelineTimings? timings,
  }) : this._(
         kind: FramePosePipelineResultKind.rejected,
         poseCount: poseCount,
         selectedAssessment: selectedAssessment,
         timings: timings,
       );

  const FramePosePipelineResult.pendingAcceptance({
    required int poseCount,
    required PoseQualityAssessment selectedAssessment,
    FramePosePipelineTimings? timings,
  }) : this._(
         kind: FramePosePipelineResultKind.pendingAcceptance,
         poseCount: poseCount,
         selectedAssessment: selectedAssessment,
         timings: timings,
       );

  const FramePosePipelineResult.accepted({
    required int poseCount,
    required Pose selectedPose,
    required PoseQualityAssessment selectedAssessment,
    required bool didBecomeStableTracking,
    FramePosePipelineTimings? timings,
  }) : this._(
         kind: FramePosePipelineResultKind.accepted,
         poseCount: poseCount,
         selectedPose: selectedPose,
         selectedAssessment: selectedAssessment,
         didBecomeStableTracking: didBecomeStableTracking,
         timings: timings,
       );

  final FramePosePipelineResultKind kind;
  final int? poseCount;
  final Pose? selectedPose;
  final PoseQualityAssessment? selectedAssessment;
  final bool didBecomeStableTracking;
  final FramePosePipelineTimings? timings;

  bool get ranPoseDetection => poseCount != null;

  /// Whether this result breaks frame-to-frame range-rep continuity.
  ///
  /// Converter drops do not contain pose evidence and accepted frames continue
  /// history. Missing, rejected, and stabilization-pending pose results require
  /// the next accepted frame to start a fresh temporal history.
  bool get invalidatesRangeRepTemporalHistory {
    return switch (kind) {
      FramePosePipelineResultKind.noPose ||
      FramePosePipelineResultKind.rejected ||
      FramePosePipelineResultKind.pendingAcceptance => true,
      FramePosePipelineResultKind.converterDrop ||
      FramePosePipelineResultKind.accepted => false,
    };
  }

  FramePosePipelineResult withTimings(FramePosePipelineTimings timings) {
    return switch (kind) {
      FramePosePipelineResultKind.converterDrop =>
        FramePosePipelineResult.converterDrop(timings: timings),
      FramePosePipelineResultKind.noPose => FramePosePipelineResult.noPose(
        poseCount: poseCount!,
        timings: timings,
      ),
      FramePosePipelineResultKind.rejected => FramePosePipelineResult.rejected(
        poseCount: poseCount!,
        selectedAssessment: selectedAssessment,
        timings: timings,
      ),
      FramePosePipelineResultKind.pendingAcceptance =>
        FramePosePipelineResult.pendingAcceptance(
          poseCount: poseCount!,
          selectedAssessment: selectedAssessment!,
          timings: timings,
        ),
      FramePosePipelineResultKind.accepted => FramePosePipelineResult.accepted(
        poseCount: poseCount!,
        selectedPose: selectedPose!,
        selectedAssessment: selectedAssessment!,
        didBecomeStableTracking: didBecomeStableTracking,
        timings: timings,
      ),
    };
  }
}

/// Owns the family-independent camera-frame and pose candidate processing flow.
class WorkoutFramePosePipeline {
  WorkoutFramePosePipeline({
    InputImageConverter inputImageConverter = const InputImageConverter(),
    PoseAcceptanceStabilizer? poseAcceptanceStabilizer,
    this.analysisFrameInterval = const Duration(milliseconds: 100),
    this.collectStageTimings = false,
  }) : _inputImageConverter = inputImageConverter,
       _poseAcceptanceStabilizer =
           poseAcceptanceStabilizer ?? PoseAcceptanceStabilizer();

  final InputImageConverter _inputImageConverter;
  final PoseAcceptanceStabilizer _poseAcceptanceStabilizer;
  final Duration analysisFrameInterval;

  /// Enables low-overhead Stopwatch profiling in debug/profile builds.
  ///
  /// Production wiring keeps this disabled in release mode so measurement does
  /// not become part of the user-facing hot path.
  final bool collectStageTimings;

  bool _isProcessing = false;
  DateTime? _lastAnalysisStartedAt;

  FrameProcessingGateDecision prepareCameraFrame({required DateTime now}) {
    if (_isProcessing) {
      return FrameProcessingGateDecision.reentrantDrop;
    }

    if (_lastAnalysisStartedAt != null &&
        now.difference(_lastAnalysisStartedAt!) < analysisFrameInterval) {
      return FrameProcessingGateDecision.throttledDrop;
    }

    _lastAnalysisStartedAt = now;
    _isProcessing = true;
    return FrameProcessingGateDecision.proceed;
  }

  void finishCameraFrame() {
    _isProcessing = false;
  }

  Future<FramePosePipelineResult> processCameraFrame({
    required CameraImage image,
    required int sensorOrientation,
    required DeviceOrientation? deviceOrientation,
    required CameraLensDirection? lensDirection,
    required PoseDetector detector,
    required PoseQualityAssessor assessPose,
  }) async {
    if (!collectStageTimings) {
      final inputImage = _inputImageConverter.convert(
        image,
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        lensDirection: lensDirection,
      );
      if (inputImage == null) {
        return const FramePosePipelineResult.converterDrop();
      }

      return processInputImage(
        inputImage: inputImage,
        detector: detector,
        assessPose: assessPose,
      );
    }

    final totalStopwatch = Stopwatch()..start();
    final conversionStopwatch = Stopwatch()..start();
    final inputImage = _inputImageConverter.convert(
      image,
      sensorOrientation: sensorOrientation,
      deviceOrientation: deviceOrientation,
      lensDirection: lensDirection,
    );
    conversionStopwatch.stop();

    if (inputImage == null) {
      totalStopwatch.stop();
      return FramePosePipelineResult.converterDrop(
        timings: FramePosePipelineTimings(
          conversionDuration: conversionStopwatch.elapsed,
          totalDuration: totalStopwatch.elapsed,
        ),
      );
    }

    return _processInputImageProfiled(
      inputImage: inputImage,
      detector: detector,
      assessPose: assessPose,
      conversionDuration: conversionStopwatch.elapsed,
      totalStopwatch: totalStopwatch,
    );
  }

  Future<FramePosePipelineResult> processInputImage({
    required InputImage inputImage,
    required PoseDetector detector,
    required PoseQualityAssessor assessPose,
  }) async {
    if (!collectStageTimings) {
      return _processInputImageUnprofiled(
        inputImage: inputImage,
        detector: detector,
        assessPose: assessPose,
      );
    }

    return _processInputImageProfiled(
      inputImage: inputImage,
      detector: detector,
      assessPose: assessPose,
      conversionDuration: null,
      totalStopwatch: Stopwatch()..start(),
    );
  }

  Future<FramePosePipelineResult> _processInputImageUnprofiled({
    required InputImage inputImage,
    required PoseDetector detector,
    required PoseQualityAssessor assessPose,
  }) async {
    final poses = await detector.processImage(inputImage);
    return _evaluateDetectedPoses(poses, assessPose: assessPose);
  }

  Future<FramePosePipelineResult> _processInputImageProfiled({
    required InputImage inputImage,
    required PoseDetector detector,
    required PoseQualityAssessor assessPose,
    required Duration? conversionDuration,
    required Stopwatch totalStopwatch,
  }) async {
    final detectionStopwatch = Stopwatch()..start();
    final poses = await detector.processImage(inputImage);
    detectionStopwatch.stop();

    final evaluationStopwatch = Stopwatch()..start();
    final result = _evaluateDetectedPoses(poses, assessPose: assessPose);
    evaluationStopwatch.stop();
    totalStopwatch.stop();

    return result.withTimings(
      FramePosePipelineTimings(
        conversionDuration: conversionDuration,
        poseDetectionDuration: detectionStopwatch.elapsed,
        candidateEvaluationDuration: evaluationStopwatch.elapsed,
        totalDuration: totalStopwatch.elapsed,
      ),
    );
  }

  FramePosePipelineResult _evaluateDetectedPoses(
    List<Pose> poses, {
    required PoseQualityAssessor assessPose,
  }) {
    if (poses.isEmpty) {
      _poseAcceptanceStabilizer.recordInvalidFrame();
      return FramePosePipelineResult.noPose(poseCount: poses.length);
    }

    final candidates = <_SelectedPoseCandidate>[];
    for (var index = 0; index < poses.length; index++) {
      final pose = poses[index];
      final assessment = assessPose(pose);
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
      _poseAcceptanceStabilizer.recordInvalidFrame();
      return FramePosePipelineResult.rejected(
        poseCount: poses.length,
        selectedAssessment: selectedCandidate?.assessment,
      );
    }

    final acceptance = _poseAcceptanceStabilizer.recordAcceptedFrame();
    if (!acceptance.shouldAcceptForAnalysis) {
      return FramePosePipelineResult.pendingAcceptance(
        poseCount: poses.length,
        selectedAssessment: selectedCandidate.assessment,
      );
    }

    return FramePosePipelineResult.accepted(
      poseCount: poses.length,
      selectedPose: selectedCandidate.pose,
      selectedAssessment: selectedCandidate.assessment,
      didBecomeStableTracking: acceptance.didBecomeStable,
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
