import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_status_tone.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/session_result_visual.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  test('maps persisted session outcomes without inventing score data', () {
    final excellent = buildWorkoutSession(
      id: 'excellent',
      startedAt: DateTime(2024, 1, 1),
      averageScore: 92,
    );
    final completed = buildWorkoutSession(
      id: 'completed',
      startedAt: DateTime(2024, 1, 1),
      averageScore: 0,
    );

    expect(sessionResultTone(excellent), SessionResultTone.excellent);
    expect(sessionResultTone(completed), SessionResultTone.completed);
  });

  test('keeps valid, low-confidence, invalid and unknown reps distinct', () {
    const valid = WorkoutRep(
      repIndex: 1,
      exerciseType: 'squat',
      analysisKind: 'rangeRep',
      validationStatus: 'valid',
    );
    const lowConfidence = WorkoutRep(
      repIndex: 2,
      exerciseType: 'squat',
      analysisKind: 'rangeRep',
      validationStatus: 'lowConfidence',
    );
    const invalid = WorkoutRep(
      repIndex: 3,
      exerciseType: 'squat',
      analysisKind: 'rangeRep',
      validationStatus: 'invalid',
    );
    const unknown = WorkoutRep(
      repIndex: 4,
      exerciseType: 'squat',
      analysisKind: 'rangeRep',
    );

    expect(repStatusTone(valid), AppStatusTone.success);
    expect(repStatusTone(lowConfidence), AppStatusTone.caution);
    expect(repStatusTone(invalid), AppStatusTone.invalid);
    expect(repStatusTone(unknown), AppStatusTone.neutral);
  });
}
