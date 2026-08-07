import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../achievements/presentation/providers/achievement_event_providers.dart';
import '../../../achievements/presentation/providers/achievements_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../challenges/presentation/providers/challenge_progress_providers.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../workout_analysis/presentation/providers/session_repository_provider.dart';
import '../../../workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import '../../application/services/reward_runtime_service.dart';
import 'reward_providers.dart';

final rewardRuntimeServiceProvider = Provider<RewardRuntimeService>((ref) {
  return RewardRuntimeService(
    sessionRepository: ref.watch(sessionRepositoryProvider),
    progressRepository: ref.watch(challengeProgressRepositoryProvider),
    rewardRepository: ref.watch(rewardLedgerRepositoryProvider),
    eventRepository: ref.watch(achievementEventRepositoryProvider),
    eventOutbox: ref.watch(achievementEventOutboxProvider),
  );
});

final rewardRuntimeBootstrapProvider = FutureProvider<void>((ref) async {
  final ownerId = ref.watch(currentUserIdProvider);
  if (ownerId == null) {
    return;
  }

  try {
    await ref
        .read(rewardRuntimeServiceProvider)
        .reconcileUser(ownerId: ownerId);
    ref.invalidate(challengeGoalsProvider);
    ref.invalidate(achievementsProvider);
    ref.invalidate(userSessionsSnapshotProvider);
  } catch (error, stackTrace) {
    developer.log(
      'Reward reconciliation failed without blocking app startup.',
      name: 'rewards.runtime.bootstrap',
      error: error,
      stackTrace: stackTrace,
    );
  }
});
