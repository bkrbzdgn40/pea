import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../application/assessment_engine.dart';
import '../../application/assessment_measurement_extractor.dart';
import '../../application/assessment_pose_quality_policy.dart';
import '../../application/common_frame_pose_pipeline.dart';
import '../../application/exercise_metrics.dart';
import '../../application/pose_quality_policy.dart';
import '../../domain/models/assessment_models.dart';
import 'pose_provider.dart';
import 'selected_assessment_provider.dart';
import 'settings_provider.dart';

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
    // Keep the auto-disposed ML Kit detector alive for the full assessment
    // session. WorkoutController owns the same dependency this way; using
    // only ref.read(...) from frame callbacks can leave the detector without
    // a listener and allow Riverpod to dispose it between frames.
    ref.watch(poseDetectorProvider);
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
    DeviceOrientation? deviceOrientation,
    CameraLensDirection? lensDirection,
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
        deviceOrientation: deviceOrientation,
        lensDirection: lensDirection,
        detector: detector,
        assessPose: (pose) =>
            _poseQualityPolicy.assess(pose: pose, type: _selection.type),
      );

      switch (result.kind) {
        case FramePosePipelineResultKind.converterDrop:
          _publishUnavailableInput(
            capturedAt: now,
            feedbackMessage: ref
                .read(appLocalizationsProvider)
                .assessmentFrameAnalysisFailed,
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
            feedbackMessage: ref
                .read(appLocalizationsProvider)
                .assessmentHoldPositionBriefly,
          );
          return;
        case FramePosePipelineResultKind.accepted:
          break;
      }

      if (state.snapshot.isCompleted) {
        return;
      }
      final pose = result.selectedPose!;
      final observation = _observationFor(
        pose,
        capturedAt: now,
        poseAssessment: result.selectedAssessment!,
      );
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
        feedbackMessage: ref
            .read(appLocalizationsProvider)
            .assessmentFrameAnalysisFailed,
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
        feedbackMessage: ref
            .read(appLocalizationsProvider)
            .assessmentNotReadyFeedback,
      );
      return null;
    }

    final result = _engine.complete();
    state = _stateFor(
      snapshot: _engine.snapshot,
      feedbackMessage: result.hasSufficientData
          ? ref.read(appLocalizationsProvider).assessmentCompletedFeedback
          : ref.read(appLocalizationsProvider).assessmentInsufficientFeedback,
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
    required PoseQualityAssessment poseAssessment,
  }) {
    return switch (_selection.type) {
      AssessmentType.squat => _extractor.extractSquat(
        pose,
        side: switch (poseAssessment.preferredRangeRepSide) {
          RangeRepSide.left => AssessmentSide.left,
          RangeRepSide.right => AssessmentSide.right,
          null => null,
        },
      ),
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
      return ref.read(appLocalizationsProvider).assessmentReadyFeedback;
    }

    if (observation case BalanceAssessmentObservation balance) {
      final clearance = balance.raisedFootClearanceRatio;
      if (!balance.isComplete ||
          clearance == null ||
          !clearance.isFinite ||
          clearance < _engine.config.minimumRaisedFootClearanceRatio) {
        return ref.read(appLocalizationsProvider).balanceStanceResetFeedback;
      }
    }

    return _instructionFor(_selection);
  }

  String _progressMessage(AssessmentSnapshot snapshot) {
    if (snapshot.isReadyToComplete) {
      return ref.read(appLocalizationsProvider).assessmentReady;
    }

    switch (snapshot.type) {
      case AssessmentType.squat:
        return ref
            .read(appLocalizationsProvider)
            .assessmentMovementProgress(
              (snapshot.readinessProgress * 100).round(),
            );
      case AssessmentType.balance:
        final elapsed = snapshot.continuousEvidenceDuration ?? Duration.zero;
        final target = _engine.config.minimumBalanceDuration;
        return ref
            .read(appLocalizationsProvider)
            .assessmentContinuousStanceProgress(
              _seconds(elapsed),
              _seconds(target),
            );
      case AssessmentType.shoulderMobility:
        return ref
            .read(appLocalizationsProvider)
            .assessmentElevationProgress(
              (snapshot.readinessProgress * 100).round(),
            );
    }
  }

  String _instructionFor(AssessmentSelection selection) {
    return switch (selection.type) {
      AssessmentType.squat =>
        ref.read(appLocalizationsProvider).squatAssessmentInstruction,
      AssessmentType.balance =>
        ref.read(appLocalizationsProvider).balanceAssessmentInstruction,
      AssessmentType.shoulderMobility =>
        ref.read(appLocalizationsProvider).shoulderAssessmentInstruction,
    };
  }

  String _poseQualityFeedback(PoseRejectionReason? reason) {
    if (reason == PoseRejectionReason.lowLandmarkLikelihood ||
        reason == PoseRejectionReason.lowMeanLikelihood) {
      return ref.read(appLocalizationsProvider).poseQualityLowConfidence;
    }
    if (reason == PoseRejectionReason.nonFiniteCoordinate ||
        reason == PoseRejectionReason.degenerateGeometry) {
      return ref.read(appLocalizationsProvider).poseQualityGeometryUnavailable;
    }
    return ref
        .read(appLocalizationsProvider)
        .poseQualityKeepRequiredJointsVisible;
  }

  String _seconds(Duration duration) {
    return (duration.inMilliseconds / 1000).toStringAsFixed(1);
  }
}
