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
      expect(result.countsTowardReps, isTrue);
      expect(result.shouldPublishScore, isTrue);
    });

    test(
      'returns low confidence on coverage loss when configured to allow it',
      () {
        final result = policy.evaluate(_summary(hadCoverageDrop: true));

        expect(result.status, RangeRepValidationStatus.lowConfidence);
        expect(result.reasons, [RangeRepValidationReason.coverageLoss]);
        expect(result.countsTowardReps, isTrue);
        expect(result.shouldPublishScore, isTrue);
      },
    );

    test('keeps a persistent form break low confidence by default', () {
      final result = policy.evaluate(_summary(hadFormViolation: true));

      expect(result.status, RangeRepValidationStatus.lowConfidence);
      expect(result.reasons, [RangeRepValidationReason.persistentFormBreak]);
      expect(result.countsTowardReps, isTrue);
      expect(result.shouldPublishScore, isTrue);
    });

    test('can invalidate a persistent form break for one exercise', () {
      const strictPolicy = RangeRepValidationPolicy(
        config: RangeRepValidationConfig(invalidateOnPersistentFormBreak: true),
      );

      final result = strictPolicy.evaluate(_summary(hadFormViolation: true));

      expect(result.status, RangeRepValidationStatus.invalid);
      expect(result.reasons, [RangeRepValidationReason.persistentFormBreak]);
      expect(result.countsTowardReps, isFalse);
      expect(result.shouldPublishScore, isFalse);
    });

    test('accepts a total repetition lasting exactly 1.5 seconds', () {
      const totalTempoPolicy = RangeRepValidationPolicy(
        config: RangeRepValidationConfig(
          minDescentMillis: 0,
          minAscentMillis: 0,
          minTotalRepMillis: 1500,
        ),
      );

      final result = totalTempoPolicy.evaluate(
        _summary(totalRepDuration: const Duration(milliseconds: 1500)),
      );

      expect(result.status, RangeRepValidationStatus.valid);
      expect(result.reasons, isEmpty);
    });

    test('flags a total repetition below 1.5 seconds', () {
      const totalTempoPolicy = RangeRepValidationPolicy(
        config: RangeRepValidationConfig(
          minDescentMillis: 0,
          minAscentMillis: 0,
          minTotalRepMillis: 1500,
        ),
      );

      final result = totalTempoPolicy.evaluate(
        _summary(totalRepDuration: const Duration(milliseconds: 1499)),
      );

      expect(result.status, RangeRepValidationStatus.lowConfidence);
      expect(result.reasons, [RangeRepValidationReason.excessiveRepSpeed]);
      expect(result.countsTowardReps, isTrue);
    });

    test('returns invalid when the phase sequence is incomplete', () {
      final result = policy.evaluate(_summary(completedPhaseSequence: false));

      expect(result.status, RangeRepValidationStatus.invalid);
      expect(
        result.reasons,
        contains(RangeRepValidationReason.incompletePhase),
      );
      expect(result.countsTowardReps, isFalse);
      expect(result.shouldPublishScore, isFalse);
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

    test('quarantines tempo from every range-rep main score', () {
      expect(
        RangeRepValidationResult.valid().shouldIncludeTempoInMainScore,
        isFalse,
      );
      expect(
        RangeRepValidationResult.lowConfidence(const <RangeRepValidationReason>[
          RangeRepValidationReason.persistentFormBreak,
        ]).shouldIncludeTempoInMainScore,
        isFalse,
      );
    });
  });
}

RangeRepRepSummary _summary({
  int repIndex = 1,
  double minAngle = 80,
  double worstFormMetric = 60,
  Duration descentDuration = const Duration(milliseconds: 400),
  Duration ascentDuration = const Duration(milliseconds: 300),
  Duration? totalRepDuration,
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
    totalRepDuration: totalRepDuration,
    hadFormViolation: hadFormViolation,
    hadCoverageDrop: hadCoverageDrop,
    switchedSideDuringRep: switchedSideDuringRep,
    completedPhaseSequence: completedPhaseSequence,
    selectedSideLabel: 'left',
    analysisKindLabel: 'rangeRep',
  );
}
