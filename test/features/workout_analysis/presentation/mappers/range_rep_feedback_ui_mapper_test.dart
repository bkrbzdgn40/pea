import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/range_rep_feedback_ui_mapper.dart';

void main() {
  test('squat keeps the existing directional and form copy', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.descend,
        exerciseType: ExerciseType.squat,
      ),
      'Asagi in...',
    );
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.keepBodyUpright,
        exerciseType: ExerciseType.squat,
      ),
      'Sirtini Dik Tut!',
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

  test('sit-up uses a form-appropriate feedback copy', () {
    expect(
      mapRangeRepFeedbackCodeToMessage(
        RangeRepFeedbackCode.keepBodyUpright,
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
}
