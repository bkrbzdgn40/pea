import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_rep_summary.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  final definition = catalog.definitionFor(ExerciseType.standingHipExtension);

  test('uses total repetition duration instead of narrow phase timing', () {
    final config = loadExerciseConfig(definition.analysisConfigAssetPath);
    final validation = definition.analysisRangeRepValidationConfig;

    expect(validation.minDescentMillis, 0);
    expect(validation.minAscentMillis, 0);
    expect(validation.minTotalRepMillis, 1501);
    expect(config.rangeRepPhaseQuality?.minDescendingMillis, 0);
    expect(config.rangeRepPhaseQuality?.minAscendingMillis, 0);
  });

  test('flags 1.5 seconds and accepts the first millisecond above it', () {
    final policy = RangeRepValidationPolicy(
      config: definition.analysisRangeRepValidationConfig,
    );

    final boundary = policy.evaluate(
      _summary(totalRepDuration: const Duration(milliseconds: 1500)),
    );
    final controlled = policy.evaluate(
      _summary(totalRepDuration: const Duration(milliseconds: 1501)),
    );

    expect(boundary.status, RangeRepValidationStatus.lowConfidence);
    expect(boundary.reasons, [RangeRepValidationReason.excessiveRepSpeed]);
    expect(controlled.status, RangeRepValidationStatus.valid);
    expect(controlled.reasons, isEmpty);
  });

  test('does not emit legacy phase-speed reasons', () {
    final policy = RangeRepValidationPolicy(
      config: definition.analysisRangeRepValidationConfig,
    );

    final result = policy.evaluate(
      _summary(
        totalRepDuration: const Duration(milliseconds: 1600),
        descentDuration: const Duration(milliseconds: 1),
        ascentDuration: const Duration(milliseconds: 1),
      ),
    );

    expect(result.status, RangeRepValidationStatus.valid);
    expect(
      result.reasons,
      isNot(contains(RangeRepValidationReason.excessiveDescentSpeed)),
    );
    expect(
      result.reasons,
      isNot(contains(RangeRepValidationReason.excessiveAscentSpeed)),
    );
  });
}

RangeRepRepSummary _summary({
  required Duration totalRepDuration,
  Duration descentDuration = const Duration(milliseconds: 100),
  Duration ascentDuration = const Duration(milliseconds: 100),
}) {
  return RangeRepRepSummary(
    repIndex: 1,
    minAngle: 160,
    worstFormMetric: 180,
    descentDuration: descentDuration,
    ascentDuration: ascentDuration,
    totalRepDuration: totalRepDuration,
    hadFormViolation: false,
    hadCoverageDrop: false,
    switchedSideDuringRep: false,
    completedPhaseSequence: true,
    primaryRom: 16,
  );
}
