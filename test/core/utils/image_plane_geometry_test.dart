import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/core/utils/image_plane_geometry.dart';

const _tolerance = 1e-12;

void main() {
  group('imagePlaneInclination', () {
    test('vertical downward segment is zero degrees', () {
      final result = imagePlaneInclination(
        const math.Point<double>(0, 0),
        const math.Point<double>(0, 4),
      );

      expect(result, 0.0);
    });

    test('vertical upward segment is zero degrees', () {
      final result = imagePlaneInclination(
        const math.Point<double>(0, 4),
        const math.Point<double>(0, 0),
      );

      expect(result, 0.0);
    });

    test('horizontal right segment is 90 degrees', () {
      final result = imagePlaneInclination(
        const math.Point<double>(0, 0),
        const math.Point<double>(4, 0),
      );

      expect(result, closeTo(90.0, _tolerance));
    });

    test('horizontal left segment is 90 degrees', () {
      final result = imagePlaneInclination(
        const math.Point<double>(4, 0),
        const math.Point<double>(0, 0),
      );

      expect(result, closeTo(90.0, _tolerance));
    });

    test('both diagonal orientations are 45 degrees', () {
      final downRight = imagePlaneInclination(
        const math.Point<double>(0, 0),
        const math.Point<double>(3, 3),
      );
      final downLeft = imagePlaneInclination(
        const math.Point<double>(0, 0),
        const math.Point<double>(-3, 3),
      );

      expect(downRight, closeTo(45.0, _tolerance));
      expect(downLeft, closeTo(45.0, _tolerance));
    });

    test('reversing endpoints preserves inclination', () {
      const start = math.Point<double>(1, 2);
      const end = math.Point<double>(4, 6);

      expect(
        imagePlaneInclination(end, start),
        closeTo(imagePlaneInclination(start, end)!, _tolerance),
      );
    });

    test('translation preserves inclination', () {
      final original = imagePlaneInclination(
        const math.Point<double>(1, 2),
        const math.Point<double>(4, 6),
      );
      final translated = imagePlaneInclination(
        const math.Point<double>(11, -5),
        const math.Point<double>(14, -1),
      );

      expect(translated, closeTo(original!, _tolerance));
    });

    test('uniform positive scaling preserves inclination', () {
      final original = imagePlaneInclination(
        const math.Point<double>(1, 2),
        const math.Point<double>(4, 6),
      );
      final scaled = imagePlaneInclination(
        const math.Point<double>(5, 10),
        const math.Point<double>(20, 30),
      );

      expect(scaled, closeTo(original!, _tolerance));
    });

    test('zero-length segment returns null', () {
      expect(
        imagePlaneInclination(
          const math.Point<double>(2, 3),
          const math.Point<double>(2, 3),
        ),
        isNull,
      );
    });
  });

  group('normalizedPointToLineDeviation', () {
    test('point on the infinite horizontal line has zero deviation', () {
      final result = normalizedPointToLineDeviation(
        point: const math.Point<double>(5, 0),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 0),
      );

      expect(result, 0.0);
    });

    test('one unit from a two-unit horizontal line is 0.5', () {
      final result = normalizedPointToLineDeviation(
        point: const math.Point<double>(1, 1),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 0),
      );

      expect(result, closeTo(0.5, _tolerance));
    });

    test('one unit from a two-unit vertical line is 0.5', () {
      final result = normalizedPointToLineDeviation(
        point: const math.Point<double>(1, 1),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(0, 2),
      );

      expect(result, closeTo(0.5, _tolerance));
    });

    test('diagonal reference line uses perpendicular deviation', () {
      final result = normalizedPointToLineDeviation(
        point: const math.Point<double>(0, 2),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 2),
      );

      expect(result, closeTo(0.5, _tolerance));
    });

    test('swapping line endpoints preserves magnitude', () {
      const point = math.Point<double>(0, 2);
      const start = math.Point<double>(0, 0);
      const end = math.Point<double>(2, 2);
      final forward = normalizedPointToLineDeviation(
        point: point,
        lineStart: start,
        lineEnd: end,
      );
      final reversed = normalizedPointToLineDeviation(
        point: point,
        lineStart: end,
        lineEnd: start,
      );

      expect(reversed, closeTo(forward!, _tolerance));
    });

    test('translation preserves normalized deviation', () {
      final original = normalizedPointToLineDeviation(
        point: const math.Point<double>(0, 2),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 2),
      );
      final translated = normalizedPointToLineDeviation(
        point: const math.Point<double>(10, -3),
        lineStart: const math.Point<double>(10, -5),
        lineEnd: const math.Point<double>(12, -3),
      );

      expect(translated, closeTo(original!, _tolerance));
    });

    test('uniform positive scaling preserves normalized deviation', () {
      final original = normalizedPointToLineDeviation(
        point: const math.Point<double>(0, 2),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 2),
      );
      final scaled = normalizedPointToLineDeviation(
        point: const math.Point<double>(0, 8),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(8, 8),
      );

      expect(scaled, closeTo(original!, _tolerance));
    });

    test('far point may have deviation greater than one', () {
      final result = normalizedPointToLineDeviation(
        point: const math.Point<double>(1, 3),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 0),
      );

      expect(result, closeTo(1.5, _tolerance));
    });

    test('zero-length reference line returns null', () {
      final result = normalizedPointToLineDeviation(
        point: const math.Point<double>(1, 1),
        lineStart: const math.Point<double>(2, 2),
        lineEnd: const math.Point<double>(2, 2),
      );

      expect(result, isNull);
    });
  });

  group('normalizedAxisOffset', () {
    test('horizontal axis uses x offset only', () {
      final result = normalizedAxisOffset(
        point: const math.Point<double>(3, 100),
        referencePoint: const math.Point<double>(1, -100),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(0, 4),
        axis: ImagePlaneAxis.horizontal,
      );

      expect(result, closeTo(0.5, _tolerance));
    });

    test('vertical axis uses y offset only', () {
      final result = normalizedAxisOffset(
        point: const math.Point<double>(100, 3),
        referencePoint: const math.Point<double>(-100, 1),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(4, 0),
        axis: ImagePlaneAxis.vertical,
      );

      expect(result, closeTo(0.5, _tolerance));
    });

    test('non-selected-axis movement does not affect result', () {
      final first = normalizedAxisOffset(
        point: const math.Point<double>(3, 1),
        referencePoint: const math.Point<double>(1, 1),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(0, 4),
        axis: ImagePlaneAxis.horizontal,
      );
      final movedVertically = normalizedAxisOffset(
        point: const math.Point<double>(3, 500),
        referencePoint: const math.Point<double>(1, -500),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(0, 4),
        axis: ImagePlaneAxis.horizontal,
      );

      expect(movedVertically, closeTo(first!, _tolerance));
    });

    test('equal selected-axis coordinates return zero', () {
      final result = normalizedAxisOffset(
        point: const math.Point<double>(3, 100),
        referencePoint: const math.Point<double>(3, -100),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(0, 4),
        axis: ImagePlaneAxis.horizontal,
      );

      expect(result, 0.0);
    });

    test('normalization uses Euclidean segment length', () {
      final result = normalizedAxisOffset(
        point: const math.Point<double>(2.5, 0),
        referencePoint: const math.Point<double>(0, 0),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(3, 4),
        axis: ImagePlaneAxis.horizontal,
      );

      expect(result, closeTo(0.5, _tolerance));
    });

    test('translation preserves normalized offset', () {
      final original = normalizedAxisOffset(
        point: const math.Point<double>(3, 2),
        referencePoint: const math.Point<double>(1, 0),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(0, 4),
        axis: ImagePlaneAxis.horizontal,
      );
      final translated = normalizedAxisOffset(
        point: const math.Point<double>(13, -5),
        referencePoint: const math.Point<double>(11, -7),
        normalizationStart: const math.Point<double>(10, -7),
        normalizationEnd: const math.Point<double>(10, -3),
        axis: ImagePlaneAxis.horizontal,
      );

      expect(translated, closeTo(original!, _tolerance));
    });

    test('uniform positive scaling preserves normalized offset', () {
      final original = normalizedAxisOffset(
        point: const math.Point<double>(3, 2),
        referencePoint: const math.Point<double>(1, 0),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(0, 4),
        axis: ImagePlaneAxis.horizontal,
      );
      final scaled = normalizedAxisOffset(
        point: const math.Point<double>(12, 8),
        referencePoint: const math.Point<double>(4, 0),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(0, 16),
        axis: ImagePlaneAxis.horizontal,
      );

      expect(scaled, closeTo(original!, _tolerance));
    });

    test('offset may be greater than one', () {
      final result = normalizedAxisOffset(
        point: const math.Point<double>(5, 0),
        referencePoint: const math.Point<double>(0, 0),
        normalizationStart: const math.Point<double>(0, 0),
        normalizationEnd: const math.Point<double>(0, 2),
        axis: ImagePlaneAxis.horizontal,
      );

      expect(result, closeTo(2.5, _tolerance));
    });

    test('zero-length normalization segment returns null', () {
      final result = normalizedAxisOffset(
        point: const math.Point<double>(3, 0),
        referencePoint: const math.Point<double>(0, 0),
        normalizationStart: const math.Point<double>(1, 1),
        normalizationEnd: const math.Point<double>(1, 1),
        axis: ImagePlaneAxis.horizontal,
      );

      expect(result, isNull);
    });
  });

  group('signedDeviation', () {
    test('positive cross product returns positive deviation', () {
      final result = signedDeviation(
        point: const math.Point<double>(1, 1),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 0),
      );

      expect(result, closeTo(0.5, _tolerance));
    });

    test('negative cross product returns negative deviation', () {
      final result = signedDeviation(
        point: const math.Point<double>(1, -1),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 0),
      );

      expect(result, closeTo(-0.5, _tolerance));
    });

    test('collinear point returns positive zero', () {
      final result = signedDeviation(
        point: const math.Point<double>(5, 0),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 0),
      );

      expect(result, 0.0);
      expect(result!.isNegative, isFalse);
    });

    test('absolute value equals unsigned normalized deviation', () {
      const point = math.Point<double>(0, 2);
      const start = math.Point<double>(0, 0);
      const end = math.Point<double>(2, 2);
      final signed = signedDeviation(
        point: point,
        lineStart: start,
        lineEnd: end,
      );
      final unsigned = normalizedPointToLineDeviation(
        point: point,
        lineStart: start,
        lineEnd: end,
      );

      expect(signed!.abs(), closeTo(unsigned!, _tolerance));
    });

    test('reversing line endpoints flips sign and preserves magnitude', () {
      const point = math.Point<double>(1, 1);
      const start = math.Point<double>(0, 0);
      const end = math.Point<double>(2, 0);
      final forward = signedDeviation(
        point: point,
        lineStart: start,
        lineEnd: end,
      );
      final reversed = signedDeviation(
        point: point,
        lineStart: end,
        lineEnd: start,
      );

      expect(reversed, closeTo(-forward!, _tolerance));
      expect(reversed!.abs(), closeTo(forward.abs(), _tolerance));
    });

    test('translation preserves signed normalized deviation', () {
      final original = signedDeviation(
        point: const math.Point<double>(1, 1),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 0),
      );
      final translated = signedDeviation(
        point: const math.Point<double>(11, -4),
        lineStart: const math.Point<double>(10, -5),
        lineEnd: const math.Point<double>(12, -5),
      );

      expect(translated, closeTo(original!, _tolerance));
    });

    test('uniform positive scaling preserves signed normalized deviation', () {
      final original = signedDeviation(
        point: const math.Point<double>(1, 1),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(2, 0),
      );
      final scaled = signedDeviation(
        point: const math.Point<double>(4, 4),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(8, 0),
      );

      expect(scaled, closeTo(original!, _tolerance));
    });

    test('non-horizontal baseline uses full cross-product orientation', () {
      final left = signedDeviation(
        point: const math.Point<double>(-1, 1),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(0, 2),
      );
      final right = signedDeviation(
        point: const math.Point<double>(1, 1),
        lineStart: const math.Point<double>(0, 0),
        lineEnd: const math.Point<double>(0, 2),
      );

      expect(left, closeTo(0.5, _tolerance));
      expect(right, closeTo(-0.5, _tolerance));
    });

    test('zero-length reference line returns null', () {
      final result = signedDeviation(
        point: const math.Point<double>(1, 1),
        lineStart: const math.Point<double>(2, 2),
        lineEnd: const math.Point<double>(2, 2),
      );

      expect(result, isNull);
    });
  });
}
