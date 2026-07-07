class AnalysisFrame {
  const AnalysisFrame({
    required this.primaryMetric,
    required this.formMetric,
    this.bodyLineAngle,
    this.armSupportAngle,
    this.legExtensionAngle,
  });

  final double primaryMetric;
  final double formMetric;
  final double? bodyLineAngle;
  final double? armSupportAngle;
  final double? legExtensionAngle;
}
