import 'dart:developer' as developer;

import 'repositories/session_repository.dart';
import 'exercise_catalog.dart';
import 'engine_kind.dart';
import 'hold_session_metrics_collector.dart';
import 'workout_state.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/range_rep_contract.dart';
import '../domain/models/range_rep_validation_result.dart';
import '../domain/models/workout_rep.dart';
import '../domain/models/workout_session.dart';
import '../domain/models/validated_rep_event.dart';

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
    required this.hasSavableProgress,
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
  final bool hasSavableProgress;
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

  bool get hasSavableProgress;

  WorkoutSessionLifecycleStateSnapshot currentStateSnapshot();

  void startSession({required ExerciseType exercise});

  void collect(WorkoutState next);

  bool beginFinish();

  Future<FinishWorkoutSessionResult> finishSession({
    required WorkoutState finalState,
  });

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
  int? _lastObservedValidationAttemptIndex;
  int _validOutcomeCount = 0;
  int _lowConfidenceOutcomeCount = 0;
  int _invalidOutcomeCount = 0;
  double _repScoreSum = 0.0;
  int _scoredRepCount = 0;
  double _bestScore = 0.0;
  int _formWarningCount = 0;
  bool _previousFormBad = false;
  final List<WorkoutRep> _completedWorkoutReps = <WorkoutRep>[];
  bool _isFinishing = false;
  bool _hasSavedSession = false;
  bool _finishArmed = false;

  @override
  bool get isFinishing => _isFinishing;

  @override
  bool get hasSavedSession => _hasSavedSession;

  @override
  bool get hasSavableProgress =>
      _validOutcomeCount > 0 ||
      _lowConfidenceOutcomeCount > 0 ||
      _invalidOutcomeCount > 0 ||
      _holdSessionCollector.totalHoldSeconds > 0;

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
      hasSavableProgress: hasSavableProgress,
      isFinishing: _isFinishing,
      hasSavedSession: _hasSavedSession,
    );
  }

  @override
  void startSession({required ExerciseType exercise}) {
    _activeSessionExercise = exercise;
    _sessionStartedAt = _clock();
    _lastObservedRepCount = 0;
    _lastObservedValidationAttemptIndex = null;
    _validOutcomeCount = 0;
    _lowConfidenceOutcomeCount = 0;
    _invalidOutcomeCount = 0;
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
    _publishCompletedSession(null);
  }

  @override
  void collect(WorkoutState next) {
    final rangeRepAnalysis = next.rangeRepAnalysis;
    if (rangeRepAnalysis != null) {
      final validatedRepEvent = next.validatedRepEvent;
      final WorkoutRep? collectedRep;
      if (validatedRepEvent != null) {
        collectedRep = _collectValidatedRepEvent(
          event: validatedRepEvent,
          next: next,
        );
      } else {
        final repDelta = next.repCount - _lastObservedRepCount;
        final hasNewValidationOutcome = _recordValidationOutcomeIfNew(next);
        collectedRep = hasNewValidationOutcome
            ? _collectCompletedWorkoutRep(next: next, repDelta: repDelta)
            : null;
      }
      final collectedScore = collectedRep?.score;
      if (collectedScore != null) {
        _repScoreSum += collectedScore;
        _scoredRepCount += 1;

        if (collectedScore > _bestScore) {
          _bestScore = collectedScore;
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

  WorkoutRep? _collectValidatedRepEvent({
    required ValidatedRepEvent event,
    required WorkoutState next,
  }) {
    if (_lastObservedValidationAttemptIndex == event.attemptIndex) {
      return null;
    }

    switch (event.validationStatus) {
      case RangeRepValidationStatus.valid:
        _validOutcomeCount += 1;
        break;
      case RangeRepValidationStatus.lowConfidence:
        _lowConfidenceOutcomeCount += 1;
        break;
      case RangeRepValidationStatus.invalid:
        _invalidOutcomeCount += 1;
        break;
    }
    _lastObservedValidationAttemptIndex = event.attemptIndex;

    final alreadyCollected = _completedWorkoutReps.any(
      (rep) => rep.repIndex == event.attemptIndex,
    );
    if (alreadyCollected) {
      return null;
    }

    final activeSessionExercise = _activeSessionExercise;
    if (activeSessionExercise == null) {
      return null;
    }
    final towardPeakMuscleAction = _exerciseCatalog
        .definitionFor(activeSessionExercise)
        .analysisRangeRepContract
        .towardPeakMuscleAction;
    final towardPeakMillis = event.descentDuration?.inMilliseconds;
    final returnToNeutralMillis = event.ascentDuration?.inMilliseconds;
    final eccentricMillis =
        towardPeakMuscleAction == RangeRepTowardPeakMuscleAction.eccentric
        ? towardPeakMillis
        : returnToNeutralMillis;
    final concentricMillis =
        towardPeakMuscleAction == RangeRepTowardPeakMuscleAction.concentric
        ? towardPeakMillis
        : returnToNeutralMillis;
    final tempoAssessment = event.tempoAssessment;
    final sideLabel = event.side?.name;
    final candidate = WorkoutRep(
      repIndex: event.attemptIndex,
      exerciseType: event.exerciseType == 'unknown'
          ? activeSessionExercise.id
          : event.exerciseType,
      analysisKind: event.analysisKind,
      recordedAt: event.completedAt,
      validationStatus: event.validationStatus.name,
      validationReasons: event.validationReasons
          .map((reason) => reason.name)
          .toList(growable: false),
      score: event.finalScore,
      minPrimaryMetric: event.minPrimaryMetric,
      worstFormMetric: event.worstFormMetric,
      descentMillis: towardPeakMillis,
      ascentMillis: returnToNeutralMillis,
      confidence: event.measurementConfidence,
      primaryRom: event.primaryRom,
      eccentricMillis: eccentricMillis,
      concentricMillis: concentricMillis,
      tempoMeasurementStatus: tempoAssessment?.measurement.status.name,
      tempoMeasurementIssues:
          tempoAssessment?.measurement.issues
              .map((issue) => issue.name)
              .toList(growable: false) ??
          const <String>[],
      tempoQuality: tempoAssessment?.quality.name,
      tempoSeverity: tempoAssessment?.severity.name,
      tempoReasons:
          tempoAssessment?.reasons
              .map((reason) => reason.name)
              .toList(growable: false) ??
          const <String>[],
      tempoIncludedInScore: event.tempoIncludedInScore,
      tempoTotalMillis: tempoAssessment
          ?.measurement
          .measuredTempo
          ?.totalRepDuration
          .inMilliseconds,
      techniqueObservations: next.rangeRepAnalysis!.techniqueObservations
          .map((observation) => observation.toMap())
          .toList(growable: false),
      selectedSide: sideLabel,
      selectedSideLabel: sideLabel,
      coverageQuality: event.coverageQuality,
      feedback: next.feedbackMessage,
      hadFormViolation: event.hadFormViolation,
      hadCoverageDrop: event.hadCoverageDrop,
      switchedSideDuringRep: event.switchedSideDuringRep,
      completedPhaseSequence: event.completedPhaseSequence,
    );
    _completedWorkoutReps.add(candidate);
    return candidate;
  }

  bool _recordValidationOutcomeIfNew(WorkoutState next) {
    final metrics = next.calibrationMetrics;
    final attemptIndex = metrics.lastRangeRepValidatedRepIndex;
    if (!metrics.hasLastRangeRepValidation || attemptIndex == null) {
      return false;
    }
    if (_lastObservedValidationAttemptIndex == attemptIndex) {
      return false;
    }

    switch (metrics.lastRangeRepValidationStatus) {
      case 'valid':
        _validOutcomeCount += 1;
        break;
      case 'lowConfidence':
      case 'low confidence':
        _lowConfidenceOutcomeCount += 1;
        break;
      case 'invalid':
        _invalidOutcomeCount += 1;
        break;
      default:
        return false;
    }
    _lastObservedValidationAttemptIndex = attemptIndex;
    return true;
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
      return FinishWorkoutSessionResult.success(session);
    } catch (error, stackTrace) {
      developer.log(
        'Workout session persistence failed.',
        name: 'workout.session.persistence',
        error: error,
        stackTrace: stackTrace,
      );
      _isFinishing = false;
      return const FinishWorkoutSessionResult.failure(
        FinishWorkoutSessionFailure.persistenceFailure,
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

    final attemptIndex = metrics.lastRangeRepValidatedRepIndex;
    if (attemptIndex == null || attemptIndex < 1) {
      return null;
    }
    final isInvalid = metrics.lastRangeRepValidationStatus == 'invalid';
    if (!isInvalid && repDelta < 1) {
      return null;
    }
    final repIndex = attemptIndex;

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
          ? _canonicalValidationStatus(metrics.lastRangeRepValidationStatus)
          : 'unknown',
      validationReasons: metrics.hasLastRangeRepValidation
          ? List<String>.from(metrics.lastRangeRepValidationReasons)
          : const <String>[],
      score: isInvalid ? null : rangeRepAnalysis.lastRepScore,
      minPrimaryMetric: metrics.lastRangeRepSummaryMinAngle,
      worstFormMetric: metrics.lastRangeRepSummaryWorstFormMetric,
      descentMillis: metrics.lastRangeRepSummaryDescentMillis,
      ascentMillis: metrics.lastRangeRepSummaryAscentMillis,
      confidence: metrics.lastRangeRepSummaryConfidence,
      primaryRom: metrics.lastRangeRepSummaryPrimaryRom,
      eccentricMillis: eccentricMillis,
      concentricMillis: concentricMillis,
      tempoMeasurementStatus:
          metrics.lastRepTempoAssessment?.measurement.status.name,
      tempoMeasurementIssues:
          metrics.lastRepTempoAssessment?.measurement.issues
              .map((issue) => issue.name)
              .toList(growable: false) ??
          const <String>[],
      tempoQuality: metrics.lastRepTempoAssessment?.quality.name,
      tempoSeverity: metrics.lastRepTempoAssessment?.severity.name,
      tempoReasons:
          metrics.lastRepTempoAssessment?.reasons
              .map((reason) => reason.name)
              .toList(growable: false) ??
          const <String>[],
      tempoIncludedInScore: metrics.lastRepTempoIncludedInScore,
      tempoTotalMillis: metrics
          .lastRepTempoAssessment
          ?.measurement
          .measuredTempo
          ?.totalRepDuration
          .inMilliseconds,
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
      totalReps: isHoldAnalysis
          ? finalState.repCount
          : _validOutcomeCount + _lowConfidenceOutcomeCount,
      averageScore: isHoldAnalysis
          ? 0
          : (_scoredRepCount == 0 ? 0 : _repScoreSum / _scoredRepCount),
      bestScore: isHoldAnalysis ? 0 : _bestScore,
      worstScore: isHoldAnalysis ? 0 : _worstRepScore(),
      validReps: isHoldAnalysis ? 0 : _validOutcomeCount,
      lowConfidenceReps: isHoldAnalysis ? 0 : _lowConfidenceOutcomeCount,
      invalidReps: isHoldAnalysis ? 0 : _invalidOutcomeCount,
      formWarningCount: isHoldAnalysis ? 0 : _formWarningCount,
      totalHoldSeconds: _holdSessionCollector.totalHoldSeconds,
      bestHoldSeconds: _holdSessionCollector.bestHoldSeconds,
      formBreakCount: _holdSessionCollector.formBreakCount,
      reps: persistedReps,
    );
  }

  String _canonicalValidationStatus(String? status) {
    if (status == null) {
      return 'unknown';
    }
    return status == 'low confidence' ? 'lowConfidence' : status;
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
