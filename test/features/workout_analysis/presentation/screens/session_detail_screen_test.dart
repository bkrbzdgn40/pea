import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/session_repository_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/session_detail_screen.dart';

import '../../../../support/presentation_test_support.dart';
import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets(
    'shows user-focused session results and hides raw technical metrics',
    (WidgetTester tester) async {
      final session = buildWorkoutSession(
        id: 'session-1',
        ownerId: 'owner-1',
        exerciseType: 'push_up',
        startedAt: DateTime(2024, 1, 5, 9, 30),
        totalReps: 1,
        averageScore: 89.6,
        bestScore: 93,
        durationSec: 65,
      );
      final repository = TestSessionRepository(
        sessionById: {'session-1': session},
        repsBySessionId: {
          'session-1': [
            WorkoutRep(
              repIndex: 1,
              exerciseType: 'push_up',
              analysisKind: 'rangeRep',
              validationStatus: 'valid',
              validationReasons: const <String>['insufficient rom'],
              score: 89.6,
              primaryRom: 72.4,
              tempoTotalMillis: 1800,
              minPrimaryMetric: 74.3,
              worstFormMetric: 81.2,
              feedback: 'Daha kontrollu cikis',
              selectedSideLabel: 'left',
              measurementConfidence: MeasurementConfidenceBreakdown(
                landmarkLikelihood: 0.99,
                signalAvailability: 1,
                geometryPlausibility: 1,
                temporalContinuity: 0.78,
                combined: 0.956,
                issues: const <MeasurementConfidenceIssue>[],
              ),
            ),
          ],
        },
      );

      await pumpTestApp(
        tester,
        home: SessionDetailScreen(session: session),
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();

      expect(find.text('Şınav'), findsOneWidget);
      expect(find.text('05.01.2024 09:30'), findsOneWidget);
      expect(find.textContaining('1:05'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('session-detail-primary-result'),
          ),
          matching: find.text('89.6'),
        ),
        findsOneWidget,
      );
      expect(find.text('Sayılmış: 1'), findsOneWidget);
      expect(find.text('Temiz: 0'), findsOneWidget);
      expect(find.text('İncelenmeli: 1'), findsOneWidget);
      expect(find.text('Hareket kalitesi'), findsOneWidget);
      expect(find.text('Sonraki odak'), findsOneWidget);
      expect(find.text('Tekrar Detayları'), findsOneWidget);
      expect(find.text('Tekrar 1'), findsOneWidget);
      expect(find.text('Kalite'), findsOneWidget);
      expect(find.text('Hareket açıklığı'), findsNothing);
      expect(find.text('Tempo'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('session-rep-metrics-1')),
          matching: find.text('89.6'),
        ),
        findsOneWidget,
      );
      expect(find.text('72.4°'), findsNothing);
      expect(find.text('1,8 sn'), findsOneWidget);
      expect(find.text('İncelenmeli'), findsOneWidget);
      expect(find.text('Sorun: Yetersiz hareket açıklığı'), findsOneWidget);
      expect(find.text('Geri bildirim: Daha kontrollu cikis'), findsOneWidget);

      expect(
        find.byKey(const ValueKey<String>('session-detail-technical-details')),
        findsNothing,
      );
      expect(find.text('Form ve Hareket Aralığı Skoru'), findsNothing);
      expect(find.text('Birincil Metrik'), findsNothing);
      expect(find.text('En Kötü Form'), findsNothing);
      expect(find.text('Sol'), findsNothing);
      expect(find.text('Ölçüm güveni'), findsNothing);
      expect(find.text('%96'), findsNothing);
    },
  );

  testWidgets(
    'formats biceps curl title through the canonical exercise string',
    (WidgetTester tester) async {
      final session = buildWorkoutSession(
        id: 'session-biceps',
        ownerId: 'owner-1',
        exerciseType: 'biceps_curl',
        startedAt: DateTime(2024, 1, 6, 10, 15),
        totalReps: 1,
        averageScore: 91.2,
        bestScore: 96,
        durationSec: 75,
      );

      await pumpTestApp(
        tester,
        home: SessionDetailScreen(session: session),
        overrides: [
          sessionRepositoryProvider.overrideWithValue(
            TestSessionRepository(sessionById: {'session-biceps': session}),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Biseps Curl'), findsOneWidget);
      expect(find.text('06.01.2024 10:15'), findsOneWidget);
    },
  );

  testWidgets('localizes review feedback and summary copy in English', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'session-en',
      ownerId: 'owner-1',
      exerciseType: 'push_up',
      startedAt: DateTime(2024, 1, 7, 11),
      totalReps: 1,
      averageScore: 90,
    );
    final repository = TestSessionRepository(
      sessionById: {'session-en': session},
      repsBySessionId: {
        'session-en': const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'push_up',
            analysisKind: 'rangeRep',
            validationStatus: 'lowConfidence',
            validationReasons: <String>[],
            score: 90,
            feedback: 'Başarılı!',
          ),
        ],
      },
    );

    await pumpTestApp(
      tester,
      locale: const Locale('en'),
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Push-up'), findsOneWidget);
    expect(
      find.textContaining('1 rep counted · 0 clean · 1 needs review'),
      findsOneWidget,
    );
    expect(find.text('Feedback: Rep completed!'), findsOneWidget);
  });

  testWidgets('shows only the most important recommendation', (
    WidgetTester tester,
  ) async {
    final baseSession = buildWorkoutSession(
      id: 'session-layered-recommendations',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 8, 9),
      totalReps: 1,
      averageScore: 70,
    );
    final session = baseSession.copyWith(formWarningCount: 1);
    final repository = TestSessionRepository(
      sessionById: {'session-layered-recommendations': session},
      repsBySessionId: {
        'session-layered-recommendations': const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            validationReasons: <String>[
              'insufficient rom',
              'persistent form break',
              'coverage loss',
            ],
            score: 70,
          ),
        ],
      },
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Daha derin tekrarlar için hareket açıklığını kontrollü biçimde artır.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tekrarlar arasında hareket açıklığını, gövde kontrolünü ve ritmi daha tutarlı korumaya çalış.',
      ),
      findsNothing,
    );
    expect(find.textContaining('Yetersiz hareket açıklığı'), findsWidgets);
  });

  testWidgets('shows a compact detail row for every rep', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'session-clean-overview',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 8, 10),
      totalReps: 7,
      averageScore: 82,
    );
    final reps = List<WorkoutRep>.generate(
      7,
      (index) => WorkoutRep(
        repIndex: index + 1,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        validationStatus: 'valid',
        score: 80 + index.toDouble(),
      ),
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [
        sessionRepositoryProvider.overrideWithValue(
          TestSessionRepository(
            sessionById: {'session-clean-overview': session},
            repsBySessionId: {'session-clean-overview': reps},
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    for (var index = 1; index <= 7; index++) {
      expect(
        find.byKey(ValueKey<String>('session-rep-detail-$index')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('session-rep-metrics-$index')),
        findsOneWidget,
      );
    }
    expect(find.text('Tüm sayılmış tekrarlar temiz tamamlandı.'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('session-rep-details')),
      findsOneWidget,
    );
  });

  testWidgets('shows two compact metrics for every rep', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'session-review-only',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 8, 10, 30),
      totalReps: 3,
      averageScore: 80,
    );
    const reps = <WorkoutRep>[
      WorkoutRep(
        repIndex: 1,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        validationStatus: 'valid',
        score: 90,
        primaryRom: 84,
        tempoTotalMillis: 1900,
      ),
      WorkoutRep(
        repIndex: 2,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        validationStatus: 'lowConfidence',
        score: 75,
        primaryRom: 61.5,
        tempoTotalMillis: 2400,
      ),
      WorkoutRep(
        repIndex: 3,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        validationStatus: 'valid',
        score: 100,
        primaryRom: 78,
        tempoTotalMillis: 2100,
      ),
      WorkoutRep(
        repIndex: 4,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        validationStatus: 'invalid',
        validationReasons: <String>['incomplete phase'],
        score: 60,
        primaryRom: 35,
        tempoTotalMillis: 900,
      ),
    ];

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [
        sessionRepositoryProvider.overrideWithValue(
          TestSessionRepository(
            sessionById: {'session-review-only': session},
            repsBySessionId: {'session-review-only': reps},
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    for (var index = 1; index <= 4; index++) {
      expect(
        find.byKey(ValueKey<String>('session-rep-detail-$index')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('session-rep-metrics-$index')),
        findsOneWidget,
      );
    }
    expect(find.text('84°'), findsNothing);
    expect(find.text('1,9 sn'), findsOneWidget);
    expect(find.text('61.5°'), findsNothing);
    expect(find.text('2,4 sn'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.textContaining('/100'), findsNothing);
    expect(find.text('Sayılmadı'), findsOneWidget);
    expect(find.text('Sorun: Eksik faz tamamlanması'), findsOneWidget);
    expect(
      find.textContaining('1 deneme tamamlanmadığı için sayılmadı.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses hold results without repetition language', (
    WidgetTester tester,
  ) async {
    final baseSession = buildWorkoutSession(
      id: 'session-hold-layered',
      ownerId: 'owner-1',
      exerciseType: 'plank',
      analysisKind: 'hold',
      startedAt: DateTime(2024, 1, 8, 11),
      durationSec: 60,
    );
    final session = baseSession.copyWith(
      totalHoldSeconds: 42,
      bestHoldSeconds: 18,
      formBreakCount: 2,
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [
        sessionRepositoryProvider.overrideWithValue(
          TestSessionRepository(sessionById: {'session-hold-layered': session}),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('0:18'), findsOneWidget);
    expect(find.text('En İyi Tutuş'), findsOneWidget);
    expect(find.text('Toplam Tutuş: 0:42'), findsOneWidget);
    expect(find.text('Form kesintisi: 2'), findsOneWidget);
    expect(find.text('Tekrar Detayları'), findsNothing);
    expect(find.textContaining('Sayılmış'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletes a session only after explicit confirmation', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'session-delete',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 8, 12),
      totalReps: 1,
    );
    final repository = TestSessionRepository(
      sessions: [session],
      sessionById: {'session-delete': session},
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await _openDeleteDialog(tester);

    expect(find.text('Oturum silinsin mi?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('session-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(repository.deletedSessionIds, ['session-delete']);
  });

  testWidgets('cancel keeps the saved session', (WidgetTester tester) async {
    final session = buildWorkoutSession(
      id: 'session-cancel',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 8, 12),
      totalReps: 1,
    );
    final repository = TestSessionRepository(
      sessionById: {'session-cancel': session},
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await _openDeleteDialog(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('session-delete-cancel')),
    );
    await tester.pumpAndSettle();

    expect(repository.deletedSessionIds, isEmpty);
  });

  testWidgets('shows an actionable error when deletion fails', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'session-failure',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 8, 12),
      totalReps: 1,
    );
    final repository = TestSessionRepository(
      sessionById: {'session-failure': session},
      deleteSessionError: StateError('offline'),
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await _openDeleteDialog(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('session-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Oturum silinemedi. Bağlantını kontrol edip tekrar dene.'),
      findsOneWidget,
    );
    expect(repository.deletedSessionIds, isEmpty);
  });

  testWidgets('uses a two-panel report with rep review on wide screens', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = buildWorkoutSession(
      id: 'session-wide-report',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 10, 12),
      totalReps: 2,
      averageScore: 84,
      durationSec: 50,
    );
    final repository = TestSessionRepository(
      sessionById: {'session-wide-report': session},
      repsBySessionId: {
        'session-wide-report': const <WorkoutRep>[
          WorkoutRep(
            repIndex: 1,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            score: 88,
          ),
          WorkoutRep(
            repIndex: 2,
            exerciseType: 'squat',
            analysisKind: 'rangeRep',
            validationStatus: 'lowConfidence',
            score: 80,
          ),
        ],
      },
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('session-detail-wide-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('session-rep-details')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('session-rep-detail-2')),
      findsOneWidget,
    );
    expect(find.text('İncelenmeli'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to one scroll column for compact large text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = buildWorkoutSession(
      id: 'session-large-text-report',
      ownerId: 'owner-1',
      exerciseType: 'standing_hip_abduction',
      startedAt: DateTime(2024, 1, 10, 13),
      totalReps: 1,
      averageScore: 82,
      durationSec: 45,
    );

    await pumpTestApp(
      tester,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(844, 390),
          textScaler: TextScaler.linear(2),
        ),
        child: SessionDetailScreen(session: session),
      ),
      overrides: [
        sessionRepositoryProvider.overrideWithValue(
          TestSessionRepository(
            sessionById: {'session-large-text-report': session},
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('session-detail-portrait-layout')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows only actionable measurement warnings', (
    WidgetTester tester,
  ) async {
    final session = buildWorkoutSession(
      id: 'session-evidence',
      ownerId: 'owner-1',
      exerciseType: 'squat',
      startedAt: DateTime(2024, 1, 11, 9),
      totalReps: 6,
      averageScore: 92,
      preparationOutcome: PreparationOutcome.overridden,
      measurementQuality: SessionMeasurementQuality.limited,
      averageMeasurementConfidence: 0.74,
      measurementSampleCount: 6,
    );

    await pumpTestApp(
      tester,
      home: SessionDetailScreen(session: session),
      overrides: [
        sessionRepositoryProvider.overrideWithValue(
          TestSessionRepository(sessionById: {'session-evidence': session}),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('session-detail-measurement-warning')),
      findsOneWidget,
    );
    expect(find.text('Hazırlık kontrolü atlandı'), findsOneWidget);
    expect(find.text('Ölçüm kalitesi'), findsNothing);
    expect(find.text('Manuel geçildi'), findsNothing);
    expect(find.text('%74'), findsNothing);
    expect(find.text('6 ölçüm örneği'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('session-detail-measurement-evidence')),
      findsNothing,
    );
  });
}

Future<void> _openDeleteDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('session-actions-menu')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey<String>('session-delete-menu-item')),
  );
  await tester.pumpAndSettle();
}
