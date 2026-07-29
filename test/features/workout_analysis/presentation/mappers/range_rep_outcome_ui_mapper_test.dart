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
    expect(result.title, 'Geçerli tekrar');
    expect(result.message, contains('Hareket aralığı'));
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
    expect(result.message, contains('Yeterli hareket aralığı'));
    expect(result.message, isNot(contains('hızlı')));
  });

  test('uses the measured low-confidence reason in English', () {
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
    expect(
      result.message,
      'The rep was completed, but the ascent was too fast.',
    );
  });

  test('explains total repetition speed with the calibrated floor', () {
    final result = mapRangeRepOutcomeToViewData(
      repIndex: 5,
      status: RangeRepValidationStatus.lowConfidence,
      reasons: const <RangeRepValidationReason>[
        RangeRepValidationReason.excessiveRepSpeed,
      ],
      localizations: tr,
    );

    expect(result.primaryReason, RangeRepValidationReason.excessiveRepSpeed);
    expect(result.message, contains('1,5 saniyenin altındaydı'));
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
