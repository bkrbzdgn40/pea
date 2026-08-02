import 'package:cloud_firestore/cloud_firestore.dart';

/// Debug-only mirror of the strict Firestore workout write contract.
///
/// This does not authorize writes and must not replace emulator coverage. It
/// only explains which local payload fields would fail the deployed rules when
/// an atomic batch returns one generic permission-denied error.
class FirestoreWorkoutWriteDiagnostics {
  const FirestoreWorkoutWriteDiagnostics._();

  static const Set<String> _sessionKeys = <String>{
    'id',
    'ownerId',
    'exerciseType',
    'analysisKind',
    'startedAt',
    'endedAt',
    'durationSeconds',
    'totalReps',
    'validReps',
    'lowConfidenceReps',
    'invalidReps',
    'averageScore',
    'bestScore',
    'worstScore',
    'formWarningCount',
    'holdDurationSeconds',
    'bestHoldSeconds',
    'holdFormBreakCount',
    'createdAt',
    'updatedAt',
  };

  static const Set<String> _repKeys = <String>{
    'id',
    'ownerId',
    'sessionId',
    'exerciseType',
    'analysisKind',
    'repIndex',
    'score',
    'isValid',
    'validationStatus',
    'invalidReason',
    'validationReasons',
    'endedAt',
    'durationSeconds',
    'minPrimaryMetric',
    'worstFormMetric',
    'descentMillis',
    'ascentMillis',
    'hadFormViolation',
    'hadCoverageDrop',
    'switchedSideDuringRep',
    'completedPhaseSequence',
    'selectedSide',
    'measurementConfidence',
    'confidence',
    'primaryRom',
    'eccentricMillis',
    'concentricMillis',
    'tempoMeasurementStatus',
    'tempoMeasurementIssues',
    'tempoQuality',
    'tempoSeverity',
    'tempoReasons',
    'tempoIncludedInScore',
    'tempoTotalMillis',
    'techniqueObservations',
    'coverageQuality',
    'feedback',
    'createdAt',
  };

  static const Set<String> _measurementConfidenceKeys = <String>{
    'landmarkLikelihood',
    'signalAvailability',
    'geometryPlausibility',
    'temporalContinuity',
    'combined',
    'issues',
  };

  static const Set<String> _measurementConfidenceIssues = <String>{
    'missing_required_landmark',
    'low_landmark_likelihood',
    'low_mean_likelihood',
    'missing_required_signal',
    'non_finite_geometry',
    'degenerate_geometry',
    'temporal_history_unavailable',
    'temporal_discontinuity',
    'coverage_interruption',
    'side_switch_during_rep',
    'legacy_scalar_only',
  };

  static Map<String, Object?> buildReport({
    required String sessionPath,
    required String ownerId,
    required String sessionId,
    required Map<String, dynamic> sessionPayload,
    required List<FirestoreRepWriteDiagnosticInput> reps,
  }) {
    return <String, Object?>{
      'sessionPath': sessionPath,
      'sessionIssues': inspectSession(
        payload: sessionPayload,
        ownerId: ownerId,
        sessionId: sessionId,
      ),
      'sessionPayload': _jsonSafe(sessionPayload),
      'repReports': reps
          .map(
            (rep) => <String, Object?>{
              'path': rep.path,
              'issues': inspectRep(
                payload: rep.payload,
                ownerId: ownerId,
                sessionId: sessionId,
                repId: rep.repId,
              ),
              'payload': _jsonSafeRep(rep.payload),
            },
          )
          .toList(growable: false),
    };
  }

  static List<String> inspectSession({
    required Map<String, dynamic> payload,
    required String ownerId,
    required String sessionId,
  }) {
    final issues = <String>[];
    _checkExactKeys(payload, _sessionKeys, 'session', issues);
    _expect(
      payload['id'] is String && payload['id'] == sessionId,
      'session.id',
      issues,
    );
    _expect(
      payload['ownerId'] is String && payload['ownerId'] == ownerId,
      'session.ownerId',
      issues,
    );
    _expect(payload['exerciseType'] is String, 'session.exerciseType', issues);
    _expect(payload['analysisKind'] is String, 'session.analysisKind', issues);
    _expect(payload['startedAt'] is Timestamp, 'session.startedAt', issues);
    _expect(payload['endedAt'] is Timestamp, 'session.endedAt', issues);
    _expect(payload['createdAt'] is Timestamp, 'session.createdAt', issues);
    _expect(payload['updatedAt'] is Timestamp, 'session.updatedAt', issues);

    final startedAt = payload['startedAt'];
    final endedAt = payload['endedAt'];
    if (startedAt is Timestamp && endedAt is Timestamp) {
      _expect(
        !endedAt.toDate().isBefore(startedAt.toDate()),
        'session.endedAtBeforeStartedAt',
        issues,
      );
    }

    for (final key in const <String>[
      'durationSeconds',
      'totalReps',
      'validReps',
      'lowConfidenceReps',
      'invalidReps',
      'formWarningCount',
      'holdFormBreakCount',
    ]) {
      _expect(_isNonNegativeInt(payload[key]), 'session.$key', issues);
    }
    for (final key in const <String>[
      'averageScore',
      'bestScore',
      'worstScore',
    ]) {
      _expect(_isScore(payload[key]), 'session.$key', issues);
    }
    for (final key in const <String>[
      'holdDurationSeconds',
      'bestHoldSeconds',
    ]) {
      _expect(_isNonNegativeNumber(payload[key]), 'session.$key', issues);
    }

    final total = payload['totalReps'];
    final valid = payload['validReps'];
    final low = payload['lowConfidenceReps'];
    if (total is int && valid is int && low is int) {
      _expect(
        valid + low <= total,
        'session.acceptedCountsExceedTotal',
        issues,
      );
    }
    return issues;
  }

  static List<String> inspectRep({
    required Map<String, dynamic> payload,
    required String ownerId,
    required String sessionId,
    required String repId,
  }) {
    final issues = <String>[];
    _checkExactKeys(payload, _repKeys, 'rep', issues);
    _expect(
      payload['id'] is String && payload['id'] == repId,
      'rep.id',
      issues,
    );
    _expect(
      payload['ownerId'] is String && payload['ownerId'] == ownerId,
      'rep.ownerId',
      issues,
    );
    _expect(
      payload['sessionId'] is String && payload['sessionId'] == sessionId,
      'rep.sessionId',
      issues,
    );
    _expect(payload['exerciseType'] is String, 'rep.exerciseType', issues);
    _expect(payload['analysisKind'] is String, 'rep.analysisKind', issues);
    _expect(_isPositiveInt(payload['repIndex']), 'rep.repIndex', issues);
    _expect(payload['isValid'] is bool, 'rep.isValid', issues);
    _expect(payload['createdAt'] is Timestamp, 'rep.createdAt', issues);

    _expect(_isNullableScore(payload['score']), 'rep.score', issues);
    _expect(
      _isNullableString(payload['validationStatus']),
      'rep.validationStatus',
      issues,
    );
    _expect(
      _isNullableString(payload['invalidReason']),
      'rep.invalidReason',
      issues,
    );
    _expect(
      payload['validationReasons'] == null ||
          payload['validationReasons'] is List,
      'rep.validationReasons',
      issues,
    );
    _expect(_isNullableTimestamp(payload['endedAt']), 'rep.endedAt', issues);
    _expect(
      _isNullableNonNegativeNumber(payload['durationSeconds']),
      'rep.durationSeconds',
      issues,
    );
    _expect(
      _isNullableNumber(payload['minPrimaryMetric']),
      'rep.minPrimaryMetric',
      issues,
    );
    _expect(
      _isNullableNumber(payload['worstFormMetric']),
      'rep.worstFormMetric',
      issues,
    );

    for (final key in const <String>[
      'descentMillis',
      'ascentMillis',
      'eccentricMillis',
      'concentricMillis',
      'tempoTotalMillis',
    ]) {
      _expect(_isNullableNonNegativeInt(payload[key]), 'rep.$key', issues);
    }
    for (final key in const <String>[
      'hadFormViolation',
      'hadCoverageDrop',
      'switchedSideDuringRep',
      'completedPhaseSequence',
      'tempoIncludedInScore',
    ]) {
      _expect(_isNullableBool(payload[key]), 'rep.$key', issues);
    }
    _expect(
      _isNullableString(payload['selectedSide']),
      'rep.selectedSide',
      issues,
    );
    _expect(
      _isNullableUnitInterval(payload['confidence']),
      'rep.confidence',
      issues,
    );
    _inspectMeasurementConfidence(payload, issues);
    _expect(
      _isNullableNonNegativeNumber(payload['primaryRom']),
      'rep.primaryRom',
      issues,
    );
    _expect(
      _isOneOfOrNull(payload['tempoMeasurementStatus'], const <String>{
        'eligible',
        'unavailable',
      }),
      'rep.tempoMeasurementStatus',
      issues,
    );
    _expect(
      payload['tempoMeasurementIssues'] == null ||
          payload['tempoMeasurementIssues'] is List,
      'rep.tempoMeasurementIssues',
      issues,
    );
    _expect(
      _isOneOfOrNull(payload['tempoQuality'], const <String>{
        'unavailable',
        'target',
        'tooFast',
        'tooSlow',
      }),
      'rep.tempoQuality',
      issues,
    );
    _expect(
      _isOneOfOrNull(payload['tempoSeverity'], const <String>{
        'none',
        'mild',
        'strong',
      }),
      'rep.tempoSeverity',
      issues,
    );
    _expect(
      payload['tempoReasons'] == null || payload['tempoReasons'] is List,
      'rep.tempoReasons',
      issues,
    );
    _expect(
      payload['techniqueObservations'] == null ||
          payload['techniqueObservations'] is List,
      'rep.techniqueObservations',
      issues,
    );
    _expect(
      _isNullableUnitInterval(payload['coverageQuality']),
      'rep.coverageQuality',
      issues,
    );
    _expect(_isNullableString(payload['feedback']), 'rep.feedback', issues);
    return issues;
  }

  static void _inspectMeasurementConfidence(
    Map<String, dynamic> payload,
    List<String> issues,
  ) {
    final raw = payload['measurementConfidence'];
    if (raw == null) {
      return;
    }
    if (raw is! Map) {
      issues.add('rep.measurementConfidence');
      return;
    }
    final confidence = Map<String, Object?>.from(raw.cast<String, Object?>());
    _checkExactKeys(
      confidence,
      _measurementConfidenceKeys,
      'rep.measurementConfidence',
      issues,
    );
    for (final key in const <String>[
      'landmarkLikelihood',
      'signalAvailability',
      'geometryPlausibility',
      'temporalContinuity',
      'combined',
    ]) {
      _expect(
        _isNullableUnitInterval(confidence[key]),
        'rep.measurementConfidence.$key',
        issues,
      );
    }
    final rawIssues = confidence['issues'];
    final issueListIsValid =
        rawIssues is List &&
        rawIssues.every(
          (value) =>
              value is String && _measurementConfidenceIssues.contains(value),
        );
    _expect(issueListIsValid, 'rep.measurementConfidence.issues', issues);
    _expect(
      payload['confidence'] == confidence['combined'],
      'rep.confidenceCombinedMismatch',
      issues,
    );
  }

  static void _checkExactKeys(
    Map<Object?, Object?> payload,
    Set<String> expected,
    String prefix,
    List<String> issues,
  ) {
    final actual = payload.keys.whereType<String>().toSet();
    final missing = expected.difference(actual);
    final unexpected = actual.difference(expected);
    if (missing.isNotEmpty) {
      issues.add('$prefix.missingKeys:${missing.toList()..sort()}');
    }
    if (unexpected.isNotEmpty) {
      issues.add('$prefix.unexpectedKeys:${unexpected.toList()..sort()}');
    }
  }

  static void _expect(bool condition, String issue, List<String> issues) {
    if (!condition) {
      issues.add(issue);
    }
  }

  static bool _isScore(Object? value) =>
      value is num && value.isFinite && value >= 0 && value <= 100;
  static bool _isNullableScore(Object? value) =>
      value == null || _isScore(value);
  static bool _isNonNegativeInt(Object? value) => value is int && value >= 0;
  static bool _isPositiveInt(Object? value) => value is int && value >= 1;
  static bool _isNullableNonNegativeInt(Object? value) =>
      value == null || _isNonNegativeInt(value);
  static bool _isNonNegativeNumber(Object? value) =>
      value is num && value.isFinite && value >= 0;
  static bool _isNullableNonNegativeNumber(Object? value) =>
      value == null || _isNonNegativeNumber(value);
  static bool _isNullableNumber(Object? value) =>
      value == null || value is num && value.isFinite;
  static bool _isNullableString(Object? value) =>
      value == null || value is String;
  static bool _isNullableBool(Object? value) => value == null || value is bool;
  static bool _isNullableTimestamp(Object? value) =>
      value == null || value is Timestamp;
  static bool _isNullableUnitInterval(Object? value) =>
      value == null ||
      value is num && value.isFinite && value >= 0 && value <= 1;
  static bool _isOneOfOrNull(Object? value, Set<String> allowed) =>
      value == null || value is String && allowed.contains(value);

  static Object? _jsonSafe(Object? value) {
    if (value is num && !value.isFinite) {
      return value.toString();
    }
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is Map) {
      return value.map<String, Object?>(
        (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
      );
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    return value;
  }

  static Map<String, Object?> _jsonSafeRep(Map<String, dynamic> payload) {
    final result = Map<String, Object?>.from(
      _jsonSafe(payload) as Map<String, Object?>,
    );
    final observations = payload['techniqueObservations'];
    if (observations is List) {
      result['techniqueObservations'] = '<${observations.length} items>';
    }
    return result;
  }
}

class FirestoreRepWriteDiagnosticInput {
  const FirestoreRepWriteDiagnosticInput({
    required this.path,
    required this.repId,
    required this.payload,
  });

  final String path;
  final String repId;
  final Map<String, dynamic> payload;
}
