import 'repositories/session_repository.dart';
import 'exercise_catalog.dart';
import 'engine_kind.dart';
import 'hold_session_metrics_collector.dart';
import 'workout_state.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/workout_rep.dart';
import '../domain/models/workout_session.dart';

class WorkoutSessionLifecycleStateSnapshot {
  const WorkoutSessionLifecycleStateSnapshot({
    required this.activeSessionExercise,
    required this.sessionStartedAt,
    required this.lastObservedRepCount,
    required this.repScoreSum,
    required this.scoredRepCount,
    required this.bestScore,
    required this.formWarningCount,
    required this.previousFormBad,
    required this.totalHoldSeconds,
    required this.bestHoldSeconds,
    required this.formBreakCount,
    required this.completedWorkoutReps,
    required this.isFinishing,
    required this.hasSavedSession,
  });

  final ExerciseType? activeSessionExercise;
  final DateTime? sessionStartedAt;
  final int lastObservedRepCount;
  final double repScoreSum;
  final int scoredRepCount;
  final double bestScore;
  final int formWarningCount;
  final bool previousFormBad;
  final double totalHoldSeconds;
  final double bestHoldSeconds;
  final int formBreakCount;
  final List<WorkoutRep> completedWorkoutReps;
  final bool isFinishing;
  final bool hasSavedSession;
}

enum FinishWorkoutSessionFailure {
  missingOwner,
  missingExercise,
  persistenceFailure,
  alreadyFinishing,
  alreadySaved,
}

enum DiscardWorkoutSessionFailure { noSavedSession, persistenceFailure }

class DiscardWorkoutSessionResult {
  const DiscardWorkoutSessionResult._({required this.failure});

  const DiscardWorkoutSessionResult.success() : this._(failure: null);

  const DiscardWorkoutSessionResult.failure(
    DiscardWorkoutSessionFailure failure,
  ) : this._(failure: failure);

  final DiscardWorkoutSessionFailure? failure;

  bool get isSuccess => failure == null;
}

class FinishWorkoutSessionResult {
  const FinishWorkoutSessionResult._({
    required this.failure,
    required this.session,
  });

  const FinishWorkoutSessionResult.success(WorkoutSession session)
    : this._(failure: null, session: session);

  const FinishWorkoutSessionResult.failure(FinishWorkoutSessionFailure failure)
    : this._(failure: failure, session: null);

  final FinishWorkoutSessionFailure? failure;
  final WorkoutSession? session;

  bool get isSuccess => session != null;
}

abstract class WorkoutSessionLifecycleOwner {
  bool get isFinishing;

  bool get hasSavedSession;

  WorkoutSessionLifecycleStateSnapshot currentStateSnapshot();

  void startSession({required ExerciseType exercise});

  void collect(WorkoutState next);

  bool beginFinish();

  Future<FinishWorkoutSessionResult> finishSession({
    required WorkoutState finalState,
  });

  Future<DiscardWorkoutSessionResult> discardSavedSession();

  void completeFinishFlow();
}

class WorkoutSessionLifecycleController
    implements WorkoutSessionLifecycleOwner {
  WorkoutSessionLifecycleController({
    required SessionRepository sessionRepository,
    required String? Function() resolveOwnerId,
    required void Function() invalidateUserSessionsSnapshot,
    required void Function(WorkoutSession? session) publishCompletedSession,
    DateTime Function()? clock,
    HoldSessionMetricsCollector? holdSessionCollector,
    ExerciseCatalog exerciseCatalog = const ExerciseCatalog(),
  }) : _sessionRepository = sessionRepository,
       _resolveOwnerId = resolveOwnerId,
       _invalidateUserSessionsSnapshot = invalidateUserSessionsSnapshot,
       _publishCompletedSession = publishCompletedSession,
       _clock = clock ?? DateTime.now,
       _holdSessionCollector =
           holdSessionCollector ?? HoldSessionMetricsCollector(),
       _exerciseCatalog = exerciseCatalog;

  final SessionRepository _sessionRepository;
  final String? Function() _resolveOwnerId;
  final void Function() _invalidateUserSessionsSnapshot;
  final void Function(WorkoutSession? session) _publishCompletedSession;
  final DateTime Function() _clock;
  final HoldSessionMetricsCollector _holdSessionCollector;
  final ExerciseCatalog _exerciseCatalog;

  ExerciseType? _activeSessionExercise;
  DateTime? _sessionStartedAt;
  int _lastObservedRepCount = 0;
  double _repScoreSum = 0.0;
  int _scoredRepCount = 0;
  double _bestScore = 0.0;
  int _formWarningCount = 0;
  bool _previousFormBad = false;
  final List<WorkoutRep> _completedWorkoutReps = <WorkoutRep>[];
  bool _isFinishing = false;
  bool _hasSavedSession = false;
  bool _finishArmed = false;
  WorkoutSession? _savedSession;

  @override
  bool get isFinishing => _isFinishing;

  @override
  bool get hasSavedSession => _hasSavedSession;

  @override
  WorkoutSessionLifecycleStateSnapshot currentStateSnapshot() {
    return WorkoutSessionLifecycleStateSnapshot(
      activeSessionExercise: _activeSessionExercise,
      sessionStartedAt: _sessionStartedAt,
      lastObservedRepCount: _lastObservedRepCount,
      repScoreSum: _repScoreSum,
      scoredRepCount: _scoredRepCount,
      bestScore: _bestScore,
      formWarningCount: _formWarningCount,
      previousFormBad: _previousFormBad,
      totalHoldSeconds: _holdSessionCollector.totalHoldSeconds,
      bestHoldSeconds: _holdSessionCollector.bestHoldSeconds,
      formBreakCount: _holdSessionCollector.formBreakCount,
      completedWorkoutReps: List<WorkoutRep>.unmodifiable(
        _completedWorkoutReps,
      ),
      isFinishing: _isFinishing,
      hasSavedSession: _hasSavedSession,
    );
  }

  @override
  void startSession({required ExerciseType exercise}) {
    _activeSessionExercise = exercise;
    _sessionStartedAt = _clock();
    _lastObservedRepCount = 0;
    _repScoreSum = 0.0;
    _scoredRepCount = 0;
    _bestScore = 0.0;
    _formWarningCount = 0;
    _previousFormBad = false;
    _holdSessionCollector.reset();
    _completedWorkoutReps.clear();
    _isFinishing = false;
    _hasSavedSession = false;
    _finishArmed = false;
    _savedSession = null;
    _publishCompletedSession(null);
  }

  @override
  void collect(WorkoutState next) {
    final rangeRepAnalysis = next.rangeRepAnalysis;
    if (rangeRepAnalysis != null) {
      final repDelta = next.repCount - _lastObservedRepCount;
      if (repDelta > 0) {
        final collectedRep = _collectCompletedWorkoutRep(
          next: next,
          repDelta: repDelta,
        );
        final collectedScore = collectedRep?.score;
        if (collectedScore != null) {
          _repScoreSum += collectedScore;
          _scoredRepCount += 1;

          if (collectedScore > _bestScore) {
            _bestScore = collectedScore;
          }
        }
      }

      if (!_previousFormBad && rangeRepAnalysis.isFormBad) {
        _formWarningCount += 1;
      }
    }

    _holdSessionCollector.collect(next);

    _lastObservedRepCount = rangeRepAnalysis?.repCount ?? 0;
    _previousFormBad = rangeRepAnalysis?.isFormBad ?? false;
  }

  @override
  bool beginFinish() {
    if (_isFinishing || _hasSavedSession) {
      return false;
    }

    _isFinishing = true;
    _finishArmed = true;
    return true;
  }

  @override
  Future<FinishWorkoutSessionResult> finishSession({
    required WorkoutState finalState,
  }) async {
    if (_hasSavedSession) {
      return FinishWorkoutSessionResult.failure(
        FinishWorkoutSessionFailure.alreadySaved,
      );
    }

    if (!_finishArmed) {
      if (_isFinishing) {
        return const FinishWorkoutSessionResult.failure(
          FinishWorkoutSessionFailure.alreadyFinishing,
        );
      }
      if (!beginFinish()) {
        return const FinishWorkoutSessionResult.failure(
          FinishWorkoutSessionFailure.alreadyFinishing,
        );
      }
    }

    _finishArmed = false;

    final ownerId = _resolveOwnerId();
    if (ownerId == null) {
      _isFinishing = false;
      return const FinishWorkoutSessionResult.failure(
        FinishWorkoutSessionFailure.missingOwner,
      );
    }

    collect(finalState);

    final activeSessionExercise = _activeSessionExercise;
    if (activeSessionExercise == null) {
      _isFinishing = false;
      return const FinishWorkoutSessionResult.failure(
        FinishWorkoutSessionFailure.missingExercise,
      );
    }

    final session = _buildWorkoutSession(
      ownerId: ownerId,
      exercise: activeSessionExercise,
      finalState: finalState,
    );

    try {
      await _sessionRepository.saveSession(session);
      _invalidateUserSessionsSnapshot();
      _publishCompletedSession(session);
      _hasSavedSession = true;
      _savedSession = session;
      return FinishWorkoutSessionResult.success(session);
    } catch (_) {
      _isFinishing = false;
      return const FinishWorkoutSessionResult.failure(
        FinishWorkoutSessionFailure.persistenceFailure,
      );
    }
  }

  @override
  Future<DiscardWorkoutSessionResult> discardSavedSession() async {
    final session = _savedSession;
    if (!_hasSavedSession || session == null) {
      return const DiscardWorkoutSessionResult.failure(
        DiscardWorkoutSessionFailure.noSavedSession,
      );
    }

    try {
      await _sessionRepository.deleteSession(
        ownerId: session.ownerId,
        sessionId: session.id,
      );
      _invalidateUserSessionsSnapshot();
      _hasSavedSession = false;
      _isFinishing = false;
      _finishArmed = false;
      _savedSession = null;
      return const DiscardWorkoutSessionResult.success();
    } catch (_) {
      return const DiscardWorkoutSessionResult.failure(
        DiscardWorkoutSessionFailure.persistenceFailure,
      );
    }
  }

  @override
  void completeFinishFlow() {
    if (!_hasSavedSession) {
      return;
    }

    _isFinishing = false;
    _finishArmed = false;
  }

  WorkoutRep? _collectCompletedWorkoutRep({
    required WorkoutState next,
    required int repDelta,
  }) {
    final candidate = _buildCompletedWorkoutRep(next: next, repDelta: repDelta);
    if (candidate == null) {
      return null;
    }

    final alreadyCollected = _completedWorkoutReps.any(
      (rep) => rep.repIndex == candidate.repIndex,
    );
    if (alreadyCollected) {
      return null;
    }

    _completedWorkoutReps.add(candidate);
    return candidate;
  }

  WorkoutRep? _buildCompletedWorkoutRep({
    required WorkoutState next,
    required int repDelta,
  }) {
    final rangeRepAnalysis = next.rangeRepAnalysis;
    if (rangeRepAnalysis == null) {
      return null;
    }

    final activeSessionExercise = _activeSessionExercise;
    if (activeSessionExercise == null) {
      return null;
    }

    final metrics = next.calibrationMetrics;
    if (!metrics.hasLastRangeRepSummary) {
      return null;
    }

    final explicitRepIndex = metrics.lastRangeRepValidatedRepIndex;
    final repIndex =
        explicitRepIndex ?? (repDelta == 1 ? rangeRepAnalysis.repCount : null);
    if (repIndex == null ||
        repIndex < 1 ||
        repIndex > rangeRepAnalysis.repCount) {
      return null;
    }

    final towardPeakMuscleAction = _exerciseCatalog
        .definitionFor(activeSessionExercise)
        .analysisRangeRepContract
        .towardPeakMuscleAction;
    final towardPeakMillis = metrics.lastRangeRepSummaryDescentMillis;
    final returnToNeutralMillis = metrics.lastRangeRepSummaryAscentMillis;
    final eccentricMillis =
        towardPeakMuscleAction == RangeRepTowardPeakMuscleAction.eccentric
        ? towardPeakMillis
        : returnToNeutralMillis;
    final concentricMillis =
        towardPeakMuscleAction == RangeRepTowardPeakMuscleAction.concentric
        ? towardPeakMillis
        : returnToNeutralMillis;

    return WorkoutRep(
      repIndex: repIndex,
      exerciseType: activeSessionExercise.id,
      analysisKind: next.analysisKind.name,
      recordedAt: _clock(),
      validationStatus: metrics.hasLastRangeRepValidation
          ? metrics.lastRangeRepValidationStatus
          : 'unknown',
      validationReasons: metrics.hasLastRangeRepValidation
          ? List<String>.from(metrics.lastRangeRepValidationReasons)
          : const <String>[],
      score: rangeRepAnalysis.lastRepScore,
      minPrimaryMetric: metrics.lastRangeRepSummaryMinAngle,
      worstFormMetric: metrics.lastRangeRepSummaryWorstFormMetric,
      descentMillis: metrics.lastRangeRepSummaryDescentMillis,
      ascentMillis: metrics.lastRangeRepSummaryAscentMillis,
      confidence: metrics.lastRangeRepSummaryConfidence,
      primaryRom: metrics.lastRangeRepSummaryPrimaryRom,
      eccentricMillis: eccentricMillis,
      concentricMillis: concentricMillis,
      techniqueObservations: rangeRepAnalysis.techniqueObservations
          .map((observation) => observation.toMap())
          .toList(growable: false),
      selectedSide: metrics.lastRangeRepSummarySelectedSideLabel,
      coverageQuality: metrics.lastRangeRepSummaryCoverageQuality,
      feedback: next.feedbackMessage,
      hadFormViolation: metrics.lastRangeRepSummaryHadFormViolation,
      hadCoverageDrop: metrics.lastRangeRepSummaryHadCoverageDrop,
      switchedSideDuringRep: metrics.lastRangeRepSummarySwitchedSideDuringRep,
      completedPhaseSequence: metrics.lastRangeRepSummaryCompletedPhaseSequence,
      selectedSideLabel: metrics.lastRangeRepSummarySelectedSideLabel,
    );
  }

  WorkoutSession _buildWorkoutSession({
    required String ownerId,
    required ExerciseType exercise,
    required WorkoutState finalState,
  }) {
    final endedAt = _clock();
    final startedAt = _sessionStartedAt ?? endedAt;
    final durationSec = endedAt.difference(startedAt).inSeconds;
    final isHoldAnalysis = finalState.analysisKind == EngineKind.hold;
    final persistedReps = _completedWorkoutReps.isEmpty
        ? null
        : List<WorkoutRep>.unmodifiable(
            _completedWorkoutReps.toList()
              ..sort((left, right) => left.repIndex.compareTo(right.repIndex)),
          );

    return WorkoutSession(
      id: 'session_${endedAt.microsecondsSinceEpoch}',
      ownerId: ownerId,
      exerciseType: exercise.id,
      analysisKind: finalState.analysisKind.name,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSec: durationSec < 0 ? 0 : durationSec,
      totalReps: finalState.repCount,
      averageScore: isHoldAnalysis
          ? 0
          : (_scoredRepCount == 0 ? 0 : _repScoreSum / _scoredRepCount),
      bestScore: isHoldAnalysis ? 0 : _bestScore,
      worstScore: isHoldAnalysis ? 0 : _worstRepScore(),
      validReps: isHoldAnalysis ? 0 : _validRepCount(),
      invalidReps: isHoldAnalysis ? 0 : _invalidRepCount(),
      formWarningCount: isHoldAnalysis ? 0 : _formWarningCount,
      totalHoldSeconds: _holdSessionCollector.totalHoldSeconds,
      bestHoldSeconds: _holdSessionCollector.bestHoldSeconds,
      formBreakCount: _holdSessionCollector.formBreakCount,
      reps: persistedReps,
    );
  }

  int _validRepCount() {
    return _completedWorkoutReps.where((rep) => rep.isValidatedAsValid).length;
  }

  int _invalidRepCount() {
    return _completedWorkoutReps
        .where((rep) => rep.isValidatedAsInvalid)
        .length;
  }

  double _worstRepScore() {
    final scoredReps = _completedWorkoutReps
        .map((rep) => rep.score)
        .whereType<double>()
        .toList(growable: false);
    if (scoredReps.isEmpty) {
      return 0.0;
    }

    return scoredReps.reduce((value, next) => value < next ? value : next);
  }
}
