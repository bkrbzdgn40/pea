import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/range_rep_feedback_ui_mapper.dart';

void main() {
  const tr = AppLocalizations(Locale('tr'));
  const en = AppLocalizations(Locale('en'));

  test('legacy form threshold feedback code is anatomy-neutral', () {
    expect(
      RangeRepFeedbackCode.legacyFormThresholdViolation.code,
      'legacy_form_threshold_violation',
    );
    expect(
      RangeRepFeedbackCode.keepBodyUpright,
      RangeRepFeedbackCode.legacyFormThresholdViolation,
    );
  });

  test('squat keeps directional copy without an upright-back claim', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        localizations: tr,
        exerciseType: ExerciseType.squat,
      ),
      'Aşağı in...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.legacyFormThresholdViolation,
        localizations: tr,
        exerciseType: ExerciseType.squat,
      ),
      'Formunu koru.',
    );
  });

  test('push-up keeps the existing directional and form copy', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.ascend,
        localizations: tr,
        exerciseType: ExerciseType.pushUp,
      ),
      'Yukarı...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.controlDescent,
        localizations: tr,
        exerciseType: ExerciseType.pushUp,
      ),
      'İnişi kontrollü yap.',
    );
  });

  test('sit-up maps angle decrease to the physical upward cue', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        localizations: tr,
        exerciseType: ExerciseType.sitUp,
      ),
      'Yukarı kalk...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.controlDescent,
        localizations: tr,
        exerciseType: ExerciseType.sitUp,
      ),
      'Yukarı kalkışı kontrollü yap.',
    );
  });

  test('sit-up maps angle increase to the physical lowering cue', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.ascend,
        localizations: tr,
        exerciseType: ExerciseType.sitUp,
      ),
      'Kontrollü geri in...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.controlAscent,
        localizations: tr,
        exerciseType: ExerciseType.sitUp,
      ),
      'Geri inişi kontrollü yap.',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.stabilizeTransition,
        localizations: tr,
        exerciseType: ExerciseType.sitUp,
      ),
      'Üstte geçişi sabitle.',
    );
  });

  test('sit-up keeps compatibility form copy anatomy-specific', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.legacyFormThresholdViolation,
        localizations: tr,
        exerciseType: ExerciseType.sitUp,
      ),
      'Bacak açını koru.',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.maintainForm,
        localizations: tr,
        exerciseType: ExerciseType.sitUp,
      ),
      'Bacak pozisyonunu koru.',
    );
  });

  test(
    'Romanian deadlift form feedback matches the absolute knee-angle gate',
    () {
      expect(
        mapRangeRepFeedbackCodeToMessage(
          RangeRepFeedbackCode.legacyFormThresholdViolation,
          localizations: tr,
          exerciseType: ExerciseType.romanianDeadlift,
        ),
        'Dizlerini biraz daha az bük.',
      );
      expect(
        mapRangeRepFeedbackCodeToMessage(
          RangeRepFeedbackCode.maintainForm,
          localizations: tr,
          exerciseType: ExerciseType.romanianDeadlift,
        ),
        'Dizlerini biraz daha az bükerek kalça menteşesini koru.',
      );
      expect(
        mapRangeRepFeedbackCodeToMessage(
          RangeRepFeedbackCode.legacyFormThresholdViolation,
          localizations: en,
          exerciseType: ExerciseType.romanianDeadlift,
        ),
        'Bend your knees a little less.',
      );
    },
  );

  test('biceps curl maps range-rep cues to simultaneous-arm copy', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        localizations: tr,
        exerciseType: ExerciseType.bicepsCurl,
      ),
      'Kollarını yukarı çek...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.ascend,
        localizations: tr,
        exerciseType: ExerciseType.bicepsCurl,
      ),
      'Kontrollü indir...',
    );
  });

  test('Day 11 increasing-direction exercises use physical movement copy', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        localizations: tr,
        exerciseType: ExerciseType.calfRaise,
      ),
      'Topuklarını kontrollü kaldır...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        localizations: tr,
        exerciseType: ExerciseType.frontRaise,
      ),
      'Kollarını kontrollü öne kaldır...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        localizations: tr,
        exerciseType: ExerciseType.gluteBridge,
      ),
      'Kalçanı kontrollü yukarı kaldır...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        localizations: tr,
        exerciseType: ExerciseType.jumpingJack,
      ),
      'Kollarını ve bacaklarını aç...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.ascend,
        localizations: tr,
        exerciseType: ExerciseType.jumpingJack,
      ),
      'Ritmi koru...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.ascend,
        localizations: en,
        exerciseType: ExerciseType.jumpingJack,
      ),
      'Keep the rhythm...',
    );
  });

  test(
    'Jumping Jack form feedback describes the combined bilateral signal',
    () {
      expect(
        mapRangeRepFeedbackCodeToMessage(
          RangeRepFeedbackCode.legacyFormThresholdViolation,
          localizations: tr,
          exerciseType: ExerciseType.jumpingJack,
        ),
        'Kollarını birlikte tepeye kaldırırken bacaklarını da tamamen aç.',
      );
      expect(
        mapRangeRepFeedbackCodeToMessage(
          RangeRepFeedbackCode.legacyFormThresholdViolation,
          localizations: en,
          exerciseType: ExerciseType.jumpingJack,
        ),
        'Raise both arms together as you fully open your legs.',
      );
    },
  );

  test('biceps curl form feedback matches the upper-arm posture metric', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.legacyFormThresholdViolation,
        localizations: tr,
        exerciseType: ExerciseType.bicepsCurl,
      ),
      'Dirseklerini gövdene yakın tut.',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.maintainForm,
        localizations: tr,
        exerciseType: ExerciseType.bicepsCurl,
      ),
      'Dirseklerini gövdene yakın tut.',
    );
  });

  test('runtime feedback supports English copy', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.bodyNotVisible,
        localizations: en,
        exerciseType: ExerciseType.squat,
      ),
      'Body is not clearly visible.',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        localizations: en,
        exerciseType: ExerciseType.bicepsCurl,
      ),
      'Curl your arms up...',
    );
  });
}
