import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/core/firebase/firebase_failures.dart';
import 'package:pose_estimation_app/core/firebase/firestore_paths.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
import 'package:pose_estimation_app/features/workout_analysis/infrastructure/remote/firebase_session_write_auth_guard.dart';
import 'package:pose_estimation_app/features/workout_analysis/infrastructure/remote/firestore_session_remote_source.dart';

void main() {
  group('FirestoreSessionRemoteSource', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreSessionRemoteSource remoteSource;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      remoteSource = FirestoreSessionRemoteSource(firestore);
    });

    test(
      'saveSession stores the session summary document separately from rep docs',
      () async {
        final session = _session();

        await remoteSource.saveSession(session);

        final sessionSnapshot = await firestore
            .doc(FirestorePaths.userSessionDoc(session.ownerId, session.id))
            .get();
        final repsSnapshot = await firestore
            .collection(
              FirestorePaths.userSessionReps(session.ownerId, session.id),
            )
            .orderBy('repIndex')
            .get();

        expect(sessionSnapshot.exists, isTrue);
        expect(sessionSnapshot.data(), isNotNull);
        expect(sessionSnapshot.data()!.containsKey('reps'), isFalse);
        expect(sessionSnapshot.data()!['preparationOutcome'], 'passed');
        expect(sessionSnapshot.data()!['measurementQuality'], 'moderate');
        expect(sessionSnapshot.data()!['averageMeasurementConfidence'], 0.84);
        expect(sessionSnapshot.data()!['measurementSampleCount'], 2);
        expect(repsSnapshot.docs, hasLength(2));
        expect(repsSnapshot.docs.first.id, 'rep_0001');
        expect(repsSnapshot.docs.last.id, 'rep_0002');
      },
    );

    test(
      'saveSession publishes the session only after every rep write',
      () async {
        final writeExecutor = _RecordingSessionWriteExecutor();
        remoteSource = FirestoreSessionRemoteSource(
          firestore,
          writeExecutor: writeExecutor,
        );
        final session = _session();
        final sessionPath = FirestorePaths.userSessionDoc(
          session.ownerId,
          session.id,
        );
        final repsPath = FirestorePaths.userSessionReps(
          session.ownerId,
          session.id,
        );

        await remoteSource.saveSession(session);

        final sets = writeExecutor.operations
            .where((operation) => operation.kind == _WriteOperationKind.set)
            .toList(growable: false);
        expect(sets, hasLength(3));
        expect(sets.last.path, sessionPath);
        expect(
          sets
              .take(sets.length - 1)
              .every((operation) => operation.path.startsWith('$repsPath/')),
          isTrue,
        );
      },
    );

    test(
      'saveSession deletes stale reps before publishing the session',
      () async {
        final session = _session();
        final repsPath = FirestorePaths.userSessionReps(
          session.ownerId,
          session.id,
        );
        final sessionPath = FirestorePaths.userSessionDoc(
          session.ownerId,
          session.id,
        );
        final writeExecutor = _RecordingSessionWriteExecutor(
          existingRepPayloads: const <String, Map<String, dynamic>>{
            'rep_0001': <String, dynamic>{'marker': 'existing'},
            'rep_0099': <String, dynamic>{'marker': 'stale'},
          },
        );
        remoteSource = FirestoreSessionRemoteSource(
          firestore,
          writeExecutor: writeExecutor,
        );

        await remoteSource.saveSession(
          session.copyWith(reps: <WorkoutRep>[session.reps!.last]),
        );

        expect(
          writeExecutor.operations.map((operation) => operation.path),
          <String>['$repsPath/rep_0001', '$repsPath/rep_0099', sessionPath],
        );
        expect(
          writeExecutor.operations.map((operation) => operation.kind),
          <_WriteOperationKind>[
            _WriteOperationKind.set,
            _WriteOperationKind.delete,
            _WriteOperationKind.set,
          ],
        );
      },
    );

    test(
      'saveSession removes an earlier new rep when a later rep fails',
      () async {
        final session = _session();
        final repsPath = FirestorePaths.userSessionReps(
          session.ownerId,
          session.id,
        );
        var repSetCount = 0;
        String? firstWrittenRepPath;
        final writeExecutor = _RecordingSessionWriteExecutor(
          onOperation: (operation) async {
            if (operation.kind != _WriteOperationKind.set ||
                !operation.path.startsWith('$repsPath/')) {
              return;
            }
            repSetCount += 1;
            if (repSetCount == 1) {
              firstWrittenRepPath = operation.path;
              return;
            }
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            );
          },
        );
        remoteSource = FirestoreSessionRemoteSource(
          firestore,
          writeExecutor: writeExecutor,
        );

        await expectLater(
          remoteSource.saveSession(session),
          throwsA(isA<FirestoreFailure>()),
        );

        final deletedPaths = writeExecutor.operations
            .where((operation) => operation.kind == _WriteOperationKind.delete)
            .map((operation) => operation.path)
            .toSet();
        expect(firstWrittenRepPath, isNotNull);
        expect(deletedPaths, contains(firstWrittenRepPath));
      },
    );

    test('saveSession restores an overwritten rep when publish fails', () async {
      final session = _session();
      final sessionPath = FirestorePaths.userSessionDoc(
        session.ownerId,
        session.id,
      );
      final repPath =
          '${FirestorePaths.userSessionReps(session.ownerId, session.id)}/rep_0001';
      final writeExecutor = _RecordingSessionWriteExecutor(
        existingRepPayloads: const <String, Map<String, dynamic>>{
          'rep_0001': <String, dynamic>{'marker': 'before'},
        },
        onOperation: (operation) async {
          if (operation.kind == _WriteOperationKind.set &&
              operation.path == sessionPath) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            );
          }
        },
      );
      remoteSource = FirestoreSessionRemoteSource(
        firestore,
        writeExecutor: writeExecutor,
      );

      await expectLater(
        remoteSource.saveSession(
          session.copyWith(reps: <WorkoutRep>[session.reps!.last]),
        ),
        throwsA(isA<FirestoreFailure>()),
      );

      final repSets = writeExecutor.operations
          .where(
            (operation) =>
                operation.kind == _WriteOperationKind.set &&
                operation.path == repPath,
          )
          .toList(growable: false);
      expect(repSets, hasLength(2));
      expect(repSets.last.payload, <String, dynamic>{'marker': 'before'});
    });

    test(
      'saveSession restores a deleted stale rep when publish fails',
      () async {
        final session = _session();
        final repsPath = FirestorePaths.userSessionReps(
          session.ownerId,
          session.id,
        );
        final sessionPath = FirestorePaths.userSessionDoc(
          session.ownerId,
          session.id,
        );
        final writeExecutor = _RecordingSessionWriteExecutor(
          existingRepPayloads: const <String, Map<String, dynamic>>{
            'rep_0001': <String, dynamic>{'marker': 'existing'},
            'rep_0099': <String, dynamic>{'marker': 'stale'},
          },
          onOperation: (operation) async {
            if (operation.kind == _WriteOperationKind.set &&
                operation.path == sessionPath) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
              );
            }
          },
        );
        remoteSource = FirestoreSessionRemoteSource(
          firestore,
          writeExecutor: writeExecutor,
        );

        await expectLater(
          remoteSource.saveSession(
            session.copyWith(reps: <WorkoutRep>[session.reps!.last]),
          ),
          throwsA(isA<FirestoreFailure>()),
        );

        final staleOperations = writeExecutor.operations
            .where((operation) => operation.path == '$repsPath/rep_0099')
            .toList(growable: false);
        expect(staleOperations, hasLength(2));
        expect(staleOperations.first.kind, _WriteOperationKind.delete);
        expect(staleOperations.last.kind, _WriteOperationKind.set);
        expect(staleOperations.last.payload, <String, dynamic>{
          'marker': 'stale',
        });
      },
    );

    test(
      'rollback failure does not replace the original write failure',
      () async {
        final session = _session().copyWith(
          reps: <WorkoutRep>[_session().reps!.last],
        );
        final sessionPath = FirestorePaths.userSessionDoc(
          session.ownerId,
          session.id,
        );
        final writeExecutor = _RecordingSessionWriteExecutor(
          onOperation: (operation) async {
            if (operation.kind == _WriteOperationKind.set &&
                operation.path == sessionPath) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              );
            }
            if (operation.kind == _WriteOperationKind.delete) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
              );
            }
          },
        );
        remoteSource = FirestoreSessionRemoteSource(
          firestore,
          writeExecutor: writeExecutor,
        );

        await expectLater(
          remoteSource.saveSession(session),
          throwsA(
            isA<FirestoreFailure>().having(
              (failure) => (failure.cause as FirebaseException).code,
              'original Firebase code',
              'permission-denied',
            ),
          ),
        );
      },
    );

    test('permission denial retries the split write chain only once', () async {
      final session = _session();
      final sessionPath = FirestorePaths.userSessionDoc(
        session.ownerId,
        session.id,
      );
      final authGuard = _RecordingSessionWriteAuthGuard();
      var failedFirstPublish = false;
      final writeExecutor = _RecordingSessionWriteExecutor(
        onOperation: (operation) async {
          if (!failedFirstPublish &&
              operation.kind == _WriteOperationKind.set &&
              operation.path == sessionPath) {
            failedFirstPublish = true;
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            );
          }
        },
      );
      remoteSource = FirestoreSessionRemoteSource(
        firestore,
        authGuard: authGuard,
        writeExecutor: writeExecutor,
      );

      await remoteSource.saveSession(session);

      expect(authGuard.calls, <_AuthGuardCall>[
        const _AuthGuardCall(
          ownerId: 'owner_1',
          reloadUser: false,
          forceRefresh: false,
        ),
        const _AuthGuardCall(
          ownerId: 'owner_1',
          reloadUser: true,
          forceRefresh: true,
        ),
      ]);
      expect(
        writeExecutor.operations.where(
          (operation) =>
              operation.kind == _WriteOperationKind.set &&
              operation.path == sessionPath,
        ),
        hasLength(2),
      );
    });

    test('successful save does not invoke rollback writes', () async {
      final writeExecutor = _RecordingSessionWriteExecutor();
      remoteSource = FirestoreSessionRemoteSource(
        firestore,
        writeExecutor: writeExecutor,
      );

      await remoteSource.saveSession(_session());

      expect(
        writeExecutor.operations.where(
          (operation) => operation.kind == _WriteOperationKind.delete,
        ),
        isEmpty,
      );
    });

    test(
      'saveSession verifies the authenticated owner before writing',
      () async {
        final authGuard = _RecordingSessionWriteAuthGuard();
        remoteSource = FirestoreSessionRemoteSource(
          firestore,
          authGuard: authGuard,
        );
        final session = _session();

        await remoteSource.saveSession(session);

        expect(authGuard.calls, <_AuthGuardCall>[
          const _AuthGuardCall(
            ownerId: 'owner_1',
            reloadUser: false,
            forceRefresh: false,
          ),
        ]);
      },
    );

    test(
      'saveSession stops before writing when auth owner mismatches',
      () async {
        final authGuard = _RecordingSessionWriteAuthGuard(
          failure: AuthFailure(
            message:
                'Authenticated user does not match the workout session owner.',
            cause: StateError('authUid=other, ownerId=owner_1'),
          ),
        );
        remoteSource = FirestoreSessionRemoteSource(
          firestore,
          authGuard: authGuard,
        );
        final session = _session();

        await expectLater(
          remoteSource.saveSession(session),
          throwsA(
            isA<FirestoreFailure>().having(
              (failure) => failure.message,
              'message',
              'Workout session owner could not be authenticated.',
            ),
          ),
        );

        final snapshot = await firestore
            .doc(FirestorePaths.userSessionDoc(session.ownerId, session.id))
            .get();
        expect(snapshot.exists, isFalse);
      },
    );

    test(
      'listSessions returns summary-first sessions without loading reps',
      () async {
        final session = _session();

        await remoteSource.saveSession(session);
        final sessions = await remoteSource.listSessions(
          ownerId: session.ownerId,
        );

        expect(sessions, hasLength(1));
        expect(sessions.single.id, session.id);
        expect(sessions.single.totalReps, 2);
        expect(sessions.single.reps, isNull);
        expect(sessions.single.validReps, 1);
        expect(sessions.single.invalidReps, 1);
        expect(sessions.single.worstScore, 90.0);
      },
    );

    test(
      'listSessionReps returns reps ordered by repIndex ascending',
      () async {
        final session = _session();

        await remoteSource.saveSession(session);
        final reps = await remoteSource.listSessionReps(
          ownerId: session.ownerId,
          sessionId: session.id,
        );

        expect(reps.map((rep) => rep.repIndex).toList(), <int>[1, 2]);
        expect(reps.first.feedback, 'Guzel tempo');
        expect(reps.last.primaryValidationReason, 'insufficient rom');
      },
    );

    test(
      'listSessionReps returns an empty list for summary-only sessions',
      () async {
        final session = WorkoutSession(
          id: 'session_summary_only',
          ownerId: 'owner_1',
          exerciseType: 'squat',
          analysisKind: 'rangeRep',
          startedAt: DateTime.utc(2026, 1, 1, 12),
          endedAt: DateTime.utc(2026, 1, 1, 12, 10),
          durationSec: 600,
          totalReps: 2,
          averageScore: 83.5,
          bestScore: 90.0,
          worstScore: 77.0,
          validReps: 1,
          invalidReps: 1,
          formWarningCount: 2,
        );

        await remoteSource.saveSession(session);
        final reps = await remoteSource.listSessionReps(
          ownerId: session.ownerId,
          sessionId: session.id,
        );

        expect(reps, isEmpty);
      },
    );

    test(
      'deleteSession removes both the session document and rep subcollection',
      () async {
        final session = _session();

        await remoteSource.saveSession(session);
        await remoteSource.deleteSession(
          ownerId: session.ownerId,
          sessionId: session.id,
        );

        final sessionSnapshot = await firestore
            .doc(FirestorePaths.userSessionDoc(session.ownerId, session.id))
            .get();
        final repsSnapshot = await firestore
            .collection(
              FirestorePaths.userSessionReps(session.ownerId, session.id),
            )
            .get();

        expect(sessionSnapshot.exists, isFalse);
        expect(repsSnapshot.docs, isEmpty);
      },
    );

    test('deleteAllSessions removes every session and rep document', () async {
      final first = _session();
      final second = WorkoutSession(
        id: 'session_2',
        ownerId: first.ownerId,
        exerciseType: 'plank',
        analysisKind: 'hold',
        startedAt: DateTime.utc(2026, 1, 2, 12),
        endedAt: DateTime.utc(2026, 1, 2, 12, 1),
        durationSec: 60,
        totalReps: 0,
        averageScore: 0,
        bestScore: 0,
        formWarningCount: 0,
        totalHoldSeconds: 30,
        bestHoldSeconds: 30,
        reps: const <WorkoutRep>[],
      );

      await remoteSource.saveSession(first);
      await remoteSource.saveSession(second);
      await remoteSource.deleteAllSessions(ownerId: first.ownerId);

      final sessions = await firestore
          .collection(FirestorePaths.userSessions(first.ownerId))
          .get();
      final firstReps = await firestore
          .collection(FirestorePaths.userSessionReps(first.ownerId, first.id))
          .get();

      expect(sessions.docs, isEmpty);
      expect(firstReps.docs, isEmpty);
    });
  });
}

WorkoutSession _session() {
  return WorkoutSession(
    id: 'session_1',
    ownerId: 'owner_1',
    exerciseType: 'squat',
    analysisKind: 'rangeRep',
    startedAt: DateTime.utc(2026, 1, 1, 12),
    endedAt: DateTime.utc(2026, 1, 1, 12, 10),
    durationSec: 600,
    totalReps: 2,
    averageScore: 83.5,
    bestScore: 90.0,
    worstScore: 77.0,
    validReps: 1,
    invalidReps: 1,
    formWarningCount: 2,
    preparationOutcome: PreparationOutcome.passed,
    measurementQuality: SessionMeasurementQuality.moderate,
    averageMeasurementConfidence: 0.84,
    measurementSampleCount: 2,
    reps: <WorkoutRep>[
      WorkoutRep(
        repIndex: 2,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        recordedAt: DateTime.utc(2026, 1, 1, 12, 0, 4),
        validationStatus: 'invalid',
        validationReasons: const <String>['insufficient rom'],
        score: 77.0,
        minPrimaryMetric: 101.0,
        worstFormMetric: 54.0,
        descentMillis: 700,
        ascentMillis: 650,
        feedback: 'Daha derine in',
        selectedSideLabel: 'left',
      ),
      WorkoutRep(
        repIndex: 1,
        exerciseType: 'squat',
        analysisKind: 'rangeRep',
        recordedAt: DateTime.utc(2026, 1, 1, 12, 0, 2),
        validationStatus: 'valid',
        score: 90.0,
        minPrimaryMetric: 94.0,
        worstFormMetric: 43.0,
        descentMillis: 620,
        ascentMillis: 540,
        feedback: 'Guzel tempo',
        selectedSideLabel: 'right',
      ),
    ],
  );
}

class _RecordingSessionWriteAuthGuard implements SessionWriteAuthGuard {
  _RecordingSessionWriteAuthGuard({this.failure});

  final AuthFailure? failure;
  final List<_AuthGuardCall> calls = <_AuthGuardCall>[];

  @override
  Future<SessionWriteAuthSnapshot> verifyOwner({
    required String ownerId,
    required bool reloadUser,
    required bool forceRefresh,
  }) async {
    calls.add(
      _AuthGuardCall(
        ownerId: ownerId,
        reloadUser: reloadUser,
        forceRefresh: forceRefresh,
      ),
    );
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return SessionWriteAuthSnapshot(
      uid: ownerId,
      isAnonymous: true,
      reloadedUser: reloadUser,
      forcedTokenRefresh: forceRefresh,
      tokenPresent: true,
      audience: 'pose-estimation-app-dd06c',
      subject: ownerId,
      userIdClaim: ownerId,
      signInProvider: 'anonymous',
    );
  }
}

class _AuthGuardCall {
  const _AuthGuardCall({
    required this.ownerId,
    required this.reloadUser,
    required this.forceRefresh,
  });

  final String ownerId;
  final bool reloadUser;
  final bool forceRefresh;

  @override
  bool operator ==(Object other) {
    return other is _AuthGuardCall &&
        other.ownerId == ownerId &&
        other.reloadUser == reloadUser &&
        other.forceRefresh == forceRefresh;
  }

  @override
  int get hashCode => Object.hash(ownerId, reloadUser, forceRefresh);
}

enum _WriteOperationKind { set, delete }

class _RecordedWriteOperation {
  const _RecordedWriteOperation({
    required this.kind,
    required this.path,
    this.payload,
  });

  final _WriteOperationKind kind;
  final String path;
  final Map<String, dynamic>? payload;
}

class _RecordingSessionWriteExecutor implements FirestoreSessionWriteExecutor {
  _RecordingSessionWriteExecutor({
    this.existingRepPayloads = const <String, Map<String, dynamic>>{},
    this.onOperation,
  });

  final Map<String, Map<String, dynamic>> existingRepPayloads;
  final Future<void> Function(_RecordedWriteOperation operation)? onOperation;
  final List<_RecordedWriteOperation> operations = <_RecordedWriteOperation>[];

  @override
  Future<Map<String, Map<String, dynamic>>> loadRepPayloads(
    CollectionReference<Map<String, dynamic>> repsCollection,
  ) async {
    return <String, Map<String, dynamic>>{
      for (final entry in existingRepPayloads.entries)
        entry.key: Map<String, dynamic>.from(entry.value),
    };
  }

  @override
  Future<void> set(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, dynamic> payload,
  ) async {
    final operation = _RecordedWriteOperation(
      kind: _WriteOperationKind.set,
      path: document.path,
      payload: Map<String, dynamic>.from(payload),
    );
    operations.add(operation);
    final callback = onOperation;
    if (callback != null) {
      await callback(operation);
    }
  }

  @override
  Future<void> delete(DocumentReference<Map<String, dynamic>> document) async {
    final operation = _RecordedWriteOperation(
      kind: _WriteOperationKind.delete,
      path: document.path,
    );
    operations.add(operation);
    final callback = onOperation;
    if (callback != null) {
      await callback(operation);
    }
  }
}
