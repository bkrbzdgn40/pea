import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/analytics_screen.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('shows dashboard charts on the dedicated Analytics screen', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AnalyticsScreen(),
      overrides: [
        homeDashboardProvider.overrideWith(
          (ref) => const HomeDashboardData(
            totalAnalyses: 9,
            averageScore: 0,
            thisWeekCount: 3,
            bestScore: 0,
            scoreTrend: <ScoreTrendPoint>[],
            exerciseDistribution: [
              ExerciseDistributionItem(
                label: 'Squat',
                value: 60,
                exerciseId: 'squat',
              ),
              ExerciseDistributionItem(
                label: 'Plank',
                value: 40,
                exerciseId: 'plank',
              ),
            ],
            source: HomeDashboardSource.real,
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Analitik'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('analytics-total-analyses')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('analytics-this-week')), findsOneWidget);
    expect(find.byKey(const Key('exercise-distribution-card')), findsOneWidget);
    expect(
      find.byKey(const Key('exercise-distribution-chart-surface')),
      findsOneWidget,
    );
  });

  testWidgets('keeps the empty Analytics screen usable with large text', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const AnalyticsScreen(),
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
      overrides: [
        homeDashboardProvider.overrideWith(
          (ref) =>
              HomeDashboardData.fallback(source: HomeDashboardSource.empty),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Analitik için henüz veri yok'), findsOneWidget);
    expectNoPresentationExceptions(tester);
  });
}
