import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/repositories/session_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_session_lifecycle_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_technique_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

void main() {
  test(
    'startSession resets accumulated runtime state and clears publication',
    () {
      final clock = _MutableClock(DateTime.utc(2030, 1, 1, 12));
      final repository = _FakeSessionRepository();
      final publications = <WorkoutSession?>[];
      var invalidationCount = 0;
      final controller = WorkoutSessionLifecycleController(
        sessionRepository: repository,
        resolveOwnerId: () => 'owner-1',
        invalidateUserSessionsSnapshot: () => invalidationCount += 1,
        publishCompletedSession: publications.add,
        clock: clock.now,
      );

      controller.startSession(exercise: ExerciseType.plank);
      controller.collect(
        _holdState(
          currentHoldSeconds: 5,
          bestHoldSeconds: 5,
          isHolding: true,
          hadHoldFormBreak: true,
        ),
      );

      clock.advance(const Duration(seconds: 15));
      controller.startSession(exercise: ExerciseType.squat);

      final snapshot = controller.currentStateSnapshot();
      expect(snapshot.activeSessionExercise, ExerciseType.squat);
      expect(snapshot.sessionStartedAt, clock.now());
      expect(snapshot.lastObservedRepCount, 0);
      expect(snapshot.repScoreSum, 0);
      expect(snapshot.scoredRepCount, 0);
      expect(snapshot.bestScore, 0);
      expect(snapshot.formWarningCount, 0);
      expect(snapshot.previousFormBad, isFalse);
      expect(snapshot.totalHoldSeconds, 0);
      expect(snapshot.bestHoldSeconds, 0);
      expect(snapshot.formBreakCount, 0);
      expect(snapshot.completedWorkoutReps, isEmpty);
      expect(snapshot.isFinishing, isFalse);
      expect(snapshot.hasSavedSession, isFalse);
      expect(publications, <WorkoutSession?>[null, null]);
      expect(invalidationCount, 0);
      expect(repository.saveCallCount, 0);
    },
  );

  test(
    'range-rep accumulation finalizes sorted reps and saves exactly once',
    () async {
      final clock = _MutableClock(DateTime.utc(2030, 1, 1, 12));
      final repository = _FakeSessionRepository();
      final publications = <WorkoutSession?>[];
      var invalidationCount = 0;
      final controller = WorkoutSessionLifecycleController(
        sessionRepository: repository,
        resolveOwnerId: () => 'owner-1',
        invalidateUserSessionsSnapshot: () => invalidationCount += 1,
        publishCompletedSession: publications.add,
        clock: clock.now,
      );

      controller.startSession(exercise: ExerciseType.squat);

      clock.advance(const Duration(seconds: 2));
      controller.collect(
        _rangeRepState(
          repCount: 2,
          lastRepScore: 80,
          isFormBad: true,
          feedbackMessage: 'Ilk tekrar',
          validatedRepIndex: 2,
          validationStatus: 'valid',
          minPrimaryMetric: 88,
          worstFormMetric: 156,
          descentMillis: 420,
          ascentMillis: 320,
          selectedSideLabel: 'left',
        ),
      );

      clock.advance(const Duration(seconds: 3));
      controller.collect(
        _rangeRepState(
          repCount: 3,
          lastRepScore: 99,
          isFormBad: true,
          feedbackMessage: 'Duplicate olmamali',
          validatedRepIndex: 2,
          validationStatus: 'valid',
          minPrimaryMetric: 77,
          worstFormMetric: 166,
          descentMillis: 900,
          ascentMillis: 800,
          selectedSideLabel: 'right',
        ),
      );

      clock.advance(const Duration(seconds: 4));
      controller.collect(
        _rangeRepState(
          repCount: 4,
          lastRepScore: 60,
          isFormBad: false,
          feedbackMessage: 'Ikinci tekrar',
          validatedRepIndex: 1,
          validationStatus: 'invalid',
          validationReasons: const <String>['depth'],
          minPrimaryMetric: 95,
          worstFormMetric: 170,
          descentMillis: 510,
          ascentMillis: 410,
          hadFormViolation: true,
          hadCoverageDrop: true,
          switchedSideDuringRep: true,
          completedPhaseSequence: false,
          selectedSideLabel: 'right',
          confidence: 0.82,
          primaryRom: 55,
          coverageQuality: 0.76,
          techniqueObservations: const <RangeRepTechniqueObservation>[
            RangeRepTechniqueObservation(
              type: RangeRepTechniqueObservationType.torsoSwing,
              code: 'biceps_torso_swing_observed',
              severity: RangeRepTechniqueSeverity.info,
            ),
          ],
        ),
      );

      clock.advance(const Duration(seconds: 3));
      final finalState = _rangeRepState(
        repCount: 5,
        lastRepScore: 40,
        isFormBad: true,
        feedbackMessage: 'Final frame',
        validatedRepIndex: 5,
        validationStatus: 'valid',
        minPrimaryMetric: 82,
        worstFormMetric: 148,
        descentMillis: 390,
        ascentMillis: 280,
        selectedSideLabel: 'left',
      );

      expect(controller.beginFinish(), isTrue);

      final result = await controller.finishSession(finalState: finalState);

      expect(result.failure, isNull);
      expect(result.isSuccess, isTrue);
      expect(repository.saveCallCount, 1);
      expect(repository.savedSessions, hasLength(1));
      expect(invalidationCount, 1);
      expect(publications, hasLength(2));

      final session = repository.savedSessions.single;
      expect(result.session, same(session));
      expect(publications.last, same(session));
      expect(session.id, 'session_${clock.now().microsecondsSinceEpoch}');
      expect(session.ownerId, 'owner-1');
      expect(session.exerciseType, ExerciseType.squat.id);
      expect(session.analysisKind, EngineKind.rangeRep.name);
      expect(session.startedAt, DateTime.utc(2030, 1, 1, 12));
      expect(session.endedAt, clock.now());
      expect(session.durationSec, 12);
      expect(session.totalReps, 5);
      expect(session.averageScore, closeTo(60.0, 0.001));
      expect(session.bestScore, 80);
      expect(session.worstScore, 40);
      expect(session.validReps, 2);
      expect(session.invalidReps, 1);
      expect(session.formWarningCount, 2);
      expect(session.totalHoldSeconds, 0);
      expect(session.bestHoldSeconds, 0);
      expect(session.formBreakCount, 0);
      expect(session.reps, hasLength(3));
      expect(
        session.reps!.map((rep) => rep.repIndex).toList(growable: false),
        <int>[1, 2, 5],
      );

      final firstRep = session.reps![0];
      final secondRep = session.reps![1];
      final finalRep = session.reps![2];

      expect(firstRep.recordedAt, DateTime.utc(2030, 1, 1, 12, 0, 9));
      expect(firstRep.validationStatus, 'invalid');
      expect(firstRep.validationReasons, <String>['depth']);
      expect(firstRep.score, 60);
      expect(firstRep.minPrimaryMetric, 95);
      expect(firstRep.worstFormMetric, 170);
      expect(firstRep.descentMillis, 510);
      expect(firstRep.ascentMillis, 410);
      expect(firstRep.feedback, 'Ikinci tekrar');
      expect(firstRep.hadFormViolation, isTrue);
      expect(firstRep.hadCoverageDrop, isTrue);
      expect(firstRep.switchedSideDuringRep, isTrue);
      expect(firstRep.completedPhaseSequence, isFalse);
      expect(firstRep.selectedSideLabel, 'right');
      expect(firstRep.selectedSide, 'right');
      expect(firstRep.confidence, 0.82);
      expect(firstRep.primaryRom, 55);
      expect(firstRep.eccentricMillis, 510);
      expect(firstRep.concentricMillis, 410);
      expect(firstRep.techniqueObservations, hasLength(1));
      expect(firstRep.coverageQuality, 0.76);

      expect(secondRep.recordedAt, DateTime.utc(2030, 1, 1, 12, 0, 2));
      expect(secondRep.validationStatus, 'valid');
      expect(secondRep.validationReasons, isEmpty);
      expect(secondRep.score, 80);
      expect(secondRep.minPrimaryMetric, 88);
      expect(secondRep.worstFormMetric, 156);
      expect(secondRep.descentMillis, 420);
      expect(secondRep.ascentMillis, 320);
      expect(secondRep.feedback, 'Ilk tekrar');
      expect(secondRep.hadFormViolation, isFalse);
      expect(secondRep.hadCoverageDrop, isFalse);
      expect(secondRep.switchedSideDuringRep, isFalse);
      expect(secondRep.completedPhaseSequence, isTrue);
      expect(secondRep.selectedSideLabel, 'left');

      expect(finalRep.recordedAt, DateTime.utc(2030, 1, 1, 12, 0, 12));
      expect(finalRep.repIndex, 5);
      expect(finalRep.feedback, 'Final frame');

      final snapshot = controller.currentStateSnapshot();
      expect(snapshot.hasSavedSession, isTrue);
      expect(snapshot.isFinishing, isTrue);
      expect(snapshot.formWarningCount, 2);
      expect(snapshot.completedWorkoutReps, hasLength(3));

      controller.completeFinishFlow();
      expect(controller.currentStateSnapshot().isFinishing, isFalse);
      expect(controller.beginFinish(), isFalse);
      final duplicateResult = await controller.finishSession(
        finalState: finalState,
      );
      expect(duplicateResult.failure, FinishWorkoutSessionFailure.alreadySaved);
      expect(repository.saveCallCount, 1);
      expect(invalidationCount, 1);
    },
  );

  test(
    'sit-up range-rep sessions persist the canonical exercise id and kind',
    () async {
      final clock = _MutableClock(DateTime.utc(2030, 1, 1, 12));
      final repository = _FakeSessionRepository();
      final controller = WorkoutSessionLifecycleController(
        sessionRepository: repository,
        resolveOwnerId: () => 'owner-1',
        invalidateUserSessionsSnapshot: () {},
        publishCompletedSession: (_) {},
        clock: clock.now,
      );

      controller.startSession(exercise: ExerciseType.sitUp);
      controller.collect(
        _rangeRepState(
          repCount: 1,
          lastRepScore: 88,
          feedbackMessage: 'Sit-up tamamlandi',
          validatedRepIndex: 1,
          validationStatus: 'valid',
          minPrimaryMetric: 84,
          worstFormMetric: 120,
          descentMillis: 410,
          ascentMillis: 360,
          selectedSideLabel: 'left',
        ),
      );

      clock.advance(const Duration(seconds: 6));
      final result = await controller.finishSession(
        finalState: _rangeRepState(
          repCount: 1,
          lastRepScore: 88,
          feedbackMessage: 'Sit-up tamamlandi',
          validatedRepIndex: 1,
          validationStatus: 'valid',
          minPrimaryMetric: 84,
          worstFormMetric: 120,
          descentMillis: 410,
          ascentMillis: 360,
          selectedSideLabel: 'left',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(repository.savedSessions, hasLength(1));
      final session = repository.savedSessions.single;
      final rep = session.reps!.single;

      expect(session.exerciseType, ExerciseType.sitUp.id);
      expect(session.analysisKind, EngineKind.rangeRep.name);
      expect(session.totalReps, 1);
      expect(rep.repIndex, 1);
      expect(rep.score, 88);
      expect(rep.minPrimaryMetric, 84);
      expect(rep.worstFormMetric, 120);
      expect(rep.feedback, 'Sit-up tamamlandi');
    },
  );

  test('hold accumulation tracks totals, best hold, and form breaks', () {
    final controller = WorkoutSessionLifecycleController(
      sessionRepository: _FakeSessionRepository(),
      resolveOwnerId: () => 'owner-1',
      invalidateUserSessionsSnapshot: () {},
      publishCompletedSession: (_) {},
    );

    controller.startSession(exercise: ExerciseType.plank);
    controller.collect(
      _holdState(currentHoldSeconds: 5, bestHoldSeconds: 5, isHolding: true),
    );
    controller.collect(
      _holdState(
        currentHoldSeconds: 5,
        bestHoldSeconds: 5,
        isHolding: false,
        isHoldVisibilitySuspended: true,
      ),
    );
    controller.collect(
      _holdState(currentHoldSeconds: 5, bestHoldSeconds: 5, isHolding: true),
    );
    controller.collect(
      _holdState(
        currentHoldSeconds: 6,
        bestHoldSeconds: 6,
        isHolding: true,
        hadHoldFormBreak: true,
      ),
    );
    controller.collect(
      _holdState(
        currentHoldSeconds: 6,
        bestHoldSeconds: 6,
        isHolding: true,
        hadHoldFormBreak: true,
      ),
    );
    controller.collect(
      _holdState(currentHoldSeconds: 0, bestHoldSeconds: 6, isHolding: false),
    );
    controller.collect(
      _holdState(currentHoldSeconds: 0, bestHoldSeconds: 6, isHolding: true),
    );
    controller.collect(
      _holdState(currentHoldSeconds: 1, bestHoldSeconds: 6, isHolding: true),
    );
    controller.collect(
      _holdState(
        currentHoldSeconds: 2,
        bestHoldSeconds: 6,
        isHolding: true,
        hadHoldFormBreak: true,
      ),
    );

    final snapshot = controller.currentStateSnapshot();
    expect(snapshot.totalHoldSeconds, closeTo(8.0, 0.001));
    expect(snapshot.bestHoldSeconds, closeTo(6.0, 0.001));
    expect(snapshot.formBreakCount, 2);
  });

  test(
    'hold finalization preserves hold fields and clamps negative duration',
    () async {
      final clock = _MutableClock(DateTime.utc(2030, 1, 1, 12, 0, 5));
      final repository = _FakeSessionRepository();
      final publications = <WorkoutSession?>[];
      var invalidationCount = 0;
      final controller = WorkoutSessionLifecycleController(
        sessionRepository: repository,
        resolveOwnerId: () => 'owner-1',
        invalidateUserSessionsSnapshot: () => invalidationCount += 1,
        publishCompletedSession: publications.add,
        clock: clock.now,
      );

      controller.startSession(exercise: ExerciseType.plank);
      controller.collect(
        _holdState(currentHoldSeconds: 5, bestHoldSeconds: 5, isHolding: true),
      );
      controller.collect(
        _holdState(
          currentHoldSeconds: 5,
          bestHoldSeconds: 5,
          isHolding: false,
          isHoldVisibilitySuspended: true,
        ),
      );
      controller.collect(
        _holdState(currentHoldSeconds: 5, bestHoldSeconds: 5, isHolding: true),
      );
      controller.collect(
        _holdState(
          currentHoldSeconds: 6,
          bestHoldSeconds: 6,
          isHolding: true,
          hadHoldFormBreak: true,
        ),
      );

      clock.set(DateTime.utc(2030, 1, 1, 12));
      expect(controller.beginFinish(), isTrue);

      final result = await controller.finishSession(
        finalState: _holdState(
          currentHoldSeconds: 6,
          bestHoldSeconds: 6,
          isHolding: true,
          hadHoldFormBreak: true,
        ),
      );

      expect(result.failure, isNull);
      expect(repository.savedSessions, hasLength(1));
      expect(invalidationCount, 1);
      expect(publications.last, same(repository.savedSessions.single));

      final session = repository.savedSessions.single;
      expect(session.id, 'session_${clock.now().microsecondsSinceEpoch}');
      expect(session.ownerId, 'owner-1');
      expect(session.exerciseType, ExerciseType.plank.id);
      expect(session.analysisKind, EngineKind.hold.name);
      expect(session.startedAt, DateTime.utc(2030, 1, 1, 12, 0, 5));
      expect(session.endedAt, DateTime.utc(2030, 1, 1, 12));
      expect(session.durationSec, 0);
      expect(session.totalReps, 0);
      expect(session.averageScore, 0);
      expect(session.bestScore, 0);
      expect(session.worstScore, 0);
      expect(session.validReps, 0);
      expect(session.invalidReps, 0);
      expect(session.formWarningCount, 0);
      expect(session.totalHoldSeconds, closeTo(6.0, 0.001));
      expect(session.bestHoldSeconds, closeTo(6.0, 0.001));
      expect(session.formBreakCount, 1);
      expect(session.reps, isNull);

      final snapshot = controller.currentStateSnapshot();
      expect(snapshot.hasSavedSession, isTrue);
      expect(snapshot.isFinishing, isTrue);
      controller.completeFinishFlow();
      expect(controller.currentStateSnapshot().isFinishing, isFalse);
    },
  );

  test(
    'save failure does not publish success or invalidate and allows retry',
    () async {
      final clock = _MutableClock(DateTime.utc(2030, 1, 1, 12));
      final repository = _FakeSessionRepository()..throwOnSave = true;
      final publications = <WorkoutSession?>[];
      var invalidationCount = 0;
      final controller = WorkoutSessionLifecycleController(
        sessionRepository: repository,
        resolveOwnerId: () => 'owner-1',
        invalidateUserSessionsSnapshot: () => invalidationCount += 1,
        publishCompletedSession: publications.add,
        clock: clock.now,
      );

      controller.startSession(exercise: ExerciseType.squat);
      final state = _rangeRepState(
        repCount: 1,
        lastRepScore: 72,
        validatedRepIndex: 1,
        validationStatus: 'valid',
      );
      controller.collect(state);

      expect(controller.beginFinish(), isTrue);
      final failedResult = await controller.finishSession(finalState: state);

      expect(
        failedResult.failure,
        FinishWorkoutSessionFailure.persistenceFailure,
      );
      expect(repository.saveCallCount, 1);
      expect(repository.savedSessions, isEmpty);
      expect(invalidationCount, 0);
      expect(publications, <WorkoutSession?>[null]);
      expect(controller.currentStateSnapshot().isFinishing, isFalse);
      expect(controller.currentStateSnapshot().hasSavedSession, isFalse);

      repository.throwOnSave = false;
      expect(controller.beginFinish(), isTrue);
      final retryResult = await controller.finishSession(finalState: state);

      expect(retryResult.failure, isNull);
      expect(repository.saveCallCount, 2);
      expect(repository.savedSessions, hasLength(1));
      expect(invalidationCount, 1);
      expect(publications, hasLength(2));
      expect(controller.currentStateSnapshot().hasSavedSession, isTrue);
      expect(controller.currentStateSnapshot().isFinishing, isTrue);
      controller.completeFinishFlow();
      expect(controller.currentStateSnapshot().isFinishing, isFalse);
    },
  );

  test(
    'in-flight finish rejects a concurrent duplicate save attempt',
    () async {
      final clock = _MutableClock(DateTime.utc(2030, 1, 1, 12));
      final repository = _FakeSessionRepository()
        ..saveCompleter = Completer<void>();
      final publications = <WorkoutSession?>[];
      var invalidationCount = 0;
      final controller = WorkoutSessionLifecycleController(
        sessionRepository: repository,
        resolveOwnerId: () => 'owner-1',
        invalidateUserSessionsSnapshot: () => invalidationCount += 1,
        publishCompletedSession: publications.add,
        clock: clock.now,
      );

      controller.startSession(exercise: ExerciseType.squat);
      final state = _rangeRepState(
        repCount: 1,
        lastRepScore: 72,
        validatedRepIndex: 1,
        validationStatus: 'valid',
      );
      controller.collect(state);

      expect(controller.beginFinish(), isTrue);
      final firstFinish = controller.finishSession(finalState: state);
      expect(repository.saveCallCount, 1);
      expect(controller.currentStateSnapshot().isFinishing, isTrue);

      final duplicateResult = await controller.finishSession(finalState: state);

      expect(
        duplicateResult.failure,
        FinishWorkoutSessionFailure.alreadyFinishing,
      );
      expect(repository.saveCallCount, 1);
      expect(repository.savedSessions, isEmpty);
      expect(invalidationCount, 0);
      expect(publications, <WorkoutSession?>[null]);

      repository.saveCompleter!.complete();
      final firstResult = await firstFinish;

      expect(firstResult.failure, isNull);
      expect(repository.saveCallCount, 1);
      expect(repository.savedSessions, hasLength(1));
      expect(invalidationCount, 1);
      expect(publications, hasLength(2));
      expect(controller.currentStateSnapshot().hasSavedSession, isTrue);
      expect(controller.currentStateSnapshot().isFinishing, isTrue);
      controller.completeFinishFlow();
      expect(controller.currentStateSnapshot().isFinishing, isFalse);
    },
  );

  test('missing owner fails without saving', () async {
    final repository = _FakeSessionRepository();
    final publications = <WorkoutSession?>[];
    var invalidationCount = 0;
    final controller = WorkoutSessionLifecycleController(
      sessionRepository: repository,
      resolveOwnerId: () => null,
      invalidateUserSessionsSnapshot: () => invalidationCount += 1,
      publishCompletedSession: publications.add,
    );

    controller.startSession(exercise: ExerciseType.squat);
    final state = _rangeRepState(
      repCount: 1,
      lastRepScore: 72,
      validatedRepIndex: 1,
      validationStatus: 'valid',
    );
    controller.collect(state);

    expect(controller.beginFinish(), isTrue);
    final result = await controller.finishSession(finalState: state);

    expect(result.failure, FinishWorkoutSessionFailure.missingOwner);
    expect(repository.saveCallCount, 0);
    expect(repository.savedSessions, isEmpty);
    expect(invalidationCount, 0);
    expect(publications, <WorkoutSession?>[null]);
    expect(controller.currentStateSnapshot().isFinishing, isFalse);
  });

  test('missing exercise fails without saving', () async {
    final repository = _FakeSessionRepository();
    final publications = <WorkoutSession?>[];
    var invalidationCount = 0;
    final controller = WorkoutSessionLifecycleController(
      sessionRepository: repository,
      resolveOwnerId: () => 'owner-1',
      invalidateUserSessionsSnapshot: () => invalidationCount += 1,
      publishCompletedSession: publications.add,
    );

    final state = _rangeRepState(
      repCount: 1,
      lastRepScore: 72,
      validatedRepIndex: 1,
      validationStatus: 'valid',
    );

    expect(controller.beginFinish(), isTrue);
    final result = await controller.finishSession(finalState: state);

    expect(result.failure, FinishWorkoutSessionFailure.missingExercise);
    expect(repository.saveCallCount, 0);
    expect(repository.savedSessions, isEmpty);
    expect(invalidationCount, 0);
    expect(publications, isEmpty);
    expect(controller.currentStateSnapshot().isFinishing, isFalse);
  });
}

WorkoutState _rangeRepState({
  required int repCount,
  required double lastRepScore,
  required int validatedRepIndex,
  required String validationStatus,
  bool isFormBad = false,
  String feedbackMessage = 'Hazir',
  List<String> validationReasons = const <String>[],
  double minPrimaryMetric = 80,
  double worstFormMetric = 150,
  int descentMillis = 400,
  int ascentMillis = 300,
  bool hadFormViolation = false,
  bool hadCoverageDrop = false,
  bool switchedSideDuringRep = false,
  bool completedPhaseSequence = true,
  String selectedSideLabel = 'left',
  double? confidence,
  double? primaryRom,
  double? coverageQuality,
  List<RangeRepTechniqueObservation> techniqueObservations =
      const <RangeRepTechniqueObservation>[],
}) {
  return WorkoutState.rangeRep(
    feedbackMessage: feedbackMessage,
    analysis: RangeRepWorkoutAnalysisState(
      repCount: repCount,
      isFormBad: isFormBad,
      lastRepScore: lastRepScore,
      techniqueObservations: techniqueObservations,
      calibrationMetrics: WorkoutCalibrationMetrics.rangeRep(
        payload: RangeRepWorkoutCalibrationMetrics(
          hasLastRangeRepValidation: true,
          lastRangeRepValidationStatus: validationStatus,
          lastRangeRepValidationReasons: validationReasons,
          lastRangeRepValidatedRepIndex: validatedRepIndex,
          hasLastRangeRepSummary: true,
          lastRangeRepSummaryMinAngle: minPrimaryMetric,
          lastRangeRepSummaryWorstFormMetric: worstFormMetric,
          lastRangeRepSummaryDescentMillis: descentMillis,
          lastRangeRepSummaryAscentMillis: ascentMillis,
          lastRangeRepSummaryHadFormViolation: hadFormViolation,
          lastRangeRepSummaryHadCoverageDrop: hadCoverageDrop,
          lastRangeRepSummarySwitchedSideDuringRep: switchedSideDuringRep,
          lastRangeRepSummaryCompletedPhaseSequence: completedPhaseSequence,
          lastRangeRepSummarySelectedSideLabel: selectedSideLabel,
          lastRangeRepSummaryConfidence: confidence,
          lastRangeRepSummaryPrimaryRom: primaryRom,
          lastRangeRepSummaryCoverageQuality: coverageQuality,
        ),
      ),
    ),
  );
}

WorkoutState _holdState({
  required double currentHoldSeconds,
  required double bestHoldSeconds,
  required bool isHolding,
  bool isHoldVisibilitySuspended = false,
  bool hadHoldFormBreak = false,
}) {
  return WorkoutState.hold(
    analysis: HoldWorkoutAnalysisState(
      currentHoldSeconds: currentHoldSeconds,
      bestHoldSeconds: bestHoldSeconds,
      isHolding: isHolding,
      isHoldVisibilitySuspended: isHoldVisibilitySuspended,
      hadHoldFormBreak: hadHoldFormBreak,
    ),
  );
}

class _MutableClock {
  _MutableClock(this._current);

  DateTime _current;

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  void set(DateTime next) {
    _current = next;
  }
}

class _FakeSessionRepository implements SessionRepository {
  final List<WorkoutSession> savedSessions = <WorkoutSession>[];
  var saveCallCount = 0;
  var throwOnSave = false;
  Completer<void>? saveCompleter;

  @override
  Future<void> saveSession(WorkoutSession session) async {
    saveCallCount += 1;
    if (throwOnSave) {
      throw StateError('save failed');
    }
    final completer = saveCompleter;
    if (completer != null) {
      await completer.future;
    }
    savedSessions.add(session);
  }

  @override
  Future<WorkoutSession?> getSessionById({
    required String ownerId,
    required String sessionId,
  }) async {
    return null;
  }

  @override
  Future<List<WorkoutRep>> listSessionReps({
    required String ownerId,
    required String sessionId,
  }) async {
    return const <WorkoutRep>[];
  }

  @override
  Future<List<WorkoutSession>> listSessions({
    required String ownerId,
    int limit = 20,
    String? exerciseType,
    WorkoutSession? startAfter,
  }) async {
    return List<WorkoutSession>.unmodifiable(savedSessions);
  }

  @override
  Future<void> deleteSession({
    required String ownerId,
    required String sessionId,
  }) async {}
}
