import 'package:camera/camera.dart';
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

class FramePosePipelineResult {
  const FramePosePipelineResult._({
    required this.kind,
    required this.poseCount,
    this.selectedPose,
    this.selectedAssessment,
    this.didBecomeStableTracking = false,
  });

  const FramePosePipelineResult.converterDrop()
    : this._(kind: FramePosePipelineResultKind.converterDrop, poseCount: null);

  const FramePosePipelineResult.noPose({required int poseCount})
    : this._(kind: FramePosePipelineResultKind.noPose, poseCount: poseCount);

  const FramePosePipelineResult.rejected({
    required int poseCount,
    required PoseQualityAssessment? selectedAssessment,
  }) : this._(
         kind: FramePosePipelineResultKind.rejected,
         poseCount: poseCount,
         selectedAssessment: selectedAssessment,
       );

  const FramePosePipelineResult.pendingAcceptance({
    required int poseCount,
    required PoseQualityAssessment selectedAssessment,
  }) : this._(
         kind: FramePosePipelineResultKind.pendingAcceptance,
         poseCount: poseCount,
         selectedAssessment: selectedAssessment,
       );

  const FramePosePipelineResult.accepted({
    required int poseCount,
    required Pose selectedPose,
    required PoseQualityAssessment selectedAssessment,
    required bool didBecomeStableTracking,
  }) : this._(
         kind: FramePosePipelineResultKind.accepted,
         poseCount: poseCount,
         selectedPose: selectedPose,
         selectedAssessment: selectedAssessment,
         didBecomeStableTracking: didBecomeStableTracking,
       );

  final FramePosePipelineResultKind kind;
  final int? poseCount;
  final Pose? selectedPose;
  final PoseQualityAssessment? selectedAssessment;
  final bool didBecomeStableTracking;

  bool get ranPoseDetection => poseCount != null;
}

/// Owns the family-independent camera-frame and pose candidate processing flow.
class WorkoutFramePosePipeline {
  WorkoutFramePosePipeline({
    InputImageConverter inputImageConverter = const InputImageConverter(),
    PoseAcceptanceStabilizer? poseAcceptanceStabilizer,
    this.analysisFrameInterval = const Duration(milliseconds: 100),
  }) : _inputImageConverter = inputImageConverter,
       _poseAcceptanceStabilizer =
           poseAcceptanceStabilizer ?? PoseAcceptanceStabilizer();

  final InputImageConverter _inputImageConverter;
  final PoseAcceptanceStabilizer _poseAcceptanceStabilizer;
  final Duration analysisFrameInterval;

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
    required PoseDetector detector,
    required PoseQualityAssessor assessPose,
  }) async {
    final inputImage = _inputImageConverter.convert(image, sensorOrientation);
    if (inputImage == null) {
      return const FramePosePipelineResult.converterDrop();
    }

    return processInputImage(
      inputImage: inputImage,
      detector: detector,
      assessPose: assessPose,
    );
  }

  Future<FramePosePipelineResult> processInputImage({
    required InputImage inputImage,
    required PoseDetector detector,
    required PoseQualityAssessor assessPose,
  }) async {
    final poses = await detector.processImage(inputImage);
    return _evaluateDetectedPoses(poses, assessPose: assessPose);
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
