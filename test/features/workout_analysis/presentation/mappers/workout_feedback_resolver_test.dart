import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/feedback_delivery_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/workout_feedback_resolver.dart';

void main() {
  const tr = AppLocalizations(Locale('tr'));
  const en = AppLocalizations(Locale('en'));

  test('caches range-rep message and cue for the same context', () {
    final subject = WorkoutFeedbackResolver();

    final first = subject.resolveRangeRep(
      code: RangeRepFeedbackCode.descend,
      localizations: tr,
      exerciseType: ExerciseType.squat,
    );
    final second = subject.resolveRangeRep(
      code: RangeRepFeedbackCode.descend,
      localizations: tr,
      exerciseType: ExerciseType.squat,
    );

    expect(second, same(first));
    expect(first.cue.id, 'range:descend');
    expect(first.cue.kind, FeedbackDeliveryKind.movement);
  });

  test('keeps language and exercise-specific range copy separate', () {
    final subject = WorkoutFeedbackResolver();

    final squatTr = subject.resolveRangeRep(
      code: RangeRepFeedbackCode.descend,
      localizations: tr,
      exerciseType: ExerciseType.squat,
    );
    final crunchTr = subject.resolveRangeRep(
      code: RangeRepFeedbackCode.descend,
      localizations: tr,
      exerciseType: ExerciseType.crunch,
    );
    final squatEn = subject.resolveRangeRep(
      code: RangeRepFeedbackCode.descend,
      localizations: en,
      exerciseType: ExerciseType.squat,
    );

    expect(crunchTr.message, isNot(squatTr.message));
    expect(squatEn.message, isNot(squatTr.message));
  });

  test('preserves hold fallback delivery identity', () {
    final subject = WorkoutFeedbackResolver();

    final fallback = subject.resolveHold(code: null, localizations: tr);
    final coded = subject.resolveHold(
      code: HoldFeedbackCode.preparePosition,
      localizations: tr,
    );

    expect(fallback.message, coded.message);
    expect(fallback.cue.id, 'hold:fallback:${fallback.message}');
    expect(coded.cue.id, 'hold:prepare_position');
    expect(coded.cue.kind, FeedbackDeliveryKind.status);
  });
}
