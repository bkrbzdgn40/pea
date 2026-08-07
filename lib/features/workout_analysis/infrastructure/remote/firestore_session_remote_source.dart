import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/firebase/firebase_failures.dart';
import '../../../../core/firebase/firestore_paths.dart';
import '../../domain/models/workout_rep.dart';
import '../../domain/models/workout_session.dart';
import '../mappers/workout_rep_firestore_mapper.dart';
import '../mappers/workout_session_firestore_mapper.dart';
import 'firebase_session_write_auth_guard.dart';
import 'firestore_workout_write_diagnostics.dart';

/// One-shot Firestore data source for user-owned workout sessions.
class FirestoreSessionRemoteSource {
  FirestoreSessionRemoteSource(
    this._firestore, {
    SessionWriteAuthGuard? authGuard,
    WorkoutSessionFirestoreMapper? sessionMapper,
    WorkoutRepFirestoreMapper? repMapper,
    FirestoreSessionWriteExecutor? writeExecutor,
  }) : _authGuard = authGuard,
       _sessionMapper = sessionMapper ?? const WorkoutSessionFirestoreMapper(),
       _repMapper = repMapper ?? const WorkoutRepFirestoreMapper(),
       _writeExecutor = writeExecutor ?? const _DefaultSessionWriteExecutor();

  final FirebaseFirestore _firestore;
  final SessionWriteAuthGuard? _authGuard;
  final WorkoutSessionFirestoreMapper _sessionMapper;
  final WorkoutRepFirestoreMapper _repMapper;
  final FirestoreSessionWriteExecutor _writeExecutor;

  Future<void> saveSession(WorkoutSession session) async {
    final sessionDocument = _sessionDocument(session.ownerId, session.id);
    final repsCollection = _sessionRepsCollection(session.ownerId, session.id);
    final sessionPayload = _sessionMapper.toDocument(session);
    final repWrites = (session.reps ?? const <WorkoutRep>[])
        .map((rep) {
          final repId = _repMapper.documentIdFor(rep);
          return _PendingRepWrite(
            document: repsCollection.doc(repId),
            repId: repId,
            payload: _repMapper.toDocument(rep: rep, session: session),
          );
        })
        .toList(growable: false);

    SessionWriteAuthSnapshot? initialAuth;
    try {
      initialAuth = await _verifySessionOwner(
        ownerId: session.ownerId,
        reloadUser: false,
        forceRefresh: false,
        stage: 'preflight',
      );
      await _commitSessionWrite(
        sessionDocument: sessionDocument,
        repsCollection: repsCollection,
        sessionPayload: sessionPayload,
        repWrites: repWrites,
      );
      return;
    } on FirebaseException catch (error, stackTrace) {
      if (error.code == 'permission-denied' && _authGuard != null) {
        try {
          final refreshedAuth = await _verifySessionOwner(
            ownerId: session.ownerId,
            reloadUser: true,
            forceRefresh: true,
            stage: 'permissionDeniedRetry',
          );
          await _commitSessionWrite(
            sessionDocument: sessionDocument,
            repsCollection: repsCollection,
            sessionPayload: sessionPayload,
            repWrites: repWrites,
          );
          if (kDebugMode) {
            developer.log(
              jsonEncode(<String, Object?>{
                'sessionPath': sessionDocument.path,
                'auth': refreshedAuth?.toDiagnosticJson(),
              }),
              name: 'workout.session.firestore.retrySucceeded',
            );
          }
          return;
        } on FirebaseException catch (retryError, retryStackTrace) {
          _logWriteFailure(
            error: retryError,
            stackTrace: retryStackTrace,
            session: session,
            sessionDocument: sessionDocument,
            sessionPayload: sessionPayload,
            repWrites: repWrites,
            initialAuth: initialAuth,
          );
          throw FirestoreFailure(
            message: 'Workout session could not be saved after auth refresh.',
            cause: retryError,
            stackTrace: retryStackTrace,
          );
        } on AuthFailure catch (authError, authStackTrace) {
          _logAuthFailure(
            error: authError,
            stackTrace: authStackTrace,
            sessionPath: sessionDocument.path,
          );
          throw FirestoreFailure(
            message: 'Workout session owner could not be authenticated.',
            cause: authError,
            stackTrace: authStackTrace,
          );
        }
      }

      _logWriteFailure(
        error: error,
        stackTrace: stackTrace,
        session: session,
        sessionDocument: sessionDocument,
        sessionPayload: sessionPayload,
        repWrites: repWrites,
        initialAuth: initialAuth,
      );
      throw FirestoreFailure(
        message: 'Workout session could not be saved.',
        cause: error,
        stackTrace: stackTrace,
      );
    } on AuthFailure catch (error, stackTrace) {
      _logAuthFailure(
        error: error,
        stackTrace: stackTrace,
        sessionPath: sessionDocument.path,
      );
      throw FirestoreFailure(
        message: 'Workout session owner could not be authenticated.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<SessionWriteAuthSnapshot?> _verifySessionOwner({
    required String ownerId,
    required bool reloadUser,
    required bool forceRefresh,
    required String stage,
  }) async {
    final authGuard = _authGuard;
    if (authGuard == null) {
      return null;
    }

    final snapshot = await authGuard.verifyOwner(
      ownerId: ownerId,
      reloadUser: reloadUser,
      forceRefresh: forceRefresh,
    );
    if (kDebugMode) {
      developer.log(
        jsonEncode(<String, Object?>{
          'stage': stage,
          ...snapshot.toDiagnosticJson(),
        }),
        name: 'workout.session.auth',
      );
    }
    return snapshot;
  }

  Future<void> _commitSessionWrite({
    required DocumentReference<Map<String, dynamic>> sessionDocument,
    required CollectionReference<Map<String, dynamic>> repsCollection,
    required Map<String, dynamic> sessionPayload,
    required List<_PendingRepWrite> repWrites,
  }) async {
    final existingRepsById = await _writeExecutor.loadRepPayloads(
      repsCollection,
    );
    final desiredRepIds = repWrites.map((write) => write.repId).toSet();

    try {
      // Firestore security rules have a 1,000-expression budget per request.
      // A single batch containing a full session and several rich rep payloads
      // can exceed that budget even when every document is valid. Keep each rep
      // as its own request, then publish the session summary last so History
      // cannot observe a new session before all rep documents are ready.
      for (final write in repWrites) {
        await _writeExecutor.set(write.document, write.payload);
      }

      for (final repId in existingRepsById.keys) {
        if (!desiredRepIds.contains(repId)) {
          await _writeExecutor.delete(repsCollection.doc(repId));
        }
      }

      await _writeExecutor.set(sessionDocument, sessionPayload);
    } catch (error, stackTrace) {
      await _restoreRepDocumentsAfterFailedSave(
        existingRepsById: existingRepsById,
        repsCollection: repsCollection,
        repWrites: repWrites,
        sessionPath: sessionDocument.path,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _restoreRepDocumentsAfterFailedSave({
    required Map<String, Map<String, dynamic>> existingRepsById,
    required CollectionReference<Map<String, dynamic>> repsCollection,
    required List<_PendingRepWrite> repWrites,
    required String sessionPath,
  }) async {
    try {
      final desiredRepIds = repWrites.map((write) => write.repId).toSet();

      for (final write in repWrites.reversed) {
        final existing = existingRepsById[write.repId];
        if (existing == null) {
          await _writeExecutor.delete(write.document);
        } else {
          await _writeExecutor.set(write.document, existing);
        }
      }

      for (final entry in existingRepsById.entries) {
        if (!desiredRepIds.contains(entry.key)) {
          await _writeExecutor.set(repsCollection.doc(entry.key), entry.value);
        }
      }
    } catch (cleanupError, cleanupStackTrace) {
      if (kDebugMode) {
        developer.log(
          jsonEncode(<String, Object?>{
            'sessionPath': sessionPath,
            'message': 'Rep rollback could not be completed.',
          }),
          name: 'workout.session.firestore.rollbackFailed',
          error: cleanupError,
          stackTrace: cleanupStackTrace,
        );
      }
    }
  }

  void _logWriteFailure({
    required FirebaseException error,
    required StackTrace stackTrace,
    required WorkoutSession session,
    required DocumentReference<Map<String, dynamic>> sessionDocument,
    required Map<String, dynamic> sessionPayload,
    required List<_PendingRepWrite> repWrites,
    required SessionWriteAuthSnapshot? initialAuth,
  }) {
    if (!kDebugMode) {
      return;
    }

    try {
      final report = FirestoreWorkoutWriteDiagnostics.buildReport(
        sessionPath: sessionDocument.path,
        ownerId: session.ownerId,
        sessionId: session.id,
        sessionPayload: sessionPayload,
        reps: repWrites
            .map(
              (write) => FirestoreRepWriteDiagnosticInput(
                path: write.document.path,
                repId: write.repId,
                payload: write.payload,
              ),
            )
            .toList(growable: false),
      );
      developer.log(
        jsonEncode(<String, Object?>{
          'firebaseCode': error.code,
          'firebaseMessage': error.message,
          'initialAuth': initialAuth?.toDiagnosticJson(),
          ...report,
        }),
        name: 'workout.session.firestore.denied',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (diagnosticError, diagnosticStackTrace) {
      developer.log(
        'Firestore write diagnostics could not be generated.',
        name: 'workout.session.firestore.diagnostics',
        error: diagnosticError,
        stackTrace: diagnosticStackTrace,
      );
    }
  }

  void _logAuthFailure({
    required AuthFailure error,
    required StackTrace stackTrace,
    required String sessionPath,
  }) {
    if (!kDebugMode) {
      return;
    }
    developer.log(
      jsonEncode(<String, Object?>{
        'sessionPath': sessionPath,
        'message': error.message,
        'cause': error.cause?.toString(),
      }),
      name: 'workout.session.auth.failed',
      error: error,
      stackTrace: stackTrace,
    );
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
      Query<Map<String, dynamic>> query = _sessionsCollection(ownerId);

      if (exerciseType != null) {
        query = query.where('exerciseType', isEqualTo: exerciseType);
      }

      query = query
          .orderBy('startedAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true);

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
      if (kDebugMode) {
        developer.log(
          jsonEncode(<String, Object?>{
            'ownerId': ownerId,
            'exerciseType': exerciseType,
            'limit': limit,
            'startAfterSessionId': startAfter?.id,
            'firebaseCode': error.code,
            'firebaseMessage': error.message,
          }),
          name: 'workout.session.firestore.listFailed',
          error: error,
          stackTrace: stackTrace,
        );
      }
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
      const deleteBatchSize = 400;
      final repsCollection = _sessionRepsCollection(ownerId, sessionId);

      while (true) {
        final repDocuments = await repsCollection.limit(deleteBatchSize).get();
        if (repDocuments.docs.isEmpty) {
          break;
        }

        final batch = _firestore.batch();
        for (final document in repDocuments.docs) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }

      await _sessionDocument(ownerId, sessionId).delete();
    } on FirebaseException catch (error, stackTrace) {
      throw FirestoreFailure(
        message: 'Workout session could not be deleted.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> deleteAllSessions({required String ownerId}) async {
    try {
      const sessionPageSize = 50;
      final sessionsCollection = _sessionsCollection(ownerId);

      while (true) {
        final sessionDocuments = await sessionsCollection
            .limit(sessionPageSize)
            .get();
        if (sessionDocuments.docs.isEmpty) {
          break;
        }

        for (final document in sessionDocuments.docs) {
          await deleteSession(ownerId: ownerId, sessionId: document.id);
        }
      }
    } on FirestoreFailure {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      throw FirestoreFailure(
        message: 'Workout history could not be deleted.',
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

/// Testable boundary for the non-atomic session-last write sequence.
abstract interface class FirestoreSessionWriteExecutor {
  Future<Map<String, Map<String, dynamic>>> loadRepPayloads(
    CollectionReference<Map<String, dynamic>> repsCollection,
  );

  Future<void> set(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, dynamic> payload,
  );

  Future<void> delete(DocumentReference<Map<String, dynamic>> document);
}

class _DefaultSessionWriteExecutor implements FirestoreSessionWriteExecutor {
  const _DefaultSessionWriteExecutor();

  @override
  Future<Map<String, Map<String, dynamic>>> loadRepPayloads(
    CollectionReference<Map<String, dynamic>> repsCollection,
  ) async {
    final snapshot = await repsCollection.get();
    return <String, Map<String, dynamic>>{
      for (final document in snapshot.docs)
        document.id: Map<String, dynamic>.from(document.data()),
    };
  }

  @override
  Future<void> set(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, dynamic> payload,
  ) {
    return document.set(payload);
  }

  @override
  Future<void> delete(DocumentReference<Map<String, dynamic>> document) {
    return document.delete();
  }
}

class _PendingRepWrite {
  const _PendingRepWrite({
    required this.document,
    required this.repId,
    required this.payload,
  });

  final DocumentReference<Map<String, dynamic>> document;
  final String repId;
  final Map<String, dynamic> payload;
}
