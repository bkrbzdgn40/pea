/// Persistable summary of one completed workout analysis session.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.ownerId,
    required this.exerciseType,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.totalReps,
    required this.averageScore,
    required this.bestScore,
    required this.formWarningCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String exerciseType;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSec;
  final int totalReps;
  final double averageScore;
  final double bestScore;
  final int formWarningCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Duration get duration => Duration(seconds: durationSec);

  WorkoutSession copyWith({
    String? id,
    String? ownerId,
    String? exerciseType,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSec,
    int? totalReps,
    double? averageScore,
    double? bestScore,
    int? formWarningCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      exerciseType: exerciseType ?? this.exerciseType,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSec: durationSec ?? this.durationSec,
      totalReps: totalReps ?? this.totalReps,
      averageScore: averageScore ?? this.averageScore,
      bestScore: bestScore ?? this.bestScore,
      formWarningCount: formWarningCount ?? this.formWarningCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'exerciseType': exerciseType,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'durationSec': durationSec,
      'totalReps': totalReps,
      'averageScore': averageScore,
      'bestScore': bestScore,
      'formWarningCount': formWarningCount,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory WorkoutSession.fromMap(Map<String, Object?> map) {
    return WorkoutSession(
      id: _readString(map, 'id'),
      ownerId: _readString(map, 'ownerId'),
      exerciseType: _readString(map, 'exerciseType'),
      startedAt: _readDateTime(map, 'startedAt'),
      endedAt: _readDateTime(map, 'endedAt'),
      durationSec: _readInt(map, 'durationSec'),
      totalReps: _readInt(map, 'totalReps'),
      averageScore: _readDouble(map, 'averageScore'),
      bestScore: _readDouble(map, 'bestScore'),
      formWarningCount: _readInt(map, 'formWarningCount'),
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

int _readInt(Map<String, Object?> map, String key) {
  final value = map[key];
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
