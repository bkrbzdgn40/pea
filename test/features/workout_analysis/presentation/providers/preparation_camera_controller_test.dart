import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_camera_view_orientation.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_framing_geometry.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/preparation_camera_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';

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

  test('publishes exercise-aware framing as shadow diagnostics', () async {
    final detector = TestQueuedPoseDetector();
    detector.enqueue(<Pose>[
      _pose(<PoseLandmark>[
        buildLandmark(PoseLandmarkType.nose, 50, 20),
        buildLandmark(PoseLandmarkType.leftShoulder, 45, 45),
        buildLandmark(PoseLandmarkType.leftHip, 47, 90),
        buildLandmark(PoseLandmarkType.leftKnee, 48, 130),
        buildLandmark(PoseLandmarkType.leftAnkle, 49, 170),
        buildLandmark(PoseLandmarkType.leftFootIndex, 50, 180),
      ]),
    ]);

    final container = ProviderContainer(
      overrides: <Override>[
        preparationPoseDetectorProvider.overrideWith((ref) => detector),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedExerciseProvider.notifier).state =
        ExerciseType.squat;
    final subscription = container.listen<PreparationCameraState>(
      preparationCameraControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      container
          .read(
            preparationFramingAssessmentProvider((
              imageWidth: 100,
              imageHeight: 200,
              mirrorHorizontally: false,
            )),
          )
          ?.status,
      SetupFramingStatus.noPerson,
    );

    await container
        .read(preparationCameraControllerProvider.notifier)
        .processInputImageForPreview(dummyInputImage());

    final assessment = container.read(
      preparationFramingAssessmentProvider((
        imageWidth: 100,
        imageHeight: 200,
        mirrorHorizontally: false,
      )),
    );
    expect(assessment, isNotNull);
    expect(assessment!.status, SetupFramingStatus.ready);
    expect(assessment.requiredLandmarksVisible, isTrue);
  });

  test('publishes contract-aware camera-view shadow diagnostics', () async {
    final detector = TestQueuedPoseDetector();
    detector.enqueue(<Pose>[_sideOrientationPose()]);
    detector.enqueue(<Pose>[_frontOrientationPose()]);
    final capturedAt = DateTime(2026, 7, 26, 12);

    final container = ProviderContainer(
      overrides: <Override>[
        preparationPoseDetectorProvider.overrideWith((ref) => detector),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedExerciseProvider.notifier).state =
        ExerciseType.squat;
    final subscription = container.listen<PreparationCameraState>(
      preparationCameraControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final request = (
      imageWidth: 100.0,
      imageHeight: 200.0,
      mirrorHorizontally: false,
    );

    expect(
      container.read(preparationCameraViewAssessmentProvider(request))?.status,
      SetupCameraViewAdvisoryStatus.insufficientEvidence,
    );

    await container
        .read(preparationCameraControllerProvider.notifier)
        .processInputImageForPreview(dummyInputImage(), capturedAt: capturedAt);

    final sideAssessment = container.read(
      preparationCameraViewAssessmentProvider(request),
    );
    expect(sideAssessment, isNotNull);
    expect(sideAssessment!.status, SetupCameraViewAdvisoryStatus.preferred);
    expect(sideAssessment.detectedView, CameraView.side);

    await container
        .read(preparationCameraControllerProvider.notifier)
        .processInputImageForPreview(
          dummyInputImage(),
          capturedAt: capturedAt.add(const Duration(milliseconds: 200)),
        );

    final frontAssessment = container.read(
      preparationCameraViewAssessmentProvider(request),
    );
    expect(frontAssessment, isNotNull);
    expect(frontAssessment!.status, SetupCameraViewAdvisoryStatus.unsupported);
    expect(frontAssessment.detectedView, CameraView.front);
    expect(frontAssessment.recommendedView, CameraView.side);
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

Pose _sideOrientationPose() {
  return _pose(<PoseLandmark>[
    _landmarkWithDepth(PoseLandmarkType.leftShoulder, 47, 50, -26),
    _landmarkWithDepth(PoseLandmarkType.rightShoulder, 53, 50, 26),
    _landmarkWithDepth(PoseLandmarkType.leftHip, 48.5, 130, -22),
    _landmarkWithDepth(PoseLandmarkType.rightHip, 51.5, 130, 22),
  ]);
}

Pose _frontOrientationPose() {
  return _pose(<PoseLandmark>[
    _landmarkWithDepth(PoseLandmarkType.leftShoulder, 20, 50, 0),
    _landmarkWithDepth(PoseLandmarkType.rightShoulder, 80, 50, 1),
    _landmarkWithDepth(PoseLandmarkType.leftHip, 35, 130, 0),
    _landmarkWithDepth(PoseLandmarkType.rightHip, 65, 130, 1),
  ]);
}

PoseLandmark _landmarkWithDepth(
  PoseLandmarkType type,
  double x,
  double y,
  double z,
) {
  return PoseLandmark(type: type, x: x, y: y, z: z, likelihood: 0.95);
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
