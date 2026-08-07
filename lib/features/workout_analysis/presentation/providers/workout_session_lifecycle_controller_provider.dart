import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../achievements/presentation/providers/achievements_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../rewards/presentation/providers/reward_runtime_providers.dart';
import '../../application/workout_session_lifecycle_controller.dart';
import 'completed_session_provider.dart';
import 'home_achievement_showcase_provider.dart';
import 'pending_preparation_outcome_provider.dart';
import 'session_repository_provider.dart';
import 'user_sessions_snapshot_provider.dart';

final workoutSessionLifecycleControllerProvider =
    Provider.autoDispose<WorkoutSessionLifecycleOwner>((ref) {
      return WorkoutSessionLifecycleController(
        sessionRepository: ref.watch(sessionRepositoryProvider),
        resolveOwnerId: () {
          final repositoryUserId = ref
              .read(authRepositoryProvider)
              .currentUserId;
          final providerUserId = ref.read(currentUserIdProvider);
          return repositoryUserId ?? providerUserId;
        },
        resolvePreparationOutcome: () =>
            ref.read(pendingPreparationOutcomeProvider),
        invalidateUserSessionsSnapshot: () {
          ref.invalidate(userSessionsSnapshotProvider);
        },
        publishCompletedSession: (session) {
          ref.read(completedSessionProvider.notifier).state = session;
        },
        onSessionPersisted: (session) async {
          await ref
              .read(rewardRuntimeServiceProvider)
              .syncPersistedSession(session: session);
          ref.invalidate(challengeGoalsProvider);
          ref.invalidate(achievementsProvider);
          ref.invalidate(homeAchievementShowcaseProvider);
        },
      );
    });
