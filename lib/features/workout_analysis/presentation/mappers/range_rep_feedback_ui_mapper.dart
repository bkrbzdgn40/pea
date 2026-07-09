import '../../domain/models/range_rep_feedback_code.dart';

String mapRangeRepFeedbackCodeToMessage(RangeRepFeedbackCode code) {
  switch (code) {
    case RangeRepFeedbackCode.ready:
      return 'Hazir!';
    case RangeRepFeedbackCode.waitForBody:
      return 'Vucut Bekleniyor...';
    case RangeRepFeedbackCode.descend:
      return 'Asagi in...';
    case RangeRepFeedbackCode.ascend:
      return 'Yukari...';
    case RangeRepFeedbackCode.repCompleted:
      return 'Basarili!';
    case RangeRepFeedbackCode.repIncomplete:
      return 'Hareketi tamamlamadin.';
    case RangeRepFeedbackCode.keepBodyUpright:
      return 'Sirtini Dik Tut!';
    case RangeRepFeedbackCode.controlDescent:
      return 'Inisi kontrollu yap.';
    case RangeRepFeedbackCode.controlAscent:
      return 'Yukselisi kontrollu yap.';
    case RangeRepFeedbackCode.stabilizeTransition:
      return 'Dipte gecisi sabitle.';
    case RangeRepFeedbackCode.maintainForm:
      return 'Formunu koru.';
  }
}
