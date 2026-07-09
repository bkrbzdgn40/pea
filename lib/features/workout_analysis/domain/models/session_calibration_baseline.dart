/// Session-scoped observational baseline candidate aggregated from stable
/// calibration snapshots. This is telemetry only and not a runtime truth or
/// persistence contract.
class SessionCalibrationBaseline {
  const SessionCalibrationBaseline({
    required this.analysisKind,
    required this.sampleCount,
    this.selectedSideLabel,
    this.primaryMetricBaseline,
    this.formMetricBaseline,
    this.torsoAngleBaseline,
    this.depthMetricBaseline,
    this.alignmentMetricBaseline,
    this.stabilityMetricBaseline,
    this.lockoutMetricBaseline,
    this.bottomControlMetricBaseline,
  });

  final String analysisKind;
  final String? selectedSideLabel;
  final int sampleCount;
  final double? primaryMetricBaseline;
  final double? formMetricBaseline;
  final double? torsoAngleBaseline;
  final double? depthMetricBaseline;
  final double? alignmentMetricBaseline;
  final double? stabilityMetricBaseline;
  final double? lockoutMetricBaseline;
  final double? bottomControlMetricBaseline;
}
