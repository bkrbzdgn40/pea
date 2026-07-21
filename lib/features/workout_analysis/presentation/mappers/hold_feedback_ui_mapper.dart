import '../../domain/models/hold_feedback_code.dart';

String mapHoldFeedbackCodeToMessage(HoldFeedbackCode code) {
  switch (code) {
    case HoldFeedbackCode.preparePosition:
      return 'Pozisyonu Hazirla';
    case HoldFeedbackCode.holdPosition:
      return 'Pozisyonu Koru';
    case HoldFeedbackCode.bodyNotVisible:
      return 'Vucut net gorunmuyor.';
    case HoldFeedbackCode.alignHips:
      return 'Kalcayi Hizala';
    case HoldFeedbackCode.adjustElbowSupport:
      return 'Dirsek Destegini Duzelt';
    case HoldFeedbackCode.extendLegs:
      return 'Dizleri Kaldir';
    case HoldFeedbackCode.increaseHollowCompression:
      return 'Govdeyi Biraz Daha Toparla';
    case HoldFeedbackCode.extendArmsOverhead:
      return 'Kollari Bas Ustune Uzat';
    case HoldFeedbackCode.straightenKnees:
      return 'Dizleri Duzlestir';
    case HoldFeedbackCode.adjustWallSitDepth:
      return 'Duvar Oturusu Derinligini Ayarla';
    case HoldFeedbackCode.alignWallSitTorso:
      return 'Govdeyi Duvara Hizala';
    case HoldFeedbackCode.correctForm:
      return 'Formu Duzelt';
  }
}
