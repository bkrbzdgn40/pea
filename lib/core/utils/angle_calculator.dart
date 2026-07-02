import 'dart:math' as math;

class AngleCalculator {
  /// Returns the inner angle, in degrees, at [midPoint].
  static double calculate(
    math.Point<double> firstPoint,
    math.Point<double> midPoint,
    math.Point<double> lastPoint,
  ) {
    double radians =
        math.atan2(lastPoint.y - midPoint.y, lastPoint.x - midPoint.x) -
        math.atan2(firstPoint.y - midPoint.y, firstPoint.x - midPoint.x);

    double angle = (radians * 180.0 / math.pi).abs();

    // Pose scoring expects the smaller inner angle, not the reflex angle.
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }

    return angle;
  }
}
