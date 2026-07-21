import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../application/assessment_pose_quality_policy.dart';
import '../../application/assessment_engine.dart';
import '../../application/assessment_measurement_extractor.dart';
import '../../application/common_frame_pose_pipeline.dart';
import '../../application/pose_quality_policy.dart';
import '../../domain/models/assessment_models.dart';
import 'pose_provider.dart';
import 'selected_assessment_provider.dart';

class AssessmentLiveState {
  const AssessmentLiveState({
    required this.snapshot,
    required this.feedbackMessage,
    this.landmarks,
  });

  final AssessmentSnapshot snapshot;
  final String feedbackMessage;
  final List<PoseLandmark>? landmarks;

  AssessmentLiveState copyWith({
    AssessmentSnapshot? snapshot,
    String? feedbackMessage,
    List<PoseLandmark>? landmarks,
  }) {
    return AssessmentLiveState(
      snapshot: snapshot ?? this.snapshot,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      landmarks: landmarks ?? this.landmarks,
    );
  }
}

final assessmentLiveControllerProvider =
    AutoDisposeNotifierProvider<AssessmentLiveController, AssessmentLiveState>(
      AssessmentLiveController.new,
    );

class AssessmentLiveController
    extends AutoDisposeNotifier<AssessmentLiveState> {
  final AssessmentMeasurementExtractor _extractor =
      const AssessmentMeasurementExtractor();
  final AssessmentPoseQualityPolicy _poseQualityPolicy =
      const AssessmentPoseQualityPolicy();

  late AssessmentSelection _selection;
  late AssessmentEngine _engine;
  late WorkoutFramePosePipeline _framePosePipeline;

  @override
  AssessmentLiveState build() {
    final selection = ref.watch(selectedAssessmentProvider);
    if (selection == null) {
      throw StateError('Assessment mode requires a selected assessment.');
    }
    _selection = selection;
    _engine = AssessmentEngine(type: selection.type);
    _framePosePipeline = WorkoutFramePosePipeline();
    final snapshot = _engine.start(balanceSide: selection.balanceSide);
    return AssessmentLiveState(
      snapshot: snapshot,
      feedbackMessage: _instructionFor(selection),
    );
  }

  Future<void> processCameraImage(
    CameraImage image,
    int sensorOrientation, {
    DateTime? capturedAt,
  }) async {
    final now = capturedAt ?? DateTime.now();
    if (state.snapshot.isCompleted) {
      return;
    }

    final gate = _framePosePipeline.prepareCameraFrame(now: now);
    if (gate != FrameProcessingGateDecision.proceed) {
      return;
    }

    try {
      final detector = ref.read(poseDetectorProvider);
      final result = await _framePosePipeline.processCameraFrame(
        image: image,
        sensorOrientation: sensorOrientation,
        detector: detector,
        assessPose: (pose) =>
            _poseQualityPolicy.assess(pose: pose, type: _selection.type),
      );

      switch (result.kind) {
        case FramePosePipelineResultKind.converterDrop:
          return;
        case FramePosePipelineResultKind.noPose:
          state = AssessmentLiveState(
            snapshot: state.snapshot,
            feedbackMessage: _poseQualityFeedback(null),
          );
          return;
        case FramePosePipelineResultKind.rejected:
          state = AssessmentLiveState(
            snapshot: state.snapshot,
            feedbackMessage: _poseQualityFeedback(
              result.selectedAssessment?.rejectionReason,
            ),
          );
          return;
        case FramePosePipelineResultKind.pendingAcceptance:
          state = AssessmentLiveState(
            snapshot: state.snapshot,
            feedbackMessage: 'Pozisyonunu kısa süre sabit tut.',
          );
          return;
        case FramePosePipelineResultKind.accepted:
          break;
      }

      if (state.snapshot.isCompleted) {
        return;
      }
      final pose = result.selectedPose!;
      final observation = _observationFor(pose, capturedAt: now);
      final snapshot = _engine.observe(observation);
      state = AssessmentLiveState(
        snapshot: snapshot,
        feedbackMessage: _instructionFor(_selection),
        landmarks: pose.landmarks.values.toList(growable: false),
      );
    } catch (_) {
      state = AssessmentLiveState(
        snapshot: state.snapshot,
        feedbackMessage: 'Kare analiz edilemedi. Pozisyonunu koru.',
      );
    } finally {
      _framePosePipeline.finishCameraFrame();
    }
  }

  AssessmentResult complete() {
    if (state.snapshot.isCompleted) {
      return state.snapshot.result!;
    }
    final result = _engine.complete();
    state = state.copyWith(
      snapshot: _engine.snapshot,
      feedbackMessage: result.hasSufficientData
          ? 'Değerlendirme tamamlandı.'
          : 'Sonuç için yeterli ölçüm toplanamadı.',
    );
    return result;
  }

  AssessmentObservation _observationFor(
    Pose pose, {
    required DateTime capturedAt,
  }) {
    return switch (_selection.type) {
      AssessmentType.squat => _extractor.extractSquat(pose),
      AssessmentType.balance => _extractor.extractBalance(
        pose,
        side: _selection.balanceSide!,
        capturedAt: capturedAt,
      ),
      AssessmentType.shoulderMobility => _extractor.extractShoulderMobility(
        pose,
      ),
    };
  }

  String _instructionFor(AssessmentSelection selection) {
    return switch (selection.type) {
      AssessmentType.squat =>
        'Kameraya yandan dön. Tüm vücudun kadrajdayken kontrollü çömel ve tekrar ayağa kalk.',
      AssessmentType.balance =>
        'Kameraya önden dön. Tüm vücudun kadrajdayken seçilen ayağın üzerinde sabit kal.',
      AssessmentType.shoulderMobility =>
        'Kameraya önden dön. İki kolun da görünürken kollarını aşağıdan başlayarak kontrollü biçimde yukarı kaldır.',
    };
  }

  String _poseQualityFeedback(PoseRejectionReason? reason) {
    if (reason == PoseRejectionReason.lowLandmarkLikelihood ||
        reason == PoseRejectionReason.lowMeanLikelihood) {
      return 'Görüntü yeterince net değil. Işığı artır ve tüm vücudunu görünür tut.';
    }
    if (reason == PoseRejectionReason.nonFiniteCoordinate ||
        reason == PoseRejectionReason.degenerateGeometry) {
      return 'Pozisyon ölçülemiyor. Kameradan biraz uzaklaşıp tüm vücudunu kadraja al.';
    }
    return 'Tüm vücudunu kadraja al ve gerekli eklemleri görünür tut.';
  }
}
