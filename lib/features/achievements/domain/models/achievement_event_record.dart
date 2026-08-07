import 'achievement_event.dart';

class AchievementEventRecord {
  AchievementEventRecord({
    required this.ownerId,
    required this.event,
    required this.localDate,
    required this.timezoneOffset,
    required DateTime createdAt,
  }) : createdAtUtc = createdAt.toUtc() {
    if (ownerId.isEmpty || ownerId.contains('/')) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Invalid owner id.');
    }
    if (!_isValidLocalDate(localDate)) {
      throw ArgumentError.value(
        localDate,
        'localDate',
        'Expected a real YYYY-MM-DD date.',
      );
    }
    if (timezoneOffset.abs() > const Duration(hours: 14) ||
        timezoneOffset.inSeconds % 60 != 0) {
      throw ArgumentError.value(timezoneOffset, 'timezoneOffset');
    }
    if (localDate != _localDateFor(event.occurredAtUtc, timezoneOffset)) {
      throw ArgumentError.value(
        localDate,
        'localDate',
        'Does not match the event time and timezone offset.',
      );
    }
    if (createdAtUtc.isBefore(event.occurredAtUtc)) {
      throw ArgumentError('createdAt must not precede occurredAt.');
    }
  }

  final String ownerId;
  final AchievementEvent event;
  final String localDate;
  final Duration timezoneOffset;
  final DateTime createdAtUtc;

  String get id => event.eventId;
}

bool _isValidLocalDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return false;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

String _localDateFor(DateTime instant, Duration offset) {
  final wall = instant.toUtc().add(offset);
  return '${wall.year.toString().padLeft(4, '0')}-'
      '${wall.month.toString().padLeft(2, '0')}-'
      '${wall.day.toString().padLeft(2, '0')}';
}
