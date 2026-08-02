import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/rep_tempo_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/tempo_measurement_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/tempo_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/range_rep_outcome_ui_mapper.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/range_rep_outcome_view_data.dart';

void main() {
  const tr = AppLocalizations(Locale('tr'));
  const en = AppLocalizations(Locale('en'));

  test('projects a valid rep without tempo coaching', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 3,
      status: RangeRepValidationStatus.valid,
      reasons: const <RangeRepValidationReason>[],
      localizations: tr,
      measurementConfidence: _confidence(0.95),
    );

    expect(result.tone, RangeRepOutcomeTone.positive);
    expect(result.message, contains('Hareket aralığı'));
    expect(result.tempoQuality, isNull);
  });

  test('shows target tempo for eligible coached rep', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 4,
      status: RangeRepValidationStatus.valid,
      reasons: const <RangeRepValidationReason>[],
      localizations: tr,
      tempoAssessment: _assessment(RepTempoQuality.target),
      measurementConfidence: _confidence(0.94),
    );

    expect(result.tone, RangeRepOutcomeTone.positive);
    expect(result.tempoQuality, RepTempoQuality.target);
    expect(result.message, contains('Tempo hedef aralıkta'));
  });

  test('shows reliable fast coaching without lowering rep confidence', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 5,
      status: RangeRepValidationStatus.valid,
      reasons: const <RangeRepValidationReason>[],
      localizations: tr,
      exerciseType: ExerciseType.bicepsCurl,
      towardPeakIsEccentric: false,
      tempoAssessment: _assessment(RepTempoQuality.tooFast),
      measurementConfidence: _confidence(0.92),
    );

    expect(result.tone, RangeRepOutcomeTone.caution);
    expect(result.status, RangeRepValidationStatus.valid);
    expect(
      result.measurementConfidence,
      RangeRepMeasurementConfidence.reliable,
    );
    expect(result.message, contains('Kolu indirme'));
    expect(result.message, contains('daha hızlıydı'));
  });

  test('keeps unavailable tempo visual-only and separate from validity', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 6,
      status: RangeRepValidationStatus.valid,
      reasons: const <RangeRepValidationReason>[],
      localizations: en,
      tempoAssessment: _assessment(RepTempoQuality.unavailable),
      measurementConfidence: _confidence(0.91),
    );

    expect(result.status, RangeRepValidationStatus.valid);
    expect(result.tempoQuality, RepTempoQuality.unavailable);
    expect(
      result.measurementConfidence,
      RangeRepMeasurementConfidence.reliable,
    );
    expect(result.message, contains('could not be evaluated'));
    expect(result.message, contains('not included in the score'));
  });

  test('prioritizes invalid range of motion over tempo coaching', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 7,
      status: RangeRepValidationStatus.invalid,
      reasons: const <RangeRepValidationReason>[
        RangeRepValidationReason.insufficientRom,
      ],
      localizations: tr,
      tempoAssessment: _assessment(RepTempoQuality.tooFast),
      measurementConfidence: _confidence(0.72),
    );

    expect(result.primaryReason, RangeRepValidationReason.insufficientRom);
    expect(result.tone, RangeRepOutcomeTone.invalid);
    expect(result.measurementConfidence, RangeRepMeasurementConfidence.limited);
    expect(result.message, contains('Yeterli hareket aralığı'));
    expect(result.message, isNot(contains('hızlı')));
  });

  test('keeps a form caution separate from measurement confidence', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 8,
      status: RangeRepValidationStatus.lowConfidence,
      reasons: const <RangeRepValidationReason>[
        RangeRepValidationReason.persistentFormBreak,
      ],
      localizations: tr,
      tempoAssessment: _assessment(RepTempoQuality.tooSlow),
      measurementConfidence: _confidence(0.93),
    );

    expect(result.title, 'Form uyarısı');
    expect(result.techniqueOutcome, RangeRepTechniqueOutcome.caution);
    expect(
      result.measurementConfidence,
      RangeRepMeasurementConfidence.reliable,
    );
    expect(result.message, contains('form uyarısı'));
  });

  test('treats the 0.80 confidence boundary as reliable', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 9,
      status: RangeRepValidationStatus.valid,
      reasons: const <RangeRepValidationReason>[],
      localizations: tr,
      measurementConfidence: _confidence(0.80),
    );

    expect(
      result.measurementConfidence,
      RangeRepMeasurementConfidence.reliable,
    );
  });

  test('keeps missing measurement confidence explicitly unknown', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 9,
      status: RangeRepValidationStatus.valid,
      reasons: const <RangeRepValidationReason>[],
      localizations: tr,
    );

    expect(result.measurementConfidence, RangeRepMeasurementConfidence.unknown);
    expect(result.measurementConfidenceScore, isNull);
  });
}

RepTempoAssessment _assessment(RepTempoQuality quality) {
  final measurement = TempoMeasurementAssessment(
    status: quality == RepTempoQuality.unavailable
        ? TempoMeasurementStatus.unavailable
        : TempoMeasurementStatus.eligible,
    issues: quality == RepTempoQuality.unavailable
        ? const <TempoMeasurementIssue>[
            TempoMeasurementIssue.visibilityInterrupted,
          ]
        : const <TempoMeasurementIssue>[],
    measuredTempo: const TempoRepResult(
      repIndex: 1,
      eccentricDuration: Duration(milliseconds: 700),
      bottomPauseDuration: Duration.zero,
      concentricDuration: Duration(milliseconds: 600),
      topPauseDuration: Duration.zero,
      totalRepDuration: Duration(milliseconds: 1300),
      towardPeakDuration: Duration(milliseconds: 600),
      returnDuration: Duration(milliseconds: 700),
    ),
    trace: null,
  );
  return RepTempoAssessment(
    quality: quality,
    severity:
        quality == RepTempoQuality.tooFast || quality == RepTempoQuality.tooSlow
        ? RepTempoSeverity.mild
        : RepTempoSeverity.none,
    reasons: switch (quality) {
      RepTempoQuality.tooFast => const <RepTempoReason>[
        RepTempoReason.eccentricTooFast,
      ],
      RepTempoQuality.tooSlow => const <RepTempoReason>[
        RepTempoReason.totalTooSlow,
      ],
      RepTempoQuality.unavailable => const <RepTempoReason>[
        RepTempoReason.measurementUnavailable,
      ],
      RepTempoQuality.target => const <RepTempoReason>[],
    },
    measurement: measurement,
    coachingEnabled: true,
  );
}

MeasurementConfidenceBreakdown _confidence(double combined) {
  return MeasurementConfidenceBreakdown(
    landmarkLikelihood: combined,
    signalAvailability: combined,
    geometryPlausibility: combined,
    temporalContinuity: combined,
    combined: combined,
    issues: const <MeasurementConfidenceIssue>[],
  );
}
