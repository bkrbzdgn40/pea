import 'dart:math' as math;

// All inputs use 2D image coordinates: x increases to the right and y
// increases downward. These primitives do not describe 3D or anatomical
// geometry.

/// An axis in the 2D image plane.
enum ImagePlaneAxis {
  /// Compares x coordinates.
  horizontal,

  /// Compares y coordinates.
  vertical,
}

/// Returns a segment's acute, direction-independent inclination from vertical.
///
/// The result is in degrees from 0 (vertical) through 90 (horizontal). Returns
/// `null` when [start] and [end] define a zero-length segment.
double? imagePlaneInclination(
  math.Point<double> start,
  math.Point<double> end,
) {
  final dx = (end.x - start.x).abs();
  final dy = (end.y - start.y).abs();

  if (dx == 0.0 && dy == 0.0) {
    return null;
  }

  return math.atan2(dx, dy) * 180.0 / math.pi;
}

/// Returns unsigned point deviation from an infinite line, normalized by its
/// reference segment length.
///
/// The result is dimensionless and is not clamped. Returns `null` when the
/// reference line has zero length.
double? normalizedPointToLineDeviation({
  required math.Point<double> point,
  required math.Point<double> lineStart,
  required math.Point<double> lineEnd,
}) {
  final lineLengthSquared = _squaredDistance(lineStart, lineEnd);
  if (lineLengthSquared == 0.0) {
    return null;
  }

  return _crossProduct(
        point: point,
        lineStart: lineStart,
        lineEnd: lineEnd,
      ).abs() /
      lineLengthSquared;
}

/// Returns absolute image-axis offset normalized by a reference segment.
///
/// The selected-axis offset is divided by the Euclidean normalization length.
/// The result is dimensionless and is not clamped. Returns `null` when the
/// normalization segment has zero length.
double? normalizedAxisOffset({
  required math.Point<double> point,
  required math.Point<double> referencePoint,
  required math.Point<double> normalizationStart,
  required math.Point<double> normalizationEnd,
  required ImagePlaneAxis axis,
}) {
  final normalizationLengthSquared = _squaredDistance(
    normalizationStart,
    normalizationEnd,
  );
  if (normalizationLengthSquared == 0.0) {
    return null;
  }

  final offset = switch (axis) {
    ImagePlaneAxis.horizontal => (point.x - referencePoint.x).abs(),
    ImagePlaneAxis.vertical => (point.y - referencePoint.y).abs(),
  };

  return offset / math.sqrt(normalizationLengthSquared);
}

/// Returns signed point deviation from an oriented infinite line, normalized
/// by its reference segment length.
///
/// The sign follows the cross product of `lineStart -> lineEnd` and
/// `lineStart -> point`: positive cross products return positive values and
/// negative cross products return negative values. Because image y increases
/// downward, this sign describes image-plane orientation only; it does not
/// imply anatomical direction or coaching meaning. Returns `null` when the
/// reference line has zero length.
double? signedDeviation({
  required math.Point<double> point,
  required math.Point<double> lineStart,
  required math.Point<double> lineEnd,
}) {
  final lineLengthSquared = _squaredDistance(lineStart, lineEnd);
  if (lineLengthSquared == 0.0) {
    return null;
  }

  final cross = _crossProduct(
    point: point,
    lineStart: lineStart,
    lineEnd: lineEnd,
  );
  if (cross == 0.0) {
    return 0.0;
  }

  return cross / lineLengthSquared;
}

double _squaredDistance(math.Point<double> start, math.Point<double> end) {
  final dx = end.x - start.x;
  final dy = end.y - start.y;
  return (dx * dx) + (dy * dy);
}

double _crossProduct({
  required math.Point<double> point,
  required math.Point<double> lineStart,
  required math.Point<double> lineEnd,
}) {
  final lineDx = lineEnd.x - lineStart.x;
  final lineDy = lineEnd.y - lineStart.y;
  final pointDx = point.x - lineStart.x;
  final pointDy = point.y - lineStart.y;
  return (lineDx * pointDy) - (lineDy * pointDx);
}
