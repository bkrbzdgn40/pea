enum AchievementEventType {
  guideStepOpened,
  plannedWorkoutCompleted,
  controlledTempoSession,
}

class AchievementEvent {
  AchievementEvent({
    required this.eventId,
    required this.type,
    required this.subjectId,
    required DateTime occurredAt,
  }) : occurredAtUtc = occurredAt.toUtc() {
    if (eventId.isEmpty || eventId.contains('/')) {
      throw ArgumentError.value(
        eventId,
        'eventId',
        'Must be a valid Firestore document id.',
      );
    }
    if (subjectId.isEmpty || subjectId.contains('/')) {
      throw ArgumentError.value(
        subjectId,
        'subjectId',
        'Must be non-empty and must not contain a slash.',
      );
    }
    final expectedEventId = switch (type) {
      AchievementEventType.guideStepOpened => 'guide-step:$subjectId',
      AchievementEventType.plannedWorkoutCompleted =>
        'planned-workout:$subjectId',
      AchievementEventType.controlledTempoSession =>
        'controlled-tempo:$subjectId',
    };
    if (eventId != expectedEventId) {
      throw ArgumentError.value(
        eventId,
        'eventId',
        'Must match the event type and subject.',
      );
    }
    if (type == AchievementEventType.guideStepOpened &&
        !const <String>{'1', '2', '3', '4', '5', '6'}.contains(subjectId)) {
      throw ArgumentError.value(
        subjectId,
        'subjectId',
        'Guide step must be between 1 and 6.',
      );
    }
  }

  factory AchievementEvent.guideStepOpened({
    required String stepId,
    required DateTime occurredAt,
  }) {
    return AchievementEvent(
      eventId: 'guide-step:$stepId',
      type: AchievementEventType.guideStepOpened,
      subjectId: stepId,
      occurredAt: occurredAt,
    );
  }

  factory AchievementEvent.plannedWorkoutCompleted({
    required String planRunId,
    required DateTime occurredAt,
  }) {
    return AchievementEvent(
      eventId: 'planned-workout:$planRunId',
      type: AchievementEventType.plannedWorkoutCompleted,
      subjectId: planRunId,
      occurredAt: occurredAt,
    );
  }

  factory AchievementEvent.controlledTempoSession({
    required String sessionId,
    required DateTime occurredAt,
  }) {
    return AchievementEvent(
      eventId: 'controlled-tempo:$sessionId',
      type: AchievementEventType.controlledTempoSession,
      subjectId: sessionId,
      occurredAt: occurredAt,
    );
  }

  final String eventId;
  final AchievementEventType type;
  final String subjectId;
  final DateTime occurredAtUtc;
}
