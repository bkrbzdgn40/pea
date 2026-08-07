import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/outbox/achievement_event_outbox.dart';
import '../../domain/models/achievement_event.dart';

class SharedPreferencesAchievementEventOutbox
    implements AchievementEventOutbox {
  const SharedPreferencesAchievementEventOutbox();

  static const String _keyPrefix = 'pea.rewardEventOutbox.v1';

  @override
  Future<void> enqueue(PendingAchievementEvent pendingEvent) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey(pendingEvent.ownerId, pendingEvent.id),
      jsonEncode(_encode(pendingEvent)),
    );
  }

  @override
  Future<List<PendingAchievementEvent>> listPending({
    required String ownerId,
  }) async {
    _validateOwnerId(ownerId);
    final preferences = await SharedPreferences.getInstance();
    final ownerPrefix = '${_keyPrefix}_${_encodeKeyPart(ownerId)}_';
    final keys =
        preferences
            .getKeys()
            .where((key) => key.startsWith(ownerPrefix))
            .toList(growable: false)
          ..sort();
    final pending = <PendingAchievementEvent>[];
    for (final key in keys) {
      final raw = preferences.getString(key);
      if (raw == null) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Outbox payload must be a JSON object.');
        }
        final event = _decode(decoded);
        if (event.ownerId != ownerId) {
          throw const FormatException('Outbox owner mismatch.');
        }
        pending.add(event);
      } on FormatException {
        await preferences.remove(key);
      } on ArgumentError {
        await preferences.remove(key);
      }
    }
    pending.sort(
      (left, right) =>
          left.event.occurredAtUtc.compareTo(right.event.occurredAtUtc),
    );
    return List<PendingAchievementEvent>.unmodifiable(pending);
  }

  @override
  Future<void> remove({
    required String ownerId,
    required String eventId,
  }) async {
    _validateOwnerId(ownerId);
    if (eventId.isEmpty || eventId.contains('/')) {
      throw ArgumentError.value(eventId, 'eventId');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey(ownerId, eventId));
  }

  Map<String, Object> _encode(PendingAchievementEvent pendingEvent) {
    return <String, Object>{
      'ownerId': pendingEvent.ownerId,
      'eventId': pendingEvent.event.eventId,
      'type': _typeToWire(pendingEvent.event.type),
      'subjectId': pendingEvent.event.subjectId,
      'occurredAtUtc': pendingEvent.event.occurredAtUtc.toIso8601String(),
      'timezoneOffsetMinutes': pendingEvent.timezoneOffset.inMinutes,
    };
  }

  PendingAchievementEvent _decode(Map<String, dynamic> data) {
    final ownerId = data['ownerId'];
    final eventId = data['eventId'];
    final type = _typeFromWire(data['type']);
    final subjectId = data['subjectId'];
    final occurredAt = data['occurredAtUtc'];
    final timezoneOffsetMinutes = data['timezoneOffsetMinutes'];
    if (ownerId is! String ||
        eventId is! String ||
        type == null ||
        subjectId is! String ||
        occurredAt is! String ||
        timezoneOffsetMinutes is! int) {
      throw const FormatException('Invalid achievement event outbox payload.');
    }
    final parsedOccurredAt = DateTime.tryParse(occurredAt);
    if (parsedOccurredAt == null || !parsedOccurredAt.isUtc) {
      throw const FormatException('Outbox event time must be UTC ISO-8601.');
    }
    return PendingAchievementEvent(
      ownerId: ownerId,
      event: AchievementEvent(
        eventId: eventId,
        type: type,
        subjectId: subjectId,
        occurredAt: parsedOccurredAt,
      ),
      timezoneOffset: Duration(minutes: timezoneOffsetMinutes),
    );
  }

  String _storageKey(String ownerId, String eventId) {
    _validateOwnerId(ownerId);
    if (eventId.isEmpty || eventId.contains('/')) {
      throw ArgumentError.value(eventId, 'eventId');
    }
    return '${_keyPrefix}_${_encodeKeyPart(ownerId)}_${_encodeKeyPart(eventId)}';
  }
}

String _encodeKeyPart(String value) {
  return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
}

void _validateOwnerId(String ownerId) {
  if (ownerId.isEmpty || ownerId.contains('/')) {
    throw ArgumentError.value(ownerId, 'ownerId');
  }
}

String _typeToWire(AchievementEventType type) {
  return switch (type) {
    AchievementEventType.guideStepOpened => 'guideStepOpened',
    AchievementEventType.plannedWorkoutCompleted => 'plannedWorkoutCompleted',
    AchievementEventType.controlledTempoSession => 'controlledTempoSession',
  };
}

AchievementEventType? _typeFromWire(Object? value) {
  return switch (value) {
    'guideStepOpened' => AchievementEventType.guideStepOpened,
    'plannedWorkoutCompleted' => AchievementEventType.plannedWorkoutCompleted,
    'controlledTempoSession' => AchievementEventType.controlledTempoSession,
    _ => null,
  };
}
