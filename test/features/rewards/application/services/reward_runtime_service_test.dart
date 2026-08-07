import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/application/outbox/achievement_event_outbox.dart';
import 'package:pose_estimation_app/features/achievements/application/repositories/achievement_event_repository.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event_record.dart';
import 'package:pose_estimation_app/features/achievements/infrastructure/repositories/firestore_achievement_event_repository.dart';
import 'package:pose_estimation_app/features/challenges/infrastructure/repositories/firestore_challenge_progress_repository.dart';
import 'package:pose_estimation_app/features/rewards/application/services/reward_runtime_service.dart';
import 'package:pose_estimation_app/features/rewards/infrastructure/repositories/firestore_reward_ledger_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

import '../../../../support/presentation_test_support.dart';

void main() {
  group('RewardRuntimeService', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreChallengeProgressRepository progressRepository;
    late FirestoreRewardLedgerRepository rewardRepository;
    late FirestoreAchievementEventRepository eventRepository;
    late DateTime now;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      progressRepository = FirestoreChallengeProgressRepository(firestore);
      rewardRepository = FirestoreRewardLedgerRepository(firestore);
      eventRepository = FirestoreAchievementEventRepository(firestore);
      now = DateTime.utc(2026, 8, 7, 12);
    });

    RewardRuntimeService buildService(
      TestSessionRepository sessionRepository,
      DateTime Function() clock,
    ) {
      return RewardRuntimeService(
        sessionRepository: sessionRepository,
        progressRepository: progressRepository,
        rewardRepository: rewardRepository,
        eventRepository: eventRepository,
        clock: clock,
      );
    }

    test(
      'persists progress, awards a medal, and deduplicates session retries',
      () async {
        final session = _trustedSession(id: 'session-1', validReps: 10);
        final sessionRepository = TestSessionRepository(sessions: [session]);
        final service = buildService(sessionRepository, () => now);

        await service.syncPersistedSession(session: session);
        await service.syncPersistedSession(session: session);

        final contribution = await progressRepository.getContribution(
          ownerId: 'user-1',
          sessionId: 'session-1',
        );
        final day = await progressRepository.getActivityDay(
          ownerId: 'user-1',
          localDate: '2026-08-07',
        );
        final medals = await rewardRepository.listChallengeMedals(
          ownerId: 'user-1',
        );
        final achievements = await rewardRepository.listAchievementRewards(
          ownerId: 'user-1',
        );

        expect(contribution?.contribution.value, 10);
        expect(day?.trustedSessionCount, 1);
        expect(day?.validRepsByExercise.values.single, 10);
        expect(
          medals.items.any((reward) => reward.period.name == 'daily'),
          isTrue,
        );
        expect(
          achievements.items.any(
            (reward) => reward.achievementId == 'first_reliable_analysis',
          ),
          isTrue,
        );
      },
    );

    test(
      'a later untrusted rewrite removes active progress but keeps earned rewards',
      () async {
        final trusted = _trustedSession(id: 'session-1', validReps: 10);
        final untrusted = _trustedSession(
          id: 'session-1',
          validReps: 10,
          quality: SessionMeasurementQuality.limited,
          preparationOutcome: PreparationOutcome.overridden,
          confidence: 0.7,
        );
        final sessionRepository = TestSessionRepository(sessions: [untrusted]);
        final service = buildService(sessionRepository, () => now);

        await service.syncPersistedSession(session: trusted);
        await service.syncPersistedSession(session: untrusted);

        expect(
          await progressRepository.getContribution(
            ownerId: 'user-1',
            sessionId: 'session-1',
          ),
          isNull,
        );
        expect(
          (await rewardRepository.listChallengeMedals(ownerId: 'user-1')).items,
          isNotEmpty,
        );
      },
    );

    test(
      'controlled tempo creates its event and unlocks the achievement',
      () async {
        final reps = List<WorkoutRep>.generate(
          5,
          (index) => WorkoutRep(
            repIndex: index + 1,
            exerciseType: 'push_up',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            tempoMeasurementStatus: 'eligible',
            tempoQuality: 'target',
          ),
        );
        final session = _trustedSession(
          id: 'session-tempo',
          validReps: 5,
          reps: reps,
        );
        final service = buildService(
          TestSessionRepository(sessions: [session]),
          () => now,
        );

        await service.syncPersistedSession(session: session);

        final events = await eventRepository.listEvents(ownerId: 'user-1');
        final rewards = await rewardRepository.listAchievementRewards(
          ownerId: 'user-1',
        );
        expect(
          events.any(
            (record) =>
                record.event.eventId == 'controlled-tempo:session-tempo',
          ),
          isTrue,
        );
        expect(
          rewards.items.any(
            (reward) => reward.achievementId == 'controlled_tempo',
          ),
          isTrue,
        );
      },
    );

    test(
      'reconciliation recovers controlled tempo from persisted rep details',
      () async {
        final reps = List<WorkoutRep>.generate(
          5,
          (index) => WorkoutRep(
            repIndex: index + 1,
            exerciseType: 'push_up',
            analysisKind: 'rangeRep',
            validationStatus: 'valid',
            tempoMeasurementStatus: 'eligible',
            tempoQuality: 'target',
          ),
        );
        final session = _trustedSession(
          id: 'session-tempo-reconcile',
          validReps: 5,
        );
        final service = buildService(
          TestSessionRepository(
            sessions: [session],
            repsBySessionId: {'session-tempo-reconcile': reps},
          ),
          () => now,
        );

        await service.reconcileUser(ownerId: 'user-1');

        expect(
          (await eventRepository.listEvents(ownerId: 'user-1')).any(
            (record) =>
                record.event.eventId ==
                'controlled-tempo:session-tempo-reconcile',
          ),
          isTrue,
        );
        expect(
          await rewardRepository.getAchievementReward(
            ownerId: 'user-1',
            rewardId: 'achievement:controlled_tempo',
          ),
          isNotNull,
        );
      },
    );

    test('six unique guide steps unlock Hazır Başla', () async {
      final service = buildService(TestSessionRepository(), () => now);
      for (var step = 1; step <= 6; step += 1) {
        await service.recordGuideStep(
          ownerId: 'user-1',
          stepId: '$step',
          occurredAt: now,
          timezoneOffset: Duration.zero,
        );
      }

      final reward = await rewardRepository.getAchievementReward(
        ownerId: 'user-1',
        rewardId: 'achievement:guide_completed',
      );
      expect(reward, isNotNull);
    });

    test(
      'five unique completed plan runs unlock both plan achievements',
      () async {
        final service = buildService(TestSessionRepository(), () => now);
        for (var index = 0; index < 5; index += 1) {
          await service.recordPlannedWorkoutCompletion(
            ownerId: 'user-1',
            planRunId: 'plan_run_$index',
            totalSets: 3,
            completedSets: 3,
            allSetSessionsPersisted: true,
            completedAt: now.subtract(Duration(minutes: 5 - index)),
            timezoneOffset: Duration.zero,
          );
        }

        expect(
          await rewardRepository.getAchievementReward(
            ownerId: 'user-1',
            rewardId: 'achievement:planned_workout_completed',
          ),
          isNotNull,
        );
        expect(
          await rewardRepository.getAchievementReward(
            ownerId: 'user-1',
            rewardId: 'achievement:planned_workouts_5',
          ),
          isNotNull,
        );
      },
    );

    test(
      'reconciliation flushes a runtime event left in the local outbox',
      () async {
        final outbox = _MemoryAchievementEventOutbox();
        final failingRepository = _FailOnceAchievementEventRepository(
          eventRepository,
        );
        final firstService = RewardRuntimeService(
          sessionRepository: TestSessionRepository(),
          progressRepository: progressRepository,
          rewardRepository: rewardRepository,
          eventRepository: failingRepository,
          eventOutbox: outbox,
          clock: () => now,
        );

        await expectLater(
          firstService.recordGuideStep(
            ownerId: 'user-1',
            stepId: '1',
            occurredAt: now,
            timezoneOffset: Duration.zero,
          ),
          throwsStateError,
        );
        expect(await outbox.listPending(ownerId: 'user-1'), hasLength(1));

        final recoveryService = RewardRuntimeService(
          sessionRepository: TestSessionRepository(),
          progressRepository: progressRepository,
          rewardRepository: rewardRepository,
          eventRepository: eventRepository,
          eventOutbox: outbox,
          clock: () => now.add(const Duration(minutes: 1)),
        );
        final report = await recoveryService.reconcileUser(ownerId: 'user-1');

        expect(report.flushedPendingEvents, 1);
        expect(await outbox.listPending(ownerId: 'user-1'), isEmpty);
        expect(
          await eventRepository.listEvents(ownerId: 'user-1'),
          hasLength(1),
        );
      },
    );

    test(
      'reconciliation never invents medal progress for a session without a captured timezone',
      () async {
        final legacySession = _trustedSession(
          id: 'legacy-without-zone',
          validReps: 12,
          timezoneOffset: null,
        );
        final service = buildService(
          TestSessionRepository(sessions: [legacySession]),
          () => now,
        );

        final report = await service.reconcileUser(ownerId: 'user-1');

        expect(report.scannedSessions, 1);
        expect(report.syncedSessions, 0);
        expect(
          await progressRepository.getContribution(
            ownerId: 'user-1',
            sessionId: 'legacy-without-zone',
          ),
          isNull,
        );
        expect(
          (await rewardRepository.listChallengeMedals(ownerId: 'user-1')).items,
          isEmpty,
        );
        expect(
          await rewardRepository.getAchievementReward(
            ownerId: 'user-1',
            rewardId: 'achievement:first_reliable_analysis',
          ),
          isNotNull,
        );
      },
    );

    test(
      'a live session can complete a backfillable achievement using trusted pre-launch history',
      () async {
        final historical = List<WorkoutSession>.generate(
          4,
          (index) => _trustedSession(
            id: 'historical-$index',
            validReps: 5,
            endedAt: DateTime.utc(2026, 8, 1 + index, 10),
            timezoneOffset: null,
          ),
        );
        final current = _trustedSession(id: 'current-session', validReps: 5);
        final service = buildService(
          TestSessionRepository(sessions: [...historical, current]),
          () => now,
        );

        await service.syncPersistedSession(session: current);

        final reward = await rewardRepository.getAchievementReward(
          ownerId: 'user-1',
          rewardId: 'achievement:reliable_sessions_5',
        );
        expect(reward, isNotNull);
        expect(reward?.isBackfilled, isTrue);
        expect(reward?.qualifyingEventId, 'current-session');
      },
    );

    test(
      'reconciliation backfills allowed achievements without historical medals',
      () async {
        final oldSession = _trustedSession(
          id: 'old-session',
          validReps: 12,
          endedAt: DateTime.utc(2026, 8, 1, 10),
        );
        final service = buildService(
          TestSessionRepository(sessions: [oldSession]),
          () => now,
        );

        final report = await service.reconcileUser(ownerId: 'user-1');

        expect(report.scannedSessions, 1);
        expect(report.syncedSessions, 0);
        expect(report.flushedPendingEvents, 0);
        expect(
          await progressRepository.getContribution(
            ownerId: 'user-1',
            sessionId: 'old-session',
          ),
          isNull,
        );
        expect(
          (await rewardRepository.listChallengeMedals(ownerId: 'user-1')).items,
          isEmpty,
        );
        final achievement = await rewardRepository.getAchievementReward(
          ownerId: 'user-1',
          rewardId: 'achievement:first_reliable_analysis',
        );
        expect(achievement?.isBackfilled, isTrue);
      },
    );

    test(
      'reconciliation removes contribution whose session no longer exists',
      () async {
        final session = _trustedSession(id: 'deleted-session', validReps: 10);
        final service = buildService(TestSessionRepository(), () => now);
        await service.syncPersistedSession(session: session);

        final report = await service.reconcileUser(ownerId: 'user-1');

        expect(report.removedStaleContributions, 1);
        expect(
          await progressRepository.getContribution(
            ownerId: 'user-1',
            sessionId: 'deleted-session',
          ),
          isNull,
        );
      },
    );
  });
}

WorkoutSession _trustedSession({
  required String id,
  required int validReps,
  DateTime? endedAt,
  SessionMeasurementQuality quality = SessionMeasurementQuality.high,
  PreparationOutcome preparationOutcome = PreparationOutcome.passed,
  double confidence = 0.95,
  List<WorkoutRep>? reps,
  Duration? timezoneOffset = Duration.zero,
}) {
  final end = endedAt ?? DateTime.utc(2026, 8, 7, 10);
  return WorkoutSession(
    id: id,
    ownerId: 'user-1',
    exerciseType: 'push_up',
    analysisKind: 'rangeRep',
    startedAt: end.subtract(const Duration(minutes: 1)),
    endedAt: end,
    durationSec: 60,
    totalReps: validReps,
    validReps: validReps,
    averageScore: 80,
    bestScore: 85,
    worstScore: 75,
    formWarningCount: 0,
    preparationOutcome: preparationOutcome,
    measurementQuality: quality,
    averageMeasurementConfidence: confidence,
    measurementSampleCount: 5,
    timezoneOffset: timezoneOffset,
    reps: reps,
  );
}

class _MemoryAchievementEventOutbox implements AchievementEventOutbox {
  final Map<String, PendingAchievementEvent> _pending =
      <String, PendingAchievementEvent>{};

  String _key(String ownerId, String eventId) => '$ownerId::$eventId';

  @override
  Future<void> enqueue(PendingAchievementEvent pendingEvent) async {
    _pending[_key(pendingEvent.ownerId, pendingEvent.id)] = pendingEvent;
  }

  @override
  Future<List<PendingAchievementEvent>> listPending({
    required String ownerId,
  }) async {
    final result = _pending.values
        .where((pending) => pending.ownerId == ownerId)
        .toList(growable: false);
    result.sort(
      (left, right) =>
          left.event.occurredAtUtc.compareTo(right.event.occurredAtUtc),
    );
    return result;
  }

  @override
  Future<void> remove({
    required String ownerId,
    required String eventId,
  }) async {
    _pending.remove(_key(ownerId, eventId));
  }
}

class _FailOnceAchievementEventRepository
    implements AchievementEventRepository {
  _FailOnceAchievementEventRepository(this._delegate);

  final AchievementEventRepository _delegate;
  var _shouldFail = true;

  @override
  Future<AchievementEventWriteResult> recordEvent({
    required String ownerId,
    required AchievementEvent event,
    required Duration timezoneOffset,
    required DateTime now,
  }) {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('simulated event persistence failure');
    }
    return _delegate.recordEvent(
      ownerId: ownerId,
      event: event,
      timezoneOffset: timezoneOffset,
      now: now,
    );
  }

  @override
  Future<List<AchievementEventRecord>> listEvents({required String ownerId}) {
    return _delegate.listEvents(ownerId: ownerId);
  }
}
