import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  test('RangeRepContracts.sitUp exposes the mandatory phases and signals', () {
    final contract = RangeRepContracts.sitUp;

    expect(
      contract.supportedPhases,
      containsAll(<RangeRepPhase>[
        RangeRepPhase.descending,
        RangeRepPhase.peak,
        RangeRepPhase.ascending,
      ]),
    );
    expect(
      contract.supportedSignals,
      containsAll(<RangeRepSignal>[
        RangeRepSignal.primaryMetric,
        RangeRepSignal.formMetric,
        RangeRepSignal.postureAngle,
        RangeRepSignal.depthMetric,
      ]),
    );
    expect(contract.supportsSignal(RangeRepSignal.alignmentMetric), isFalse);
    expect(contract.supportsSignal(RangeRepSignal.endRangeMetric), isFalse);
  });
}
