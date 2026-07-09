class CalibrationSnapshot {
  const CalibrationSnapshot({
    required this.analysisKind,
    this.selectedSideLabel,
    this.primaryMetricBaseline,
    this.formMetricBaseline,
    this.torsoAngleBaseline,
    this.depthMetricBaseline,
    this.alignmentMetricBaseline,
    this.stabilityMetricBaseline,
    this.lockoutMetricBaseline,
    this.bottomControlMetricBaseline,
    this.createdAt,
  });

  final String analysisKind;
  final String? selectedSideLabel;
  final double? primaryMetricBaseline;
  final double? formMetricBaseline;
  final double? torsoAngleBaseline;
  final double? depthMetricBaseline;
  final double? alignmentMetricBaseline;
  final double? stabilityMetricBaseline;
  final double? lockoutMetricBaseline;
  final double? bottomControlMetricBaseline;
  final DateTime? createdAt;

  bool get hasAnyBaseline =>
      primaryMetricBaseline != null ||
      formMetricBaseline != null ||
      torsoAngleBaseline != null ||
      depthMetricBaseline != null ||
      alignmentMetricBaseline != null ||
      stabilityMetricBaseline != null ||
      lockoutMetricBaseline != null ||
      bottomControlMetricBaseline != null;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'analysisKind': analysisKind,
      'selectedSideLabel': selectedSideLabel,
      'primaryMetricBaseline': primaryMetricBaseline,
      'formMetricBaseline': formMetricBaseline,
      'torsoAngleBaseline': torsoAngleBaseline,
      'depthMetricBaseline': depthMetricBaseline,
      'alignmentMetricBaseline': alignmentMetricBaseline,
      'stabilityMetricBaseline': stabilityMetricBaseline,
      'lockoutMetricBaseline': lockoutMetricBaseline,
      'bottomControlMetricBaseline': bottomControlMetricBaseline,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory CalibrationSnapshot.fromMap(Map<String, Object?> map) {
    return CalibrationSnapshot(
      analysisKind: _readStringOrDefault(map, 'analysisKind', 'rangeRep'),
      selectedSideLabel: _readNullableString(map, 'selectedSideLabel'),
      primaryMetricBaseline: _readNullableDouble(map, 'primaryMetricBaseline'),
      formMetricBaseline: _readNullableDouble(map, 'formMetricBaseline'),
      torsoAngleBaseline: _readNullableDouble(map, 'torsoAngleBaseline'),
      depthMetricBaseline: _readNullableDouble(map, 'depthMetricBaseline'),
      alignmentMetricBaseline: _readNullableDouble(
        map,
        'alignmentMetricBaseline',
      ),
      stabilityMetricBaseline: _readNullableDouble(
        map,
        'stabilityMetricBaseline',
      ),
      lockoutMetricBaseline: _readNullableDouble(map, 'lockoutMetricBaseline'),
      bottomControlMetricBaseline: _readNullableDouble(
        map,
        'bottomControlMetricBaseline',
      ),
      createdAt: _readNullableDateTime(map, 'createdAt'),
    );
  }
}

String _readStringOrDefault(
  Map<String, Object?> map,
  String key,
  String fallback,
) {
  final value = map[key];
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Expected string for "$key".');
}

String? _readNullableString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw FormatException('Expected nullable string for "$key".');
}

double? _readNullableDouble(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Expected nullable number for "$key".');
}

DateTime? _readNullableDateTime(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.parse(value);
  }
  throw FormatException('Expected nullable ISO-8601 date string for "$key".');
}
