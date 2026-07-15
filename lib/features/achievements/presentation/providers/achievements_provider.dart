import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout_analysis/application/workout_statistics_calculator.dart';
import '../../../workout_analysis/domain/models/workout_session.dart';
import '../../../workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import '../data/demo_achievements.dart';
import '../models/achievement.dart';

final achievementsProvider = FutureProvider<AchievementsState>((ref) async {
  final snapshot = await ref.watch(userSessionsSnapshotProvider.future);

  return switch (snapshot.source) {
    UserSessionsSnapshotSource.real => AchievementsState(
      achievements: _buildAchievementsFromSessions(snapshot.sessions),
      source: AchievementsDataSource.real,
    ),
    UserSessionsSnapshotSource.noUser => const AchievementsState(
      achievements: demoAchievements,
      source: AchievementsDataSource.demoNoUser,
    ),
    UserSessionsSnapshotSource.empty => const AchievementsState(
      achievements: demoAchievements,
      source: AchievementsDataSource.demoEmpty,
    ),
    UserSessionsSnapshotSource.error => const AchievementsState(
      achievements: demoAchievements,
      source: AchievementsDataSource.demoError,
    ),
  };
});

class AchievementsState {
  const AchievementsState({required this.achievements, required this.source});

  final List<Achievement> achievements;
  final AchievementsDataSource source;

  bool get isFallback => source != AchievementsDataSource.real;

  String get sourceMessage {
    return switch (source) {
      AchievementsDataSource.real => 'Gerçek oturum verisi',
      AchievementsDataSource.demoNoUser =>
        'Kullanıcı verisi yok, örnek rozetler',
      AchievementsDataSource.demoEmpty => 'Henüz oturum yok, örnek rozetler',
      AchievementsDataSource.demoError =>
        'Rozet verisi alınamadı, örnek rozetler',
    };
  }
}

enum AchievementsDataSource { real, demoNoUser, demoEmpty, demoError }

List<Achievement> _buildAchievementsFromSessions(
  List<WorkoutSession> sessions,
) {
  final statistics = WorkoutStatisticsCalculator().calculate(sessions);

  return [
    Achievement(
      id: 'first_analysis',
      title: 'İlk Analiz',
      description: 'İlk canlı analiz oturumunu tamamladın.',
      isUnlocked: statistics.snapshotSessionCount >= 1,
      progress: statistics.snapshotSessionCount >= 1 ? 1 : 0,
      requirementText: '1 analiz tamamla',
    ),
    Achievement(
      id: 'score_90_plus',
      title: '90+ Skor',
      description: 'Yüksek form kalitesiyle güçlü bir oturum çıkar.',
      isUnlocked: statistics.bestScore >= 90,
      progress: statistics.bestScore / 90,
      requirementText: 'Bir oturumda 90+ en iyi skor al',
    ),
    Achievement(
      id: 'hundred_reps',
      title: '100 Tekrar',
      description: 'Toplam tekrar hacmini istikrarlı şekilde artır.',
      isUnlocked: statistics.snapshotTotalReps >= 100,
      progress: statistics.snapshotTotalReps / 100,
      requirementText: 'Toplam 100 tekrar tamamla',
    ),
    Achievement(
      id: 'ten_sessions',
      title: '10 Oturum',
      description: 'Antrenman geçmişini büyüt ve ritmini koru.',
      isUnlocked: statistics.snapshotSessionCount >= 10,
      progress: statistics.snapshotSessionCount / 10,
      requirementText: '10 analiz oturumu tamamla',
    ),
  ];
}
