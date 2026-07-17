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
    case RangeRepFeedbackCode.keepBodyUpright:
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
