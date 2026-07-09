import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/core/firebase/firestore_paths.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';
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
        expect(repsSnapshot.docs, hasLength(2));
        expect(repsSnapshot.docs.first.id, 'rep_0001');
        expect(repsSnapshot.docs.last.id, 'rep_0002');
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
        expect(sessions.single.worstScore, 77.0);
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
