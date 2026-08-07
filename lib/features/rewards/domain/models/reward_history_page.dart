import 'reward_history_cursor.dart';
import 'user_reward.dart';

class RewardHistoryPage<T extends UserReward> {
  RewardHistoryPage({required List<T> items, required this.nextCursor})
    : items = List.unmodifiable(items);

  final List<T> items;
  final RewardHistoryCursor? nextCursor;
}
