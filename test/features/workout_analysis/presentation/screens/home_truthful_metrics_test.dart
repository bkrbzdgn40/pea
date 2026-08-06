import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('analytics metrics stay off the focused Home surface', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const HomeScreen(),
      overrides: [
        homeDashboardProvider.overrideWith(
          (ref) => const HomeDashboardData(
            totalAnalyses: 6,
            averageScore: 84,
            thisWeekCount: 3,
            bestScore: 92,
            scoreTrend: [
              ScoreTrendPoint(label: 'Pzt', score: 81),
              ScoreTrendPoint(label: 'Çar', score: 84),
              ScoreTrendPoint(label: 'Cum', score: 87),
            ],
            exerciseDistribution: [
              ExerciseDistributionItem(label: 'Squat', value: 100),
            ],
            source: HomeDashboardSource.real,
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.text('Toplam Analiz'), findsNothing);
    expect(find.text('Bu Hafta'), findsNothing);
    expect(find.text('Ortalama Skor'), findsNothing);
    expect(find.text('En İyi Skor'), findsNothing);
    expect(find.text('Skor Trendi'), findsNothing);
    expect(find.text('Analize Başla'), findsOneWidget);
  });
}
