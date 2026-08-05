import 'session_measurement_evidence.dart';
import 'workout_rep.dart';

/// Persistable domain snapshot of one completed workout analysis session.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.ownerId,
    required this.exerciseType,
    this.analysisKind = 'rangeRep',
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.totalReps,
    required this.averageScore,
    required this.bestScore,
    this.worstScore = 0.0,
    this.validReps = 0,
    this.lowConfidenceReps = 0,
    this.invalidReps = 0,
    required this.formWarningCount,
    this.totalHoldSeconds = 0.0,
    this.bestHoldSeconds = 0.0,
    this.formBreakCount = 0,
    this.preparationOutcome = PreparationOutcome.legacyUnknown,
    this.measurementQuality = SessionMeasurementQuality.unknown,
    this.averageMeasurementConfidence,
    this.measurementSampleCount = 0,
    this.reps,
    this.createdAt,
    this.updatedAt,
  }) : assert(measurementSampleCount >= 0),
       assert(
         averageMeasurementConfidence == null ||
             (averageMeasurementConfidence >= 0 &&
                 averageMeasurementConfidence <= 1),
       ),
       assert(
         (averageMeasurementConfidence == null &&
                 measurementSampleCount == 0) ||
             (averageMeasurementConfidence != null &&
                 measurementSampleCount > 0),
       ),
       assert(
         (measurementSampleCount == 0 &&
                 measurementQuality == SessionMeasurementQuality.unknown) ||
             (measurementSampleCount == 1 &&
                 measurementQuality ==
                     SessionMeasurementQuality.insufficient) ||
             (measurementSampleCount >= 2 &&
                 measurementQuality != SessionMeasurementQuality.unknown &&
                 measurementQuality != SessionMeasurementQuality.insufficient),
       ),
       assert(
         preparationOutcome == PreparationOutcome.passed ||
             (measurementQuality != SessionMeasurementQuality.high &&
                 measurementQuality != SessionMeasurementQuality.moderate),
       );

  final String id;
  final String ownerId;
  final String exerciseType;
  final String analysisKind;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSec;
  final int totalReps;
  final double averageScore;
  final double bestScore;
  final double worstScore;
  final int validReps;
  final int lowConfidenceReps;
  final int invalidReps;
  final int formWarningCount;
  final double totalHoldSeconds;
  final double bestHoldSeconds;
  final int formBreakCount;
  final PreparationOutcome preparationOutcome;
  final SessionMeasurementQuality measurementQuality;
  final double? averageMeasurementConfidence;
  final int measurementSampleCount;

  /// Optional rep-level details kept in the domain model.
  ///
  /// The current Firestore session document contract is summary-only and does
  /// not persist this field.
  final List<WorkoutRep>? reps;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Duration get duration => Duration(seconds: durationSec);
  bool get isHoldSession => analysisKind == 'hold';
  bool get preparationWasOverridden =>
      preparationOutcome == PreparationOutcome.overridden;
  bool get hasKnownMeasurementEvidence =>
      averageMeasurementConfidence != null && measurementSampleCount > 0;
  bool get hasLimitedMeasurementEvidence =>
      measurementQuality == SessionMeasurementQuality.limited ||
      measurementQuality == SessionMeasurementQuality.insufficient;

  WorkoutSession copyWith({
    String? id,
    String? ownerId,
    String? exerciseType,
    String? analysisKind,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSec,
    int? totalReps,
    double? averageScore,
    double? bestScore,
    double? worstScore,
    int? validReps,
    int? lowConfidenceReps,
    int? invalidReps,
    int? formWarningCount,
    double? totalHoldSeconds,
    double? bestHoldSeconds,
    int? formBreakCount,
    PreparationOutcome? preparationOutcome,
    SessionMeasurementQuality? measurementQuality,
    double? averageMeasurementConfidence,
    int? measurementSampleCount,
    List<WorkoutRep>? reps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      exerciseType: exerciseType ?? this.exerciseType,
      analysisKind: analysisKind ?? this.analysisKind,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSec: durationSec ?? this.durationSec,
      totalReps: totalReps ?? this.totalReps,
      averageScore: averageScore ?? this.averageScore,
      bestScore: bestScore ?? this.bestScore,
      worstScore: worstScore ?? this.worstScore,
      validReps: validReps ?? this.validReps,
      lowConfidenceReps: lowConfidenceReps ?? this.lowConfidenceReps,
      invalidReps: invalidReps ?? this.invalidReps,
      formWarningCount: formWarningCount ?? this.formWarningCount,
      totalHoldSeconds: totalHoldSeconds ?? this.totalHoldSeconds,
      bestHoldSeconds: bestHoldSeconds ?? this.bestHoldSeconds,
      formBreakCount: formBreakCount ?? this.formBreakCount,
      preparationOutcome: preparationOutcome ?? this.preparationOutcome,
      measurementQuality: measurementQuality ?? this.measurementQuality,
      averageMeasurementConfidence:
          averageMeasurementConfidence ?? this.averageMeasurementConfidence,
      measurementSampleCount:
          measurementSampleCount ?? this.measurementSampleCount,
      reps: reps ?? this.reps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Generic domain serialization for local/model usage.
  ///
  /// This shape is intentionally broader than today's Firestore session
  /// document payload, which persists summary fields only.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'exerciseType': exerciseType,
      'analysisKind': analysisKind,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'durationSec': durationSec,
      'totalReps': totalReps,
      'averageScore': averageScore,
      'bestScore': bestScore,
      'worstScore': worstScore,
      'validReps': validReps,
      'lowConfidenceReps': lowConfidenceReps,
      'invalidReps': invalidReps,
      'formWarningCount': formWarningCount,
      'totalHoldSeconds': totalHoldSeconds,
      'bestHoldSeconds': bestHoldSeconds,
      'formBreakCount': formBreakCount,
      'preparationOutcome': preparationOutcome.name,
      'measurementQuality': measurementQuality.name,
      'averageMeasurementConfidence': averageMeasurementConfidence,
      'measurementSampleCount': measurementSampleCount,
      'reps': reps?.map((rep) => rep.toMap()).toList(growable: false),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory WorkoutSession.fromMap(Map<String, Object?> map) {
    return WorkoutSession(
      id: _readString(map, 'id'),
      ownerId: _readString(map, 'ownerId'),
      exerciseType: _readString(map, 'exerciseType'),
      analysisKind: _readStringOrDefault(map, 'analysisKind', 'rangeRep'),
      startedAt: _readDateTime(map, 'startedAt'),
      endedAt: _readDateTime(map, 'endedAt'),
      durationSec: _readIntWithFallback(map, 'durationSec', 'durationSeconds'),
      totalReps: _readInt(map, 'totalReps'),
      averageScore: _readDouble(map, 'averageScore'),
      bestScore: _readDouble(map, 'bestScore'),
      worstScore: _readDoubleOrDefault(map, 'worstScore', 0),
      validReps: _readIntOrDefault(map, 'validReps', 0),
      lowConfidenceReps: _readIntOrDefault(map, 'lowConfidenceReps', 0),
      invalidReps: _readIntOrDefault(map, 'invalidReps', 0),
      formWarningCount: _readInt(map, 'formWarningCount'),
      totalHoldSeconds: _readDoubleWithFallback(
        map,
        'totalHoldSeconds',
        'holdDurationSeconds',
        0,
      ),
      bestHoldSeconds: _readDoubleOrDefault(map, 'bestHoldSeconds', 0),
      formBreakCount: _readIntWithFallbackOrDefault(
        map,
        'formBreakCount',
        'holdFormBreakCount',
        0,
      ),
      preparationOutcome: PreparationOutcome.fromWireValue(
        map['preparationOutcome'],
      ),
      measurementQuality: SessionMeasurementQuality.fromWireValue(
        map['measurementQuality'],
      ),
      averageMeasurementConfidence: _readNullableDouble(
        map,
        'averageMeasurementConfidence',
      ),
      measurementSampleCount: _readIntOrDefault(
        map,
        'measurementSampleCount',
        0,
      ),
      reps: _readNullableWorkoutReps(map, 'reps'),
      createdAt: _readNullableDateTime(map, 'createdAt'),
      updatedAt: _readNullableDateTime(map, 'updatedAt'),
    );
  }
}

String _readString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String) {
    return value;
  }

  throw FormatException('Expected string for "$key".');
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

int _readInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Expected number for "$key".');
}

int _readIntWithFallback(
  Map<String, Object?> map,
  String key,
  String fallbackKey,
) {
  final value = map[key] ?? map[fallbackKey];
  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Expected number for "$key".');
}

int _readIntOrDefault(Map<String, Object?> map, String key, int fallback) {
  final value = map[key];
  if (value == null) {
    return fallback;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Expected number for "$key".');
}

int _readIntWithFallbackOrDefault(
  Map<String, Object?> map,
  String key,
  String fallbackKey,
  int fallback,
) {
  final value = map[key] ?? map[fallbackKey];
  if (value == null) {
    return fallback;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Expected number for "$key".');
}

double _readDouble(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is num) {
    return value.toDouble();
  }

  throw FormatException('Expected number for "$key".');
}

double _readDoubleOrDefault(
  Map<String, Object?> map,
  String key,
  double fallback,
) {
  final value = map[key];
  if (value == null) {
    return fallback;
  }

  if (value is num) {
    return value.toDouble();
  }

  throw FormatException('Expected number for "$key".');
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

double _readDoubleWithFallback(
  Map<String, Object?> map,
  String key,
  String fallbackKey,
  double fallback,
) {
  final value = map[key] ?? map[fallbackKey];
  if (value == null) {
    return fallback;
  }

  if (value is num) {
    return value.toDouble();
  }

  throw FormatException('Expected number for "$key".');
}

DateTime _readDateTime(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.parse(value);
  }

  throw FormatException('Expected ISO-8601 date string for "$key".');
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

List<WorkoutRep>? _readNullableWorkoutReps(
  Map<String, Object?> map,
  String key,
) {
  final value = map[key];
  if (value == null) {
    return null;
  }

  if (value is Iterable) {
    return List<WorkoutRep>.unmodifiable(
      value.map((entry) {
        if (entry is Map) {
          return WorkoutRep.fromMap(Map<String, Object?>.from(entry));
        }

        throw FormatException('Expected map entries in "$key".');
      }),
    );
  }

  throw FormatException('Expected list for "$key".');
}
