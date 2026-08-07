import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../rewards/domain/models/achievement_reward.dart';
import '../../../rewards/presentation/providers/reward_providers.dart';

const int homeAchievementShowcaseLimit = 3;

final homeAchievementShowcaseOwnerIdProvider = Provider<String?>((ref) {
  try {
    return ref.watch(currentUserIdProvider);
  } catch (_) {
    // Home treats the showcase as optional. Auth/bootstrap failures must not
    // make the primary analysis actions unusable.
    return null;
  }
});

final homeAchievementShowcaseProvider =
    FutureProvider<HomeAchievementShowcaseData?>((ref) async {
      final ownerId = ref.watch(homeAchievementShowcaseOwnerIdProvider);
      if (ownerId == null) {
        return null;
      }

      final page = await ref
          .watch(rewardLedgerRepositoryProvider)
          .listAchievementRewards(
            ownerId: ownerId,
            limit: homeAchievementShowcaseLimit,
          );

      return HomeAchievementShowcaseData(
        rewards: page.items.take(homeAchievementShowcaseLimit).toList(),
      );
    });

class HomeAchievementShowcaseData {
  HomeAchievementShowcaseData({required List<AchievementReward> rewards})
    : rewards = List<AchievementReward>.unmodifiable(rewards);

  final List<AchievementReward> rewards;
}
