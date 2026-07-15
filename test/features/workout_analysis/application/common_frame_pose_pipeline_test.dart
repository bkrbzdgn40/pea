import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/common_frame_pose_pipeline.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  group('WorkoutFramePosePipeline', () {
    test(
      'camera frame gate blocks reentrant and throttled frames until the interval elapses',
      () {
        final pipeline = WorkoutFramePosePipeline();
        final clock = TestFakeClock();

        expect(
          pipeline.prepareCameraFrame(now: clock.now()),
          FrameProcessingGateDecision.proceed,
        );
        expect(
          pipeline.prepareCameraFrame(now: clock.now()),
          FrameProcessingGateDecision.reentrantDrop,
        );

        pipeline.finishCameraFrame();

        expect(
          pipeline.prepareCameraFrame(now: clock.now()),
          FrameProcessingGateDecision.throttledDrop,
        );

        clock.advance(const Duration(milliseconds: 100));

        expect(
          pipeline.prepareCameraFrame(now: clock.now()),
          FrameProcessingGateDecision.proceed,
        );
      },
    );

    test(
      'processInputImage keeps the first accepted frame pending and then accepts the best candidate',
      () async {
        final pipeline = WorkoutFramePosePipeline();
        final detector = TestQueuedPoseDetector();
        final poseQualityPolicy = const PoseQualityPolicy();
        PoseQualityAssessment assessPose(Pose pose) {
          return poseQualityPolicy.assess(
            pose: pose,
            config: buildSquatConfig(),
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.squat,
          );
        }

        final acceptedPose = buildSquatPose(
          angle: 170,
          defaultLikelihood: 0.66,
        );
        final rejectedPose = buildSquatPose(
          angle: 90,
          defaultLikelihood: 1.0,
          likelihoodOverrides: const <PoseLandmarkType, double>{
            PoseLandmarkType.leftAnkle: 0.49,
          },
        );

        detector.enqueue(<Pose>[acceptedPose, rejectedPose]);
        final first = await pipeline.processInputImage(
          inputImage: dummyInputImage(),
          detector: detector,
          assessPose: assessPose,
        );

        detector.enqueue(<Pose>[acceptedPose, rejectedPose]);
        final second = await pipeline.processInputImage(
          inputImage: dummyInputImage(),
          detector: detector,
          assessPose: assessPose,
        );

        expect(first.kind, FramePosePipelineResultKind.pendingAcceptance);
        expect(second.kind, FramePosePipelineResultKind.accepted);
        expect(second.selectedPose, same(acceptedPose));
        expect(
          second.selectedAssessment?.acceptedRangeRepSides,
          const <RangeRepSide>{RangeRepSide.left},
        );
        expect(
          second.selectedAssessment?.preferredRangeRepSide,
          RangeRepSide.left,
        );
      },
    );
  });
}
