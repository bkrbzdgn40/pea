import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../challenges/domain/models/challenge_period.dart';
import '../../../challenges/presentation/providers/challenge_progress_providers.dart';
import '../../../rewards/application/repositories/reward_ledger_repository.dart';
import '../../../rewards/domain/models/achievement_reward.dart';
import '../../../rewards/domain/models/challenge_medal_reward.dart';
import '../../../rewards/domain/models/reward_history_cursor.dart';
import '../../../rewards/domain/models/user_reward.dart';
import '../../../rewards/presentation/providers/reward_providers.dart';
import '../../../workout_analysis/domain/models/workout_session.dart';
import '../../../workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import '../../application/runtime_achievement_facts_builder.dart';
import '../../application/session_achievement_facts_builder.dart';
import '../../domain/achievement_catalog.dart';
import '../../domain/achievement_evaluator.dart';
import '../../domain/models/achievement_definition.dart';
import '../../domain/models/achievement_evaluation.dart';
import '../../domain/models/achievement_visibility.dart';
import '../models/achievement.dart';
import 'achievement_event_providers.dart';

final achievementsOwnerIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserIdProvider);
});

final achievementsProvider = FutureProvider<AchievementsState>((ref) async {
  final providerOwnerId = ref.watch(achievementsOwnerIdProvider);
  final progressRepository = ref.watch(challengeProgressRepositoryProvider);
  final eventRepository = ref.watch(achievementEventRepositoryProvider);
  final rewardRepository = ref.watch(rewardLedgerRepositoryProvider);
  final snapshot = await ref.watch(userSessionsSnapshotProvider.future);

  if (snapshot.source == UserSessionsSnapshotSource.noUser) {
    return const AchievementsState(
      achievements: <Achievement>[],
      source: AchievementsDataSource.noUser,
    );
  }
  if (snapshot.source == UserSessionsSnapshotSource.error) {
    return const AchievementsState(
      achievements: <Achievement>[],
      source: AchievementsDataSource.error,
    );
  }

  final ownerId = _resolveOwnerId(
    sessions: snapshot.sessions,
    providerOwnerId: providerOwnerId,
  );
  if (ownerId == null) {
    return const AchievementsState(
      achievements: <Achievement>[],
      source: AchievementsDataSource.noUser,
    );
  }

  try {
    final contributions = await progressRepository.listContributions(
      ownerId: ownerId,
    );
    final events = await eventRepository.listEvents(ownerId: ownerId);
    final achievementRewards = await _listAllAchievementRewards(
      rewardRepository,
      ownerId,
    );
    final medalRewards = await _listAllChallengeMedals(
      rewardRepository,
      ownerId,
    );

    final weeklyMedals = medalRewards
        .where((reward) => reward.period == ChallengePeriod.weekly)
        .toList(growable: false);
    final runtimeFacts = const RuntimeAchievementFactsBuilder().build(
      contributions: contributions,
      events: events,
      weeklyMedals: weeklyMedals,
    );
    final historicalFacts = const SessionAchievementFactsBuilder().build(
      snapshot.sessions,
    );
    const evaluator = AchievementEvaluator();
    final rewardByAchievementId = <String, AchievementReward>{
      for (final reward in achievementRewards) reward.achievementId: reward,
    };

    final allPresentationAchievements = <Achievement>[];
    final visibleAndEarnedAchievements = <Achievement>[];
    for (final definition in AchievementCatalog.all) {
      var evaluation = evaluator.evaluate(definition, runtimeFacts);
      if (definition.allowsHistoricalBackfill) {
        final historical = evaluator.evaluate(definition, historicalFacts);
        if (historical.current > evaluation.current) {
          evaluation = historical;
        }
      }

      final reward = rewardByAchievementId[definition.id];
      final achievement = _presentationAchievement(
        definition: definition,
        evaluation: evaluation,
        persistedReward: reward,
      );
      allPresentationAchievements.add(achievement);
      if (definition.visibility == AchievementVisibility.visible ||
          achievement.isUnlocked) {
        visibleAndEarnedAchievements.add(achievement);
      }
    }

    final rewards = <UserReward>[...achievementRewards, ...medalRewards]
      ..sort(_compareRewardsNewestFirst);

    final source =
        contributions.isEmpty &&
            events.isEmpty &&
            achievementRewards.isEmpty &&
            medalRewards.isEmpty &&
            snapshot.sessions.isEmpty
        ? AchievementsDataSource.empty
        : AchievementsDataSource.real;

    return AchievementsState(
      achievements: visibleAndEarnedAchievements,
      source: source,
      rewards: rewards,
      recommendedAchievement: _selectRecommendedAchievement(
        allPresentationAchievements,
      ),
    );
  } catch (_) {
    return const AchievementsState(
      achievements: <Achievement>[],
      source: AchievementsDataSource.error,
    );
  }
});

class AchievementsState {
  const AchievementsState({
    required this.achievements,
    required this.source,
    this.rewards = const <UserReward>[],
    this.recommendedAchievement,
  });

  final List<Achievement> achievements;
  final AchievementsDataSource source;
  final List<UserReward> rewards;
  final Achievement? recommendedAchievement;

  bool get canPresent =>
      source == AchievementsDataSource.real ||
      source == AchievementsDataSource.empty;

  List<Achievement> get earnedAchievements {
    final earned = achievements
        .where((achievement) => achievement.isUnlocked)
        .toList(growable: false);
    earned.sort((left, right) {
      final leftAt = left.unlockedAtUtc;
      final rightAt = right.unlockedAtUtc;
      if (leftAt != null && rightAt != null) {
        final byDate = rightAt.compareTo(leftAt);
        if (byDate != 0) return byDate;
      } else if (leftAt != null) {
        return -1;
      } else if (rightAt != null) {
        return 1;
      }
      return left.id.compareTo(right.id);
    });
    return earned;
  }

  Achievement? get nextAchievement {
    final explicit = recommendedAchievement;
    if (explicit != null && !explicit.isUnlocked) {
      return explicit;
    }
    return _selectRecommendedAchievement(achievements);
  }

  int get medalCount => rewards.whereType<ChallengeMedalReward>().length;

  String get sourceMessage {
    return switch (source) {
      AchievementsDataSource.real => 'Gerçek ödül verisi',
      AchievementsDataSource.noUser => 'Kullanıcı oturumu bulunamadı',
      AchievementsDataSource.empty => 'Henüz ödül yok',
      AchievementsDataSource.error => 'Ödül verisi alınamadı',
    };
  }
}

enum AchievementsDataSource { real, noUser, empty, error }

String? _resolveOwnerId({
  required List<WorkoutSession> sessions,
  required String? providerOwnerId,
}) {
  if (sessions.isNotEmpty) {
    return sessions.first.ownerId;
  }
  return providerOwnerId;
}

Achievement _presentationAchievement({
  required AchievementDefinition definition,
  required AchievementEvaluation evaluation,
  required AchievementReward? persistedReward,
}) {
  final copy = _fallbackCopy(definition.id, evaluation);
  return Achievement(
    id: definition.id,
    title: copy.title,
    description: copy.description,
    isUnlocked: persistedReward != null || evaluation.isUnlocked,
    progress: persistedReward != null ? 1 : evaluation.normalizedProgress,
    requirementText: copy.requirement,
    current: evaluation.current,
    target: evaluation.target,
    unlockedAtUtc: persistedReward?.unlockedAtUtc,
    isSecret: definition.visibility == AchievementVisibility.hidden,
  );
}

Achievement? _selectRecommendedAchievement(Iterable<Achievement> achievements) {
  final byId = <String, Achievement>{
    for (final achievement in achievements) achievement.id: achievement,
  };
  const priority = <String>[
    'first_reliable_analysis',
    'guide_completed',
    'exercise_explorer_3',
    'balanced_explorer',
    'planned_workout_completed',
    'planned_workouts_5',
    'controlled_tempo',
    'reliable_sessions_5',
    'rhythm_30_days',
  ];

  for (final id in priority) {
    final achievement = byId[id];
    if (achievement == null || achievement.isUnlocked) {
      continue;
    }
    if (id == 'rhythm_30_days' && achievement.current < 21) {
      continue;
    }
    if (achievement.isSecret && id != 'rhythm_30_days') {
      continue;
    }
    return achievement;
  }
  return null;
}

Future<List<AchievementReward>> _listAllAchievementRewards(
  RewardLedgerRepository repository,
  String ownerId,
) async {
  final rewards = <AchievementReward>[];
  RewardHistoryCursor? cursor;
  do {
    final page = await repository.listAchievementRewards(
      ownerId: ownerId,
      limit: 50,
      startAfter: cursor,
    );
    rewards.addAll(page.items);
    cursor = page.nextCursor;
  } while (cursor != null);
  return rewards;
}

Future<List<ChallengeMedalReward>> _listAllChallengeMedals(
  RewardLedgerRepository repository,
  String ownerId,
) async {
  final rewards = <ChallengeMedalReward>[];
  RewardHistoryCursor? cursor;
  do {
    final page = await repository.listChallengeMedals(
      ownerId: ownerId,
      limit: 50,
      startAfter: cursor,
    );
    rewards.addAll(page.items);
    cursor = page.nextCursor;
  } while (cursor != null);
  return rewards;
}

int _compareRewardsNewestFirst(UserReward left, UserReward right) {
  final byDate = right.historyAtUtc.compareTo(left.historyAtUtc);
  if (byDate != 0) return byDate;
  return right.id.compareTo(left.id);
}

_AchievementCopy _fallbackCopy(String id, AchievementEvaluation evaluation) {
  return switch (id) {
    'first_reliable_analysis' => const _AchievementCopy(
      title: 'Güvenilir Başlangıç',
      description: 'İlk güvenilir hareket analizini tamamla.',
      requirement: 'İlk güvenilir analizini tamamla',
    ),
    'reliable_sessions_5' => _AchievementCopy(
      title: 'Sağlam Temel',
      description: 'Güvenilir analizlerle sağlam bir temel oluştur.',
      requirement: '${evaluation.current} / 5 güvenilir oturum',
    ),
    'exercise_explorer_3' => _AchievementCopy(
      title: 'Hareket Kaşifi',
      description: 'Farklı hareketleri güvenilir analizlerle keşfet.',
      requirement: '${evaluation.current} / 3 farklı egzersiz',
    ),
    'guide_completed' => _AchievementCopy(
      title: 'Hazır Başla',
      description: 'Analiz akışının bütün temel adımlarını incele.',
      requirement: '${evaluation.current} / 6 adım incelendi',
    ),
    'controlled_tempo' => const _AchievementCopy(
      title: 'Kontrollü Ritim',
      description: 'Tekrarlarını kontrollü ve ölçülebilir bir tempoda tamamla.',
      requirement: 'En az 5 tekrarı kontrollü tempoyla tamamla',
    ),
    'planned_workout_completed' => const _AchievementCopy(
      title: 'Plan Tamamlandı',
      description: 'İlk planlı antrenmanını baştan sona tamamla.',
      requirement: 'İlk planlı antrenmanını tamamla',
    ),
    'planned_workouts_5' => _AchievementCopy(
      title: 'Planına Sadık',
      description: 'Planlı antrenmanlarını düzenli biçimde tamamla.',
      requirement: '${evaluation.current} / 5 plan tamamlandı',
    ),
    'balanced_explorer' => _AchievementCopy(
      title: 'Dengeli Kaşif',
      description: 'Alt vücut, üst vücut ve core hareketlerini keşfet.',
      requirement: '${evaluation.current} / 3 bölge keşfedildi',
    ),
    'return_after_14_days' => const _AchievementCopy(
      title: 'Geri Dönüş',
      description:
          'Ara verdikten sonra güvenilir bir hareket günüyle geri dön.',
      requirement: 'Ritmine geri dön',
    ),
    'rhythm_30_days' => _AchievementCopy(
      title: 'Otuz Günlük Ritim',
      description: 'Nitelikli hareket günlerinden uzun bir ritim oluştur.',
      requirement: '${evaluation.current} / 30 nitelikli gün',
    ),
    'golden_week' => const _AchievementCopy(
      title: 'Altın Hafta',
      description: 'Bir haftada üç farklı egzersizde madalya kazan.',
      requirement: 'Aynı hafta 3 farklı egzersizde madalya kazan',
    ),
    _ => _AchievementCopy(title: id, description: id, requirement: id),
  };
}

class _AchievementCopy {
  const _AchievementCopy({
    required this.title,
    required this.description,
    required this.requirement,
  });

  final String title;
  final String description;
  final String requirement;
}
