import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/user_workout_goal.dart';
import '../../domain/models/workout_goal_template.dart';

class UserWorkoutGoalFirestoreMapper {
  const UserWorkoutGoalFirestoreMapper();

  Map<String, Object?> toDocument(UserWorkoutGoal goal) {
    final template = templateForGoalType(goal.type);
    if (goal.id != goal.type.storageValue ||
        goal.ownerId.isEmpty ||
        goal.period != goal.type.period ||
        !template.accepts(goal.targetValue) ||
        goal.updatedAt.isBefore(goal.createdAt)) {
      throw ArgumentError.value(goal, 'goal', 'Invalid workout goal.');
    }

    return <String, Object?>{
      'id': goal.id,
      'ownerId': goal.ownerId,
      'type': goal.type.storageValue,
      'period': goal.period.storageValue,
      'targetValue': goal.type == WorkoutGoalType.averageScore
          ? goal.targetValue
          : goal.targetValue.toInt(),
      'status': goal.status.storageValue,
      'createdAt': Timestamp.fromDate(goal.createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(goal.updatedAt.toUtc()),
    };
  }

  UserWorkoutGoal fromDocument(Map<String, Object?> data) {
    final type = WorkoutGoalTypeStorage.tryParse(data['type'] as String?);
    final period = WorkoutGoalPeriodStorage.tryParse(data['period'] as String?);
    final status = WorkoutGoalStatusStorage.tryParse(data['status'] as String?);
    final id = data['id'];
    final ownerId = data['ownerId'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    final targetValue = data['targetValue'];
    final numericTarget = targetValue is num ? targetValue.toDouble() : null;

    if (id is! String ||
        id.isEmpty ||
        ownerId is! String ||
        ownerId.isEmpty ||
        type == null ||
        period == null ||
        status == null ||
        createdAt is! Timestamp ||
        updatedAt is! Timestamp ||
        numericTarget == null ||
        id != type.storageValue ||
        period != type.period ||
        !templateForGoalType(type).accepts(numericTarget) ||
        updatedAt.toDate().isBefore(createdAt.toDate())) {
      throw const FormatException('Invalid workout goal document.');
    }

    return UserWorkoutGoal(
      id: id,
      ownerId: ownerId,
      type: type,
      period: period,
      targetValue: numericTarget,
      status: status,
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt.toDate(),
    );
  }
}
