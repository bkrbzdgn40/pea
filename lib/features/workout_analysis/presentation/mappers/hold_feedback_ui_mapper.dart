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
    case HoldFeedbackCode.correctForm:
      return 'Formu Duzelt';
  }
}
