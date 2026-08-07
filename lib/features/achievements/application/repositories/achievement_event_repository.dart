import '../../domain/models/achievement_event.dart';
import '../../domain/models/achievement_event_record.dart';

enum AchievementEventWriteStatus { created, unchanged }

class AchievementEventWriteResult {
  const AchievementEventWriteResult({
    required this.status,
    required this.record,
  });

  final AchievementEventWriteStatus status;
  final AchievementEventRecord record;
}

abstract interface class AchievementEventRepository {
  Future<AchievementEventWriteResult> recordEvent({
    required String ownerId,
    required AchievementEvent event,
    required Duration timezoneOffset,
    required DateTime now,
  });

  Future<List<AchievementEventRecord>> listEvents({required String ownerId});
}
