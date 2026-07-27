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

  test('uses a narrow-band standing hip extension tempo tolerance', () {
    final config = loadExerciseConfig(definition.analysisConfigAssetPath);

    expect(definition.analysisRangeRepValidationConfig.minDescentMillis, 150);
    expect(config.rangeRepPhaseQuality?.minDescendingMillis, 150);
  });

  test('accepts 160 ms toward-peak timing but flags 120 ms', () {
    final policy = RangeRepValidationPolicy(
      config: definition.analysisRangeRepValidationConfig,
    );

    final controlled = policy.evaluate(
      _summary(descentDuration: const Duration(milliseconds: 160)),
    );
    final explosive = policy.evaluate(
      _summary(descentDuration: const Duration(milliseconds: 120)),
    );

    expect(
      controlled.reasons,
      isNot(contains(RangeRepValidationReason.excessiveDescentSpeed)),
    );
    expect(
      explosive.reasons,
      contains(RangeRepValidationReason.excessiveDescentSpeed),
    );
  });
}

RangeRepRepSummary _summary({required Duration descentDuration}) {
  return RangeRepRepSummary(
    repIndex: 1,
    minAngle: 160,
    worstFormMetric: 180,
    descentDuration: descentDuration,
    ascentDuration: const Duration(milliseconds: 400),
    hadFormViolation: false,
    hadCoverageDrop: false,
    switchedSideDuringRep: false,
    completedPhaseSequence: true,
    primaryRom: 16,
  );
}
