import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/presentation/models/achievement.dart';
import 'package:pose_estimation_app/features/achievements/presentation/providers/achievements_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/home_dashboard_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/home_dashboard_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/screens/home_screen.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets(
    'range-rep-only history keeps universal Home metrics without global scores',
    (WidgetTester tester) async {
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
          goalsProvider.overrideWith(
            (ref) => const GoalsState(
              source: GoalsDataSource.real,
              goals: <WorkoutGoal>[],
            ),
          ),
          achievementsProvider.overrideWith(
            (ref) => const AchievementsState(
              source: AchievementsDataSource.real,
              achievements: <Achievement>[],
            ),
          ),
        ],
      );
      await tester.pump();

      expect(find.text('Toplam Analiz'), findsOneWidget);
      expect(find.text('Bu Hafta'), findsOneWidget);
      expect(find.text('Ortalama Skor'), findsNothing);
      expect(find.text('En İyi Skor'), findsNothing);
      expect(find.text('Skor Trendi'), findsNothing);
    },
  );
}
