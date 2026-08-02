import 'measurement_confidence_breakdown.dart';

/// Persistable exercise-agnostic facts about one completed workout rep.
class WorkoutRep {
  const WorkoutRep({
    required this.repIndex,
    required this.exerciseType,
    required this.analysisKind,
    this.recordedAt,
    this.validationStatus,
    this.validationReasons = const <String>[],
    this.score,
    this.minPrimaryMetric,
    this.worstFormMetric,
    this.descentMillis,
    this.ascentMillis,
    this.feedback,
    this.hadFormViolation = false,
    this.hadCoverageDrop = false,
    this.switchedSideDuringRep = false,
    this.completedPhaseSequence = false,
    this.selectedSideLabel,
    this.measurementConfidence,
    double? confidence,
    this.primaryRom,
    this.eccentricMillis,
    this.concentricMillis,
    this.tempoMeasurementStatus,
    this.tempoMeasurementIssues = const <String>[],
    this.tempoQuality,
    this.tempoSeverity,
    this.tempoReasons = const <String>[],
    this.tempoIncludedInScore = false,
    this.tempoTotalMillis,
    this.techniqueObservations = const <Map<String, Object?>>[],
    this.selectedSide,
    this.coverageQuality,
  }) : assert(measurementConfidence == null || confidence == null),
       _legacyConfidence = confidence;

  final int repIndex;
  final String exerciseType;
  final String analysisKind;
  final DateTime? recordedAt;
  final String? validationStatus;
  final List<String> validationReasons;
  final double? score;
  final double? minPrimaryMetric;
  final double? worstFormMetric;
  final int? descentMillis;
  final int? ascentMillis;
  final String? feedback;
  final bool hadFormViolation;
  final bool hadCoverageDrop;
  final bool switchedSideDuringRep;
  final bool completedPhaseSequence;
  final String? selectedSideLabel;
  final MeasurementConfidenceBreakdown? measurementConfidence;
  final double? _legacyConfidence;
  final double? primaryRom;
  final int? eccentricMillis;
  final int? concentricMillis;
  final String? tempoMeasurementStatus;
  final List<String> tempoMeasurementIssues;
  final String? tempoQuality;
  final String? tempoSeverity;
  final List<String> tempoReasons;
  final bool tempoIncludedInScore;
  final int? tempoTotalMillis;
  final List<Map<String, Object?>> techniqueObservations;
  final String? selectedSide;
  final double? coverageQuality;

  double? get confidence =>
      measurementConfidence?.combined ?? _legacyConfidence;

  MeasurementConfidenceBreakdown? get effectiveMeasurementConfidence {
    final native = measurementConfidence;
    if (native != null) {
      return native;
    }
    final legacy = _legacyConfidence;
    return legacy == null
        ? null
        : MeasurementConfidenceBreakdown.legacyScalar(legacy);
  }

  /// Stable Firestore document id for persisted reps.
  String get stableId {
    return 'rep_${repIndex.toString().padLeft(4, '0')}';
  }

  /// Observed rep duration derived from the phase timings currently retained.
  Duration? get observedDuration {
    final explicitTempoTotalMillis = tempoTotalMillis;
    if (explicitTempoTotalMillis != null) {
      return Duration(milliseconds: explicitTempoTotalMillis);
    }
    if (descentMillis == null && ascentMillis == null) {
      return null;
    }

    return Duration(milliseconds: (descentMillis ?? 0) + (ascentMillis ?? 0));
  }

  bool get isTempoMeasurementEligible => tempoMeasurementStatus == 'eligible';

  bool get hasTempoCoachingResult =>
      tempoQuality != null && tempoQuality != 'unavailable';

  bool get isValidatedAsValid => validationStatus == 'valid';

  bool get isValidatedAsLowConfidence {
    return validationStatus == 'lowConfidence' ||
        validationStatus == 'low confidence';
  }

  bool get isValidatedAsInvalid => validationStatus == 'invalid';

  bool get isValidationUnknown {
    return !isValidatedAsValid &&
        !isValidatedAsLowConfidence &&
        !isValidatedAsInvalid;
  }

  String? get primaryValidationReason {
    if (validationReasons.isEmpty) {
      return null;
    }

    return validationReasons.first;
  }

  Map<String, Object?> toMap() {
    return {
      'repIndex': repIndex,
      'exerciseType': exerciseType,
      'analysisKind': analysisKind,
      'recordedAt': recordedAt?.toIso8601String(),
      'validationStatus': validationStatus,
      'validationReasons': validationReasons.toList(growable: false),
      'score': score,
      'minPrimaryMetric': minPrimaryMetric,
      'worstFormMetric': worstFormMetric,
      'descentMillis': descentMillis,
      'ascentMillis': ascentMillis,
      'feedback': feedback,
      'hadFormViolation': hadFormViolation,
      'hadCoverageDrop': hadCoverageDrop,
      'switchedSideDuringRep': switchedSideDuringRep,
      'completedPhaseSequence': completedPhaseSequence,
      'selectedSideLabel': selectedSideLabel,
      'measurementConfidence': measurementConfidence?.toMap(),
      'confidence': confidence,
      'primaryRom': primaryRom,
      'eccentricMillis': eccentricMillis,
      'concentricMillis': concentricMillis,
      'tempoMeasurementStatus': tempoMeasurementStatus,
      'tempoMeasurementIssues': tempoMeasurementIssues.toList(growable: false),
      'tempoQuality': tempoQuality,
      'tempoSeverity': tempoSeverity,
      'tempoReasons': tempoReasons.toList(growable: false),
      'tempoIncludedInScore': tempoIncludedInScore,
      'tempoTotalMillis': tempoTotalMillis,
      'techniqueObservations': techniqueObservations
          .map((item) => Map<String, Object?>.from(item))
          .toList(growable: false),
      'selectedSide': selectedSide ?? selectedSideLabel,
      'coverageQuality': coverageQuality,
    };
  }

  factory WorkoutRep.fromMap(Map<String, Object?> map) {
    final measurementConfidence = _readMeasurementConfidence(
      map,
      'measurementConfidence',
    );
    return WorkoutRep(
      repIndex: _readRequiredInt(map, 'repIndex'),
      exerciseType: _readRequiredString(map, 'exerciseType'),
      analysisKind: _readRequiredString(map, 'analysisKind'),
      recordedAt: _readNullableDateTime(map, 'recordedAt'),
      validationStatus: _readNullableString(map, 'validationStatus'),
      validationReasons: _readStringList(map, 'validationReasons'),
      score: _readNullableDouble(map, 'score'),
      minPrimaryMetric: _readNullableDouble(map, 'minPrimaryMetric'),
      worstFormMetric: _readNullableDouble(map, 'worstFormMetric'),
      descentMillis: _readNullableInt(map, 'descentMillis'),
      ascentMillis: _readNullableInt(map, 'ascentMillis'),
      feedback: _readNullableString(map, 'feedback'),
      hadFormViolation: _readBoolOrDefault(map, 'hadFormViolation', false),
      hadCoverageDrop: _readBoolOrDefault(map, 'hadCoverageDrop', false),
      switchedSideDuringRep: _readBoolOrDefault(
        map,
        'switchedSideDuringRep',
        false,
      ),
      completedPhaseSequence: _readBoolOrDefault(
        map,
        'completedPhaseSequence',
        false,
      ),
      selectedSideLabel:
          _readNullableString(map, 'selectedSideLabel') ??
          _readNullableString(map, 'selectedSide'),
      measurementConfidence: measurementConfidence,
      confidence: measurementConfidence == null
          ? _readNullableDouble(map, 'confidence')
          : null,
      primaryRom: _readNullableDouble(map, 'primaryRom'),
      eccentricMillis:
          _readNullableInt(map, 'eccentricMillis') ??
          _readNullableInt(map, 'descentMillis'),
      concentricMillis:
          _readNullableInt(map, 'concentricMillis') ??
          _readNullableInt(map, 'ascentMillis'),
      tempoMeasurementStatus: _readNullableString(
        map,
        'tempoMeasurementStatus',
      ),
      tempoMeasurementIssues: _readStringList(map, 'tempoMeasurementIssues'),
      tempoQuality: _readNullableString(map, 'tempoQuality'),
      tempoSeverity: _readNullableString(map, 'tempoSeverity'),
      tempoReasons: _readStringList(map, 'tempoReasons'),
      tempoIncludedInScore: _readBoolOrDefault(
        map,
        'tempoIncludedInScore',
        false,
      ),
      tempoTotalMillis: _readNullableInt(map, 'tempoTotalMillis'),
      techniqueObservations: _readMapList(map, 'techniqueObservations'),
      selectedSide:
          _readNullableString(map, 'selectedSide') ??
          _readNullableString(map, 'selectedSideLabel'),
      coverageQuality: _readNullableDouble(map, 'coverageQuality'),
    );
  }
}

MeasurementConfidenceBreakdown? _readMeasurementConfidence(
  Map<String, Object?> map,
  String key,
) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is Map) {
    return MeasurementConfidenceBreakdown.fromMap(
      Map<String, Object?>.from(value.cast<String, Object?>()),
    );
  }
  throw FormatException('Expected nullable map for "$key".');
}

String _readRequiredString(Map<String, Object?> map, String key) {
  final value = map[key];
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

int _readRequiredInt(Map<String, Object?> map, String key) {
  final value = map[key];
  final parsed = _parseInt(value);
  if (parsed != null) {
    return parsed;
  }

  throw FormatException('Expected integer for "$key".');
}

int? _readNullableInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }

  final parsed = _parseInt(value);
  if (parsed != null) {
    return parsed;
  }

  throw FormatException('Expected nullable integer for "$key".');
}

double? _readNullableDouble(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }

  final parsed = _parseDouble(value);
  if (parsed != null) {
    return parsed;
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
    return DateTime.tryParse(value);
  }

  throw FormatException('Expected nullable ISO-8601 date string for "$key".');
}

List<String> _readStringList(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return const <String>[];
  }

  if (value is Iterable) {
    return List<String>.unmodifiable(value.whereType<String>());
  }

  throw FormatException('Expected list for "$key".');
}

List<Map<String, Object?>> _readMapList(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return const <Map<String, Object?>>[];
  }
  if (value is Iterable) {
    return List<Map<String, Object?>>.unmodifiable(
      value.whereType<Map>().map(
        (item) => Map<String, Object?>.from(item.cast<String, Object?>()),
      ),
    );
  }
  throw FormatException('Expected map list for "$key".');
}

bool _readBoolOrDefault(Map<String, Object?> map, String key, bool fallback) {
  final value = map[key];
  if (value == null) {
    return fallback;
  }

  if (value is bool) {
    return value;
  }

  throw FormatException('Expected boolean for "$key".');
}

int? _parseInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

double? _parseDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}
