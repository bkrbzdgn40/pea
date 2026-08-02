import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
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

  bool get isTransitionLocked => _isTransitionLocked;

  bool get advanceFailed => _advanceFailed;

  int? get resumeCountdownValue => _resumeCountdownValue;

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
    if (!_isTransitionLocked) {
      return;
    }
    await _advanceAfterTransition();
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
      _startResumeCountdown();
      return;
    }

    final planController = _ref.read(workoutPlanSessionProvider.notifier);
    final nextExercise = planController.nextExerciseAfterCompletedSet;
    if (nextExercise == null || _isRestRouteVisible) {
      _startResumeCountdown();
      return;
    }

    final localizations = AppLocalizations.of(_context());
    final planName = _ref.read(workoutPlanSessionProvider).plan?.name.trim();
    final nextSetNumber =
        nextExercise == snapshot.currentExercise &&
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
        ),
      ),
    );
    _isRestRouteVisible = false;
    if (!_isMounted() ||
        !_ref.read(workoutPlanSessionProvider).isSetCompleted) {
      return;
    }
    _startResumeCountdown();
  }

  void _startResumeCountdown() {
    _resumeCountdownTimer?.cancel();
    if (!_isMounted()) {
      return;
    }
    _resumeCountdownValue = 3;
    _notifyStateChanged();
    _announceResumeCountdown(3);
    _resumeCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!_isMounted() || !_isTransitionLocked) {
        timer.cancel();
        return;
      }
      final currentValue = _resumeCountdownValue;
      if (currentValue == null || currentValue <= 1) {
        timer.cancel();
        unawaited(_advanceAfterTransition());
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

  Future<void> _advanceAfterTransition() async {
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

    final activeExercise = _ref.read(activeAnalysisExerciseProvider);
    final nextExercise = _ref
        .read(workoutPlanSessionProvider.notifier)
        .nextExerciseAfterCompletedSet;
    final changesExercise =
        nextExercise == null || nextExercise != activeExercise;
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
    if (_ref.read(workoutPlanSessionProvider).isWorkoutCompleted) {
      return;
    }

    if (!changesExercise) {
      _ref.read(workoutControllerProvider.notifier).handleManualResume();
    }
    _ref.read(feedbackDeliveryProvider).reset();
    _resumeCountdownValue = null;
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

    final nextSnapshot = planController.advance(
      resumeState: _ref.read(workoutControllerProvider),
    );
    if (nextSnapshot.isWorkoutCompleted) {
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
