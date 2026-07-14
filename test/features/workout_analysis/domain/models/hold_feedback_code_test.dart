import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';

void main() {
  test('stable codes and families stay explicit and unique', () {
    final scenarios =
        <
          ({
            HoldFeedbackCode code,
            String stableCode,
            HoldFeedbackFamily family,
          })
        >[
          (
            code: HoldFeedbackCode.preparePosition,
            stableCode: 'prepare_position',
            family: HoldFeedbackFamily.systemState,
          ),
          (
            code: HoldFeedbackCode.holdPosition,
            stableCode: 'hold_position',
            family: HoldFeedbackFamily.systemState,
          ),
          (
            code: HoldFeedbackCode.bodyNotVisible,
            stableCode: 'body_not_visible',
            family: HoldFeedbackFamily.systemState,
          ),
          (
            code: HoldFeedbackCode.alignHips,
            stableCode: 'align_hips',
            family: HoldFeedbackFamily.correctiveCue,
          ),
          (
            code: HoldFeedbackCode.adjustElbowSupport,
            stableCode: 'adjust_elbow_support',
            family: HoldFeedbackFamily.correctiveCue,
          ),
          (
            code: HoldFeedbackCode.extendLegs,
            stableCode: 'extend_legs',
            family: HoldFeedbackFamily.correctiveCue,
          ),
          (
            code: HoldFeedbackCode.correctForm,
            stableCode: 'correct_form',
            family: HoldFeedbackFamily.correctiveCue,
          ),
        ];

    final stableCodes = <String>{};
    for (final scenario in scenarios) {
      expect(scenario.code.code, scenario.stableCode);
      expect(scenario.code.family, scenario.family);
      expect(stableCodes.add(scenario.stableCode), isTrue);
    }

    expect(
      scenarios
          .where(
            (scenario) => scenario.family == HoldFeedbackFamily.systemState,
          )
          .map((scenario) => scenario.code),
      <HoldFeedbackCode>[
        HoldFeedbackCode.preparePosition,
        HoldFeedbackCode.holdPosition,
        HoldFeedbackCode.bodyNotVisible,
      ],
    );
    expect(
      scenarios
          .where(
            (scenario) => scenario.family == HoldFeedbackFamily.correctiveCue,
          )
          .map((scenario) => scenario.code),
      <HoldFeedbackCode>[
        HoldFeedbackCode.alignHips,
        HoldFeedbackCode.adjustElbowSupport,
        HoldFeedbackCode.extendLegs,
        HoldFeedbackCode.correctForm,
      ],
    );
  });
}
