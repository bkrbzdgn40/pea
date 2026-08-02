/// Machine-readable measurement-quality issues for one frame or repetition.
///
/// These issues describe whether the measurement can be trusted. They do not
/// describe technique quality, repetition validity, or tempo execution.
enum MeasurementConfidenceIssue {
  missingRequiredLandmark,
  lowLandmarkLikelihood,
  lowMeanLikelihood,
  missingRequiredSignal,
  nonFiniteGeometry,
  degenerateGeometry,
  temporalHistoryUnavailable,
  temporalDiscontinuity,
  coverageInterruption,
  sideSwitchDuringRep,
  legacyScalarOnly,
}

/// Stable serialization and diagnostics codes for measurement issues.
extension MeasurementConfidenceIssueX on MeasurementConfidenceIssue {
  String get code {
    switch (this) {
      case MeasurementConfidenceIssue.missingRequiredLandmark:
        return 'missing_required_landmark';
      case MeasurementConfidenceIssue.lowLandmarkLikelihood:
        return 'low_landmark_likelihood';
      case MeasurementConfidenceIssue.lowMeanLikelihood:
        return 'low_mean_likelihood';
      case MeasurementConfidenceIssue.missingRequiredSignal:
        return 'missing_required_signal';
      case MeasurementConfidenceIssue.nonFiniteGeometry:
        return 'non_finite_geometry';
      case MeasurementConfidenceIssue.degenerateGeometry:
        return 'degenerate_geometry';
      case MeasurementConfidenceIssue.temporalHistoryUnavailable:
        return 'temporal_history_unavailable';
      case MeasurementConfidenceIssue.temporalDiscontinuity:
        return 'temporal_discontinuity';
      case MeasurementConfidenceIssue.coverageInterruption:
        return 'coverage_interruption';
      case MeasurementConfidenceIssue.sideSwitchDuringRep:
        return 'side_switch_during_rep';
      case MeasurementConfidenceIssue.legacyScalarOnly:
        return 'legacy_scalar_only';
    }
  }

  static MeasurementConfidenceIssue fromCode(String code) {
    switch (code) {
      case 'missing_required_landmark':
        return MeasurementConfidenceIssue.missingRequiredLandmark;
      case 'low_landmark_likelihood':
        return MeasurementConfidenceIssue.lowLandmarkLikelihood;
      case 'low_mean_likelihood':
        return MeasurementConfidenceIssue.lowMeanLikelihood;
      case 'missing_required_signal':
        return MeasurementConfidenceIssue.missingRequiredSignal;
      case 'non_finite_geometry':
        return MeasurementConfidenceIssue.nonFiniteGeometry;
      case 'degenerate_geometry':
        return MeasurementConfidenceIssue.degenerateGeometry;
      case 'temporal_history_unavailable':
        return MeasurementConfidenceIssue.temporalHistoryUnavailable;
      case 'temporal_discontinuity':
        return MeasurementConfidenceIssue.temporalDiscontinuity;
      case 'coverage_interruption':
        return MeasurementConfidenceIssue.coverageInterruption;
      case 'side_switch_during_rep':
        return MeasurementConfidenceIssue.sideSwitchDuringRep;
      case 'legacy_scalar_only':
        return MeasurementConfidenceIssue.legacyScalarOnly;
    }

    throw FormatException('Unknown measurement confidence issue: $code');
  }
}

/// Immutable Measurement Confidence V2 result.
///
/// Every numeric component is normalized to the inclusive 0.0..1.0 range.
/// A null component means that dimension could not be measured. [combined]
/// must remain null when the policy cannot produce a trustworthy aggregate.
class MeasurementConfidenceBreakdown {
  MeasurementConfidenceBreakdown({
    required this.landmarkLikelihood,
    required this.signalAvailability,
    required this.geometryPlausibility,
    required this.temporalContinuity,
    required this.combined,
    required List<MeasurementConfidenceIssue> issues,
  }) : issues = List<MeasurementConfidenceIssue>.unmodifiable(
         <MeasurementConfidenceIssue>{...issues},
       ) {
    _validateComponent(landmarkLikelihood, 'landmarkLikelihood');
    _validateComponent(signalAvailability, 'signalAvailability');
    _validateComponent(geometryPlausibility, 'geometryPlausibility');
    _validateComponent(temporalContinuity, 'temporalContinuity');
    _validateComponent(combined, 'combined');
  }

  /// Compatibility bridge for callers that still provide one legacy scalar.
  ///
  /// The scalar is projected onto every component so downstream aggregation
  /// has one source of truth. The typed issue prevents it from being mistaken
  /// for a native Confidence V2 measurement.
  const MeasurementConfidenceBreakdown.legacyScalar(double value)
    : assert(value >= 0.0 && value <= 1.0),
      landmarkLikelihood = value,
      signalAvailability = value,
      geometryPlausibility = value,
      temporalContinuity = value,
      combined = value,
      issues = const <MeasurementConfidenceIssue>[
        MeasurementConfidenceIssue.legacyScalarOnly,
      ];

  final double? landmarkLikelihood;
  final double? signalAvailability;
  final double? geometryPlausibility;
  final double? temporalContinuity;
  final double? combined;
  final List<MeasurementConfidenceIssue> issues;

  bool get isKnown => combined != null;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'landmarkLikelihood': landmarkLikelihood,
      'signalAvailability': signalAvailability,
      'geometryPlausibility': geometryPlausibility,
      'temporalContinuity': temporalContinuity,
      'combined': combined,
      'issues': issues.map((issue) => issue.code).toList(growable: false),
    };
  }

  factory MeasurementConfidenceBreakdown.fromMap(Map<String, Object?> map) {
    final rawIssues = map['issues'];
    if (rawIssues is! Iterable) {
      throw const FormatException(
        'Expected measurement confidence issues to be a list.',
      );
    }

    final issues = rawIssues
        .map((value) {
          if (value is! String) {
            throw const FormatException(
              'Expected measurement confidence issue codes to be strings.',
            );
          }
          return MeasurementConfidenceIssueX.fromCode(value);
        })
        .toList(growable: false);

    return MeasurementConfidenceBreakdown(
      landmarkLikelihood: _readNullableUnitInterval(map, 'landmarkLikelihood'),
      signalAvailability: _readNullableUnitInterval(map, 'signalAvailability'),
      geometryPlausibility: _readNullableUnitInterval(
        map,
        'geometryPlausibility',
      ),
      temporalContinuity: _readNullableUnitInterval(map, 'temporalContinuity'),
      combined: _readNullableUnitInterval(map, 'combined'),
      issues: issues,
    );
  }

  static double? _readNullableUnitInterval(
    Map<String, Object?> map,
    String key,
  ) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException('Expected nullable number for "$key".');
  }

  static void _validateComponent(double? value, String name) {
    if (value == null) {
      return;
    }
    if (!value.isFinite || value < 0.0 || value > 1.0) {
      throw ArgumentError.value(
        value,
        name,
        'must be finite and between 0.0 and 1.0 inclusive',
      );
    }
  }
}
