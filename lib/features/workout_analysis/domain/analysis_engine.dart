import 'models/rep_score_breakdown.dart';

/// Common contract for engines that consume extracted analysis metrics.
///
/// The first group is the stable live-analysis surface used by the controller.
/// The diagnostics getters are kept for today's calibration/debug needs and do
/// not imply that every future engine family must expose the same internals.
abstract class AnalysisEngine {
  void update(double primaryMetric, double formMetric);

  void reset();

  int get repCount;
  bool get isFormBad;
  double get lastRepScore;
  double get maxRom;
  String get feedback;
  String get phaseLabel;

  // Diagnostics surface kept during the transition to multiple engine families.
  double get currentRepWorstBackAngle;
  bool get currentRepHadFormViolation;
  RepScoreBreakdown? get lastRepScoreBreakdown;
}
