import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

class TestQueuedPoseDetector implements PoseDetector {
  final List<List<Pose>> _queuedPoses = <List<Pose>>[];

  void enqueue(List<Pose> poses) {
    _queuedPoses.add(poses);
  }

  @override
  Future<List<Pose>> processImage(InputImage inputImage) async {
    if (_queuedPoses.isEmpty) {
      throw StateError('No queued pose result for test detector.');
    }

    return _queuedPoses.removeAt(0);
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFakeClock {
  DateTime _current = DateTime.utc(2030, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}

Future<void> analyzeFrame(
  WorkoutController controller,
  TestQueuedPoseDetector detector,
  List<Pose> poses,
) async {
  detector.enqueue(poses);
  await controller.processInputImageForAnalysis(dummyInputImage());
}

InputImage dummyInputImage() {
  return InputImage.fromBytes(
    bytes: Uint8List.fromList(<int>[0, 0, 0, 0]),
    metadata: const InputImageMetadata(
      size: Size(1, 1),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: 1,
    ),
  );
}

ExerciseConfig buildSquatConfig() {
  return ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 150,
    thresholdPeak: 95,
    formThreshold: 45,
    targetMinAngle: 70,
  );
}

ExerciseConfig buildPlankConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 168,
    thresholdPeak: 0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160,
      bodyLineEntryAngle: 168,
      bodyLineSustainAngle: 166,
      armSupportMinAngle: 60,
      armSupportMaxAngle: 120,
      legExtensionMinAngle: 165,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
    holdSignals: const HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
      alignment: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.leftAnkle,
      ),
      support: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftElbow,
        last: PoseLandmarkType.leftWrist,
      ),
      extension: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
    ),
  );
}

Pose buildSquatPose({
  required double angle,
  double defaultLikelihood = 0.95,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
}) {
  final radians = angle * (math.pi / 180.0);
  final ankleX = math.sin(radians);
  final ankleY = math.cos(radians);
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(PoseLandmarkType type, double x, double y) {
    if (missingLandmarks.contains(type)) {
      return;
    }

    landmarks[type] = buildLandmark(
      type,
      x,
      y,
      likelihood: likelihoodOverrides[type] ?? defaultLikelihood,
    );
  }

  addLandmark(PoseLandmarkType.leftShoulder, -1, 1);
  addLandmark(PoseLandmarkType.leftHip, 0, 1);
  addLandmark(PoseLandmarkType.leftKnee, 0, 0);
  addLandmark(PoseLandmarkType.leftAnkle, ankleX, ankleY);

  return Pose(landmarks: landmarks);
}

Pose buildPlankPose({
  double defaultLikelihood = 0.95,
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
  bool rightOnly = false,
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(PoseLandmarkType type, double x, double y) {
    if (missingLandmarks.contains(type)) {
      return;
    }

    landmarks[type] = buildLandmark(type, x, y, likelihood: defaultLikelihood);
  }

  if (rightOnly) {
    addLandmark(PoseLandmarkType.rightShoulder, 1, 0);
    addLandmark(PoseLandmarkType.rightElbow, 0.5, 0);
    addLandmark(PoseLandmarkType.rightWrist, 0.5, -1);
    addLandmark(PoseLandmarkType.rightHip, 0, 0);
    addLandmark(PoseLandmarkType.rightKnee, -0.2, 0);
    addLandmark(PoseLandmarkType.rightAnkle, -1, 0.2);
  } else {
    addLandmark(PoseLandmarkType.leftShoulder, -1, 0);
    addLandmark(PoseLandmarkType.leftElbow, -0.5, 0);
    addLandmark(PoseLandmarkType.leftWrist, -0.5, -1);
    addLandmark(PoseLandmarkType.leftHip, 0, 0);
    addLandmark(PoseLandmarkType.leftKnee, 0.2, 0);
    addLandmark(PoseLandmarkType.leftAnkle, 1, 0.2);
  }

  return Pose(landmarks: landmarks);
}

PoseLandmark buildLandmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.95,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);
}
