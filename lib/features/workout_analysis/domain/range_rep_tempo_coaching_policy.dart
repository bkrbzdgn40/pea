import 'models/rep_tempo_assessment.dart';
import 'models/tempo_measurement_assessment.dart';

/// Exercise-specific boundaries used only after timing integrity is proven.
class RangeRepTempoCoachingConfig {
  const RangeRepTempoCoachingConfig({
    this.enabled = false,
    this.hardMinEccentricMillis,
    this.softMinEccentricMillis,
    this.softMaxEccentricMillis,
    this.hardMaxEccentricMillis,
    this.hardMinConcentricMillis,
    this.softMinConcentricMillis,
    this.softMaxConcentricMillis,
    this.hardMaxConcentricMillis,
    this.hardMinTotalMillis,
    this.softMinTotalMillis,
    this.softMaxTotalMillis,
    this.hardMaxTotalMillis,
  }) : assert(
         hardMinEccentricMillis == null ||
             softMinEccentricMillis == null ||
             hardMinEccentricMillis <= softMinEccentricMillis,
       ),
       assert(
         softMaxEccentricMillis == null ||
             hardMaxEccentricMillis == null ||
             softMaxEccentricMillis <= hardMaxEccentricMillis,
       ),
       assert(
         hardMinConcentricMillis == null ||
             softMinConcentricMillis == null ||
             hardMinConcentricMillis <= softMinConcentricMillis,
       ),
       assert(
         softMaxConcentricMillis == null ||
             hardMaxConcentricMillis == null ||
             softMaxConcentricMillis <= hardMaxConcentricMillis,
       ),
       assert(
         hardMinTotalMillis == null ||
             softMinTotalMillis == null ||
             hardMinTotalMillis <= softMinTotalMillis,
       ),
       assert(
         softMaxTotalMillis == null ||
             hardMaxTotalMillis == null ||
             softMaxTotalMillis <= hardMaxTotalMillis,
       );

  final bool enabled;
  final int? hardMinEccentricMillis;
  final int? softMinEccentricMillis;
  final int? softMaxEccentricMillis;
  final int? hardMaxEccentricMillis;
  final int? hardMinConcentricMillis;
  final int? softMinConcentricMillis;
  final int? softMaxConcentricMillis;
  final int? hardMaxConcentricMillis;
  final int? hardMinTotalMillis;
  final int? softMinTotalMillis;
  final int? softMaxTotalMillis;
  final int? hardMaxTotalMillis;
}

/// Converts an eligible measurement into target, fast, or slow coaching.
class RangeRepTempoCoachingPolicy {
  const RangeRepTempoCoachingPolicy({required this.config});

  final RangeRepTempoCoachingConfig config;

  RepTempoAssessment evaluate(TempoMeasurementAssessment measurement) {
    if (!config.enabled) {
      return RepTempoAssessment.unavailable(
        measurement: measurement,
        reason: RepTempoReason.coachingDisabled,
        coachingEnabled: false,
      );
    }
    final tempo = measurement.measuredTempo;
    if (!measurement.isEligible || tempo == null) {
      return RepTempoAssessment.unavailable(
        measurement: measurement,
        reason: RepTempoReason.measurementUnavailable,
        coachingEnabled: true,
      );
    }

    final findings = <_TempoFinding>[
      ..._classify(
        observedMillis: tempo.eccentricDuration.inMilliseconds,
        hardMinMillis: config.hardMinEccentricMillis,
        softMinMillis: config.softMinEccentricMillis,
        softMaxMillis: config.softMaxEccentricMillis,
        hardMaxMillis: config.hardMaxEccentricMillis,
        tooFastReason: RepTempoReason.eccentricTooFast,
        tooSlowReason: RepTempoReason.eccentricTooSlow,
      ),
      ..._classify(
        observedMillis: tempo.concentricDuration.inMilliseconds,
        hardMinMillis: config.hardMinConcentricMillis,
        softMinMillis: config.softMinConcentricMillis,
        softMaxMillis: config.softMaxConcentricMillis,
        hardMaxMillis: config.hardMaxConcentricMillis,
        tooFastReason: RepTempoReason.concentricTooFast,
        tooSlowReason: RepTempoReason.concentricTooSlow,
      ),
      ..._classify(
        observedMillis: tempo.totalRepDuration.inMilliseconds,
        hardMinMillis: config.hardMinTotalMillis,
        softMinMillis: config.softMinTotalMillis,
        softMaxMillis: config.softMaxTotalMillis,
        hardMaxMillis: config.hardMaxTotalMillis,
        tooFastReason: RepTempoReason.totalTooFast,
        tooSlowReason: RepTempoReason.totalTooSlow,
      ),
    ];

    if (findings.isEmpty) {
      return RepTempoAssessment(
        quality: RepTempoQuality.target,
        severity: RepTempoSeverity.none,
        reasons: const <RepTempoReason>[],
        measurement: measurement,
        coachingEnabled: true,
      );
    }

    findings.sort(_compareFindings);
    final primary = findings.first;
    return RepTempoAssessment(
      quality: primary.quality,
      severity: primary.severity,
      reasons: findings.map((finding) => finding.reason).toSet().toList(),
      measurement: measurement,
      coachingEnabled: true,
    );
  }

  List<_TempoFinding> _classify({
    required int observedMillis,
    required int? hardMinMillis,
    required int? softMinMillis,
    required int? softMaxMillis,
    required int? hardMaxMillis,
    required RepTempoReason tooFastReason,
    required RepTempoReason tooSlowReason,
  }) {
    if (hardMinMillis != null && observedMillis < hardMinMillis) {
      return <_TempoFinding>[
        _TempoFinding(
          quality: RepTempoQuality.tooFast,
          severity: RepTempoSeverity.strong,
          reason: tooFastReason,
          relativeDeviation: _relativeShortfall(observedMillis, hardMinMillis),
        ),
      ];
    }
    if (softMinMillis != null && observedMillis < softMinMillis) {
      return <_TempoFinding>[
        _TempoFinding(
          quality: RepTempoQuality.tooFast,
          severity: RepTempoSeverity.mild,
          reason: tooFastReason,
          relativeDeviation: _relativeShortfall(observedMillis, softMinMillis),
        ),
      ];
    }
    if (hardMaxMillis != null && observedMillis > hardMaxMillis) {
      return <_TempoFinding>[
        _TempoFinding(
          quality: RepTempoQuality.tooSlow,
          severity: RepTempoSeverity.strong,
          reason: tooSlowReason,
          relativeDeviation: _relativeExcess(observedMillis, hardMaxMillis),
        ),
      ];
    }
    if (softMaxMillis != null && observedMillis > softMaxMillis) {
      return <_TempoFinding>[
        _TempoFinding(
          quality: RepTempoQuality.tooSlow,
          severity: RepTempoSeverity.mild,
          reason: tooSlowReason,
          relativeDeviation: _relativeExcess(observedMillis, softMaxMillis),
        ),
      ];
    }
    return const <_TempoFinding>[];
  }

  static int _compareFindings(_TempoFinding a, _TempoFinding b) {
    final severityComparison = b.severity.index.compareTo(a.severity.index);
    if (severityComparison != 0) {
      return severityComparison;
    }
    return b.relativeDeviation.compareTo(a.relativeDeviation);
  }

  static double _relativeShortfall(int observed, int boundary) {
    if (boundary <= 0) return 0;
    return (boundary - observed) / boundary;
  }

  static double _relativeExcess(int observed, int boundary) {
    if (boundary <= 0) return 0;
    return (observed - boundary) / boundary;
  }
}

class _TempoFinding {
  const _TempoFinding({
    required this.quality,
    required this.severity,
    required this.reason,
    required this.relativeDeviation,
  });

  final RepTempoQuality quality;
  final RepTempoSeverity severity;
  final RepTempoReason reason;
  final double relativeDeviation;
}
