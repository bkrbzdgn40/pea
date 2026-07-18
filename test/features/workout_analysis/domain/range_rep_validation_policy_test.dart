import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_rep_summary.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

void main() {
  group('RangeRepValidationPolicy', () {
    const policy = RangeRepValidationPolicy(config: RangeRepValidationConfig());

    test('returns valid for a clean completed rep', () {
      final result = policy.evaluate(_summary());

      expect(result.status, RangeRepValidationStatus.valid);
      expect(result.reasons, isEmpty);
    });

    test(
      'returns low confidence on coverage loss when configured to allow it',
      () {
        final result = policy.evaluate(_summary(hadCoverageDrop: true));

        expect(result.status, RangeRepValidationStatus.lowConfidence);
        expect(result.reasons, [RangeRepValidationReason.coverageLoss]);
      },
    );

    test('returns invalid when the phase sequence is incomplete', () {
      final result = policy.evaluate(_summary(completedPhaseSequence: false));

      expect(result.status, RangeRepValidationStatus.invalid);
      expect(
        result.reasons,
        contains(RangeRepValidationReason.incompletePhase),
      );
    });

    test('returns invalid when ROM stays above the acceptable threshold', () {
      final result = policy.evaluate(_summary(minAngle: 130));

      expect(result.status, RangeRepValidationStatus.invalid);
      expect(
        result.reasons,
        contains(RangeRepValidationReason.insufficientRom),
      );
    });

    test(
      'keeps invalid status when low-confidence reasons are also present',
      () {
        final result = policy.evaluate(
          _summary(
            completedPhaseSequence: false,
            minAngle: 125,
            hadCoverageDrop: true,
            hadFormViolation: true,
          ),
        );

        expect(result.status, RangeRepValidationStatus.invalid);
        expect(
          result.reasons,
          contains(RangeRepValidationReason.incompletePhase),
        );
        expect(
          result.reasons,
          contains(RangeRepValidationReason.insufficientRom),
        );
        expect(result.reasons, contains(RangeRepValidationReason.coverageLoss));
        expect(
          result.reasons,
          contains(RangeRepValidationReason.persistentFormBreak),
        );
      },
    );
  });
}

RangeRepRepSummary _summary({
  int repIndex = 1,
  double minAngle = 80,
  double worstFormMetric = 60,
  Duration descentDuration = const Duration(milliseconds: 400),
  Duration ascentDuration = const Duration(milliseconds: 300),
  bool hadFormViolation = false,
  bool hadCoverageDrop = false,
  bool switchedSideDuringRep = false,
  bool completedPhaseSequence = true,
}) {
  return RangeRepRepSummary(
    repIndex: repIndex,
    minAngle: minAngle,
    worstFormMetric: worstFormMetric,
    descentDuration: descentDuration,
    ascentDuration: ascentDuration,
    hadFormViolation: hadFormViolation,
    hadCoverageDrop: hadCoverageDrop,
    switchedSideDuringRep: switchedSideDuringRep,
    completedPhaseSequence: completedPhaseSequence,
    selectedSideLabel: 'left',
    analysisKindLabel: 'rangeRep',
  );
}
