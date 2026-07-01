import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  const AchievementsState({
    required this.achievements,
    required this.source,
  });

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

enum AchievementsDataSource {
  real,
  demoNoUser,
  demoEmpty,
  demoError,
}

List<Achievement> _buildAchievementsFromSessions(
  List<WorkoutSession> sessions,
) {
  final sessionCount = sessions.length;
  final totalReps = sessions.fold<int>(
    0,
    (total, session) => total + session.totalReps,
  );
  final bestScore = sessions.fold<double>(
    0,
    (best, session) => session.bestScore > best ? session.bestScore : best,
  );

  return [
    Achievement(
      id: 'first_analysis',
      title: 'İlk Analiz',
      description: 'İlk canlı analiz oturumunu tamamladın.',
      isUnlocked: sessionCount >= 1,
      progress: sessionCount >= 1 ? 1 : 0,
      requirementText: '1 analiz tamamla',
    ),
    demoAchievements[1],
    Achievement(
      id: 'score_90_plus',
      title: '90+ Skor',
      description: 'Yüksek form kalitesiyle güçlü bir oturum çıkar.',
      isUnlocked: bestScore >= 90,
      progress: bestScore / 90,
      requirementText: 'Bir oturumda 90+ en iyi skor al',
    ),
    Achievement(
      id: 'hundred_reps',
      title: '100 Tekrar',
      description: 'Toplam tekrar hacmini istikrarlı şekilde artır.',
      isUnlocked: totalReps >= 100,
      progress: totalReps / 100,
      requirementText: 'Toplam 100 tekrar tamamla',
    ),
    Achievement(
      id: 'ten_sessions',
      title: '10 Oturum',
      description: 'Antrenman geçmişini büyüt ve ritmini koru.',
      isUnlocked: sessionCount >= 10,
      progress: sessionCount / 10,
      requirementText: '10 analiz oturumu tamamla',
    ),
  ];
}
