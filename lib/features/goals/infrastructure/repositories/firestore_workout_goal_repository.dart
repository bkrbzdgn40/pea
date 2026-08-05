import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_paths.dart';
import '../../application/repositories/workout_goal_repository.dart';
import '../../domain/models/user_workout_goal.dart';
import '../mappers/user_workout_goal_firestore_mapper.dart';

class FirestoreWorkoutGoalRepository implements WorkoutGoalRepository {
  FirestoreWorkoutGoalRepository(
    this._firestore, {
    UserWorkoutGoalFirestoreMapper mapper =
        const UserWorkoutGoalFirestoreMapper(),
  }) : _mapper = mapper;

  final FirebaseFirestore _firestore;
  final UserWorkoutGoalFirestoreMapper _mapper;

  CollectionReference<Map<String, dynamic>> _collection(String ownerId) {
    return _firestore.collection(FirestorePaths.userGoals(ownerId));
  }

  @override
  Future<List<UserWorkoutGoal>> listGoals({required String ownerId}) async {
    final snapshot = await _collection(ownerId).get();
    final goals = snapshot.docs
        .map((document) => _mapper.fromDocument(document.data()))
        .toList(growable: false)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return goals;
  }

  @override
  Future<void> activateGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required double targetValue,
    required DateTime now,
  }) async {
    final collection = _collection(ownerId);
    final existingSnapshot = await collection.get();
    final existingById = <String, UserWorkoutGoal>{
      for (final document in existingSnapshot.docs)
        document.id: _mapper.fromDocument(document.data()),
    };
    final batch = _firestore.batch();

    for (final entry in existingById.entries) {
      if (entry.value.status == WorkoutGoalStatus.active &&
          entry.key != type.storageValue) {
        batch.update(collection.doc(entry.key), <String, Object?>{
          'status': WorkoutGoalStatus.paused.storageValue,
          'updatedAt': Timestamp.fromDate(now.toUtc()),
        });
      }
    }

    final existing = existingById[type.storageValue];
    final goal = UserWorkoutGoal(
      id: type.storageValue,
      ownerId: ownerId,
      type: type,
      period: type.period,
      targetValue: targetValue,
      status: WorkoutGoalStatus.active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    batch.set(collection.doc(goal.id), _mapper.toDocument(goal));
    await batch.commit();
  }

  @override
  Future<void> deleteAllGoals({required String ownerId}) async {
    final snapshot = await _collection(ownerId).get();
    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final document in snapshot.docs) {
      batch.delete(document.reference);
    }
    await batch.commit();
  }

  @override
  Future<void> pauseGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required DateTime now,
  }) async {
    final document = _collection(ownerId).doc(type.storageValue);
    await document.update(<String, Object?>{
      'status': WorkoutGoalStatus.paused.storageValue,
      'updatedAt': Timestamp.fromDate(now.toUtc()),
    });
  }
}
