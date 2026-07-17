import 'dart:convert';
import 'dart:io';
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
    metadata: InputImageMetadata(
      size: Size(1, 1),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: 1,
    ),
  );
}

ExerciseConfig loadExerciseConfig(String path) {
  final rawJson = File(path).readAsStringSync();
  return ExerciseConfig.fromMap(jsonDecode(rawJson) as Map<String, dynamic>);
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
    holdSignals: HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
      alignment: PoseAngleLandmarks(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.leftAnkle,
      ),
      support: PoseAngleLandmarks(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftElbow,
        last: PoseLandmarkType.leftWrist,
      ),
      extension: PoseAngleLandmarks(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
    ),
  );
}

ExerciseConfig buildHollowHoldConfig() {
  return ExerciseConfig(
    name: 'Hollow Hold',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 170.0,
    thresholdActive: 155.0,
    thresholdPeak: 0.0,
    hollowHoldPosture: const HollowHoldPostureConfig(
      activePostureMaxAngle: 170.0,
      compressionEntryMaxAngle: 155.0,
      compressionSustainMaxAngle: 160.0,
      armExtensionMinAngle: 150.0,
      kneeExtensionMinAngle: 165.0,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
    holdSignals: HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
      compression: PoseAngleLandmarks(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.leftAnkle,
      ),
      armExtension: PoseAngleLandmarks(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftShoulder,
        last: PoseLandmarkType.leftWrist,
      ),
      kneeExtension: PoseAngleLandmarks(
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

Pose buildSitUpPose({
  required double primaryAngle,
  double formAngle = 120,
  bool includeLeftSide = true,
  bool includeRightSide = true,
  double leftDefaultLikelihood = 0.95,
  double rightDefaultLikelihood = 0.95,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(
    PoseLandmarkType type,
    double x,
    double y, {
    required double defaultLikelihood,
  }) {
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

  if (includeLeftSide) {
    final primaryRadians = primaryAngle * (math.pi / 180.0);
    final formRadians = formAngle * (math.pi / 180.0);

    addLandmark(
      PoseLandmarkType.leftHip,
      0,
      0,
      defaultLikelihood: leftDefaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.leftKnee,
      1,
      0,
      defaultLikelihood: leftDefaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.leftShoulder,
      math.cos(primaryRadians),
      math.sin(primaryRadians),
      defaultLikelihood: leftDefaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.leftAnkle,
      1 - math.cos(formRadians),
      math.sin(formRadians),
      defaultLikelihood: leftDefaultLikelihood,
    );
  }

  if (includeRightSide) {
    final primaryRadians = primaryAngle * (math.pi / 180.0);
    final formRadians = formAngle * (math.pi / 180.0);
    const rightHipX = 3.0;
    const rightKneeX = 2.0;

    addLandmark(
      PoseLandmarkType.rightHip,
      rightHipX,
      0,
      defaultLikelihood: rightDefaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.rightKnee,
      rightKneeX,
      0,
      defaultLikelihood: rightDefaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.rightShoulder,
      rightHipX - math.cos(primaryRadians),
      math.sin(primaryRadians),
      defaultLikelihood: rightDefaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.rightAnkle,
      rightKneeX + math.cos(formRadians),
      math.sin(formRadians),
      defaultLikelihood: rightDefaultLikelihood,
    );
  }

  return Pose(landmarks: landmarks);
}

Pose buildBicepsCurlPose({
  required double leftPrimaryAngle,
  double? rightPrimaryAngle,
  double leftUpperArmDriftAngle = 20,
  double? rightUpperArmDriftAngle,
  bool includeLeftSide = true,
  bool includeRightSide = true,
  double leftDefaultLikelihood = 0.95,
  double rightDefaultLikelihood = 0.95,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(
    PoseLandmarkType type,
    double x,
    double y, {
    required double defaultLikelihood,
  }) {
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

  if (includeLeftSide) {
    _addBicepsCurlSide(
      addLandmark: addLandmark,
      shoulderType: PoseLandmarkType.leftShoulder,
      elbowType: PoseLandmarkType.leftElbow,
      wristType: PoseLandmarkType.leftWrist,
      hipType: PoseLandmarkType.leftHip,
      shoulderX: 0,
      mirrorSign: 1,
      primaryAngle: leftPrimaryAngle,
      upperArmDriftAngle: leftUpperArmDriftAngle,
      defaultLikelihood: leftDefaultLikelihood,
    );
  }

  if (includeRightSide) {
    _addBicepsCurlSide(
      addLandmark: addLandmark,
      shoulderType: PoseLandmarkType.rightShoulder,
      elbowType: PoseLandmarkType.rightElbow,
      wristType: PoseLandmarkType.rightWrist,
      hipType: PoseLandmarkType.rightHip,
      shoulderX: 4,
      mirrorSign: -1,
      primaryAngle: rightPrimaryAngle ?? leftPrimaryAngle,
      upperArmDriftAngle: rightUpperArmDriftAngle ?? leftUpperArmDriftAngle,
      defaultLikelihood: rightDefaultLikelihood,
    );
  }

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

Pose buildHollowHoldPose({
  double compressionAngle = 150,
  double armExtensionAngle = 160,
  double kneeExtensionAngle = 170,
  bool includeLeftSide = true,
  bool includeRightSide = true,
  double leftDefaultLikelihood = 0.95,
  double rightDefaultLikelihood = 0.95,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(
    PoseLandmarkType type,
    double x,
    double y, {
    required double defaultLikelihood,
  }) {
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

  if (includeLeftSide) {
    _addHollowHoldSide(
      addLandmark: addLandmark,
      side: HoldSide.left,
      shoulder: const math.Point<double>(-1, 0),
      hip: const math.Point<double>(0, 0),
      compressionAngle: compressionAngle,
      armExtensionAngle: armExtensionAngle,
      kneeExtensionAngle: kneeExtensionAngle,
      defaultLikelihood: leftDefaultLikelihood,
    );
  }

  if (includeRightSide) {
    _addHollowHoldSide(
      addLandmark: addLandmark,
      side: HoldSide.right,
      shoulder: const math.Point<double>(4, 0),
      hip: const math.Point<double>(3, 0),
      compressionAngle: compressionAngle,
      armExtensionAngle: armExtensionAngle,
      kneeExtensionAngle: kneeExtensionAngle,
      defaultLikelihood: rightDefaultLikelihood,
    );
  }

  return Pose(landmarks: landmarks);
}

void _addBicepsCurlSide({
  required void Function(
    PoseLandmarkType type,
    double x,
    double y, {
    required double defaultLikelihood,
  })
  addLandmark,
  required PoseLandmarkType shoulderType,
  required PoseLandmarkType elbowType,
  required PoseLandmarkType wristType,
  required PoseLandmarkType hipType,
  required double shoulderX,
  required double mirrorSign,
  required double primaryAngle,
  required double upperArmDriftAngle,
  required double defaultLikelihood,
}) {
  final driftRadians = upperArmDriftAngle * (math.pi / 180.0);
  final primaryRadians = primaryAngle * (math.pi / 180.0);
  final shoulder = math.Point<double>(shoulderX, 0);
  final hip = math.Point<double>(shoulderX, -1);
  final elbow = math.Point<double>(
    shoulderX + (mirrorSign * math.sin(driftRadians)),
    -math.cos(driftRadians),
  );
  final upperArmVector = math.Point<double>(
    shoulder.x - elbow.x,
    shoulder.y - elbow.y,
  );
  final upperArmLength = math.sqrt(
    (upperArmVector.x * upperArmVector.x) +
        (upperArmVector.y * upperArmVector.y),
  );
  final upperArmUnit = math.Point<double>(
    upperArmVector.x / upperArmLength,
    upperArmVector.y / upperArmLength,
  );
  final wristVector = _rotatePoint(upperArmUnit, mirrorSign * primaryRadians);
  final wrist = math.Point<double>(
    elbow.x + wristVector.x,
    elbow.y + wristVector.y,
  );

  addLandmark(
    shoulderType,
    shoulder.x,
    shoulder.y,
    defaultLikelihood: defaultLikelihood,
  );
  addLandmark(
    elbowType,
    elbow.x,
    elbow.y,
    defaultLikelihood: defaultLikelihood,
  );
  addLandmark(
    wristType,
    wrist.x,
    wrist.y,
    defaultLikelihood: defaultLikelihood,
  );
  addLandmark(hipType, hip.x, hip.y, defaultLikelihood: defaultLikelihood);
}

void _addHollowHoldSide({
  required void Function(
    PoseLandmarkType type,
    double x,
    double y, {
    required double defaultLikelihood,
  })
  addLandmark,
  required HoldSide side,
  required math.Point<double> shoulder,
  required math.Point<double> hip,
  required double compressionAngle,
  required double armExtensionAngle,
  required double kneeExtensionAngle,
  required double defaultLikelihood,
}) {
  final compressionRadians = (compressionAngle - 180.0) * (math.pi / 180.0);
  final ankleVector = side == HoldSide.left
      ? math.Point<double>(
          math.cos(compressionRadians),
          math.sin(compressionRadians),
        )
      : math.Point<double>(
          -math.cos(compressionRadians),
          math.sin(compressionRadians),
        );
  final ankle = math.Point<double>(
    hip.x + ankleVector.x,
    hip.y + ankleVector.y,
  );
  final armExtensionRadians = armExtensionAngle * (math.pi / 180.0);
  final wristVector = side == HoldSide.left
      ? math.Point<double>(
          math.cos(armExtensionRadians),
          math.sin(armExtensionRadians),
        )
      : math.Point<double>(
          -math.cos(armExtensionRadians),
          math.sin(armExtensionRadians),
        );
  final wrist = math.Point<double>(
    shoulder.x + wristVector.x,
    shoulder.y + wristVector.y,
  );
  final knee = _holdKneePoint(
    hip: hip,
    ankle: ankle,
    jointAngle: kneeExtensionAngle,
  );

  if (side == HoldSide.left) {
    addLandmark(
      PoseLandmarkType.leftShoulder,
      shoulder.x,
      shoulder.y,
      defaultLikelihood: defaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.leftHip,
      hip.x,
      hip.y,
      defaultLikelihood: defaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.leftWrist,
      wrist.x,
      wrist.y,
      defaultLikelihood: defaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.leftKnee,
      knee.x,
      knee.y,
      defaultLikelihood: defaultLikelihood,
    );
    addLandmark(
      PoseLandmarkType.leftAnkle,
      ankle.x,
      ankle.y,
      defaultLikelihood: defaultLikelihood,
    );
    return;
  }

  addLandmark(
    PoseLandmarkType.rightShoulder,
    shoulder.x,
    shoulder.y,
    defaultLikelihood: defaultLikelihood,
  );
  addLandmark(
    PoseLandmarkType.rightHip,
    hip.x,
    hip.y,
    defaultLikelihood: defaultLikelihood,
  );
  addLandmark(
    PoseLandmarkType.rightWrist,
    wrist.x,
    wrist.y,
    defaultLikelihood: defaultLikelihood,
  );
  addLandmark(
    PoseLandmarkType.rightKnee,
    knee.x,
    knee.y,
    defaultLikelihood: defaultLikelihood,
  );
  addLandmark(
    PoseLandmarkType.rightAnkle,
    ankle.x,
    ankle.y,
    defaultLikelihood: defaultLikelihood,
  );
}

math.Point<double> _holdKneePoint({
  required math.Point<double> hip,
  required math.Point<double> ankle,
  required double jointAngle,
}) {
  final midpoint = math.Point<double>(
    (hip.x + ankle.x) / 2,
    (hip.y + ankle.y) / 2,
  );
  final normalizedAngle = jointAngle.clamp(0.0, 180.0);
  if (normalizedAngle >= 179.999) {
    return midpoint;
  }

  final dx = ankle.x - hip.x;
  final dy = ankle.y - hip.y;
  final chordLength = math.sqrt(dx * dx + dy * dy);
  if (chordLength == 0) {
    return midpoint;
  }

  final halfChord = chordLength / 2;
  final angleRadians = normalizedAngle * (math.pi / 180.0);
  final offset = halfChord / math.tan(angleRadians / 2);
  final perpendicular = math.Point<double>(-dy / chordLength, dx / chordLength);
  return math.Point<double>(
    midpoint.x + perpendicular.x * offset,
    midpoint.y + perpendicular.y * offset,
  );
}

math.Point<double> _rotatePoint(math.Point<double> point, double radians) {
  final cosRadians = math.cos(radians);
  final sinRadians = math.sin(radians);
  return math.Point<double>(
    (point.x * cosRadians) - (point.y * sinRadians),
    (point.x * sinRadians) + (point.y * cosRadians),
  );
}

PoseLandmark buildLandmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.95,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);
}
