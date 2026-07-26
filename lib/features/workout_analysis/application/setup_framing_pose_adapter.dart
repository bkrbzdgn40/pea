import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/exercise_setup_contract.dart';
import '../domain/models/setup_framing_geometry.dart';

/// Converts ML Kit image-space landmarks into the normalized setup geometry
/// consumed by the pure framing evaluator.
class SetupFramingPoseAdapter {
  const SetupFramingPoseAdapter();

  static const Map<SetupBodyRegion, List<PoseLandmarkType>> _regionLandmarks =
      <SetupBodyRegion, List<PoseLandmarkType>>{
        SetupBodyRegion.head: <PoseLandmarkType>[
          PoseLandmarkType.nose,
          PoseLandmarkType.leftEye,
          PoseLandmarkType.rightEye,
          PoseLandmarkType.leftEar,
          PoseLandmarkType.rightEar,
        ],
        SetupBodyRegion.shoulders: <PoseLandmarkType>[
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
        ],
        SetupBodyRegion.elbows: <PoseLandmarkType>[
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.rightElbow,
        ],
        SetupBodyRegion.wrists: <PoseLandmarkType>[
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.rightWrist,
        ],
        SetupBodyRegion.hips: <PoseLandmarkType>[
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
        ],
        SetupBodyRegion.knees: <PoseLandmarkType>[
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
        ],
        SetupBodyRegion.ankles: <PoseLandmarkType>[
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ],
        SetupBodyRegion.feet: <PoseLandmarkType>[
          PoseLandmarkType.leftHeel,
          PoseLandmarkType.rightHeel,
          PoseLandmarkType.leftFootIndex,
          PoseLandmarkType.rightFootIndex,
        ],
      };

  SetupFramingPose fromPose({
    required Pose pose,
    required double imageWidth,
    required double imageHeight,
    bool mirrorHorizontally = false,
  }) {
    return fromLandmarks(
      landmarks: pose.landmarks.values,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      mirrorHorizontally: mirrorHorizontally,
    );
  }

  SetupFramingPose fromLandmarks({
    required Iterable<PoseLandmark> landmarks,
    required double imageWidth,
    required double imageHeight,
    bool mirrorHorizontally = false,
  }) {
    _validateImageDimension(imageWidth, 'imageWidth');
    _validateImageDimension(imageHeight, 'imageHeight');
    final landmarksByType = <PoseLandmarkType, PoseLandmark>{
      for (final landmark in landmarks) landmark.type: landmark,
    };

    final landmarksByRegion =
        <SetupBodyRegion, List<NormalizedSetupLandmark>>{};
    for (final entry in _regionLandmarks.entries) {
      final normalized = <NormalizedSetupLandmark>[];
      for (final type in entry.value) {
        final landmark = landmarksByType[type];
        if (landmark == null) {
          continue;
        }

        final normalizedX = landmark.x / imageWidth;
        normalized.add(
          NormalizedSetupLandmark(
            x: mirrorHorizontally ? 1 - normalizedX : normalizedX,
            y: landmark.y / imageHeight,
            likelihood: landmark.likelihood,
          ),
        );
      }
      if (normalized.isNotEmpty) {
        landmarksByRegion[entry.key] = normalized;
      }
    }

    return SetupFramingPose(landmarksByRegion: landmarksByRegion);
  }

  void _validateImageDimension(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        name,
        'Image dimensions must be finite and greater than zero.',
      );
    }
  }
}
