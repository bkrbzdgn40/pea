class RangeRepAbortedAttemptDetectionData {
  const RangeRepAbortedAttemptDetectionData({
    required this.minAngle,
    required this.descentDuration,
    this.startAngle,
    this.primaryRom,
  });

  final double minAngle;
  final Duration descentDuration;
  final double? startAngle;
  final double? primaryRom;
}
