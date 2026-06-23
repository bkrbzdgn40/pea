import 'dart:math' as math;

class AngleCalculator {
  /// 3 nokta arasındaki iç açıyı derece (degree) cinsinden döndürür.
  /// [firstPoint] : Başlangıç noktası (Örn: Kalça)
  /// [midPoint]   : Açı merkezi olan köşe noktası (Örn: Diz)
  /// [lastPoint]  : Bitiş noktası (Örn: Ayak Bileği)
  static double calculate(
    math.Point<double> firstPoint,
    math.Point<double> midPoint,
    math.Point<double> lastPoint,
  ) {
    double radians =
        math.atan2(lastPoint.y - midPoint.y, lastPoint.x - midPoint.x) -
        math.atan2(firstPoint.y - midPoint.y, firstPoint.x - midPoint.x);

    double angle = (radians * 180.0 / math.pi).abs();

    // Dış açıyı değil, her zaman iç açıyı almak istiyoruz
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }

    return angle;
  }
}
