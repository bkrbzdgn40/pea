import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_report.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/session_report_ui_mapper.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  const tr = AppLocalizations(Locale('tr'));
  const en = AppLocalizations(Locale('en'));

  test(
    'localizes structured session report copy without changing domain data',
    () {
      final session = buildWorkoutSession(
        id: 'session-1',
        startedAt: DateTime(2024, 1, 1),
        totalReps: 2,
        averageScore: 72,
      );
      final report = SessionReport.fromSession(
        session: session,
        reps: const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'invalid',
            validationReasons: <String>['insufficient rom'],
            score: 60,
          ),
          WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            validationReasons: <String>[],
            score: 84,
          ),
        ],
      );

      expect(
        localizedSessionReportSummary(tr, report),
        contains('2 tekrar sayıldı'),
      );
      expect(
        localizedSessionReportSummary(en, report),
        contains('2 reps counted'),
      );
      expect(
        localizedSessionReportIssues(tr, report),
        contains('Yetersiz hareket açıklığı'),
      );
      expect(
        localizedSessionReportIssues(en, report),
        contains('Insufficient range of motion'),
      );
    },
  );

  test('localizes persisted range-rep feedback in either stored language', () {
    expect(
      localizeStoredWorkoutFeedback(
        feedback: 'Başarılı!',
        exerciseId: 'squat',
        localizations: en,
      ),
      'Rep completed!',
    );
    expect(
      localizeStoredWorkoutFeedback(
        feedback: 'Body is not clearly visible.',
        exerciseId: 'squat',
        localizations: tr,
      ),
      'Vücut net görünmüyor.',
    );
  });

  test('localizes legacy hold feedback persisted before localization', () {
    expect(
      localizeStoredWorkoutFeedback(
        feedback: 'Pozisyonu Koru',
        exerciseId: 'plank',
        localizations: en,
      ),
      'Hold the position.',
    );
  });
}
