import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../workout_analysis/domain/models/workout_session.dart';
import '../../../workout_analysis/presentation/providers/session_repository_provider.dart';
import '../data/demo_workout_goals.dart';
import '../models/workout_goal.dart';

final goalsProvider = FutureProvider<GoalsState>((ref) async {
  final ownerId = ref.watch(currentUserIdProvider);
  if (ownerId == null) {
    return const GoalsState(
      goals: demoWorkoutGoals,
      source: GoalsDataSource.demoNoUser,
    );
  }

  try {
    final sessions = await ref
        .read(sessionRepositoryProvider)
        .listSessions(ownerId: ownerId, limit: 100);

    if (sessions.isEmpty) {
      return const GoalsState(
        goals: demoWorkoutGoals,
        source: GoalsDataSource.demoEmpty,
      );
    }

    return GoalsState(
      goals: _buildGoalsFromSessions(sessions),
      source: GoalsDataSource.real,
    );
  } catch (_) {
    return const GoalsState(
      goals: demoWorkoutGoals,
      source: GoalsDataSource.demoError,
    );
  }
});

class GoalsState {
  const GoalsState({required this.goals, required this.source});

  final List<WorkoutGoal> goals;
  final GoalsDataSource source;

  bool get isFallback => source != GoalsDataSource.real;

  String get sourceMessage {
    return switch (source) {
      GoalsDataSource.real => 'Gerçek oturum verisi',
      GoalsDataSource.demoNoUser => 'Kullanıcı verisi yok, örnek hedefler',
      GoalsDataSource.demoEmpty => 'Henüz oturum yok, örnek hedefler',
      GoalsDataSource.demoError => 'Hedef verisi alınamadı, örnek hedefler',
    };
  }
}

enum GoalsDataSource {
  real,
  demoNoUser,
  demoEmpty,
  demoError,
}

List<WorkoutGoal> _buildGoalsFromSessions(List<WorkoutSession> sessions) {
  final weeklyAnalysisCount = _countThisWeek(sessions);
  final totalReps = sessions.fold<int>(
    0,
    (total, session) => total + session.totalReps,
  );
  final averageScore =
      sessions.fold<double>(
        0,
        (total, session) => total + session.averageScore,
      ) /
      sessions.length;

  return [
    WorkoutGoal(
      id: 'weekly_analysis_count',
      title: 'Haftalık 5 analiz',
      targetValue: 5,
      currentValue: weeklyAnalysisCount.toDouble(),
      unit: 'analiz',
      description: 'Bu hafta en az 5 canlı analiz tamamla.',
      isCompleted: weeklyAnalysisCount >= 5,
    ),
    WorkoutGoal(
      id: 'average_score_85',
      title: 'Ortalama skoru 85 üstüne çıkar',
      targetValue: 85,
      currentValue: averageScore,
      unit: 'skor',
      description: 'Form kalitesini koruyarak ortalama skorunu yükselt.',
      isCompleted: averageScore >= 85,
    ),
    WorkoutGoal(
      id: 'total_reps_200',
      title: 'Toplam 200 tekrar',
      targetValue: 200,
      currentValue: totalReps.toDouble(),
      unit: 'tekrar',
      description: 'Haftalık toplam tekrar hacmini kontrollü şekilde artır.',
      isCompleted: totalReps >= 200,
    ),
    demoWorkoutGoals[3],
  ];
}

int _countThisWeek(List<WorkoutSession> sessions) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: now.weekday - 1));

  return sessions.where((session) {
    final startedAt = session.startedAt.toLocal();
    return !startedAt.isBefore(weekStart);
  }).length;
}
