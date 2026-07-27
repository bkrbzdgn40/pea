import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared preview and landmark geometry for the preparation camera.
///
/// Camera preview sizes are commonly reported in sensor orientation. The
/// preparation flow, however, must normalize landmarks against the orientation
/// currently shown to the user. Keeping this resolution in one place prevents
/// the preview, pose overlay, and readiness evaluators from disagreeing after a
/// portrait/landscape transition.
class PreparationCameraGeometry {
  const PreparationCameraGeometry({required this.imageSize});

  final Size imageSize;

  double get aspectRatio => imageSize.width / imageSize.height;
}

class PreparationCameraGeometryResolver {
  const PreparationCameraGeometryResolver();

  PreparationCameraGeometry? resolve({
    required Size? previewSize,
    required DeviceOrientation? deviceOrientation,
    required Orientation viewportOrientation,
  }) {
    if (previewSize == null ||
        !previewSize.width.isFinite ||
        !previewSize.height.isFinite ||
        previewSize.width <= 0 ||
        previewSize.height <= 0) {
      return null;
    }

    final isWidthShorter = previewSize.width <= previewSize.height;
    final shortSide = isWidthShorter ? previewSize.width : previewSize.height;
    final longSide = isWidthShorter ? previewSize.height : previewSize.width;
    final isLandscape = switch (deviceOrientation) {
      DeviceOrientation.landscapeLeft => true,
      DeviceOrientation.landscapeRight => true,
      DeviceOrientation.portraitUp => false,
      DeviceOrientation.portraitDown => false,
      null => viewportOrientation == Orientation.landscape,
    };

    return PreparationCameraGeometry(
      imageSize: isLandscape
          ? Size(longSide, shortSide)
          : Size(shortSide, longSide),
    );
  }
}
