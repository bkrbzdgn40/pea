/// Common contract for engines that consume extracted analysis metrics.
///
/// This surface stays focused on values the live-analysis pipeline can expect
/// from every engine family. Calibration/debug diagnostics live on separate,
/// family-specific surfaces.
abstract class AnalysisEngine {
  void update(double primaryMetric, double formMetric);

  void reset();

  int get repCount;
  bool get isFormBad;
  double get lastRepScore;
  double get maxRom;
  String get feedback;
  String get phaseLabel;
}
