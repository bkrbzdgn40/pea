import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/range_rep_outcome_ui_mapper.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/range_rep_outcome_view_data.dart';

void main() {
  const tr = AppLocalizations(Locale('tr'));
  const en = AppLocalizations(Locale('en'));

  test('projects a valid rep without inventing an error reason', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 3,
      status: RangeRepValidationStatus.valid,
      reasons: const <RangeRepValidationReason>[],
      localizations: tr,
    );

    expect(result.repIndex, 3);
    expect(result.status, RangeRepValidationStatus.valid);
    expect(result.primaryReason, isNull);
    expect(result.tone, RangeRepOutcomeTone.positive);
    expect(result.techniqueOutcome, RangeRepTechniqueOutcome.accepted);
    expect(
      result.measurementConfidence,
      RangeRepMeasurementConfidence.reliable,
    );
    expect(result.title, 'Geçerli tekrar');
    expect(result.message, contains('Hareket aralığı'));
    expect(result.message, contains('temel form koşulları'));
    expect(result.message, isNot(contains('kontrol koşulları')));
  });

  test('prioritizes invalid range of motion over secondary speed reasons', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 4,
      status: RangeRepValidationStatus.invalid,
      reasons: const <RangeRepValidationReason>[
        RangeRepValidationReason.excessiveDescentSpeed,
        RangeRepValidationReason.insufficientRom,
      ],
      localizations: tr,
    );

    expect(result.primaryReason, RangeRepValidationReason.insufficientRom);
    expect(result.tone, RangeRepOutcomeTone.invalid);
    expect(result.techniqueOutcome, RangeRepTechniqueOutcome.rejected);
    expect(result.message, contains('Yeterli hareket aralığı'));
    expect(result.message, isNot(contains('hızlı')));
  });

  test('uses exercise-specific phase semantics without claiming certainty', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 2,
      status: RangeRepValidationStatus.lowConfidence,
      reasons: const <RangeRepValidationReason>[
        RangeRepValidationReason.excessiveAscentSpeed,
      ],
      localizations: en,
    );

    expect(result.primaryReason, RangeRepValidationReason.excessiveAscentSpeed);
    expect(result.tone, RangeRepOutcomeTone.caution);
    expect(result.techniqueOutcome, RangeRepTechniqueOutcome.accepted);
    expect(result.measurementConfidence, RangeRepMeasurementConfidence.limited);
    expect(result.title, 'Rep counted');
    expect(result.message, contains('could not be evaluated reliably'));
    expect(result.message, contains('was not included in the score'));
    expect(result.message, isNot(contains('faster')));
  });

  test('keeps a form caution separate from measurement confidence', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 6,
      status: RangeRepValidationStatus.lowConfidence,
      reasons: const <RangeRepValidationReason>[
        RangeRepValidationReason.persistentFormBreak,
      ],
      localizations: tr,
    );

    expect(result.title, 'Form uyarısı');
    expect(result.techniqueOutcome, RangeRepTechniqueOutcome.caution);
    expect(
      result.measurementConfidence,
      RangeRepMeasurementConfidence.reliable,
    );
    expect(result.message, contains('form uyarısı'));
    expect(result.message, isNot(contains('ölçüm güveni')));
  });

  test('explains total repetition speed without a hard-coded safety claim', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 5,
      status: RangeRepValidationStatus.lowConfidence,
      reasons: const <RangeRepValidationReason>[
        RangeRepValidationReason.excessiveRepSpeed,
      ],
      localizations: tr,
    );

    expect(result.primaryReason, RangeRepValidationReason.excessiveRepSpeed);
    expect(result.title, 'Tekrar sayıldı');
    expect(result.message, contains('güvenilir biçimde değerlendirilemedi'));
    expect(result.message, contains('skora dahil edilmedi'));
    expect(result.message, isNot(contains('hızlı')));
  });

  test('falls back without exposing enum names', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 1,
      status: RangeRepValidationStatus.invalid,
      reasons: const <RangeRepValidationReason>[],
      localizations: en,
    );

    expect(result.message, 'The rep did not meet the validation requirements.');
    expect(result.message, isNot(contains('invalidReason')));
  });
}
