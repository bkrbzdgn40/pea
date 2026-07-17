import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/screens/goals_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('shows the shared loading state while goals are unresolved', (
    WidgetTester tester,
  ) async {
    final completer = Completer<GoalsState>();

    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
      overrides: [goalsProvider.overrideWith((ref) => completer.future)],
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      const GoalsState(
        source: GoalsDataSource.real,
        goals: <WorkoutGoal>[
          WorkoutGoal(
            id: 'weekly_analysis_count',
            title: 'Haftalik 5 analiz',
            targetValue: 5,
            currentValue: 3,
            unit: 'analiz',
            description: 'Bu hafta en az 5 canli analiz tamamla.',
            isCompleted: false,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Haftalik 5 analiz'), findsOneWidget);
  });

  testWidgets('shows the shared error state when loading goals fails', (
    WidgetTester tester,
  ) async {
    final completer = Completer<GoalsState>();

    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
      overrides: [goalsProvider.overrideWith((ref) => completer.future)],
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.completeError(Exception('boom'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Hedefler yüklenemedi. Lütfen daha sonra tekrar dene.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });

  testWidgets('renders real goals and preserves completed-goal visual state', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
      overrides: [
        goalsProvider.overrideWith(
          (ref) => GoalsState(
            source: GoalsDataSource.real,
            goals: const [
              WorkoutGoal(
                id: 'weekly_analysis_count',
                title: 'Haftalik 5 analiz',
                targetValue: 5,
                currentValue: 5,
                unit: 'analiz',
                description: 'Bu hafta en az 5 canli analiz tamamla.',
                isCompleted: true,
              ),
              WorkoutGoal(
                id: 'total_reps_200',
                title: 'Haftalik 200 tekrar',
                targetValue: 200,
                currentValue: 50,
                unit: 'tekrar',
                description: 'Haftalik toplam tekrar hacmini artir.',
                isCompleted: false,
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Haftalik 5 analiz'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsOneWidget);
    expect(find.text('%100'), findsOneWidget);
    expect(
      find.text('Haftalık ilerlemeni burada takip edeceksin'),
      findsOneWidget,
    );
  });

  testWidgets('renders fallback goals as the empty-state presentation', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
      overrides: [
        goalsProvider.overrideWith(
          (ref) => GoalsState(
            source: GoalsDataSource.empty,
            goals: const [
              WorkoutGoal(
                id: 'demo_goal',
                title: 'Demo hedef',
                targetValue: 10,
                currentValue: 2,
                unit: 'analiz',
                description: 'Ornek hedef',
                isCompleted: false,
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pump();

    expect(
      find.text('İlk analizini tamamladığında hedef ilerlemen burada görünür.'),
      findsOneWidget,
    );
    expect(find.text('Demo hedef'), findsNothing);
  });
}
