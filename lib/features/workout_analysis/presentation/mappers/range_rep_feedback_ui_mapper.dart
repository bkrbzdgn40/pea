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

  if (exerciseType == ExerciseType.crunch) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Omuzlarını kontrollü kaldır...',
        en: 'Curl your shoulders up with control...',
      ),
      ascend: localizations.pick(
        tr: 'Kontrollü zemine dön...',
        en: 'Lower back to the floor with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Boynunu çekmeden gövdeni kıvır.',
        en: 'Curl your trunk without pulling your neck.',
      ),
      controlDescent: localizations.pick(
        tr: 'Yukarı kıvrılmayı kontrollü yap.',
        en: 'Control the upward curl.',
      ),
      controlAscent: localizations.pick(
        tr: 'Geri inişi kontrollü yap.',
        en: 'Control the return to the floor.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada kısa süre kontrolü koru.',
        en: 'Maintain control briefly at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Boynunu rahat, hareketi kontrollü tut.',
        en: 'Keep your neck relaxed and the movement controlled.',
      ),
    );
  }

  if (exerciseType == ExerciseType.reverseCrunch) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kalçanı kontrollü kaldır...',
        en: 'Lift your hips with control...',
      ),
      ascend: localizations.pick(
        tr: 'Kalçanı kontrollü indir...',
        en: 'Lower your hips with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Sallanmak yerine kalçanı kontrollü kıvır.',
        en: 'Curl your hips with control instead of swinging.',
      ),
      controlDescent: localizations.pick(
        tr: 'Kalça kaldırışını kontrollü yap.',
        en: 'Control the hip lift.',
      ),
      controlAscent: localizations.pick(
        tr: 'Geri dönüşü kontrollü yap.',
        en: 'Control the return.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada savrulmadan geçiş yap.',
        en: 'Transition at the top without swinging.',
      ),
      maintainForm: localizations.pick(
        tr: 'Bacaklarını savurmadan merkez bölgeni kullan.',
        en: 'Use your core without swinging your legs.',
      ),
    );
  }

  if (exerciseType == ExerciseType.bentKneeLegRaise) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Dizlerini kontrollü kaldır...',
        en: 'Raise your bent knees with control...',
      ),
      ascend: localizations.pick(
        tr: 'Bacaklarını kontrollü indir...',
        en: 'Lower your legs with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Diz açını ve bel kontrolünü koru.',
        en: 'Maintain your knee angle and lower-back control.',
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
        tr: 'Dizlerini rahatça bükülü tut.',
        en: 'Keep your knees comfortably bent.',
      ),
    );
  }

  if (exerciseType == ExerciseType.standingHamstringCurl) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Topuğunu kalçana doğru çek...',
        en: 'Curl your heel toward your glutes...',
      ),
      ascend: localizations.pick(
        tr: 'Bacağını kontrollü indir...',
        en: 'Lower your leg with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Gövdeni ve kalçanı sabit tut.',
        en: 'Keep your trunk and hips steady.',
      ),
      controlDescent: localizations.pick(
        tr: 'Büküşü kontrollü yap.',
        en: 'Control the curl.',
      ),
      controlAscent: localizations.pick(
        tr: 'Dönüşü kontrollü yap.',
        en: 'Control the return.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada dengeni koru.',
        en: 'Maintain your balance at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Destek bacağını ve gövdeni sabit tut.',
        en: 'Keep your support leg and trunk steady.',
      ),
    );
  }

  if (exerciseType == ExerciseType.standingHipAbduction) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Bacağını kontrollü yana kaldır...',
        en: 'Raise your leg to the side with control...',
      ),
      ascend: localizations.pick(
        tr: 'Bacağını kontrollü indir...',
        en: 'Lower your leg with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Çalışan dizini daha düz tut.',
        en: 'Keep the working knee straighter.',
      ),
      controlDescent: localizations.pick(
        tr: 'Yana kaldırışı kontrollü yap.',
        en: 'Control the side raise.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada gövdeni sabit tut.',
        en: 'Keep your trunk steady at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dizini düz ve gövdeni dik tut.',
        en: 'Keep your knee straight and your trunk upright.',
      ),
    );
  }

  if (exerciseType == ExerciseType.overheadTricepsExtension) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Dirseklerini kontrollü aç...',
        en: 'Extend your elbows with control...',
      ),
      ascend: localizations.pick(
        tr: 'Dirseklerini kontrollü bük...',
        en: 'Bend your elbows with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Üst kollarını başına daha yakın tut.',
        en: 'Keep your upper arms closer to your head.',
      ),
      controlDescent: localizations.pick(
        tr: 'Dirsek açışını kontrollü yap.',
        en: 'Control the elbow extension.',
      ),
      controlAscent: localizations.pick(
        tr: 'Ağırlığı kontrollü indir.',
        en: 'Lower the weight with control.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada dirseklerini sabitle.',
        en: 'Stabilize your elbows at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Üst kollarını sabit tut.',
        en: 'Keep your upper arms steady.',
      ),
    );
  }

  if (exerciseType == ExerciseType.uprightRow) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Dirseklerini kontrollü yukarı çek...',
        en: 'Pull your elbows upward with control...',
      ),
      ascend: localizations.pick(
        tr: 'Kollarını kontrollü indir...',
        en: 'Lower your arms with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Gövdeni savurmadan dirseklerinle çek.',
        en: 'Lead with your elbows without swinging your trunk.',
      ),
      controlDescent: localizations.pick(
        tr: 'Yukarı çekişi kontrollü yap.',
        en: 'Control the upward pull.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada omuzlarını sıkıştırma.',
        en: 'Avoid shrugging at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Gövdeni dik ve hareketi simetrik tut.',
        en: 'Keep your trunk upright and the movement symmetrical.',
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
        tr: 'Dizlerini biraz daha az bük.',
        en: 'Bend your knees a little less.',
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
        tr: 'Dizlerini biraz daha az bükerek kalça menteşesini koru.',
        en: 'Keep the hip hinge with slightly less knee bend.',
      ),
    );
  }

  if (exerciseType == ExerciseType.goodMorning) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kalçanı geriye göndererek kontrollü eğil...',
        en: 'Send your hips back and hinge with control...',
      ),
      ascend: localizations.pick(
        tr: 'Kalçalarını ileri getirerek doğrul...',
        en: 'Drive your hips forward to stand tall...',
      ),
      formViolation: localizations.pick(
        tr: 'Dizlerini biraz daha az bük.',
        en: 'Bend your knees a little less.',
      ),
      controlDescent: localizations.pick(
        tr: 'Kalça menteşesini kontrollü yap.',
        en: 'Control the hip hinge.',
      ),
      controlAscent: localizations.pick(
        tr: 'Dik pozisyona dönüşü kontrollü yap.',
        en: 'Control the return to standing.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Alt noktada gövde hizanı koru.',
        en: 'Maintain trunk alignment at the bottom.',
      ),
      maintainForm: localizations.pick(
        tr: 'Diz açını sabit tutup kalça menteşesini koru.',
        en: 'Keep your knee angle steady and maintain the hip hinge.',
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

  if (exerciseType == ExerciseType.standingHipExtension) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Bacağını kontrollü geriye götür...',
        en: 'Move your leg backward with control...',
      ),
      ascend: localizations.pick(
        tr: 'Bacağını kontrollü başlangıca getir...',
        en: 'Return your leg to the start with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Çalışan dizini daha düz tut.',
        en: 'Keep the working knee straighter.',
      ),
      controlDescent: localizations.pick(
        tr: 'Geri uzatışı kontrollü yap.',
        en: 'Control the backward extension.',
      ),
      controlAscent: localizations.pick(
        tr: 'Dönüşü kontrollü yap.',
        en: 'Control the return.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Arka noktada gövdeni sabit tut.',
        en: 'Keep your trunk steady at the back position.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dizini düz ve gövdeni dik tut.',
        en: 'Keep your knee straight and your trunk upright.',
      ),
    );
  }

  if (exerciseType == ExerciseType.standingKneeRaise) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Dizini kontrollü kaldır...',
        en: 'Raise your knee with control...',
      ),
      ascend: localizations.pick(
        tr: 'Ayağını kontrollü indir...',
        en: 'Lower your foot with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Kaldırırken dizini daha fazla bük.',
        en: 'Bend your knee more during the raise.',
      ),
      controlDescent: localizations.pick(
        tr: 'Diz kaldırışını kontrollü yap.',
        en: 'Control the knee raise.',
      ),
      controlAscent: localizations.pick(
        tr: 'İnişi kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada dengeni koru.',
        en: 'Maintain your balance at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Gövdeni dik ve dizini bükülü tut.',
        en: 'Keep your trunk upright and your knee bent.',
      ),
    );
  }

  if (exerciseType == ExerciseType.standingStraightLegRaise) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Düz bacağını kontrollü kaldır...',
        en: 'Raise your straight leg with control...',
      ),
      ascend: localizations.pick(
        tr: 'Bacağını kontrollü indir...',
        en: 'Lower your leg with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Çalışan dizini daha düz tut.',
        en: 'Keep the working knee straighter.',
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
        tr: 'Üst noktada gövdeni sabit tut.',
        en: 'Keep your trunk steady at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dizini düz ve gövdeni dik tut.',
        en: 'Keep your knee straight and your trunk upright.',
      ),
    );
  }

  if (exerciseType == ExerciseType.vUp) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Gövde ve bacaklarını birlikte kaldır...',
        en: 'Raise your trunk and legs together...',
      ),
      ascend: localizations.pick(
        tr: 'Kontrollü uzun pozisyona dön...',
        en: 'Return to the long position with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Gövde ve bacakları birlikte hareket ettir.',
        en: 'Move your trunk and legs together.',
      ),
      controlDescent: localizations.pick(
        tr: 'Yukarı kapanışı kontrollü yap.',
        en: 'Control the upward compression.',
      ),
      controlAscent: localizations.pick(
        tr: 'Aşağı dönüşü kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Tepe noktada savrulmadan yön değiştir.',
        en: 'Change direction at the top without swinging.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dizlerini düz ve hareketi eş zamanlı tut.',
        en: 'Keep your knees straight and the movement synchronized.',
      ),
    );
  }

  if (exerciseType == ExerciseType.frogPump) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kalçanı kontrollü kaldır...',
        en: 'Raise your hips with control...',
      ),
      ascend: localizations.pick(
        tr: 'Kalçanı kontrollü indir...',
        en: 'Lower your hips with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Ayak tabanlarını birlikte tut.',
        en: 'Keep the soles of your feet together.',
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
        tr: 'Üst noktada kalçanı sabitle.',
        en: 'Stabilize your hips at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dizlerini açık ve ayaklarını birlikte tut.',
        en: 'Keep your knees open and your feet together.',
      ),
    );
  }

  if (exerciseType == ExerciseType.lyingTricepsExtension) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Dirseğini kontrollü aç...',
        en: 'Extend your elbow with control...',
      ),
      ascend: localizations.pick(
        tr: 'Elini kontrollü başına yaklaştır...',
        en: 'Lower your hand toward your head with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Üst kolunu omuz üzerinde sabit tut.',
        en: 'Keep your upper arm steady above your shoulder.',
      ),
      controlDescent: localizations.pick(
        tr: 'Dirsek açışını kontrollü yap.',
        en: 'Control the elbow extension.',
      ),
      controlAscent: localizations.pick(
        tr: 'Aşağı dönüşü kontrollü yap.',
        en: 'Control the lowering phase.',
      ),
      stabilizeTransition: localizations.pick(
        tr: 'Üst noktada dirseğini sabitle.',
        en: 'Stabilize your elbow at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Üst kolunu hareket ettirmeden dirseğini çalıştır.',
        en: 'Move at the elbow while keeping the upper arm steady.',
      ),
    );
  }

  if (exerciseType == ExerciseType.floorChestPress) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kolunu kontrollü yukarı it...',
        en: 'Press your arm upward with control...',
      ),
      ascend: localizations.pick(
        tr: 'Dirseğini kontrollü yere yaklaştır...',
        en: 'Lower your elbow toward the floor with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Omzunu zeminde sabit tut.',
        en: 'Keep your shoulder steady on the floor.',
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
        tr: 'Üst noktada kolunu sabitle.',
        en: 'Stabilize your arm at the top.',
      ),
      maintainForm: localizations.pick(
        tr: 'Omuz ve bilek hattını kontrollü tut.',
        en: 'Keep your shoulder and wrist alignment controlled.',
      ),
    );
  }

  if (exerciseType == ExerciseType.yRaise) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kollarını Y hattına kaldır...',
        en: 'Raise your arms into the Y line...',
      ),
      ascend: localizations.pick(
        tr: 'Kollarını kontrollü indir...',
        en: 'Lower your arms with control...',
      ),
      formViolation: localizations.pick(
        tr: 'Dirseklerini daha düz tut.',
        en: 'Keep your elbows straighter.',
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
        tr: 'Y pozisyonunda iki kolu sabitle.',
        en: 'Stabilize both arms in the Y position.',
      ),
      maintainForm: localizations.pick(
        tr: 'Dirseklerini düz ve kollarını eşit tut.',
        en: 'Keep your elbows straight and both arms even.',
      ),
    );
  }

  if (exerciseType == ExerciseType.jumpingJack) {
    return _RangeRepFeedbackCopy(
      descend: localizations.pick(
        tr: 'Kollarını ve bacaklarını aç...',
        en: 'Open your arms and legs...',
      ),
      ascend: localizations.pick(tr: 'Ritmi koru...', en: 'Keep the rhythm...'),
      formViolation: localizations.pick(
        tr: 'Kollarını birlikte tepeye kaldırırken bacaklarını da tamamen aç.',
        en: 'Raise both arms together as you fully open your legs.',
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
        tr: 'Dirseklerini gövdene yakın tut.',
        en: 'Keep your elbows close to your torso.',
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
        tr: 'Dirseklerini gövdene yakın tut.',
        en: 'Keep your elbows close to your torso.',
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
