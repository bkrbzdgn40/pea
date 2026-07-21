import '../../domain/models/exercise_type.dart';
import '../../domain/models/range_rep_feedback_code.dart';

String mapRangeRepFeedbackCodeToMessage(
  RangeRepFeedbackCode code, {
  ExerciseType? exerciseType,
}) {
  final copy = _rangeRepFeedbackCopyFor(exerciseType);

  switch (code) {
    case RangeRepFeedbackCode.awaitNeutral:
      return 'Baslangic pozisyonuna gec.';
    case RangeRepFeedbackCode.ready:
      return 'Hazir!';
    case RangeRepFeedbackCode.waitForBody:
      return 'Vucut Bekleniyor...';
    case RangeRepFeedbackCode.bodyNotVisible:
      return 'Vucut net gorunmuyor.';
    case RangeRepFeedbackCode.descend:
      return copy.descend;
    case RangeRepFeedbackCode.ascend:
      return copy.ascend;
    case RangeRepFeedbackCode.repCompleted:
      return 'Basarili!';
    case RangeRepFeedbackCode.repIncomplete:
      return 'Hareketi tamamlamadin.';
    case RangeRepFeedbackCode.legacyFormThresholdViolation:
      if (exerciseType == ExerciseType.squat) {
        return 'Formunu koru.';
      }
      return copy.formViolation;
    case RangeRepFeedbackCode.controlDescent:
      return copy.controlDescent;
    case RangeRepFeedbackCode.controlAscent:
      return copy.controlAscent;
    case RangeRepFeedbackCode.stabilizeTransition:
      return copy.stabilizeTransition;
    case RangeRepFeedbackCode.maintainForm:
      return copy.maintainForm;
  }
}

_RangeRepFeedbackCopy _rangeRepFeedbackCopyFor(ExerciseType? exerciseType) {
  if (exerciseType == ExerciseType.lyingLegRaise) {
    return const _RangeRepFeedbackCopy(
      descend: 'Bacaklarini kontrollu kaldir...',
      ascend: 'Bacaklarini kontrollu indir...',
      formViolation: 'Dizlerini daha duz tut.',
      controlDescent: 'Kaldirisi kontrollu yap.',
      controlAscent: 'Inisi kontrollu yap.',
      stabilizeTransition: 'Ust noktada gecisi sabitle.',
      maintainForm: 'Dizlerini uzatmayi koru.',
    );
  }

  if (exerciseType == ExerciseType.tricepsDip) {
    return const _RangeRepFeedbackCopy(
      descend: 'Kontrollu asagi in...',
      ascend: 'Kollarinla yukari it...',
      formViolation: 'Omuzlarini gereksiz derine zorlama.',
      controlDescent: 'Inisi kontrollu yap.',
      controlAscent: 'Yukselisi kontrollu yap.',
      stabilizeTransition: 'Alt noktada gecisi sabitle.',
      maintainForm: 'Omuz pozisyonunu koru.',
    );
  }

  if (exerciseType == ExerciseType.romanianDeadlift) {
    return const _RangeRepFeedbackCopy(
      descend: 'Kalca menteşesiyle kontrollu egil...',
      ascend: 'Kalcalari ileri getirerek kalk...',
      formViolation: 'Diz acini daha sabit tut.',
      controlDescent: 'Kalca menteşesini kontrollu yap.',
      controlAscent: 'Kalkisi kontrollu yap.',
      stabilizeTransition: 'Alt noktada kontrolu koru.',
      maintainForm: 'Diz acini ve kalca menteşesini koru.',
    );
  }

  if (exerciseType == ExerciseType.lunge) {
    return const _RangeRepFeedbackCopy(
      descend: 'Kontrollu asagi in...',
      ascend: 'On bacaginla yukari it...',
      formViolation: 'Formunu koru.',
      controlDescent: 'Inisi kontrollu yap.',
      controlAscent: 'Yukselisi kontrollu yap.',
      stabilizeTransition: 'Alt noktada dengeyi koru.',
      maintainForm: 'Dengeni ve diz hattini koru.',
    );
  }

  if (exerciseType == ExerciseType.calfRaise) {
    return const _RangeRepFeedbackCopy(
      descend: 'Topuklarini kontrollu kaldir...',
      ascend: 'Topuklarini kontrollu indir...',
      formViolation: 'Diz hattini daha sabit tut.',
      controlDescent: 'Yukselisi kontrollu yap.',
      controlAscent: 'Inisi kontrollu yap.',
      stabilizeTransition: 'Ust noktada dengeyi koru.',
      maintainForm: 'Diz hattini sabit tut.',
    );
  }

  if (exerciseType == ExerciseType.frontRaise) {
    return const _RangeRepFeedbackCopy(
      descend: 'Kollarini kontrollu one kaldir...',
      ascend: 'Kollarini kontrollu indir...',
      formViolation: 'Dirseklerini gereksiz bukme.',
      controlDescent: 'Kaldirisi kontrollu yap.',
      controlAscent: 'Inisi kontrollu yap.',
      stabilizeTransition: 'Ust noktada gecisi sabitle.',
      maintainForm: 'Dirsek acini koru.',
    );
  }

  if (exerciseType == ExerciseType.gluteBridge) {
    return const _RangeRepFeedbackCopy(
      descend: 'Kalcani kontrollu yukari kaldir...',
      ascend: 'Kalcani kontrollu indir...',
      formViolation: 'Formunu koru.',
      controlDescent: 'Yukselisi kontrollu yap.',
      controlAscent: 'Inisi kontrollu yap.',
      stabilizeTransition: 'Ust noktada gecisi sabitle.',
      maintainForm: 'Kalca kontrolunu koru.',
    );
  }

  if (exerciseType == ExerciseType.jumpingJack) {
    return const _RangeRepFeedbackCopy(
      descend: 'Kollarini ve bacaklarini ac...',
      ascend: 'Kontrollu baslangica don...',
      formViolation: 'Bacaklarini yeterince ac.',
      controlDescent: 'Acilisi kontrollu yap.',
      controlAscent: 'Donusu kontrollu yap.',
      stabilizeTransition: 'Ust noktada ritmi koru.',
      maintainForm: 'Kol ve bacak acilimini birlikte koru.',
    );
  }

  if (exerciseType == ExerciseType.lateralRaise) {
    return const _RangeRepFeedbackCopy(
      descend: 'Kollarini yana kaldir...',
      ascend: 'Kontrollu indir...',
      formViolation: 'Dirseklerini gereksiz bukme.',
      controlDescent: 'Kaldirisi kontrollu yap.',
      controlAscent: 'Inisi kontrollu yap.',
      stabilizeTransition: 'Omuz hizasinda gecisi sabitle.',
      maintainForm: 'Dirsek acini koru.',
    );
  }

  if (exerciseType == ExerciseType.shoulderPress) {
    return const _RangeRepFeedbackCopy(
      descend: 'Kollari yukari presle...',
      ascend: 'Kontrollu baslangica don...',
      formViolation: 'Formunu koru.',
      controlDescent: 'Presi kontrollu yap.',
      controlAscent: 'Inisi kontrollu yap.',
      stabilizeTransition: 'Ustte gecisi sabitle.',
      maintainForm: 'Kollari birlikte hareket ettir.',
    );
  }

  if (exerciseType == ExerciseType.bicepsCurl) {
    return const _RangeRepFeedbackCopy(
      descend: 'Kollarini yukari cek...',
      ascend: 'Kontrollu indir...',
      formViolation:
          'Dirseklerini sabit tut ve kollarini birlikte hareket ettir.',
      controlDescent: 'Yukari cekisi kontrollu yap.',
      controlAscent: 'Inisi kontrollu yap.',
      stabilizeTransition: 'Ustte gecisi sabitle.',
      maintainForm: 'Dirseklerini sabit tut.',
    );
  }

  if (exerciseType == ExerciseType.sitUp) {
    return const _RangeRepFeedbackCopy(
      descend: 'Yukari kalk...',
      ascend: 'Kontrollu geri in...',
      formViolation: 'Bacak acini koru.',
      controlDescent: 'Yukari kalkisi kontrollu yap.',
      controlAscent: 'Geri inisi kontrollu yap.',
      stabilizeTransition: 'Ustte gecisi sabitle.',
      maintainForm: 'Bacak pozisyonunu koru.',
    );
  }

  return const _RangeRepFeedbackCopy(
    descend: 'Asagi in...',
    ascend: 'Yukari...',
    formViolation: 'Sirtini Dik Tut!',
    controlDescent: 'Inisi kontrollu yap.',
    controlAscent: 'Yukselisi kontrollu yap.',
    stabilizeTransition: 'Dipte gecisi sabitle.',
    maintainForm: 'Formunu koru.',
  );
}

class _RangeRepFeedbackCopy {
  const _RangeRepFeedbackCopy({
    required this.descend,
    required this.ascend,
    required this.formViolation,
    required this.controlDescent,
    required this.controlAscent,
    required this.stabilizeTransition,
    required this.maintainForm,
  });

  final String descend;
  final String ascend;
  final String formViolation;
  final String controlDescent;
  final String controlAscent;
  final String stabilizeTransition;
  final String maintainForm;
}
