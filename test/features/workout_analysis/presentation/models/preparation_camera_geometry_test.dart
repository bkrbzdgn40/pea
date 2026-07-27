import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/preparation_camera_geometry.dart';

void main() {
  const resolver = PreparationCameraGeometryResolver();

  test('uses portrait image geometry for portrait device orientations', () {
    for (final orientation in <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]) {
      final geometry = resolver.resolve(
        previewSize: const Size(640, 480),
        deviceOrientation: orientation,
        viewportOrientation: Orientation.landscape,
      );

      expect(geometry, isNotNull);
      expect(geometry!.imageSize, const Size(480, 640));
      expect(geometry.aspectRatio, closeTo(3 / 4, 1e-9));
    }
  });

  test('uses landscape image geometry for landscape device orientations', () {
    for (final orientation in <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]) {
      final geometry = resolver.resolve(
        previewSize: const Size(640, 480),
        deviceOrientation: orientation,
        viewportOrientation: Orientation.portrait,
      );

      expect(geometry, isNotNull);
      expect(geometry!.imageSize, const Size(640, 480));
      expect(geometry.aspectRatio, closeTo(4 / 3, 1e-9));
    }
  });

  test(
    'falls back to viewport orientation until camera orientation arrives',
    () {
      expect(
        resolver
            .resolve(
              previewSize: const Size(1920, 1080),
              deviceOrientation: null,
              viewportOrientation: Orientation.portrait,
            )!
            .imageSize,
        const Size(1080, 1920),
      );
      expect(
        resolver
            .resolve(
              previewSize: const Size(1920, 1080),
              deviceOrientation: null,
              viewportOrientation: Orientation.landscape,
            )!
            .imageSize,
        const Size(1920, 1080),
      );
    },
  );

  test('rejects missing or invalid preview dimensions', () {
    expect(
      resolver.resolve(
        previewSize: null,
        deviceOrientation: DeviceOrientation.portraitUp,
        viewportOrientation: Orientation.portrait,
      ),
      isNull,
    );
    expect(
      resolver.resolve(
        previewSize: const Size(0, 480),
        deviceOrientation: DeviceOrientation.portraitUp,
        viewportOrientation: Orientation.portrait,
      ),
      isNull,
    );
  });
}
