import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Resolves camera-frame orientation into the rotation metadata ML Kit expects.
class InputImageRotationResolver {
  const InputImageRotationResolver();

  static const Map<DeviceOrientation, int> _deviceOrientationDegrees =
      <DeviceOrientation, int>{
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };

  InputImageRotation? resolve({
    required TargetPlatform platform,
    required int sensorOrientation,
    required DeviceOrientation? deviceOrientation,
    required CameraLensDirection? lensDirection,
  }) {
    if (platform == TargetPlatform.iOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (platform != TargetPlatform.android ||
        deviceOrientation == null ||
        lensDirection == null) {
      return null;
    }

    final deviceDegrees = _deviceOrientationDegrees[deviceOrientation];
    if (deviceDegrees == null) {
      return null;
    }

    switch (lensDirection) {
      case CameraLensDirection.front:
        return InputImageRotationValue.fromRawValue(
          (sensorOrientation + deviceDegrees) % 360,
        );
      case CameraLensDirection.back:
        return InputImageRotationValue.fromRawValue(
          (sensorOrientation - deviceDegrees + 360) % 360,
        );
      case CameraLensDirection.external:
        return null;
    }
  }
}
