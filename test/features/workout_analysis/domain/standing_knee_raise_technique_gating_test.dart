import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  final contract = RangeRepContracts.standingKneeRaise;

  test('does not request more knee bend while standing in neutral', () {
    expect(
      contract.techniqueEvaluationPolicy,
      RangeRepTechniqueEvaluationPolicy.activeMovementOnly,
    );
    expect(
      contract.shouldEvaluateTechnique(
        primaryMetric: 170,
        activeThreshold: 145,
        peakThreshold: 95,
      ),
      isFalse,
    );
  });

  test('evaluates knee bend after the raise enters the active range', () {
    expect(
      contract.shouldEvaluateTechnique(
        primaryMetric: 140,
        activeThreshold: 145,
        peakThreshold: 95,
      ),
      isTrue,
    );
  });
}
