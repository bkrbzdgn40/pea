import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/range_rep_feedback_ui_mapper.dart';

void main() {
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
        exerciseType: ExerciseType.squat,
      ),
      'Asagi in...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.legacyFormThresholdViolation,
        exerciseType: ExerciseType.squat,
      ),
      'Formunu koru.',
    );
  });

  test('push-up keeps the existing directional and form copy', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.ascend,
        exerciseType: ExerciseType.pushUp,
      ),
      'Yukari...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.controlDescent,
        exerciseType: ExerciseType.pushUp,
      ),
      'Inisi kontrollu yap.',
    );
  });

  test('sit-up maps angle decrease to the physical upward cue', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        exerciseType: ExerciseType.sitUp,
      ),
      'Yukari kalk...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.controlDescent,
        exerciseType: ExerciseType.sitUp,
      ),
      'Yukari kalkisi kontrollu yap.',
    );
  });

  test('sit-up maps angle increase to the physical lowering cue', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.ascend,
        exerciseType: ExerciseType.sitUp,
      ),
      'Kontrollu geri in...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.controlAscent,
        exerciseType: ExerciseType.sitUp,
      ),
      'Geri inisi kontrollu yap.',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.stabilizeTransition,
        exerciseType: ExerciseType.sitUp,
      ),
      'Ustte gecisi sabitle.',
    );
  });

  test('sit-up keeps compatibility form copy anatomy-specific', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.legacyFormThresholdViolation,
        exerciseType: ExerciseType.sitUp,
      ),
      'Bacak acini koru.',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.maintainForm,
        exerciseType: ExerciseType.sitUp,
      ),
      'Bacak pozisyonunu koru.',
    );
  });

  test('biceps curl maps range-rep cues to simultaneous-arm copy', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        exerciseType: ExerciseType.bicepsCurl,
      ),
      'Kollarini yukari cek...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.ascend,
        exerciseType: ExerciseType.bicepsCurl,
      ),
      'Kontrollu indir...',
    );
  });

  test('biceps curl keeps elbow-control form feedback', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.legacyFormThresholdViolation,
        exerciseType: ExerciseType.bicepsCurl,
      ),
      'Dirseklerini sabit tut ve kollarini birlikte hareket ettir.',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.maintainForm,
        exerciseType: ExerciseType.bicepsCurl,
      ),
      'Dirseklerini sabit tut.',
    );
  });
}
