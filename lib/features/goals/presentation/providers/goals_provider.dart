import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout_analysis/application/workout_statistics_calculator.dart';
import '../../../workout_analysis/domain/models/workout_session.dart';
import '../../../workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import '../models/workout_goal.dart';

final goalsProvider = FutureProvider<GoalsState>((ref) async {
  final snapshot = await ref.watch(userSessionsSnapshotProvider.future);

  return switch (snapshot.source) {
    UserSessionsSnapshotSource.real => GoalsState(
      goals: _buildGoalsFromSessions(snapshot.sessions),
      source: GoalsDataSource.real,
    ),
    UserSessionsSnapshotSource.noUser => const GoalsState(
      goals: <WorkoutGoal>[],
      source: GoalsDataSource.noUser,
    ),
    UserSessionsSnapshotSource.empty => const GoalsState(
      goals: <WorkoutGoal>[],
      source: GoalsDataSource.empty,
    ),
    UserSessionsSnapshotSource.error => const GoalsState(
      goals: <WorkoutGoal>[],
      source: GoalsDataSource.error,
    ),
  };
});

class GoalsState {
  const GoalsState({required this.goals, required this.source});

  final List<WorkoutGoal> goals;
  final GoalsDataSource source;

  bool get isFallback => source != GoalsDataSource.real;

  String get sourceMessage {
    return switch (source) {
      GoalsDataSource.real => 'Gerçek oturum verisi',
      GoalsDataSource.noUser => 'Kullanıcı oturumu bulunamadı',
      GoalsDataSource.empty => 'Henüz oturum yok',
      GoalsDataSource.error => 'Hedef verisi alınamadı',
    };
  }
}

enum GoalsDataSource {
  real,
  noUser,
  empty,
  error;

  static const demoNoUser = noUser;
  static const demoEmpty = empty;
  static const demoError = error;
}

List<WorkoutGoal> _buildGoalsFromSessions(List<WorkoutSession> sessions) {
  final statistics = WorkoutStatisticsCalculator().calculate(sessions);

  return [
    WorkoutGoal(
      id: 'weekly_analysis_count',
      title: 'Haftalık 5 analiz',
      targetValue: 5,
      currentValue: statistics.currentWeekAnalysisCount.toDouble(),
      unit: 'analiz',
      description: 'Bu hafta en az 5 canlı analiz tamamla.',
      isCompleted: statistics.currentWeekAnalysisCount >= 5,
    ),
    WorkoutGoal(
      id: 'average_score_85',
      title: 'Ortalama skoru 85 üstüne çıkar',
      targetValue: 85,
      currentValue: statistics.averageScore,
      unit: 'skor',
      description: 'Form kalitesini koruyarak ortalama skorunu yükselt.',
      isCompleted: statistics.averageScore >= 85,
    ),
    WorkoutGoal(
      id: 'total_reps_200',
      title: 'Haftalık 200 tekrar',
      targetValue: 200,
      currentValue: statistics.currentWeekRepCount.toDouble(),
      unit: 'tekrar',
      description: 'Haftalık toplam tekrar hacmini kontrollü şekilde artır.',
      isCompleted: statistics.currentWeekRepCount >= 200,
    ),
  ];
}
