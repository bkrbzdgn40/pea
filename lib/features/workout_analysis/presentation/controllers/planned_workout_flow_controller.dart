import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../rewards/presentation/providers/reward_runtime_providers.dart';
import '../../application/feedback_delivery_controller.dart';
import '../../application/workout_engine.dart';
import '../../application/workout_session_lifecycle_controller.dart';
import '../../application/workout_state.dart';
import '../../domain/models/exercise_type.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/completed_session_metrics_provider.dart';
import '../providers/feedback_delivery_provider.dart';
import '../providers/live_pause_controller.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/workout_controller.dart';
import '../providers/workout_plan_session_provider.dart';
import '../screens/workout_plan_summary_screen.dart';
import '../screens/workout_rest_screen.dart';
import 'live_camera_session_controller.dart';

/// Owns completed-set transitions, rest navigation, and resume countdowns.
class PlannedWorkoutFlowController {
  PlannedWorkoutFlowController({
    required WidgetRef ref,
    required BuildContext Function() context,
    required bool Function() isMounted,
    required VoidCallback notifyStateChanged,
    required WorkoutSessionLifecycleOwner? Function() sessionLifecycle,
    required LiveCameraSessionController cameraSession,
    required Future<void> Function(bool enable) setScreenAwake,
    required Future<bool> Function(WorkoutState workoutState)
    finishPlannedExerciseSession,
  }) : _ref = ref,
       _context = context,
       _isMounted = isMounted,
       _notifyStateChanged = notifyStateChanged,
       _sessionLifecycle = sessionLifecycle,
       _cameraSession = cameraSession,
       _setScreenAwake = setScreenAwake,
       _finishPlannedExerciseSession = finishPlannedExerciseSession;

  final WidgetRef _ref;
  final BuildContext Function() _context;
  final bool Function() _isMounted;
  final VoidCallback _notifyStateChanged;
  final WorkoutSessionLifecycleOwner? Function() _sessionLifecycle;
  final LiveCameraSessionController _cameraSession;
  final Future<void> Function(bool enable) _setScreenAwake;
  final Future<bool> Function(WorkoutState workoutState)
  _finishPlannedExerciseSession;

  Timer? _resumeCountdownTimer;
  int? _resumeCountdownValue;
  bool _isTransitionLocked = false;
  bool _isRestRouteVisible = false;
  bool _advanceFailed = false;
  int _lastHandledCompletedSetCount = 0;
  WorkoutState? _completedSetState;
  ExerciseType? _resumeExercise;
  int? _resumeSetNumber;

  bool get isTransitionLocked => _isTransitionLocked;

  bool get advanceFailed => _advanceFailed;

  int? get resumeCountdownValue => _resumeCountdownValue;

  ExerciseType? get resumeExercise => _resumeExercise;

  int? get resumeSetNumber => _resumeSetNumber;

  void observe({
    required ExerciseType activeExercise,
    required WorkoutState workoutState,
  }) {
    final snapshot = _ref
        .read(workoutPlanSessionProvider.notifier)
        .observe(exercise: activeExercise, workoutState: workoutState);
    if (snapshot == null ||
        !snapshot.isSetCompleted ||
        snapshot.completedSets <= _lastHandledCompletedSetCount) {
      return;
    }

    _lastHandledCompletedSetCount = snapshot.completedSets;
    _completedSetState = workoutState;
    unawaited(_handleCompletedSet(snapshot));
  }

  Future<void> retryAdvance() async {
    if (!_isTransitionLocked || _resumeCountdownValue != null) {
      return;
    }
    await _prepareNextStep();
  }

  void dispose() {
    _resumeCountdownTimer?.cancel();
  }

  Future<void> _handleCompletedSet(WorkoutEngineSnapshot snapshot) async {
    if (!_isMounted() || _isTransitionLocked) {
      return;
    }

    _isTransitionLocked = true;
    _advanceFailed = false;
    _notifyStateChanged();
    _ref
        .read(workoutControllerProvider.notifier)
        .handleLifecycleInterruption(reason: 'planned set completed');
    final feedbackDelivery = _ref.read(feedbackDeliveryProvider);
    await feedbackDelivery.stop();
    feedbackDelivery.reset();
    await _cameraSession.stopImageStream();
    if (!_isMounted()) {
      return;
    }

    if (snapshot.completedSets >= snapshot.totalSets) {
      _notifyStateChanged();
      return;
    }

    if (snapshot.restAfterSet.compareTo(Duration.zero) <= 0) {
      await _prepareNextStep();
      return;
    }

    final planController = _ref.read(workoutPlanSessionProvider.notifier);
    final completedExercise = snapshot.currentExercise;
    final nextExercise = planController.nextExerciseAfterCompletedSet;
    if (completedExercise == null ||
        nextExercise == null ||
        _isRestRouteVisible) {
      await _prepareNextStep();
      return;
    }

    final localizations = AppLocalizations.of(_context());
    final planName = _ref.read(workoutPlanSessionProvider).plan?.name.trim();
    final nextSetNumber =
        nextExercise == completedExercise &&
            snapshot.setNumber < snapshot.setsInCurrentExercise
        ? snapshot.setNumber + 1
        : 1;

    _isRestRouteVisible = true;
    await Navigator.of(_context()).push<WorkoutRestResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WorkoutRestScreen(
          duration: snapshot.restAfterSet,
          planName: planName == null || planName.isEmpty
              ? localizations.plannedWorkout
              : planName,
          nextExerciseName: localizations.exerciseTitle(nextExercise.id),
          nextSetNumber: nextSetNumber,
          showExerciseCompletionTransition: nextExercise != completedExercise,
          completedExerciseName: localizations.exerciseTitle(
            completedExercise.id,
          ),
        ),
      ),
    );
    _isRestRouteVisible = false;
    if (!_isMounted() ||
        !_ref.read(workoutPlanSessionProvider).isSetCompleted) {
      return;
    }
    await _prepareNextStep();
  }

  void _startResumeCountdown() {
    _resumeCountdownTimer?.cancel();
    if (!_isMounted()) {
      return;
    }
    _resumeCountdownValue = 3;
    _notifyStateChanged();
    _announceResumeCountdown(3);
    _resumeCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isMounted() || !_isTransitionLocked) {
        timer.cancel();
        return;
      }
      final currentValue = _resumeCountdownValue;
      if (currentValue == null || currentValue <= 1) {
        timer.cancel();
        _resumePreparedStep();
        return;
      }
      final nextValue = currentValue - 1;
      _resumeCountdownValue = nextValue;
      _notifyStateChanged();
      _announceResumeCountdown(nextValue);
    });
  }

  void _announceResumeCountdown(int value) {
    unawaited(
      _ref
          .read(feedbackDeliveryProvider)
          .deliver(
            FeedbackDeliveryCue(
              id: 'planned-resume-countdown-$_lastHandledCompletedSetCount-$value',
              message: '$value',
              kind: FeedbackDeliveryKind.status,
            ),
          ),
    );
  }

  Future<void> _prepareNextStep() async {
    final WorkoutState? finalState =
        _completedSetState ?? _ref.read(workoutControllerProvider);
    if (finalState == null) {
      if (_isMounted()) {
        _resumeCountdownValue = null;
        _advanceFailed = true;
        _notifyStateChanged();
      }
      return;
    }

    final advanced = await _advancePlannedWorkout(finalState);
    if (!_isMounted()) {
      return;
    }
    if (!advanced) {
      _resumeCountdownValue = null;
      _advanceFailed = true;
      _notifyStateChanged();
      return;
    }

    final planState = _ref.read(workoutPlanSessionProvider);
    if (planState.isWorkoutCompleted) {
      return;
    }

    final snapshot = planState.snapshot;
    _resumeExercise = snapshot?.currentExercise;
    _resumeSetNumber = snapshot?.setNumber;
    _advanceFailed = false;
    _ref.read(feedbackDeliveryProvider).reset();
    _startResumeCountdown();
  }

  Future<void> _recordPlanCompletion({
    required WorkoutEngineSnapshot snapshot,
    required String? planRunId,
  }) async {
    final ownerId = _ref.read(currentUserIdProvider);
    final completedAt = snapshot.completedAt;
    if (ownerId == null || planRunId == null || completedAt == null) {
      return;
    }
    try {
      await _ref
          .read(rewardRuntimeServiceProvider)
          .recordPlannedWorkoutCompletion(
            ownerId: ownerId,
            planRunId: planRunId,
            totalSets: snapshot.totalSets,
            completedSets: snapshot.completedSets,
            allSetSessionsPersisted: true,
            completedAt: completedAt,
            timezoneOffset: completedAt.timeZoneOffset,
          );
    } catch (error, stackTrace) {
      developer.log(
        'Planned workout completion reward sync failed.',
        name: 'rewards.runtime.plan',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _resumePreparedStep() {
    if (!_isMounted() || !_isTransitionLocked) {
      return;
    }

    _ref.read(workoutControllerProvider.notifier).handleManualResume();
    _ref.read(feedbackDeliveryProvider).reset();
    _resumeCountdownValue = null;
    _resumeExercise = null;
    _resumeSetNumber = null;
    _completedSetState = null;
    _advanceFailed = false;
    _isTransitionLocked = false;
    _notifyStateChanged();
    _cameraSession.ensureLatestStream();
  }

  Future<bool> _advancePlannedWorkout(WorkoutState workoutState) async {
    final planState = _ref.read(workoutPlanSessionProvider);
    if (!planState.isSetCompleted) {
      return false;
    }

    final activeExercise = _ref.read(activeAnalysisExerciseProvider);
    final planController = _ref.read(workoutPlanSessionProvider.notifier);
    final nextExercise = planController.nextExerciseAfterCompletedSet;
    final changesExercise =
        nextExercise == null || nextExercise != activeExercise;

    if (changesExercise) {
      await _cameraSession.stopImageStream();
      if (!_isMounted()) {
        return false;
      }
      final saved = await _finishPlannedExerciseSession(workoutState);
      if (!saved || !_isMounted()) {
        return false;
      }
      _sessionLifecycle()?.completeFinishFlow();
    }

    final planRunId = planController.activeRunId;
    final nextSnapshot = planController.advance(
      resumeState: _ref.read(workoutControllerProvider),
    );
    if (nextSnapshot.isWorkoutCompleted) {
      await _recordPlanCompletion(snapshot: nextSnapshot, planRunId: planRunId);
      await _setScreenAwake(false);
      if (!_isMounted()) {
        return false;
      }
      Navigator.pushReplacement(
        _context(),
        MaterialPageRoute(builder: (_) => const WorkoutPlanSummaryScreen()),
      );
      return true;
    }

    if (changesExercise && nextExercise != null) {
      _ref.read(livePauseControllerProvider.notifier).reset();
      _ref.read(preparationCameraControllerProvider.notifier).clear();
      _ref.read(completedSessionMetricsProvider.notifier).state = null;
      _ref.read(selectedExerciseProvider.notifier).state = nextExercise;
      _sessionLifecycle()?.startSession(exercise: nextExercise);
    }
    return true;
  }
}
