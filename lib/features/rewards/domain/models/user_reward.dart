import 'reward_kind.dart';

/// Shared contract for entries that can appear in the chronological reward log.
abstract interface class UserReward {
  String get id;
  String get ownerId;
  RewardKind get kind;
  DateTime get historyAtUtc;
  DateTime get createdAtUtc;
  DateTime get updatedAtUtc;
}
