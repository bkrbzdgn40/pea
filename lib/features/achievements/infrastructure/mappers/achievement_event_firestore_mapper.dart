import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/achievement_event.dart';
import '../../domain/models/achievement_event_record.dart';

class AchievementEventFirestoreMapper {
  const AchievementEventFirestoreMapper();

  Map<String, Object?> toDocument(AchievementEventRecord record) {
    return <String, Object?>{
      'id': record.id,
      'ownerId': record.ownerId,
      'type': _eventTypeToWire(record.event.type),
      'subjectId': record.event.subjectId,
      'occurredAt': Timestamp.fromDate(record.event.occurredAtUtc),
      'localDate': record.localDate,
      'timezoneOffsetMinutes': record.timezoneOffset.inMinutes,
      'createdAt': Timestamp.fromDate(record.createdAtUtc),
    };
  }

  AchievementEventRecord fromDocument({
    required String documentId,
    required Map<String, Object?> data,
  }) {
    final id = data['id'];
    final ownerId = data['ownerId'];
    final type = _eventTypeFromWire(data['type']);
    final subjectId = data['subjectId'];
    final occurredAt = data['occurredAt'];
    final localDate = data['localDate'];
    final offsetMinutes = data['timezoneOffsetMinutes'];
    final createdAt = data['createdAt'];

    if (id is! String ||
        id != documentId ||
        ownerId is! String ||
        type == null ||
        subjectId is! String ||
        occurredAt is! Timestamp ||
        localDate is! String ||
        offsetMinutes is! int ||
        createdAt is! Timestamp) {
      throw const FormatException('Invalid achievement event document.');
    }

    try {
      return AchievementEventRecord(
        ownerId: ownerId,
        event: AchievementEvent(
          eventId: id,
          type: type,
          subjectId: subjectId,
          occurredAt: occurredAt.toDate(),
        ),
        localDate: localDate,
        timezoneOffset: Duration(minutes: offsetMinutes),
        createdAt: createdAt.toDate(),
      );
    } on ArgumentError catch (error) {
      throw FormatException('Invalid achievement event document: $error');
    }
  }
}

String _eventTypeToWire(AchievementEventType type) {
  return switch (type) {
    AchievementEventType.guideStepOpened => 'guideStepOpened',
    AchievementEventType.plannedWorkoutCompleted => 'plannedWorkoutCompleted',
    AchievementEventType.controlledTempoSession => 'controlledTempoSession',
  };
}

AchievementEventType? _eventTypeFromWire(Object? value) {
  return switch (value) {
    'guideStepOpened' => AchievementEventType.guideStepOpened,
    'plannedWorkoutCompleted' => AchievementEventType.plannedWorkoutCompleted,
    'controlledTempoSession' => AchievementEventType.controlledTempoSession,
    _ => null,
  };
}
