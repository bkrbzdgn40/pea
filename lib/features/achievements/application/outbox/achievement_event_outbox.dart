import '../../domain/models/achievement_event.dart';

class PendingAchievementEvent {
  PendingAchievementEvent({
    required this.ownerId,
    required this.event,
    required this.timezoneOffset,
  }) {
    if (ownerId.isEmpty || ownerId.contains('/')) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Invalid owner id.');
    }
    if (timezoneOffset.abs() > const Duration(hours: 14) ||
        timezoneOffset.inSeconds % 60 != 0) {
      throw ArgumentError.value(timezoneOffset, 'timezoneOffset');
    }
  }

  final String ownerId;
  final AchievementEvent event;
  final Duration timezoneOffset;

  String get id => event.eventId;
}

abstract interface class AchievementEventOutbox {
  Future<void> enqueue(PendingAchievementEvent pendingEvent);

  Future<List<PendingAchievementEvent>> listPending({required String ownerId});

  Future<void> remove({required String ownerId, required String eventId});
}
