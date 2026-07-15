import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/score_trend_detail_screen.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  testWidgets(
    'detail screen keeps best metric aligned with canonical average-score samples',
    (tester) async {
      final snapshot = UserSessionsSnapshot(
        sessions: [
          buildWorkoutSession(
            id: 'range-1',
            startedAt: DateTime(2024, 1, 1, 9),
            totalReps: 10,
            averageScore: 60,
            bestScore: 95,
          ),
          buildWorkoutSession(
            id: 'hold-1',
            startedAt: DateTime(2024, 1, 2, 9),
            exerciseType: 'plank',
            analysisKind: 'hold',
            totalReps: 0,
            averageScore: 0,
            bestScore: 0,
          ),
          buildWorkoutSession(
            id: 'range-2',
            startedAt: DateTime(2024, 1, 3, 9),
            totalReps: 12,
            averageScore: 69,
            bestScore: 100,
          ),
          buildWorkoutSession(
            id: 'range-3',
            startedAt: DateTime(2024, 1, 4, 9),
            totalReps: 8,
            averageScore: 65,
            bestScore: 65,
          ),
        ],
        source: UserSessionsSnapshotSource.real,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userSessionsSnapshotProvider.overrideWith((ref) async => snapshot),
          ],
          child: const MaterialApp(home: ScoreTrendDetailScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('01.01'), findsOneWidget);
      expect(find.text('03.01'), findsOneWidget);
      expect(find.text('04.01'), findsOneWidget);
      expect(find.text('02.01'), findsNothing);
      expect(find.text('Oturum'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('69'), findsOneWidget);
      expect(find.text('100'), findsNothing);
    },
  );
}
