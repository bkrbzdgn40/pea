import '../../../../app/localization/app_localizations.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/range_rep_feedback_code.dart';

String mapRangeRepFeedbackCodeToMessage(
  RangeRepFeedbackCode code, {
  required AppLocalizations localizations,
  ExerciseType? exerciseType,
}) {
  final copy = _rangeRepFeedbackCopyFor(
    localizations,
    exerciseType: exerciseType,
  );

  switch (code) {
    case RangeRepFeedbackCode.awaitNeutral:
      return localizations.pick(
        tr: 'Başlangıç pozisyonuna geç.',
        en: 'Move to the starting position.',
      );
    case RangeRepFeedbackCode.ready:
      return localizations.pick(tr: 'Hazır!', en: 'Ready!');
    case RangeRepFeedbackCode.waitForBody:
      return localizations.pick(
        tr: 'Vücut bekleniyor...',
        en: 'Waiting for body...',
      );
    case RangeRepFeedbackCode.bodyNotVisible:
      return localizations.pick(
        tr: 'Vücut net görünmüyor.',
        en: 'Body is not clearly visible.',
      );
    case RangeRepFeedbackCode.descend:
      return copy.descend;
    case RangeRepFeedbackCode.ascend:
      return copy.ascend;
    case RangeRepFeedbackCode.repCompleted:
      return localizations.pick(tr: 'Başarılı!', en: 'Rep completed!');
    case RangeRepFeedbackCode.repIncomplete:
      return localizations.pick(
        tr: 'Hareketi tamamlamadın.',
        en: 'Complete the full movement.',
      );
    case RangeRepFeedbackCode.legacyFormThresholdViolation:
      if (exerciseType == ExerciseType.squat) {
        return localizations.pick(
          tr: 'Formunu koru.',
          en: 'Maintain your form.',
        );
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

_RangeRepFeedbackCopy _rangeRepFeedbackCopyFor(
  AppLocalizations localizations, {
  ExerciseType? exerciseType,
}) {
  if (exerciseType == ExerciseType.lyingLegRaise) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Bacaklarını kontrollü kaldır...',
        en: 'Raise your legs with control...',
      ),
      ascend: localizations.pick(
        tr: 'Bacaklarını kontrollü indir...',
        en: 'Lower your legs with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Dizlerini daha düz tut.',
        en: 'Keep your knees straighter.',
      ),
      controlDescent: localizations.pick(
        tr: 'Kaldırışı kontrollü yap.',
        en: 'Control the lift.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada geçişi sabitle.',
        en: 'Stabilize the transition at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dizlerini uzatılmış tut.',
        en: 'Keep your knees extended.',
      ),
    );
  }

  if (exerciseType == ExerciseType.tricepsDip) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kontrollü aşağı in...',
        en: 'Lower yourself with control...',
      ),
      ascend: localizations.pick(
        tr: 'Kollarınla yukarı it...',
        en: 'Push up through your arms...',
      ),
      formViolation: localizations.pick(
        tr: 'Omuzlarını gereksiz derine zorlama.',
        en: 'Do not force your shoulders too deep.',
      ),
      controlDescent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the descent.',
      ),
      controlAscent: localizations.pick(
        tr: 'Yükselişi kontrollü yap.',
        en: 'Control the ascent.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Alt noktada geçişi sabitle.',
        en: 'Stabilize the transition at the bottom.',
      ),
      maintainForm: localizations.pick(
        tr: 'Omuz pozisyonunu koru.',
        en: 'Maintain your shoulder position.',
      ),
    );
  }

  if (exerciseType == ExerciseType.romanianDeadlift) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kalça menteşesiyle kontrollü eğil...',
        en: 'Hinge at the hips with control...',
      ),
      ascend: localizations.pick(
        tr: 'Kalçalarını ileri getirerek kalk...',
        en: 'Drive your hips forward to stand...',
      ),
      formViolation: localizations.pick(
        tr: 'Diz açını daha sabit tut.',
        en: 'Keep your knee angle more stable.',
      ),
      controlDescent: localizations.pick(
        tr: 'Kalça menteşesini kontrollü yap.',
        en: 'Control the hip hinge.',
      ),
      controlAscent: localizations.pick(
        tr: 'Kalkışı kontrollü yap.',
        en: 'Control the return to standing.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Alt noktada kontrolü koru.',
        en: 'Maintain control at the bottom.',
      ),
      maintainForm: localizations.pick(
        tr: 'Diz açını ve kalça menteşesini koru.',
        en: 'Maintain your knee angle and hip hinge.',
      ),
    );
  }

  if (exerciseType == ExerciseType.lunge) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kontrollü aşağı in...',
        en: 'Lower down with control...',
      ),
      ascend: localizations.pick(
        tr: 'Ön bacağınla yukarı it...',
        en: 'Drive up through your front leg...',
      ),
      formViolation: localizations.pick(
        tr: 'Formunu koru.',
        en: 'Maintain your form.',
      ),
      controlDescent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the descent.',
      ),
      controlAscent: localizations.pick(
        tr: 'Yükselişi kontrollü yap.',
        en: 'Control the ascent.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Alt noktada dengeyi koru.',
        en: 'Keep your balance at the bottom.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dengeni ve diz hattını koru.',
        en: 'Maintain your balance and knee alignment.',
      ),
    );
  }

  if (exerciseType == ExerciseType.calfRaise) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Topuklarını kontrollü kaldır...',
        en: 'Raise your heels with control...',
      ),
      ascend: localizations.pick(
        tr: 'Topuklarını kontrollü indir...',
        en: 'Lower your heels with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Diz hattını daha sabit tut.',
        en: 'Keep your knee alignment more stable.',
      ),
      controlDescent: localizations.pick(
        tr: 'Yükselişi kontrollü yap.',
        en: 'Control the rise.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada dengeyi koru.',
        en: 'Keep your balance at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Diz hattını sabit tut.',
        en: 'Keep your knee alignment steady.',
      ),
    );
  }

  if (exerciseType == ExerciseType.frontRaise) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kollarını kontrollü öne kaldır...',
        en: 'Raise your arms forward with control...',
      ),
      ascend: localizations.pick(
        tr: 'Kollarını kontrollü indir...',
        en: 'Lower your arms with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Dirseklerini gereksiz bükme.',
        en: 'Do not bend your elbows unnecessarily.',
      ),
      controlDescent: localizations.pick(
        tr: 'Kaldırışı kontrollü yap.',
        en: 'Control the lift.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada geçişi sabitle.',
        en: 'Stabilize the transition at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dirsek açını koru.',
        en: 'Maintain your elbow angle.',
      ),
    );
  }

  if (exerciseType == ExerciseType.gluteBridge) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kalçanı kontrollü yukarı kaldır...',
        en: 'Raise your hips with control...',
      ),
      ascend: localizations.pick(
        tr: 'Kalçanı kontrollü indir...',
        en: 'Lower your hips with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Formunu koru.',
        en: 'Maintain your form.',
      ),
      controlDescent: localizations.pick(
        tr: 'Yükselişi kontrollü yap.',
        en: 'Control the rise.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada geçişi sabitle.',
        en: 'Stabilize the transition at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Kalça kontrolünü koru.',
        en: 'Maintain hip control.',
      ),
    );
  }

  if (exerciseType == ExerciseType.jumpingJack) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kollarını ve bacaklarını aç...',
        en: 'Open your arms and legs...',
      ),
      ascend: localizations.pick(
        tr: 'Kontrollü başlangıca dön...',
        en: 'Return to the starting position with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Bacaklarını yeterince aç.',
        en: 'Open your legs farther.',
      ),
      controlDescent: localizations.pick(
        tr: 'Açılışı kontrollü yap.',
        en: 'Control the opening phase.',
      ),
      controlAscent: localizations.pick(
        tr: 'Dönüşü kontrollü yap.',
        en: 'Control the return.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada ritmi koru.',
        en: 'Keep your rhythm at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Kol ve bacak açılımını birlikte koru.',
        en: 'Keep your arm and leg movement synchronized.',
      ),
    );
  }

  if (exerciseType == ExerciseType.lateralRaise) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kollarını yana kaldır...',
        en: 'Raise your arms out to the sides...',
      ),
      ascend: localizations.pick(
        tr: 'Kontrollü indir...',
        en: 'Lower with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Dirseklerini gereksiz bükme.',
        en: 'Do not bend your elbows unnecessarily.',
      ),
      controlDescent: localizations.pick(
        tr: 'Kaldırışı kontrollü yap.',
        en: 'Control the lift.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Omuz hizasında geçişi sabitle.',
        en: 'Stabilize the transition at shoulder height.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dirsek açını koru.',
        en: 'Maintain your elbow angle.',
      ),
    );
  }

  if (exerciseType == ExerciseType.shoulderPress) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kollarını yukarı it...',
        en: 'Press your arms overhead...',
      ),
      ascend: localizations.pick(
        tr: 'Kontrollü başlangıca dön...',
        en: 'Return to the starting position with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Formunu koru.',
        en: 'Maintain your form.',
      ),
      controlDescent: localizations.pick(
        tr: 'İtişi kontrollü yap.',
        en: 'Control the press.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üstte geçişi sabitle.',
        en: 'Stabilize the transition at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Kollarını birlikte hareket ettir.',
        en: 'Move both arms together.',
      ),
    );
  }

  if (exerciseType == ExerciseType.bicepsCurl) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kollarını yukarı çek...',
        en: 'Curl your arms up...',
      ),
      ascend: localizations.pick(
        tr: 'Kontrollü indir...',
        en: 'Lower with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Dirseklerini sabit tut ve kollarını birlikte hareket ettir.',
        en: 'Keep your elbows still and move both arms together.',
      ),
      controlDescent: localizations.pick(
        tr: 'Yukarı çekişi kontrollü yap.',
        en: 'Control the curl.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üstte geçişi sabitle.',
        en: 'Stabilize the transition at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dirseklerini sabit tut.',
        en: 'Keep your elbows still.',
      ),
    );
  }

  if (exerciseType == ExerciseType.sitUp) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(tr: 'Yukarı kalk...', en: 'Curl up...'),
      ascend: localizations.pick(
        tr: 'Kontrollü geri in...',
        en: 'Lower back down with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Bacak açını koru.',
        en: 'Maintain your leg angle.',
      ),
      controlDescent: localizations.pick(
        tr: 'Yukarı kalkışı kontrollü yap.',
        en: 'Control the upward phase.',
      ),
      controlAscent: localizations.pick(
        tr: 'Geri inişi kontrollü yap.',
        en: 'Control the return.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üstte geçişi sabitle.',
        en: 'Stabilize the transition at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Bacak pozisyonunu koru.',
        en: 'Maintain your leg position.',
      ),
    );
  }

  return _RangeRepFeedbackCopy(
    descend: localizations.pick(tr: 'Aşağı in...', en: 'Lower down...'),
    ascend: localizations.pick(tr: 'Yukarı...', en: 'Move up...'),
    formViolation: localizations.pick(
      tr: 'Sırtını dik tut!',
      en: 'Keep your back upright!',
    ),
    controlDescent: localizations.pick(
      tr: 'İnişi kontrollü yap.',
      en: 'Control the descent.',
    ),
    controlAscent: localizations.pick(
      tr: 'Yükselişi kontrollü yap.',
      en: 'Control the ascent.',
    ),
    stabilizeTransition: localizations.pick(
      tr: 'Dipte geçişi sabitle.',
      en: 'Stabilize the transition at the bottom.',
    ),
    maintainForm: localizations.pick(
      tr: 'Formunu koru.',
      en: 'Maintain your form.',
    ),
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
