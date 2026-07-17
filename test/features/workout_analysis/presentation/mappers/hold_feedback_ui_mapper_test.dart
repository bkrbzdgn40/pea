import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/hold_feedback_ui_mapper.dart';

void main() {
  test('maps every hold feedback code to the existing Turkish UI message', () {
    final scenarios = <({HoldFeedbackCode code, String message})>[
      (code: HoldFeedbackCode.preparePosition, message: 'Pozisyonu Hazirla'),
      (code: HoldFeedbackCode.holdPosition, message: 'Pozisyonu Koru'),
      (code: HoldFeedbackCode.bodyNotVisible, message: 'Vucut net gorunmuyor.'),
      (code: HoldFeedbackCode.alignHips, message: 'Kalcayi Hizala'),
      (
        code: HoldFeedbackCode.adjustElbowSupport,
        message: 'Dirsek Destegini Duzelt',
      ),
      (code: HoldFeedbackCode.extendLegs, message: 'Dizleri Kaldir'),
      (
        code: HoldFeedbackCode.increaseHollowCompression,
        message: 'Govdeyi Biraz Daha Toparla',
      ),
      (
        code: HoldFeedbackCode.extendArmsOverhead,
        message: 'Kollari Bas Ustune Uzat',
      ),
      (code: HoldFeedbackCode.straightenKnees, message: 'Dizleri Duzlestir'),
      (code: HoldFeedbackCode.correctForm, message: 'Formu Duzelt'),
    ];

    for (final scenario in scenarios) {
      expect(mapHoldFeedbackCodeToMessage(scenario.code), scenario.message);
    }
  });
}
