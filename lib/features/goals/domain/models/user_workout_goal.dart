enum WorkoutGoalType { weeklySessions, weeklyReps, averageScore }

enum WorkoutGoalPeriod { weekly, allTime }

enum WorkoutGoalStatus { active, paused }

extension WorkoutGoalTypeStorage on WorkoutGoalType {
  String get storageValue => switch (this) {
    WorkoutGoalType.weeklySessions => 'weeklySessions',
    WorkoutGoalType.weeklyReps => 'weeklyReps',
    WorkoutGoalType.averageScore => 'averageScore',
  };

  WorkoutGoalPeriod get period => switch (this) {
    WorkoutGoalType.weeklySessions || WorkoutGoalType.weeklyReps =>
      WorkoutGoalPeriod.weekly,
    WorkoutGoalType.averageScore => WorkoutGoalPeriod.allTime,
  };

  static WorkoutGoalType? tryParse(String? value) {
    return switch (value) {
      'weeklySessions' => WorkoutGoalType.weeklySessions,
      'weeklyReps' => WorkoutGoalType.weeklyReps,
      'averageScore' => WorkoutGoalType.averageScore,
      _ => null,
    };
  }
}

extension WorkoutGoalPeriodStorage on WorkoutGoalPeriod {
  String get storageValue => switch (this) {
    WorkoutGoalPeriod.weekly => 'weekly',
    WorkoutGoalPeriod.allTime => 'allTime',
  };

  static WorkoutGoalPeriod? tryParse(String? value) {
    return switch (value) {
      'weekly' => WorkoutGoalPeriod.weekly,
      'allTime' => WorkoutGoalPeriod.allTime,
      _ => null,
    };
  }
}

extension WorkoutGoalStatusStorage on WorkoutGoalStatus {
  String get storageValue => switch (this) {
    WorkoutGoalStatus.active => 'active',
    WorkoutGoalStatus.paused => 'paused',
  };

  static WorkoutGoalStatus? tryParse(String? value) {
    return switch (value) {
      'active' => WorkoutGoalStatus.active,
      'paused' => WorkoutGoalStatus.paused,
      _ => null,
    };
  }
}

class UserWorkoutGoal {
  const UserWorkoutGoal({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.period,
    required this.targetValue,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final WorkoutGoalType type;
  final WorkoutGoalPeriod period;
  final double targetValue;
  final WorkoutGoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == WorkoutGoalStatus.active;

  UserWorkoutGoal copyWith({
    double? targetValue,
    WorkoutGoalStatus? status,
    DateTime? updatedAt,
  }) {
    return UserWorkoutGoal(
      id: id,
      ownerId: ownerId,
      type: type,
      period: period,
      targetValue: targetValue ?? this.targetValue,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
