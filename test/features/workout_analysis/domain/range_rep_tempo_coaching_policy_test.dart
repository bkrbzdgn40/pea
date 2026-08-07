import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/rep_tempo_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/tempo_measurement_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_tempo_coaching_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/tempo_engine.dart';

void main() {
  const config = RangeRepTempoCoachingConfig(
    enabled: true,
    hardMinEccentricMillis: 300,
    softMinEccentricMillis: 600,
    softMaxEccentricMillis: 3000,
    hardMaxEccentricMillis: 5000,
    hardMinConcentricMillis: 250,
    softMinConcentricMillis: 500,
    softMaxConcentricMillis: 2500,
    hardMaxConcentricMillis: 4000,
    hardMinTotalMillis: 700,
    softMinTotalMillis: 1200,
    softMaxTotalMillis: 5000,
    hardMaxTotalMillis: 8000,
  );
  const policy = RangeRepTempoCoachingPolicy(config: config);

  test('classifies eligible timing inside all bands as target', () {
    final result = policy.evaluate(
      _measurement(eccentricMs: 1000, concentricMs: 900, totalMs: 2200),
    );

    expect(result.quality, RepTempoQuality.target);
    expect(result.severity, RepTempoSeverity.none);
    expect(result.shouldIncludeInScore, isTrue);
  });

  test('tolerance keeps near-boundary natural variation in target', () {
    const tolerantPolicy = RangeRepTempoCoachingPolicy(
      config: config,
      toleranceRatio: 0.25,
    );

    final fastSide = tolerantPolicy.evaluate(
      _measurement(eccentricMs: 500, concentricMs: 900, totalMs: 2200),
    );
    final slowSide = tolerantPolicy.evaluate(
      _measurement(eccentricMs: 3200, concentricMs: 900, totalMs: 4300),
    );

    expect(fastSide.quality, RepTempoQuality.target);
    expect(slowSide.quality, RepTempoQuality.target);
  });

  test('classifies hard short phase as strong too fast', () {
    final result = policy.evaluate(
      _measurement(eccentricMs: 200, concentricMs: 900, totalMs: 1500),
    );

    expect(result.quality, RepTempoQuality.tooFast);
    expect(result.severity, RepTempoSeverity.strong);
    expect(result.reasons, contains(RepTempoReason.eccentricTooFast));
  });

  test('classifies long total duration as too slow', () {
    final result = policy.evaluate(
      _measurement(eccentricMs: 4000, concentricMs: 3500, totalMs: 9000),
    );

    expect(result.quality, RepTempoQuality.tooSlow);
    expect(result.severity, RepTempoSeverity.strong);
    expect(result.reasons, contains(RepTempoReason.totalTooSlow));
  });

  test('keeps unavailable measurement unavailable', () {
    final result = policy.evaluate(
      TempoMeasurementAssessment(
        status: TempoMeasurementStatus.unavailable,
        issues: const <TempoMeasurementIssue>[
          TempoMeasurementIssue.visibilityInterrupted,
        ],
        measuredTempo: _tempo(
          eccentricMs: 1000,
          concentricMs: 900,
          totalMs: 2200,
        ),
        trace: null,
      ),
    );

    expect(result.quality, RepTempoQuality.unavailable);
    expect(result.reasons, <RepTempoReason>[
      RepTempoReason.measurementUnavailable,
    ]);
    expect(result.shouldIncludeInScore, isFalse);
  });

  test('keeps coaching-disabled exercise unavailable', () {
    const disabledPolicy = RangeRepTempoCoachingPolicy(
      config: RangeRepTempoCoachingConfig(),
    );

    final result = disabledPolicy.evaluate(
      _measurement(eccentricMs: 1000, concentricMs: 900, totalMs: 2200),
    );

    expect(result.quality, RepTempoQuality.unavailable);
    expect(result.reasons, <RepTempoReason>[RepTempoReason.coachingDisabled]);
    expect(result.coachingEnabled, isFalse);
  });
}

TempoMeasurementAssessment _measurement({
  required int eccentricMs,
  required int concentricMs,
  required int totalMs,
}) {
  return TempoMeasurementAssessment(
    status: TempoMeasurementStatus.eligible,
    issues: const <TempoMeasurementIssue>[],
    measuredTempo: _tempo(
      eccentricMs: eccentricMs,
      concentricMs: concentricMs,
      totalMs: totalMs,
    ),
    trace: null,
  );
}

TempoRepResult _tempo({
  required int eccentricMs,
  required int concentricMs,
  required int totalMs,
}) {
  return TempoRepResult(
    repIndex: 1,
    eccentricDuration: Duration(milliseconds: eccentricMs),
    bottomPauseDuration: Duration.zero,
    concentricDuration: Duration(milliseconds: concentricMs),
    topPauseDuration: Duration.zero,
    totalRepDuration: Duration(milliseconds: totalMs),
    towardPeakDuration: Duration(milliseconds: eccentricMs),
    returnDuration: Duration(milliseconds: concentricMs),
  );
}
