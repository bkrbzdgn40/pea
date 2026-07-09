import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firebase_failures.dart';
import '../../../../core/firebase/firestore_paths.dart';
import '../../domain/models/workout_rep.dart';
import '../../domain/models/workout_session.dart';
import '../mappers/workout_rep_firestore_mapper.dart';
import '../mappers/workout_session_firestore_mapper.dart';

/// One-shot Firestore data source for user-owned workout sessions.
class FirestoreSessionRemoteSource {
  FirestoreSessionRemoteSource(
    this._firestore, {
    WorkoutSessionFirestoreMapper? sessionMapper,
    WorkoutRepFirestoreMapper? repMapper,
  }) : _sessionMapper = sessionMapper ?? const WorkoutSessionFirestoreMapper(),
       _repMapper = repMapper ?? const WorkoutRepFirestoreMapper();

  final FirebaseFirestore _firestore;
  final WorkoutSessionFirestoreMapper _sessionMapper;
  final WorkoutRepFirestoreMapper _repMapper;

  Future<void> saveSession(WorkoutSession session) async {
    try {
      final batch = _firestore.batch();
      final sessionDocument = _sessionDocument(session.ownerId, session.id);
      final repsCollection = _sessionRepsCollection(
        session.ownerId,
        session.id,
      );
      final existingRepDocuments = await repsCollection.get();

      for (final document in existingRepDocuments.docs) {
        batch.delete(document.reference);
      }

      batch.set(sessionDocument, _sessionMapper.toDocument(session));

      for (final rep in session.reps ?? const <WorkoutRep>[]) {
        final repId = _repMapper.documentIdFor(rep);
        batch.set(
          repsCollection.doc(repId),
          _repMapper.toDocument(rep: rep, session: session),
        );
      }

      await batch.commit();
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

      return _sessionMapper.fromDocument(
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

  Future<List<WorkoutRep>> listSessionReps({
    required String ownerId,
    required String sessionId,
  }) async {
    try {
      final snapshot = await _sessionRepsCollection(
        ownerId,
        sessionId,
      ).orderBy('repIndex').get();

      return snapshot.docs
          .map((document) => _repMapper.fromDocument(document.data()))
          .toList(growable: false);
    } on FirebaseException catch (error, stackTrace) {
      throw FirestoreFailure(
        message: 'Workout reps could not be listed.',
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
        return _sessionMapper.fromDocument(
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
      final batch = _firestore.batch();
      final repDocuments = await _sessionRepsCollection(
        ownerId,
        sessionId,
      ).get();

      for (final document in repDocuments.docs) {
        batch.delete(document.reference);
      }

      batch.delete(_sessionDocument(ownerId, sessionId));
      await batch.commit();
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

  CollectionReference<Map<String, dynamic>> _sessionRepsCollection(
    String ownerId,
    String sessionId,
  ) {
    return _firestore.collection(
      FirestorePaths.userSessionReps(ownerId, sessionId),
    );
  }

  DocumentReference<Map<String, dynamic>> _sessionDocument(
    String ownerId,
    String sessionId,
  ) {
    return _firestore.doc(FirestorePaths.userSessionDoc(ownerId, sessionId));
  }

  int _safeLimit(int limit) {
    return limit < 1 ? 1 : limit;
  }
}
