import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_report.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

void main() {
  group('SessionReport', () {
    test(
      'falls back to summary-only range-rep data when rep details are absent',
      () {
        final session = WorkoutSession(
          id: 'session_1',
          ownerId: 'owner_1',
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          startedAt: DateTime.utc(2026, 1, 1, 12),
          endedAt: DateTime.utc(2026, 1, 1, 12, 10),
          durationSec: 600,
          totalReps: 12,
          averageScore: 81.5,
          bestScore: 92.0,
          worstScore: 67.0,
          validReps: 9,
          lowConfidenceReps: 2,
          invalidReps: 2,
          formWarningCount: 3,
        );

        final report = SessionReport.fromSession(session: session);

        expect(report.isHoldSession, isFalse);
        expect(report.hasRepDetails, isFalse);
        expect(report.totalReps, 12);
        expect(report.validReps, 9);
        expect(report.lowConfidenceReps, 2);
        expect(report.invalidReps, 2);
        expect(report.unknownReps, 1);
        expect(report.averageScore, 81.5);
        expect(report.summaryMessage, contains('yalnızca özet verileri'));
        expect(report.recommendations, isNotEmpty);
      },
    );

    test(
      'derives range-rep rankings, issue aggregation, and recommendations',
      () {
        final session = WorkoutSession(
          id: 'session_1',
          ownerId: 'owner_1',
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          startedAt: DateTime.utc(2026, 1, 1, 12),
          endedAt: DateTime.utc(2026, 1, 1, 12, 10),
          durationSec: 600,
          totalReps: 2,
          averageScore: 0,
          bestScore: 0,
          worstScore: 0,
          validReps: 0,
          invalidReps: 0,
          formWarningCount: 2,
        );
        final reps = <WorkoutRep>[
          const WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            score: 91.0,
          ),
          const WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'invalid',
            validationReasons: <String>['insufficient rom', 'coverage loss'],
            score: 62.0,
            hadCoverageDrop: true,
            hadFormViolation: true,
          ),
          const WorkoutRep(
            repIndex: 3,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'low confidence',
            validationReasons: <String>[
              'coverage loss',
              'side switch during rep',
            ],
            score: 72.0,
            hadCoverageDrop: true,
            switchedSideDuringRep: true,
          ),
          const WorkoutRep(
            repIndex: 4,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'invalid',
            validationReasons: <String>['insufficient rom'],
            score: 58.0,
          ),
        ];

        final report = SessionReport.fromSession(session: session, reps: reps);

        expect(report.hasRepDetails, isTrue);
        expect(report.totalReps, 2);
        expect(report.validReps, 1);
        expect(report.lowConfidenceReps, 1);
        expect(report.invalidReps, 2);
        expect(report.unknownReps, 0);
        expect(report.averageScore, closeTo(81.5, 0.001));
        expect(report.bestScore, 91.0);
        expect(report.worstScore, 72.0);
        expect(report.topIssues.first, 'yetersiz hareket açıklığı');
        expect(report.topIssues, contains('görünürlük kaybı'));
        expect(report.coverageDropCount, 2);
        expect(report.sideSwitchCount, 1);
        expect(report.formViolationCount, 1);
        expect(report.bestReps.map((rep) => rep.repIndex), <int>[1, 3]);
        expect(report.weakestReps.map((rep) => rep.repIndex), <int>[3, 1]);
        expect(report.summaryMessage, contains('En sık sorun'));
        expect(
          report.recommendations.join(' '),
          allOf(contains('hareket açıklığını'), contains('Kamera açısını')),
        );
      },
    );

    test(
      'keeps unknown validation separate from invalid and handles null scores',
      () {
        final session = WorkoutSession(
          id: 'session_1',
          ownerId: 'owner_1',
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          startedAt: DateTime.utc(2026, 1, 1, 12),
          endedAt: DateTime.utc(2026, 1, 1, 12, 10),
          durationSec: 600,
          totalReps: 2,
          averageScore: 0,
          bestScore: 0,
          worstScore: 0,
          validReps: 0,
          invalidReps: 0,
          formWarningCount: 0,
        );
        final reps = <WorkoutRep>[
          const WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'unknown',
          ),
          const WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'low confidence',
            validationReasons: <String>['coverage loss'],
          ),
        ];

        final report = SessionReport.fromSession(session: session, reps: reps);

        expect(report.validReps, 0);
        expect(report.lowConfidenceReps, 1);
        expect(report.invalidReps, 0);
        expect(report.unknownReps, 1);
        expect(report.hasScoreData, isFalse);
        expect(report.bestReps, isEmpty);
        expect(report.weakestReps, isEmpty);
      },
    );

    test(
      'derives hold-session summary and recommendations from hold metrics',
      () {
        final session = WorkoutSession(
          id: 'session_hold',
          ownerId: 'owner_1',
          exerciseType: 'plank',
          analysisKind: 'hold',
          startedAt: DateTime.utc(2026, 1, 1, 12),
          endedAt: DateTime.utc(2026, 1, 1, 12, 5),
          durationSec: 300,
          totalReps: 0,
          averageScore: 0,
          bestScore: 0,
          worstScore: 0,
          validReps: 0,
          invalidReps: 0,
          formWarningCount: 0,
          totalHoldSeconds: 42,
          bestHoldSeconds: 18,
          formBreakCount: 2,
        );

        final report = SessionReport.fromSession(session: session);

        expect(report.isHoldSession, isTrue);
        expect(report.lowConfidenceReps, 0);
        expect(report.totalHoldSeconds, 42);
        expect(report.bestHoldSeconds, 18);
        expect(report.formBreakCount, 2);
        expect(report.summaryMessage, contains('Toplam 42 sn hold'));
        expect(report.recommendations.join(' '), contains('vücut çizgisini'));
      },
    );
  });
}
