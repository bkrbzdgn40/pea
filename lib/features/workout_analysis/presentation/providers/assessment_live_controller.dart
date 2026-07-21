import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../application/assessment_engine.dart';
import '../../application/assessment_measurement_extractor.dart';
import '../../application/assessment_pose_quality_policy.dart';
import '../../application/common_frame_pose_pipeline.dart';
import '../../application/pose_quality_policy.dart';
import '../../domain/models/assessment_models.dart';
import 'pose_provider.dart';
import 'selected_assessment_provider.dart';

class AssessmentLiveState {
  const AssessmentLiveState({
    required this.snapshot,
    required this.feedbackMessage,
    required this.progressMessage,
    this.landmarks,
  });

  final AssessmentSnapshot snapshot;
  final String feedbackMessage;
  final String progressMessage;
  final List<PoseLandmark>? landmarks;

  AssessmentLiveState copyWith({
    AssessmentSnapshot? snapshot,
    String? feedbackMessage,
    String? progressMessage,
    List<PoseLandmark>? landmarks,
  }) {
    return AssessmentLiveState(
      snapshot: snapshot ?? this.snapshot,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      progressMessage: progressMessage ?? this.progressMessage,
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
    return _stateFor(
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
          _publishUnavailableInput(
            capturedAt: now,
            feedbackMessage: 'Kare analiz edilemedi. Pozisyonunu koru.',
          );
          return;
        case FramePosePipelineResultKind.noPose:
          _publishUnavailableInput(
            capturedAt: now,
            feedbackMessage: _poseQualityFeedback(null),
          );
          return;
        case FramePosePipelineResultKind.rejected:
          _publishUnavailableInput(
            capturedAt: now,
            feedbackMessage: _poseQualityFeedback(
              result.selectedAssessment?.rejectionReason,
            ),
          );
          return;
        case FramePosePipelineResultKind.pendingAcceptance:
          _publishUnavailableInput(
            capturedAt: now,
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
      state = _stateFor(
        snapshot: snapshot,
        feedbackMessage: _feedbackAfterObservation(
          observation: observation,
          snapshot: snapshot,
        ),
        landmarks: pose.landmarks.values.toList(growable: false),
      );
    } catch (_) {
      _publishUnavailableInput(
        capturedAt: now,
        feedbackMessage: 'Kare analiz edilemedi. Pozisyonunu koru.',
      );
    } finally {
      _framePosePipeline.finishCameraFrame();
    }
  }

  AssessmentResult? complete() {
    if (state.snapshot.isCompleted) {
      return state.snapshot.result;
    }
    if (!state.snapshot.isReadyToComplete) {
      state = state.copyWith(
        feedbackMessage:
            'Ölçüm henüz hazır değil. Yönergeyi tamamlamaya devam et.',
      );
      return null;
    }

    final result = _engine.complete();
    state = _stateFor(
      snapshot: _engine.snapshot,
      feedbackMessage: result.hasSufficientData
          ? 'Değerlendirme tamamlandı.'
          : 'Sonuç için yeterli ölçüm toplanamadı.',
      landmarks: state.landmarks,
    );
    return result;
  }

  void retry() {
    _engine.reset();
    _framePosePipeline = WorkoutFramePosePipeline();
    final snapshot = _engine.start(balanceSide: _selection.balanceSide);
    state = _stateFor(
      snapshot: snapshot,
      feedbackMessage: _instructionFor(_selection),
    );
  }

  void _publishUnavailableInput({
    required DateTime capturedAt,
    required String feedbackMessage,
  }) {
    final snapshot = _engine.markInputUnavailable(capturedAt: capturedAt);
    state = _stateFor(
      snapshot: snapshot,
      feedbackMessage: feedbackMessage,
      landmarks: state.landmarks,
    );
  }

  AssessmentLiveState _stateFor({
    required AssessmentSnapshot snapshot,
    required String feedbackMessage,
    List<PoseLandmark>? landmarks,
  }) {
    return AssessmentLiveState(
      snapshot: snapshot,
      feedbackMessage: feedbackMessage,
      progressMessage: _progressMessage(snapshot),
      landmarks: landmarks,
    );
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

  String _feedbackAfterObservation({
    required AssessmentObservation observation,
    required AssessmentSnapshot snapshot,
  }) {
    if (snapshot.isReadyToComplete) {
      return 'Ölçüm hazır. Sonucu görmek için aşağıdaki düğmeye dokun.';
    }

    if (observation case BalanceAssessmentObservation balance) {
      final clearance = balance.raisedFootClearanceRatio;
      if (!balance.isComplete ||
          clearance == null ||
          !clearance.isFinite ||
          clearance < _engine.config.minimumRaisedFootClearanceRatio) {
        return 'Tek ayak duruşu bozuldu. Süre yeniden başladı.';
      }
    }

    return _instructionFor(_selection);
  }

  String _progressMessage(AssessmentSnapshot snapshot) {
    if (snapshot.isReadyToComplete) {
      return 'Ölçüm hazır';
    }

    switch (snapshot.type) {
      case AssessmentType.squat:
        return 'Hareket ilerlemesi: %${(snapshot.readinessProgress * 100).round()}';
      case AssessmentType.balance:
        final elapsed = snapshot.continuousEvidenceDuration ?? Duration.zero;
        final target = _engine.config.minimumBalanceDuration;
        return 'Kesintisiz duruş: ${_seconds(elapsed)} / ${_seconds(target)} sn';
      case AssessmentType.shoulderMobility:
        return 'Elevasyon ilerlemesi: %${(snapshot.readinessProgress * 100).round()}';
    }
  }

  String _instructionFor(AssessmentSelection selection) {
    return switch (selection.type) {
      AssessmentType.squat =>
        'Kameraya yandan dön. Tüm vücudun kadrajdayken kontrollü bir squat yap ve tekrar ayağa kalk.',
      AssessmentType.balance =>
        'Kameraya önden dön. Tüm vücudun kadrajdayken seçilen ayağın üzerinde kesintisiz sabit kal.',
      AssessmentType.shoulderMobility =>
        'Kameraya önden dön. Dirseklerini mümkün olduğunca düz tutarak kollarını gövdenin yanından iki yana doğru kontrollü biçimde kaldır.',
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

  String _seconds(Duration duration) {
    return (duration.inMilliseconds / 1000).toStringAsFixed(1);
  }
}
