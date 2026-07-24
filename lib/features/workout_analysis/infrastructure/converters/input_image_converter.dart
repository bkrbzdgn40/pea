import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'input_image_rotation_resolver.dart';

/// Converts platform camera frames into ML Kit input images when the format is safe.
class InputImageConverter {
  const InputImageConverter({
    InputImageRotationResolver rotationResolver =
        const InputImageRotationResolver(),
  }) : _rotationResolver = rotationResolver;

  final InputImageRotationResolver _rotationResolver;

  /// Returns null instead of manufacturing bytes for unsupported platform formats.
  InputImage? convert(
    CameraImage image, {
    required int sensorOrientation,
    required DeviceOrientation? deviceOrientation,
    required CameraLensDirection? lensDirection,
  }) {
    try {
      if (image.width <= 0 || image.height <= 0 || image.planes.isEmpty) {
        return null;
      }

      final rotation = _rotationResolver.resolve(
        platform: defaultTargetPlatform,
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        lensDirection: lensDirection,
      );
      if (rotation == null) return null;

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return _androidNv21InputImage(image, rotation);
        case TargetPlatform.iOS:
          return _iosBgra8888InputImage(image, rotation);
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  InputImage? _androidNv21InputImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format != InputImageFormat.nv21) return null;

    if (image.planes.length != 1) {
      // Multi-plane YUV needs stride-aware conversion; do not fake NV21 by
      // concatenating planes because that can corrupt ML Kit input.
      return null;
    }

    final plane = image.planes.first;
    final minimumBytes = image.width * image.height * 3 ~/ 2;
    if (plane.bytes.length < minimumBytes || plane.bytesPerRow < image.width) {
      return null;
    }

    return _buildInputImage(
      image: image,
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytes: plane.bytes,
      bytesPerRow: plane.bytesPerRow,
    );
  }

  InputImage? _iosBgra8888InputImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format != InputImageFormat.bgra8888 || image.planes.length != 1) {
      return null;
    }

    final plane = image.planes.first;
    final bytesPerPixel = plane.bytesPerPixel;
    if (bytesPerPixel != null && bytesPerPixel != 4) return null;

    final minimumBytesPerRow = image.width * 4;
    final minimumBytes = plane.bytesPerRow * image.height;
    if (plane.bytesPerRow < minimumBytesPerRow ||
        plane.bytes.length < minimumBytes) {
      return null;
    }

    return _buildInputImage(
      image: image,
      rotation: rotation,
      format: InputImageFormat.bgra8888,
      bytes: plane.bytes,
      bytesPerRow: plane.bytesPerRow,
    );
  }

  InputImage _buildInputImage({
    required CameraImage image,
    required InputImageRotation rotation,
    required InputImageFormat format,
    required Uint8List bytes,
    required int bytesPerRow,
  }) {
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }
}
