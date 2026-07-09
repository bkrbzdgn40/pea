import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_failures.dart';
import '../../../../core/firebase/firestore_paths.dart';
import '../../domain/models/workout_session.dart';

/// One-shot Firestore data source for user-owned workout sessions.
class FirestoreSessionRemoteSource {
  const FirestoreSessionRemoteSource(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> saveSession(WorkoutSession session) async {
    try {
      await _sessionDocument(
        session.ownerId,
        session.id,
      ).set(_toFirestoreData(session));
    } on FirebaseException catch (error, stackTrace) {
      throw FirestoreFailure(
        message: 'Workout session could not be saved.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<WorkoutSession?> getSessionById({
    required String ownerId,
    required String sessionId,
  }) async {
    try {
      final snapshot = await _sessionDocument(ownerId, sessionId).get();
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return _fromFirestoreData(
        data,
        fallbackId: snapshot.id,
        fallbackOwnerId: ownerId,
      );
    } on FirebaseException catch (error, stackTrace) {
      throw FirestoreFailure(
        message: 'Workout session could not be loaded.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<WorkoutSession>> listSessions({
    required String ownerId,
    int limit = 20,
    String? exerciseType,
    WorkoutSession? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _sessionsCollection(ownerId)
          .orderBy('startedAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true);

      if (exerciseType != null) {
        query = query.where('exerciseType', isEqualTo: exerciseType);
      }

      if (startAfter != null) {
        query = query.startAfter(<Object>[
          Timestamp.fromDate(startAfter.startedAt),
          startAfter.id,
        ]);
      }

      final snapshot = await query.limit(_safeLimit(limit)).get();

      return snapshot.docs.map((document) {
        return _fromFirestoreData(
          document.data(),
          fallbackId: document.id,
          fallbackOwnerId: ownerId,
        );
      }).toList();
    } on FirebaseException catch (error, stackTrace) {
      throw FirestoreFailure(
        message: 'Workout sessions could not be listed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> deleteSession({
    required String ownerId,
    required String sessionId,
  }) async {
    try {
      await _sessionDocument(ownerId, sessionId).delete();
    } on FirebaseException catch (error, stackTrace) {
      throw FirestoreFailure(
        message: 'Workout session could not be deleted.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  CollectionReference<Map<String, dynamic>> _sessionsCollection(
    String ownerId,
  ) {
    return _firestore.collection(FirestorePaths.userSessions(ownerId));
  }

  DocumentReference<Map<String, dynamic>> _sessionDocument(
    String ownerId,
    String sessionId,
  ) {
    return _firestore.doc(FirestorePaths.userSessionDoc(ownerId, sessionId));
  }

  Map<String, dynamic> _toFirestoreData(WorkoutSession session) {
    final now = DateTime.now();
    // Client timestamps keep the first Firestore integration deterministic.
    final createdAt = session.createdAt ?? now;
    final updatedAt = session.updatedAt ?? now;
    final firestoreData = <String, dynamic>{
      'id': session.id,
      'ownerId': session.ownerId,
      'exerciseType': session.exerciseType,
      'analysisKind': session.analysisKind,
      'startedAt': Timestamp.fromDate(session.startedAt),
      'endedAt': Timestamp.fromDate(session.endedAt),
      'durationSec': session.durationSec,
      'totalReps': session.totalReps,
      'averageScore': session.averageScore,
      'bestScore': session.bestScore,
      'formWarningCount': session.formWarningCount,
      'totalHoldSeconds': session.totalHoldSeconds,
      'bestHoldSeconds': session.bestHoldSeconds,
      'formBreakCount': session.formBreakCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    if (session.reps != null) {
      firestoreData['reps'] = session.reps!
          .map((rep) => rep.toMap())
          .toList(growable: false);
    }

    return firestoreData;
  }

  WorkoutSession _fromFirestoreData(
    Map<String, dynamic> data, {
    required String fallbackId,
    required String fallbackOwnerId,
  }) {
    // Keep Firebase Timestamp details out of the domain model.
    return WorkoutSession.fromMap(<String, Object?>{
      'id': data['id'] ?? fallbackId,
      'ownerId': data['ownerId'] ?? fallbackOwnerId,
      'exerciseType': data['exerciseType'],
      'analysisKind': data['analysisKind'],
      'startedAt': _toPlainDate(data['startedAt']),
      'endedAt': _toPlainDate(data['endedAt']),
      'durationSec': data['durationSec'],
      'totalReps': data['totalReps'],
      'averageScore': data['averageScore'],
      'bestScore': data['bestScore'],
      'formWarningCount': data['formWarningCount'],
      'totalHoldSeconds': data['totalHoldSeconds'],
      'bestHoldSeconds': data['bestHoldSeconds'],
      'formBreakCount': data['formBreakCount'],
      'reps': _toPlainRepsData(data['reps']),
      'createdAt': _toPlainDate(data['createdAt']),
      'updatedAt': _toPlainDate(data['updatedAt']),
    });
  }

  List<Map<String, Object?>>? _toPlainRepsData(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is Iterable) {
      return value
          .map((entry) => _toPlainRepData(entry))
          .toList(growable: false);
    }

    throw const FormatException('Expected list for "reps".');
  }

  Map<String, Object?> _toPlainRepData(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          if (entry.key is String)
            entry.key as String: entry.key == 'recordedAt'
                ? _toPlainDate(entry.value)
                : entry.value,
      };
    }

    throw const FormatException('Expected map entry for "reps".');
  }

  Object? _toPlainDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return value;
  }

  int _safeLimit(int limit) {
    return limit < 1 ? 1 : limit;
  }
}
