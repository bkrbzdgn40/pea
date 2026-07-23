import '../../../../app/localization/app_localizations.dart';
import '../../domain/models/hold_feedback_code.dart';

String mapHoldFeedbackCodeToMessage(
  HoldFeedbackCode code, {
  required AppLocalizations localizations,
}) {
  switch (code) {
    case HoldFeedbackCode.preparePosition:
      return localizations.pick(
        tr: 'Pozisyonu hazırla.',
        en: 'Prepare your position.',
      );
    case HoldFeedbackCode.holdPosition:
      return localizations.pick(
        tr: 'Pozisyonu koru.',
        en: 'Hold the position.',
      );
    case HoldFeedbackCode.bodyNotVisible:
      return localizations.pick(
        tr: 'Vücut net görünmüyor.',
        en: 'Body is not clearly visible.',
      );
    case HoldFeedbackCode.alignHips:
      return localizations.pick(tr: 'Kalçanı hizala.', en: 'Align your hips.');
    case HoldFeedbackCode.adjustElbowSupport:
      return localizations.pick(
        tr: 'Dirsek desteğini düzelt.',
        en: 'Adjust your elbow support.',
      );
    case HoldFeedbackCode.placeSupportElbowUnderShoulder:
      return localizations.pick(
        tr: 'Destek dirseğini omzunun altına yerleştir.',
        en: 'Place your supporting elbow under your shoulder.',
      );
    case HoldFeedbackCode.useForearmSupport:
      return localizations.pick(
        tr: 'Destek dirseğini bük ve ön kolunu yere koy.',
        en: 'Bend your supporting elbow and place your forearm on the floor.',
      );
    case HoldFeedbackCode.extendLegs:
      return localizations.pick(
        tr: 'Bacaklarını uzat.',
        en: 'Extend your legs.',
      );
    case HoldFeedbackCode.increaseHollowCompression:
      return localizations.pick(
        tr: 'Gövdeni biraz daha toparla.',
        en: 'Tighten your hollow position a little more.',
      );
    case HoldFeedbackCode.extendArmsOverhead:
      return localizations.pick(
        tr: 'Kollarını baş üstüne uzat.',
        en: 'Extend your arms overhead.',
      );
    case HoldFeedbackCode.straightenKnees:
      return localizations.pick(
        tr: 'Dizlerini düzleştir.',
        en: 'Straighten your knees.',
      );
    case HoldFeedbackCode.adjustWallSitDepth:
      return localizations.pick(
        tr: 'Duvar oturuşu derinliğini ayarla.',
        en: 'Adjust your wall sit depth.',
      );
    case HoldFeedbackCode.alignWallSitTorso:
      return localizations.pick(
        tr: 'Gövdeni duvara hizala.',
        en: 'Align your torso with the wall.',
      );
    case HoldFeedbackCode.correctForm:
      return localizations.pick(
        tr: 'Formunu düzelt.',
        en: 'Correct your form.',
      );
  }
}
