import 'dart:developer' as developer;

import '../../../achievements/application/outbox/achievement_event_outbox.dart';
import '../../../achievements/application/repositories/achievement_event_repository.dart';
import '../../../achievements/application/runtime_achievement_facts_builder.dart';
import '../../../achievements/application/session_achievement_facts_builder.dart';
import '../../../achievements/domain/achievement_catalog.dart';
import '../../../achievements/domain/achievement_evaluator.dart';
import '../../../achievements/domain/controlled_tempo_achievement_policy.dart';
import '../../../achievements/domain/models/achievement_event.dart';
import '../../../achievements/domain/models/achievement_facts.dart';
import '../../../achievements/domain/planned_workout_completion_policy.dart';
import '../../../challenges/application/repositories/challenge_progress_repository.dart';
import '../../../challenges/domain/challenge_contribution_evaluator.dart';
import '../../../challenges/domain/models/challenge_period.dart';
import '../../../workout_analysis/application/repositories/session_repository.dart';
import '../../../workout_analysis/domain/models/workout_rep.dart';
import '../../../workout_analysis/domain/models/workout_session.dart';
import '../../domain/models/achievement_award_candidate.dart';
import '../../domain/models/achievement_reward.dart';
import '../../domain/models/challenge_medal_reward.dart';
import '../../domain/models/reward_evaluation_origin.dart';
import '../../domain/models/reward_runtime_migration_policy.dart';
import '../repositories/reward_ledger_repository.dart';
import 'challenge_medal_award_service.dart';

class RewardRuntimeService {
  RewardRuntimeService({
    required SessionRepository sessionRepository,
    required ChallengeProgressRepository progressRepository,
    required RewardLedgerRepository rewardRepository,
    required AchievementEventRepository eventRepository,
    AchievementEventOutbox? eventOutbox,
    RewardRuntimeMigrationPolicy migrationPolicy =
        const RewardRuntimeMigrationPolicy(),
    ChallengeContributionEvaluator contributionEvaluator =
        const ChallengeContributionEvaluator(),
    ControlledTempoAchievementPolicy controlledTempoPolicy =
        const ControlledTempoAchievementPolicy(),
    PlannedWorkoutCompletionPolicy plannedWorkoutPolicy =
        const PlannedWorkoutCompletionPolicy(),
    RuntimeAchievementFactsBuilder runtimeFactsBuilder =
        const RuntimeAchievementFactsBuilder(),
    SessionAchievementFactsBuilder historicalFactsBuilder =
        const SessionAchievementFactsBuilder(),
    AchievementEvaluator achievementEvaluator = const AchievementEvaluator(),
    DateTime Function()? clock,
  }) : _sessionRepository = sessionRepository,
       _progressRepository = progressRepository,
       _rewardRepository = rewardRepository,
       _eventRepository = eventRepository,
       _eventOutbox = eventOutbox,
       _migrationPolicy = migrationPolicy,
       _contributionEvaluator = contributionEvaluator,
       _controlledTempoPolicy = controlledTempoPolicy,
       _plannedWorkoutPolicy = plannedWorkoutPolicy,
       _runtimeFactsBuilder = runtimeFactsBuilder,
       _historicalFactsBuilder = historicalFactsBuilder,
       _achievementEvaluator = achievementEvaluator,
       _clock = clock ?? DateTime.now,
       _medalAwardService = ChallengeMedalAwardService(
         progressRepository: progressRepository,
         rewardRepository: rewardRepository,
         migrationPolicy: migrationPolicy.challengeMedalPolicy,
       );

  final SessionRepository _sessionRepository;
  final ChallengeProgressRepository _progressRepository;
  final RewardLedgerRepository _rewardRepository;
  final AchievementEventRepository _eventRepository;
  final AchievementEventOutbox? _eventOutbox;
  final RewardRuntimeMigrationPolicy _migrationPolicy;
  final ChallengeContributionEvaluator _contributionEvaluator;
  final ControlledTempoAchievementPolicy _controlledTempoPolicy;
  final PlannedWorkoutCompletionPolicy _plannedWorkoutPolicy;
  final RuntimeAchievementFactsBuilder _runtimeFactsBuilder;
  final SessionAchievementFactsBuilder _historicalFactsBuilder;
  final AchievementEvaluator _achievementEvaluator;
  final DateTime Function() _clock;
  final ChallengeMedalAwardService _medalAwardService;

  Future<void> syncPersistedSession({
    required WorkoutSession session,
    RewardEvaluationOrigin origin = RewardEvaluationOrigin.live,
  }) async {
    final now = _clock();
    await _flushPendingEventsBestEffort(ownerId: session.ownerId, now: now);
    final timezoneOffset = session.timezoneOffset;
    if (timezoneOffset != null) {
      await _syncSessionProgressAndMedals(
        session: session,
        timezoneOffset: timezoneOffset,
        origin: origin,
        now: now,
      );

      if (_migrationPolicy.allowsProgress(
            instant: session.endedAt,
            timezoneOffset: timezoneOffset,
          ) &&
          _controlledTempoPolicy.qualifies(
            session: session,
            reps: session.reps ?? const <WorkoutRep>[],
          )) {
        await _recordEventDurably(
          ownerId: session.ownerId,
          event: AchievementEvent.controlledTempoSession(
            sessionId: session.id,
            occurredAt: session.endedAt,
          ),
          timezoneOffset: timezoneOffset,
          now: now,
        );
      }
    }

    await _evaluateAchievements(
      ownerId: session.ownerId,
      triggerEventId: session.id,
      triggerAt: session.endedAt,
      origin: origin,
    );
  }

  Future<void> recordGuideStep({
    required String ownerId,
    required String stepId,
    required DateTime occurredAt,
    required Duration timezoneOffset,
  }) async {
    final now = _clock();
    await _flushPendingEventsBestEffort(ownerId: ownerId, now: now);
    final result = await _recordEventDurably(
      ownerId: ownerId,
      event: AchievementEvent.guideStepOpened(
        stepId: stepId,
        occurredAt: occurredAt,
      ),
      timezoneOffset: timezoneOffset,
      now: now,
    );
    await _evaluateAchievements(
      ownerId: ownerId,
      triggerEventId: result.record.id,
      triggerAt: occurredAt,
      origin: RewardEvaluationOrigin.live,
    );
  }

  Future<bool> recordPlannedWorkoutCompletion({
    required String ownerId,
    required String planRunId,
    required int totalSets,
    required int completedSets,
    required bool allSetSessionsPersisted,
    required DateTime completedAt,
    required Duration timezoneOffset,
  }) async {
    if (!_plannedWorkoutPolicy.qualifies(
      totalSets: totalSets,
      completedSets: completedSets,
      allSetSessionsPersisted: allSetSessionsPersisted,
    )) {
      return false;
    }

    final now = _clock();
    await _flushPendingEventsBestEffort(ownerId: ownerId, now: now);
    final result = await _recordEventDurably(
      ownerId: ownerId,
      event: AchievementEvent.plannedWorkoutCompleted(
        planRunId: planRunId,
        occurredAt: completedAt,
      ),
      timezoneOffset: timezoneOffset,
      now: now,
    );
    await _evaluateAchievements(
      ownerId: ownerId,
      triggerEventId: result.record.id,
      triggerAt: completedAt,
      origin: RewardEvaluationOrigin.live,
    );
    return true;
  }

  Future<void> removeSessionProgress({
    required String ownerId,
    required String sessionId,
  }) async {
    await _progressRepository.removeContribution(
      ownerId: ownerId,
      sessionId: sessionId,
      now: _clock(),
    );
  }

  Future<RewardRuntimeReconciliationReport> reconcileUser({
    required String ownerId,
  }) async {
    final now = _clock();
    final flushedPendingEvents = await _flushPendingEvents(
      ownerId: ownerId,
      now: now,
    );
    final sessions = await _listAllSessions(ownerId);
    final sessionIds = sessions.map((session) => session.id).toSet();
    var syncedSessions = 0;

    for (final session in sessions) {
      final timezoneOffset = session.timezoneOffset;
      if (timezoneOffset == null ||
          !_migrationPolicy.allowsProgress(
            instant: session.endedAt,
            timezoneOffset: timezoneOffset,
          )) {
        continue;
      }
      await _syncSessionProgressAndMedals(
        session: session,
        timezoneOffset: timezoneOffset,
        origin: RewardEvaluationOrigin.reconciliation,
        now: now,
      );
      syncedSessions += 1;
    }

    final contributions = await _progressRepository.listContributions(
      ownerId: ownerId,
    );
    var removedStaleContributions = 0;
    for (final record in contributions) {
      if (sessionIds.contains(record.id)) {
        continue;
      }
      final removed = await _progressRepository.removeContribution(
        ownerId: ownerId,
        sessionId: record.id,
        now: now,
      );
      if (removed) {
        removedStaleContributions += 1;
      }
    }

    await _reconcileControlledTempo(
      ownerId: ownerId,
      sessions: sessions,
      now: now,
    );
    await _evaluateAchievements(
      ownerId: ownerId,
      triggerEventId: 'reconciliation:${now.microsecondsSinceEpoch}',
      triggerAt: now,
      origin: RewardEvaluationOrigin.reconciliation,
      historicalSessions: sessions,
    );

    return RewardRuntimeReconciliationReport(
      scannedSessions: sessions.length,
      syncedSessions: syncedSessions,
      removedStaleContributions: removedStaleContributions,
      flushedPendingEvents: flushedPendingEvents,
    );
  }

  Future<void> _flushPendingEventsBestEffort({
    required String ownerId,
    required DateTime now,
  }) async {
    try {
      await _flushPendingEvents(ownerId: ownerId, now: now);
    } catch (error, stackTrace) {
      developer.log(
        'Pending achievement events could not be flushed yet.',
        name: 'rewards.runtime.outbox',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<AchievementEventWriteResult> _recordEventDurably({
    required String ownerId,
    required AchievementEvent event,
    required Duration timezoneOffset,
    required DateTime now,
  }) async {
    final outbox = _eventOutbox;
    if (outbox != null) {
      await outbox.enqueue(
        PendingAchievementEvent(
          ownerId: ownerId,
          event: event,
          timezoneOffset: timezoneOffset,
        ),
      );
    }
    final result = await _eventRepository.recordEvent(
      ownerId: ownerId,
      event: event,
      timezoneOffset: timezoneOffset,
      now: now,
    );
    if (outbox != null) {
      await outbox.remove(ownerId: ownerId, eventId: event.eventId);
    }
    return result;
  }

  Future<int> _flushPendingEvents({
    required String ownerId,
    required DateTime now,
  }) async {
    final outbox = _eventOutbox;
    if (outbox == null) {
      return 0;
    }
    final pendingEvents = await outbox.listPending(ownerId: ownerId);
    var flushed = 0;
    for (final pending in pendingEvents) {
      await _eventRepository.recordEvent(
        ownerId: ownerId,
        event: pending.event,
        timezoneOffset: pending.timezoneOffset,
        now: now,
      );
      await outbox.remove(ownerId: ownerId, eventId: pending.id);
      flushed += 1;
    }
    return flushed;
  }

  Future<void> _syncSessionProgressAndMedals({
    required WorkoutSession session,
    required Duration timezoneOffset,
    required RewardEvaluationOrigin origin,
    required DateTime now,
  }) async {
    if (!_migrationPolicy.allowsProgress(
      instant: session.endedAt,
      timezoneOffset: timezoneOffset,
    )) {
      return;
    }

    final evaluation = _contributionEvaluator.evaluate(
      session: session,
      timezoneOffset: timezoneOffset,
    );
    final contribution = evaluation.contribution;
    if (contribution == null) {
      final existing = await _progressRepository.getContribution(
        ownerId: session.ownerId,
        sessionId: session.id,
      );
      if (existing != null) {
        await _progressRepository.removeContribution(
          ownerId: session.ownerId,
          sessionId: session.id,
          now: now,
        );
      }
      return;
    }

    await _progressRepository.upsertContribution(
      ownerId: session.ownerId,
      contribution: contribution,
      now: now,
    );

    await Future.wait(
      ChallengePeriod.values.map(
        (period) => _medalAwardService.evaluatePeriod(
          ownerId: session.ownerId,
          exerciseType: contribution.exerciseType,
          period: period,
          qualifyingEventAt: session.endedAt,
          timezoneOffset: timezoneOffset,
          qualifyingEventId: session.id,
          origin: origin,
          now: now,
        ),
      ),
    );
  }

  Future<void> _evaluateAchievements({
    required String ownerId,
    required String triggerEventId,
    required DateTime triggerAt,
    required RewardEvaluationOrigin origin,
    List<WorkoutSession>? historicalSessions,
  }) async {
    final existingRewards = await _listAllAchievementRewards(ownerId);
    final unlockedIds = existingRewards
        .map((reward) => reward.achievementId)
        .toSet();
    if (unlockedIds.length == AchievementCatalog.all.length) {
      return;
    }

    final liveFacts = await _buildRuntimeFacts(ownerId);
    AchievementFacts? historicalFacts;

    for (final definition in AchievementCatalog.all) {
      if (unlockedIds.contains(definition.id)) {
        continue;
      }

      var evaluation = _achievementEvaluator.evaluate(definition, liveFacts);
      var usedHistoricalFacts = false;
      if (definition.allowsHistoricalBackfill && !evaluation.isUnlocked) {
        final sessions = historicalSessions ?? await _listAllSessions(ownerId);
        historicalFacts ??= _historicalFactsBuilder.build(sessions);
        final historicalEvaluation = _achievementEvaluator.evaluate(
          definition,
          historicalFacts,
        );
        if (historicalEvaluation.isUnlocked) {
          evaluation = historicalEvaluation;
          usedHistoricalFacts = true;
        }
      }
      if (!evaluation.isUnlocked) {
        continue;
      }

      final isBackfilled = usedHistoricalFacts;
      final qualifyingEventId =
          isBackfilled && origin == RewardEvaluationOrigin.reconciliation
          ? (evaluation.qualifyingEventId ?? triggerEventId)
          : triggerEventId;
      await _rewardRepository.unlockAchievement(
        ownerId: ownerId,
        candidate: AchievementAwardCandidate(
          definition: definition,
          unlockedAt:
              isBackfilled && origin == RewardEvaluationOrigin.reconciliation
              ? _clock()
              : triggerAt,
          qualifyingEventId: qualifyingEventId,
          isBackfilled: isBackfilled,
        ),
        now: _clock(),
      );
    }
  }

  Future<AchievementFacts> _buildRuntimeFacts(String ownerId) async {
    final contributionsFuture = _progressRepository.listContributions(
      ownerId: ownerId,
    );
    final eventsFuture = _eventRepository.listEvents(ownerId: ownerId);
    final weeklyMedalsFuture = _listAllWeeklyMedals(ownerId);
    final contributions = await contributionsFuture;
    final events = await eventsFuture;
    final weeklyMedals = await weeklyMedalsFuture;
    return _runtimeFactsBuilder.build(
      contributions: contributions,
      events: events,
      weeklyMedals: weeklyMedals,
    );
  }

  Future<void> _reconcileControlledTempo({
    required String ownerId,
    required List<WorkoutSession> sessions,
    required DateTime now,
  }) async {
    final existing = await _rewardRepository.getAchievementReward(
      ownerId: ownerId,
      rewardId: 'achievement:controlled_tempo',
    );
    if (existing != null) {
      return;
    }

    for (final session in sessions.reversed) {
      final timezoneOffset = session.timezoneOffset;
      if (timezoneOffset == null ||
          !_migrationPolicy.allowsProgress(
            instant: session.endedAt,
            timezoneOffset: timezoneOffset,
          )) {
        continue;
      }
      final reps = await _sessionRepository.listSessionReps(
        ownerId: ownerId,
        sessionId: session.id,
      );
      if (!_controlledTempoPolicy.qualifies(session: session, reps: reps)) {
        continue;
      }
      await _recordEventDurably(
        ownerId: ownerId,
        event: AchievementEvent.controlledTempoSession(
          sessionId: session.id,
          occurredAt: session.endedAt,
        ),
        timezoneOffset: timezoneOffset,
        now: now,
      );
      return;
    }
  }

  Future<List<WorkoutSession>> _listAllSessions(String ownerId) async {
    const pageSize = 50;
    final sessions = <WorkoutSession>[];
    WorkoutSession? cursor;
    while (true) {
      final page = await _sessionRepository.listSessions(
        ownerId: ownerId,
        limit: pageSize,
        startAfter: cursor,
      );
      sessions.addAll(page);
      if (page.length < pageSize) {
        break;
      }
      cursor = page.last;
    }
    return sessions;
  }

  Future<List<AchievementReward>> _listAllAchievementRewards(
    String ownerId,
  ) async {
    final rewards = <AchievementReward>[];
    var page = await _rewardRepository.listAchievementRewards(
      ownerId: ownerId,
      limit: 50,
    );
    while (true) {
      rewards.addAll(page.items);
      final cursor = page.nextCursor;
      if (cursor == null) {
        break;
      }
      page = await _rewardRepository.listAchievementRewards(
        ownerId: ownerId,
        limit: 50,
        startAfter: cursor,
      );
    }
    return rewards;
  }

  Future<List<ChallengeMedalReward>> _listAllWeeklyMedals(
    String ownerId,
  ) async {
    final rewards = <ChallengeMedalReward>[];
    var page = await _rewardRepository.listChallengeMedals(
      ownerId: ownerId,
      period: ChallengePeriod.weekly,
      limit: 50,
    );
    while (true) {
      rewards.addAll(page.items);
      final cursor = page.nextCursor;
      if (cursor == null) {
        break;
      }
      page = await _rewardRepository.listChallengeMedals(
        ownerId: ownerId,
        period: ChallengePeriod.weekly,
        limit: 50,
        startAfter: cursor,
      );
    }
    return rewards;
  }
}

class RewardRuntimeReconciliationReport {
  const RewardRuntimeReconciliationReport({
    required this.scannedSessions,
    required this.syncedSessions,
    required this.removedStaleContributions,
    required this.flushedPendingEvents,
  });

  final int scannedSessions;
  final int syncedSessions;
  final int removedStaleContributions;
  final int flushedPendingEvents;
}

void logRewardRuntimeFailure(
  String operation,
  Object error,
  StackTrace stackTrace,
) {
  developer.log(
    'Reward runtime operation failed: $operation',
    name: 'rewards.runtime',
    error: error,
    stackTrace: stackTrace,
  );
}
