import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/preparation_camera_controller.dart';

import '../../../../support/workout_analysis_test_support.dart';

void main() {
  test('preparation camera state protects its landmark collection', () {
    final source = <PoseLandmark>[
      buildLandmark(PoseLandmarkType.leftShoulder, 10, 20),
    ];
    final state = PreparationCameraState(landmarks: source);

    source.clear();

    expect(state.hasPose, isTrue);
    expect(state.landmarks, hasLength(1));
    expect(
      () => state.landmarks.add(
        buildLandmark(PoseLandmarkType.rightShoulder, 30, 20),
      ),
      throwsUnsupportedError,
    );
  });

  test('selects the pose with the most complete landmark set', () {
    final smallerPose = _pose(<PoseLandmark>[
      buildLandmark(PoseLandmarkType.leftShoulder, 10, 20),
    ]);
    final largerPose = _pose(<PoseLandmark>[
      buildLandmark(PoseLandmarkType.leftShoulder, 10, 20),
      buildLandmark(PoseLandmarkType.leftHip, 12, 40),
    ]);

    expect(
      selectPreparationPreviewPose(<Pose>[smallerPose, largerPose]),
      same(largerPose),
    );
  });

  test('uses a detector dedicated to the preparation preview', () async {
    final preparationDetector = TestQueuedPoseDetector();
    final analysisDetector = _FailingPoseDetector();
    final pose = _pose(<PoseLandmark>[
      buildLandmark(PoseLandmarkType.leftShoulder, 10, 20),
      buildLandmark(PoseLandmarkType.leftHip, 12, 40),
    ]);
    preparationDetector.enqueue(<Pose>[pose]);

    final container = ProviderContainer(
      overrides: <Override>[
        preparationPoseDetectorProvider.overrideWith(
          (ref) => preparationDetector,
        ),
        poseDetectorProvider.overrideWith((ref) => analysisDetector),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen<PreparationCameraState>(
      preparationCameraControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container
        .read(preparationCameraControllerProvider.notifier)
        .processInputImageForPreview(dummyInputImage());

    expect(
      container.read(preparationCameraControllerProvider).landmarks,
      hasLength(2),
    );
    expect(analysisDetector.processImageCallCount, 0);
  });

  test('keeps detector order when pose completeness is tied', () {
    final firstPose = _pose(<PoseLandmark>[
      buildLandmark(PoseLandmarkType.leftShoulder, 10, 20),
    ]);
    final secondPose = _pose(<PoseLandmark>[
      buildLandmark(PoseLandmarkType.rightShoulder, 30, 20),
    ]);

    expect(
      selectPreparationPreviewPose(<Pose>[firstPose, secondPose]),
      same(firstPose),
    );
    expect(selectPreparationPreviewPose(const <Pose>[]), isNull);
  });
}

Pose _pose(List<PoseLandmark> landmarks) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      for (final landmark in landmarks) landmark.type: landmark,
    },
  );
}

class _FailingPoseDetector implements PoseDetector {
  int processImageCallCount = 0;

  @override
  Future<List<Pose>> processImage(InputImage inputImage) async {
    processImageCallCount += 1;
    throw StateError('The live-analysis detector must not be used.');
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
