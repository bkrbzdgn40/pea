import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/infrastructure/converters/input_image_rotation_resolver.dart';

void main() {
  const resolver = InputImageRotationResolver();

  group('InputImageRotationResolver', () {
    test('iOS uses the camera sensor orientation directly', () {
      expect(
        resolver.resolve(
          platform: TargetPlatform.iOS,
          sensorOrientation: 90,
          deviceOrientation: null,
          lensDirection: null,
        ),
        InputImageRotation.rotation90deg,
      );
    });

    test('Android back camera compensates for device orientation', () {
      const expectedRotations = <DeviceOrientation, InputImageRotation>{
        DeviceOrientation.portraitUp: InputImageRotation.rotation90deg,
        DeviceOrientation.landscapeLeft: InputImageRotation.rotation0deg,
        DeviceOrientation.portraitDown: InputImageRotation.rotation270deg,
        DeviceOrientation.landscapeRight: InputImageRotation.rotation180deg,
      };

      for (final entry in expectedRotations.entries) {
        expect(
          resolver.resolve(
            platform: TargetPlatform.android,
            sensorOrientation: 90,
            deviceOrientation: entry.key,
            lensDirection: CameraLensDirection.back,
          ),
          entry.value,
          reason: 'Unexpected back-camera rotation for ${entry.key.name}',
        );
      }
    });

    test('Android front camera compensates for device orientation', () {
      const expectedRotations = <DeviceOrientation, InputImageRotation>{
        DeviceOrientation.portraitUp: InputImageRotation.rotation90deg,
        DeviceOrientation.landscapeLeft: InputImageRotation.rotation180deg,
        DeviceOrientation.portraitDown: InputImageRotation.rotation270deg,
        DeviceOrientation.landscapeRight: InputImageRotation.rotation0deg,
      };

      for (final entry in expectedRotations.entries) {
        expect(
          resolver.resolve(
            platform: TargetPlatform.android,
            sensorOrientation: 90,
            deviceOrientation: entry.key,
            lensDirection: CameraLensDirection.front,
          ),
          entry.value,
          reason: 'Unexpected front-camera rotation for ${entry.key.name}',
        );
      }
    });

    test('Android drops frames when orientation context is incomplete', () {
      expect(
        resolver.resolve(
          platform: TargetPlatform.android,
          sensorOrientation: 90,
          deviceOrientation: null,
          lensDirection: CameraLensDirection.back,
        ),
        isNull,
      );
      expect(
        resolver.resolve(
          platform: TargetPlatform.android,
          sensorOrientation: 90,
          deviceOrientation: DeviceOrientation.portraitUp,
          lensDirection: null,
        ),
        isNull,
      );
    });

    test('external and unsupported platform rotations are not guessed', () {
      expect(
        resolver.resolve(
          platform: TargetPlatform.android,
          sensorOrientation: 90,
          deviceOrientation: DeviceOrientation.portraitUp,
          lensDirection: CameraLensDirection.external,
        ),
        isNull,
      );
      expect(
        resolver.resolve(
          platform: TargetPlatform.windows,
          sensorOrientation: 90,
          deviceOrientation: DeviceOrientation.portraitUp,
          lensDirection: CameraLensDirection.back,
        ),
        isNull,
      );
    });

    test('invalid rotation values are rejected', () {
      expect(
        resolver.resolve(
          platform: TargetPlatform.android,
          sensorOrientation: 45,
          deviceOrientation: DeviceOrientation.portraitUp,
          lensDirection: CameraLensDirection.back,
        ),
        isNull,
      );
    });
  });
}
