import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../application/workout_session_lifecycle_controller.dart';
import '../../application/workout_state.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/completed_session_metrics_provider.dart';
import '../providers/exercise_config_provider.dart';
import '../providers/live_pause_controller.dart';
import '../providers/live_range_rep_outcome_controller.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/workout_controller.dart';
import '../providers/workout_plan_session_provider.dart';
import '../screens/workout_summary_screen.dart';
import 'live_camera_session_controller.dart';

enum _LiveExitDecision { returnToWorkout, saveAndFinish, exitWithoutSaving }

/// Owns live-route exit, persistence, and summary navigation flows.
class LiveSessionFlowController {
  LiveSessionFlowController({
    required WidgetRef ref,
    required BuildContext Function() context,
    required bool Function() isMounted,
    required VoidCallback notifyStateChanged,
    required bool Function() hasAnalysisSelection,
    required WorkoutSessionLifecycleOwner? Function() sessionLifecycle,
    required LiveCameraSessionController cameraSession,
    required Future<void> Function(bool enable) setScreenAwake,
    required Object Function(bool leavePreparation) resolveExitDisposition,
  }) : _ref = ref,
       _context = context,
       _isMounted = isMounted,
       _notifyStateChanged = notifyStateChanged,
       _hasAnalysisSelection = hasAnalysisSelection,
       _sessionLifecycle = sessionLifecycle,
       _cameraSession = cameraSession,
       _setScreenAwake = setScreenAwake,
       _resolveExitDisposition = resolveExitDisposition;

  final WidgetRef _ref;
  final BuildContext Function() _context;
  final bool Function() _isMounted;
  final VoidCallback _notifyStateChanged;
  final bool Function() _hasAnalysisSelection;
  final WorkoutSessionLifecycleOwner? Function() _sessionLifecycle;
  final LiveCameraSessionController _cameraSession;
  final Future<void> Function(bool enable) _setScreenAwake;
  final Object Function(bool leavePreparation) _resolveExitDisposition;

  bool _isExitDialogVisible = false;
  bool _allowRoutePop = false;


  Widget buildExitGuard(Widget child) {
    return PopScope<Object?>(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(requestSessionExit());
      },
      child: child,
    );
  }

  void startSessionLifecycle() {
    final activeExercise = _ref.read(activeAnalysisExerciseProvider);
    final sessionLifecycle = _sessionLifecycle();
    if (activeExercise == null || sessionLifecycle == null) {
      return;
    }

    _ref.read(completedSessionMetricsProvider.notifier).state = null;
    sessionLifecycle.startSession(exercise: activeExercise);
    _cameraSession.onSessionLifecycleChanged();
  }

  Future<void> requestSessionExit() async {
    final sessionLifecycle = _sessionLifecycle();
    if (!_isMounted() ||
        _isExitDialogVisible ||
        (sessionLifecycle?.isFinishing ?? false)) {
      return;
    }

    if (sessionLifecycle == null ||
        sessionLifecycle.hasSavedSession ||
        !sessionLifecycle.hasSavableProgress) {
      await closeLiveRoute(resetWorkoutPlan: true);
      return;
    }

    _isExitDialogVisible = true;
    final decision = await showDialog<_LiveExitDecision>(
      context: _context(),
      barrierDismissible: false,
      builder: (dialogContext) {
        final localizations = AppLocalizations.of(dialogContext);
        return PopScope<Object?>(
          canPop: false,
          child: AlertDialog(
            key: const ValueKey<String>('live-exit-dialog'),
            title: Text(localizations.liveExitDialogTitle),
            content: Text(localizations.liveExitDialogMessage),
            actions: <Widget>[
              TextButton(
                key: const ValueKey<String>('live-exit-return-button'),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_LiveExitDecision.returnToWorkout),
                child: Text(localizations.returnToWorkout),
              ),
              TextButton(
                key: const ValueKey<String>('live-exit-discard-button'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_LiveExitDecision.exitWithoutSaving),
                child: Text(localizations.exitWithoutSaving),
              ),
              FilledButton(
                key: const ValueKey<String>('live-exit-save-button'),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_LiveExitDecision.saveAndFinish),
                child: Text(localizations.saveAndFinish),
              ),
            ],
          ),
        );
      },
    );
    _isExitDialogVisible = false;

    if (!_isMounted()) {
      return;
    }

    switch (decision) {
      case _LiveExitDecision.returnToWorkout:
      case null:
        return;
      case _LiveExitDecision.saveAndFinish:
        await finishSession(_ref.read(workoutControllerProvider));
        return;
      case _LiveExitDecision.exitWithoutSaving:
        await closeLiveRoute(resetWorkoutPlan: true);
        return;
    }
  }

  Future<void> closeLiveRoute({required bool resetWorkoutPlan}) async {
    if (!_isMounted() || _allowRoutePop) {
      return;
    }

    final shouldLeavePreparation =
        resetWorkoutPlan && _ref.read(workoutPlanSessionProvider).hasPlan;
    _ref.read(livePauseControllerProvider.notifier).cancelResume();
    if (_hasAnalysisSelection() && _ref.read(exerciseConfigProvider).hasValue) {
      _ref
          .read(workoutControllerProvider.notifier)
          .handleLifecycleInterruption(reason: 'live session exit');
    }
    _ref.read(livePauseControllerProvider.notifier).reset();
    _ref.read(preparationCameraControllerProvider.notifier).clear();
    if (resetWorkoutPlan && _ref.read(workoutPlanSessionProvider).hasPlan) {
      _ref.read(workoutPlanSessionProvider.notifier).reset();
    }

    await _cameraSession.stopImageStream();
    await _setScreenAwake(false);
    if (!_isMounted()) {
      return;
    }

    _allowRoutePop = true;
    _notifyStateChanged();
    await WidgetsBinding.instance.endOfFrame;
    if (!_isMounted()) {
      return;
    }
    final navigator = Navigator.of(_context());
    if (navigator.canPop()) {
      navigator.pop(
        _resolveExitDisposition(shouldLeavePreparation),
      );
    }
  }

  Future<void> finishSession(WorkoutState workoutState) async {
    _ref.read(livePauseControllerProvider.notifier).cancelResume();
    final sessionLifecycle = _sessionLifecycle();
    if (!_isMounted() ||
        sessionLifecycle == null ||
        !sessionLifecycle.beginFinish()) {
      return;
    }

    _notifyStateChanged();

    final completedMetrics = _ref
        .read(workoutControllerProvider.notifier)
        .liveMetricsSnapshot();

    await _cameraSession.stopImageStream();
    if (!_isMounted()) {
      return;
    }

    final result = await sessionLifecycle.finishSession(
      finalState: workoutState,
    );
    if (!_isMounted()) {
      return;
    }

    _notifyStateChanged();

    final failure = result.failure;
    if (failure != null) {
      _showFinishFailure(failure);
      _cameraSession.ensureLatestStream();
      return;
    }

    if (_ref.read(workoutPlanSessionProvider).hasPlan) {
      _ref.read(workoutPlanSessionProvider.notifier).reset();
    }
    _ref.read(completedSessionMetricsProvider.notifier).state = completedMetrics;

    await _setScreenAwake(false);
    if (!_isMounted()) {
      return;
    }
    final retryRequested = await Navigator.push<bool>(
      _context(),
      MaterialPageRoute(builder: (_) => const WorkoutSummaryScreen()),
    );

    if (!_isMounted()) {
      return;
    }

    sessionLifecycle.completeFinishFlow();
    _ref.read(livePauseControllerProvider.notifier).reset();
    _ref.read(preparationCameraControllerProvider.notifier).clear();

    if (retryRequested == true && _hasAnalysisSelection()) {
      startSessionLifecycle();
      _ref.read(workoutLiveMetricsProvider.notifier).reset();
      _ref.read(liveRangeRepOutcomeProvider.notifier).reset();
      _ref.invalidate(workoutControllerProvider);
      unawaited(_setScreenAwake(true));
    }

    _notifyStateChanged();
    _cameraSession.ensureLatestStream();
  }

  Future<bool> finishPlannedExerciseSession(
    WorkoutState workoutState,
  ) async {
    _ref.read(livePauseControllerProvider.notifier).cancelResume();
    final sessionLifecycle = _sessionLifecycle();
    if (sessionLifecycle == null || !sessionLifecycle.beginFinish()) {
      return false;
    }

    _notifyStateChanged();
    final result = await sessionLifecycle.finishSession(
      finalState: workoutState,
    );
    if (!_isMounted()) {
      return false;
    }
    _notifyStateChanged();

    switch (result.failure) {
      case FinishWorkoutSessionFailure.missingOwner:
        _showSnackBar(
          AppLocalizations.of(_context()).plannedStepMissingUser,
        );
        return false;
      case FinishWorkoutSessionFailure.missingExercise:
        _showSnackBar(
          AppLocalizations.of(_context()).plannedStepMissingExercise,
        );
        return false;
      case FinishWorkoutSessionFailure.persistenceFailure:
        _showSnackBar(
          AppLocalizations.of(_context()).plannedStepSaveFailed,
        );
        return false;
      case FinishWorkoutSessionFailure.alreadyFinishing:
      case FinishWorkoutSessionFailure.alreadySaved:
        return false;
      case null:
        return true;
    }
  }

  void _showFinishFailure(FinishWorkoutSessionFailure failure) {
    final localizations = AppLocalizations.of(_context());
    switch (failure) {
      case FinishWorkoutSessionFailure.missingOwner:
        _showSnackBar(localizations.analysisSessionPreparationFailed);
        return;
      case FinishWorkoutSessionFailure.missingExercise:
        _showSnackBar(localizations.selectValidExerciseBeforeAnalysis);
        return;
      case FinishWorkoutSessionFailure.persistenceFailure:
        _showSnackBar(localizations.sessionSaveFailed);
        return;
      case FinishWorkoutSessionFailure.alreadyFinishing:
      case FinishWorkoutSessionFailure.alreadySaved:
        return;
    }
  }

  void _showSnackBar(String message) {
    if (!_isMounted()) {
      return;
    }
    ScaffoldMessenger.of(_context()).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
