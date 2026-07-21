import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/hold_feedback_ui_mapper.dart';

void main() {
  const tr = AppLocalizations(Locale('tr'));
  const en = AppLocalizations(Locale('en'));

  test('maps every hold feedback code to Turkish UI copy', () {
    final scenarios = <({HoldFeedbackCode code, String message})>[
      (code: HoldFeedbackCode.preparePosition, message: 'Pozisyonu hazırla.'),
      (code: HoldFeedbackCode.holdPosition, message: 'Pozisyonu koru.'),
      (code: HoldFeedbackCode.bodyNotVisible, message: 'Vücut net görünmüyor.'),
      (code: HoldFeedbackCode.alignHips, message: 'Kalçanı hizala.'),
      (
        code: HoldFeedbackCode.adjustElbowSupport,
        message: 'Dirsek desteğini düzelt.',
      ),
      (code: HoldFeedbackCode.extendLegs, message: 'Bacaklarını uzat.'),
      (
        code: HoldFeedbackCode.increaseHollowCompression,
        message: 'Gövdeni biraz daha toparla.',
      ),
      (
        code: HoldFeedbackCode.extendArmsOverhead,
        message: 'Kollarını baş üstüne uzat.',
      ),
      (code: HoldFeedbackCode.straightenKnees, message: 'Dizlerini düzleştir.'),
      (
        code: HoldFeedbackCode.adjustWallSitDepth,
        message: 'Duvar oturuşu derinliğini ayarla.',
      ),
      (
        code: HoldFeedbackCode.alignWallSitTorso,
        message: 'Gövdeni duvara hizala.',
      ),
      (code: HoldFeedbackCode.correctForm, message: 'Formunu düzelt.'),
    ];

    for (final scenario in scenarios) {
      expect(
        mapHoldFeedbackCodeToMessage(scenario.code, localizations: tr),
        scenario.message,
      );
    }
  });

  test('maps hold feedback to English UI copy', () {
    expect(
      mapHoldFeedbackCodeToMessage(
        HoldFeedbackCode.holdPosition,
        localizations: en,
      ),
      'Hold the position.',
    );
    expect(
      mapHoldFeedbackCodeToMessage(
        HoldFeedbackCode.extendLegs,
        localizations: en,
      ),
      'Extend your legs.',
    );
  });
}
