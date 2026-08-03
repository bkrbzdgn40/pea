import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/widgets/home_recent_session_card.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('shows truthful range-rep summary for the latest session', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: HomeRecentSessionCard(session: _rangeSession(), onTap: () {}),
    );
    await tester.pump();

    expect(find.text('Son Oturum'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('Toplam Tekrar'), findsOneWidget);
    expect(find.text('Geçerli'), findsOneWidget);
    expect(find.text('Ort. Skor'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('Oturumu Aç'), findsOneWidget);
  });

  testWidgets('hold summary does not invent rep or score metrics', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: HomeRecentSessionCard(session: _holdSession(), onTap: () {}),
    );
    await tester.pump();

    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('Süre'), findsOneWidget);
    expect(find.text('0:45'), findsOneWidget);
    expect(find.text('Form kesintisi'), findsOneWidget);
    expect(find.text('Toplam Tekrar'), findsNothing);
    expect(find.text('Ort. Skor'), findsNothing);
  });

  testWidgets('latest session card survives compact large-text layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpTestApp(
      tester,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: HomeRecentSessionCard(
              session: _rangeSession(),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('home-recent-session')), findsOneWidget);
  });
}

WorkoutSession _rangeSession() {
  return WorkoutSession(
    id: 'range-session',
    ownerId: 'owner',
    exerciseType: 'squat',
    startedAt: DateTime(2026, 8, 3, 10, 30),
    endedAt: DateTime(2026, 8, 3, 10, 31),
    durationSec: 60,
    totalReps: 12,
    averageScore: 88,
    bestScore: 94,
    validReps: 10,
    lowConfidenceReps: 1,
    invalidReps: 1,
    formWarningCount: 1,
  );
}

WorkoutSession _holdSession() {
  return WorkoutSession(
    id: 'hold-session',
    ownerId: 'owner',
    exerciseType: 'plank',
    analysisKind: 'hold',
    startedAt: DateTime(2026, 8, 3, 10, 30),
    endedAt: DateTime(2026, 8, 3, 10, 31),
    durationSec: 45,
    totalReps: 0,
    averageScore: 0,
    bestScore: 0,
    formWarningCount: 0,
    totalHoldSeconds: 45,
    bestHoldSeconds: 45,
    formBreakCount: 2,
  );
}
