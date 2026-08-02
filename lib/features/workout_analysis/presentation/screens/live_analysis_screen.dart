import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';


import '../../../../app/layout/app_layout.dart';
import '../../../../app/layout/camera_layout_spec.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../core/orientation/app_display_orientation.dart';
import '../../application/feedback_delivery_controller.dart';
import '../../application/workout_developer_ui_config.dart';
import '../../application/workout_engine.dart';
import '../../application/workout_session_lifecycle_controller.dart';
import '../../application/workout_state.dart';
import '../../domain/models/exercise_config.dart';
import '../camera_image_stream_coordinator.dart';
import '../errors/workout_camera_error_presentation.dart';
import '../models/live_pause_state.dart';
import '../models/preparation_camera_geometry.dart';
import '../models/setup_readiness_view_data.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/completed_session_metrics_provider.dart';
import '../providers/exercise_config_provider.dart';
import '../providers/feedback_delivery_provider.dart';
import '../providers/live_pause_controller.dart';
import '../providers/live_range_rep_outcome_controller.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/preparation_readiness_controller.dart';
import '../providers/screen_awake_controller.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/workout_controller.dart';
import '../providers/workout_plan_session_provider.dart';
import '../providers/workout_session_lifecycle_controller_provider.dart';
import '../widgets/analysis_selection_required_view.dart';
import '../widgets/live_analysis/live_analysis_error_views.dart';
import '../widgets/live_analysis/live_analysis_feedback.dart';
import '../widgets/live_analysis/live_analysis_pause_overlay.dart';
import '../widgets/live_analysis/live_analysis_pose_overlays.dart';
import '../widgets/live_analysis/live_analysis_side_panel.dart';
import '../widgets/live_analysis/live_analysis_top_bar.dart';
import '../widgets/planned_workout_live_hud.dart';
import '../widgets/workout_diagnostics_panel.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'workout_plan_summary_screen.dart';
import 'workout_rest_screen.dart';
import 'workout_summary_screen.dart';

enum LiveAnalysisExitDisposition { stayInPreparation, leavePreparation }

/// Runs the live camera analysis session and handles camera lifecycle recovery.
class LiveAnalysisScreen extends ConsumerStatefulWidget {
  const LiveAnalysisScreen({super.key});

  @override
  ConsumerState<LiveAnalysisScreen> createState() => _LiveAnalysisScreenState();
}

enum _LiveExitDecision { returnToWorkout, saveAndFinish, exitWithoutSaving }


class _LiveAnalysisScreenState extends ConsumerState<LiveAnalysisScreen>
    with WidgetsBindingObserver {
  bool _isNavigatingToPermission = false;
  bool _isExitDialogVisible = false;
  bool _allowRoutePop = false;
  bool _isRecoveringCamera = false;
  bool _isRecoveringCameraRefreshInFlight = false;
  bool _showCalibrationPanel = false;
  CameraController? _observedCameraController;
  DeviceOrientation? _observedDeviceOrientation;
  DeviceOrientation _displayDeviceOrientation = DeviceOrientation.portraitUp;
  Size? _observedPreviewSize;
  late final CameraImageStreamCoordinator _imageStreamCoordinator;
  late final ScreenAwakeController _screenAwakeController;
  WorkoutSessionLifecycleOwner? _sessionLifecycle;
  ProviderSubscription<WorkoutSessionLifecycleOwner>?
  _sessionLifecycleSubscription;
  Timer? _recoveryTimer;
  ProviderSubscription<AsyncValue<ExerciseConfig>>? _exerciseConfigSubscription;
  ProviderSubscription<WorkoutState>? _workoutStateSubscription;
  Timer? _plannedResumeCountdownTimer;
  int? _plannedResumeCountdownValue;
  bool _isPlanTransitionLocked = false;
  bool _isRestRouteVisible = false;
  bool _planAdvanceFailed = false;
  int _lastHandledCompletedSetCount = 0;
  WorkoutState? _completedPlannedSetState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _displayDeviceOrientation = appDeviceOrientationFor(
      MediaQuery.orientationOf(context),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _imageStreamCoordinator = CameraImageStreamCoordinator();
    _screenAwakeController = ref.read(screenAwakeControllerProvider);
    if (_hasAnalysisSelection()) {
      _sessionLifecycleSubscription = ref
          .listenManual<WorkoutSessionLifecycleOwner>(
            workoutSessionLifecycleControllerProvider,
            (previous, next) {
              _sessionLifecycle = next;
            },
            fireImmediately: true,
          );
      _sessionLifecycle = ref.read(workoutSessionLifecycleControllerProvider);
      unawaited(_setLiveAnalysisScreenAwake(true));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_hasAnalysisSelection()) {
          return;
        }
        _startSessionLifecycle();
      });
      if (ref.read(exerciseConfigProvider).hasValue) {
        _attachWorkoutStateSubscription();
      }
      _exerciseConfigSubscription = ref
          .listenManual<AsyncValue<ExerciseConfig>>(exerciseConfigProvider, (
            _,
            next,
          ) {
            if (next.hasValue) {
              _attachWorkoutStateSubscription();
            }
          });
    }
  }

  @override
  void dispose() {
    unawaited(_setLiveAnalysisScreenAwake(false));
    _stopObservingCameraGeometry();
    _recoveryTimer?.cancel();
    _plannedResumeCountdownTimer?.cancel();
    _sessionLifecycleSubscription?.close();
    _exerciseConfigSubscription?.close();
    _workoutStateSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_imageStreamCoordinator.dispose());
    super.dispose();
  }

  void _attachWorkoutStateSubscription() {
    final sessionLifecycle = _sessionLifecycle;
    if (sessionLifecycle == null) {
      return;
    }

    _workoutStateSubscription ??= ref.listenManual<WorkoutState>(
      workoutControllerProvider,
      (_, next) {
        sessionLifecycle.collect(next);
        final activeExercise = ref.read(activeAnalysisExerciseProvider);
        if (activeExercise == null) {
          return;
        }

        final snapshot = ref
            .read(workoutPlanSessionProvider.notifier)
            .observe(exercise: activeExercise, workoutState: next);
        if (snapshot == null ||
            !snapshot.isSetCompleted ||
            snapshot.completedSets <= _lastHandledCompletedSetCount) {
          return;
        }
        _lastHandledCompletedSetCount = snapshot.completedSets;
        _completedPlannedSetState = next;
        unawaited(_handlePlannedSetCompleted(snapshot));
      },
    );
  }

  bool _hasAnalysisSelection() {
    final selectedExercise = ref.read(selectedExerciseProvider);
    final activeExercise = ref.read(activeAnalysisExerciseProvider);

    return selectedExercise != null && activeExercise != null;
  }

  void _startSessionLifecycle() {
    final activeExercise = ref.read(activeAnalysisExerciseProvider);
    final sessionLifecycle = _sessionLifecycle;
    if (activeExercise == null || sessionLifecycle == null) {
      return;
    }

    ref.read(completedSessionMetricsProvider.notifier).state = null;
    sessionLifecycle.startSession(exercise: activeExercise);
  }

  Widget _buildExitGuard(Widget child) {
    return PopScope<Object?>(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_requestSessionExit());
      },
      child: child,
    );
  }

  Future<void> _requestSessionExit() async {
    final sessionLifecycle = _sessionLifecycle;
    if (!mounted ||
        _isExitDialogVisible ||
        (sessionLifecycle?.isFinishing ?? false)) {
      return;
    }

    if (sessionLifecycle == null ||
        sessionLifecycle.hasSavedSession ||
        !sessionLifecycle.hasSavableProgress) {
      await _closeLiveRoute(resetWorkoutPlan: true);
      return;
    }

    _isExitDialogVisible = true;
    final decision = await showDialog<_LiveExitDecision>(
      context: context,
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

    if (!mounted) {
      return;
    }

    switch (decision) {
      case _LiveExitDecision.returnToWorkout:
      case null:
        return;
      case _LiveExitDecision.saveAndFinish:
        await _finishSession(ref.read(workoutControllerProvider));
        return;
      case _LiveExitDecision.exitWithoutSaving:
        await _closeLiveRoute(resetWorkoutPlan: true);
        return;
    }
  }

  Future<void> _closeLiveRoute({required bool resetWorkoutPlan}) async {
    if (!mounted || _allowRoutePop) {
      return;
    }

    final shouldLeavePreparation =
        resetWorkoutPlan && ref.read(workoutPlanSessionProvider).hasPlan;
    ref.read(livePauseControllerProvider.notifier).cancelResume();
    if (_hasAnalysisSelection() && ref.read(exerciseConfigProvider).hasValue) {
      ref
          .read(workoutControllerProvider.notifier)
          .handleLifecycleInterruption(reason: 'live session exit');
    }
    ref.read(livePauseControllerProvider.notifier).reset();
    ref.read(preparationCameraControllerProvider.notifier).clear();
    if (resetWorkoutPlan && ref.read(workoutPlanSessionProvider).hasPlan) {
      ref.read(workoutPlanSessionProvider.notifier).reset();
    }

    await _stopImageStreamIfNeeded();
    await _setLiveAnalysisScreenAwake(false);
    if (!mounted) {
      return;
    }

    setState(() => _allowRoutePop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(
        shouldLeavePreparation
            ? LiveAnalysisExitDisposition.leavePreparation
            : LiveAnalysisExitDisposition.stayInPreparation,
      );
    }
  }

  Future<void> _setLiveAnalysisScreenAwake(bool enable) {
    return enable
        ? _screenAwakeController.acquire(ScreenAwakeOwner.liveAnalysis)
        : _screenAwakeController.release(ScreenAwakeOwner.liveAnalysis);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_sessionLifecycle?.isFinishing ?? false) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref
          .read(workoutControllerProvider.notifier)
          .handleLifecycleInterruption(reason: 'app lifecycle pause');
      ref
          .read(livePauseControllerProvider.notifier)
          .handleLifecycleInterruption();
      unawaited(_setLiveAnalysisScreenAwake(false));
      // Hide preview before teardown so CameraPreview never builds a disposed controller.
      _markCameraRecovering();
      unawaited(_stopImageStreamIfNeeded());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_hasAnalysisSelection()) {
        unawaited(_setLiveAnalysisScreenAwake(true));
      }
      unawaited(_recoverCameraIfAllowed());
    }
  }

  Future<void> _stopImageStreamIfNeeded() {
    return _imageStreamCoordinator.stop();
  }

  void _pauseAnalysis(SetupReadinessRequest readinessRequest) {
    final sessionLifecycle = _sessionLifecycle;
    if (sessionLifecycle == null || sessionLifecycle.isFinishing) {
      return;
    }

    final readiness = ref.read(
      preparationReadinessStateProvider(readinessRequest),
    );
    ref
        .read(livePauseControllerProvider.notifier)
        .pause(readinessSnapshot: readiness);
    ref.read(workoutControllerProvider.notifier).handleManualPause();
    ref.read(preparationCameraControllerProvider.notifier).clear();
  }

  void _requestResume(SetupReadinessRequest readinessRequest) {
    final readiness = ref.read(
      preparationReadinessStateProvider(readinessRequest),
    );
    ref
        .read(livePauseControllerProvider.notifier)
        .requestResume(readinessSnapshot: readiness);
  }

  void _cancelResume() {
    ref.read(livePauseControllerProvider.notifier).cancelResume();
  }

  Future<void> _recoverCameraIfAllowed() async {
    final sessionLifecycle = _sessionLifecycle;
    if ((sessionLifecycle?.isFinishing ?? false) ||
        _isRecoveringCameraRefreshInFlight) {
      return;
    }
    if (_isRecoveringCamera && ref.read(cameraProvider).isLoading) return;
    if (!_hasAnalysisSelection()) {
      return;
    }

    _isRecoveringCameraRefreshInFlight = true;
    _markCameraRecovering();

    try {
      final status = await Permission.camera.status;
      if (!mounted || (sessionLifecycle?.isFinishing ?? false)) {
        return;
      }

      if (!status.isGranted) {
        await _stopImageStreamIfNeeded();
        if (!mounted || (sessionLifecycle?.isFinishing ?? false)) {
          return;
        }

        ref.invalidate(cameraProvider);
        _goToPermissionScreen();
        return;
      }

      await _stopImageStreamIfNeeded();
      if (!mounted || (sessionLifecycle?.isFinishing ?? false)) {
        return;
      }

      ref.invalidate(cameraProvider);
    } finally {
      _isRecoveringCameraRefreshInFlight = false;
    }
  }

  void _markCameraRecovering() {
    if (!mounted) return;

    _stopObservingCameraGeometry();
    if (!_isRecoveringCamera) {
      setState(() => _isRecoveringCamera = true);
    }

    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isRecoveringCamera) {
        setState(() => _isRecoveringCamera = false);
      }
    });
  }

  void _goToPermissionScreen() {
    if (_isNavigatingToPermission || !mounted) return;

    _isNavigatingToPermission = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CameraPermissionScreen()),
    );
  }

  void _goToExerciseSelectionScreen() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseSelectionScreen()),
    );
  }

  Future<void> _finishSession(WorkoutState workoutState) async {
    ref.read(livePauseControllerProvider.notifier).cancelResume();
    final sessionLifecycle = _sessionLifecycle;
    if (!mounted ||
        sessionLifecycle == null ||
        !sessionLifecycle.beginFinish()) {
      return;
    }

    setState(() {});

    final completedMetrics = ref
        .read(workoutControllerProvider.notifier)
        .liveMetricsSnapshot();

    await _stopImageStreamIfNeeded();
    if (!mounted) return;

    final result = await sessionLifecycle.finishSession(
      finalState: workoutState,
    );
    if (!mounted) return;

    setState(() {});

    switch (result.failure) {
      case FinishWorkoutSessionFailure.missingOwner:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).analysisSessionPreparationFailed,
            ),
          ),
        );
        return;
      case FinishWorkoutSessionFailure.missingExercise:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).selectValidExerciseBeforeAnalysis,
            ),
          ),
        );
        return;
      case FinishWorkoutSessionFailure.persistenceFailure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).sessionSaveFailed),
          ),
        );
        return;
      case FinishWorkoutSessionFailure.alreadyFinishing:
      case FinishWorkoutSessionFailure.alreadySaved:
        return;
      case null:
        break;
    }

    if (ref.read(workoutPlanSessionProvider).hasPlan) {
      ref.read(workoutPlanSessionProvider.notifier).reset();
    }
    ref.read(completedSessionMetricsProvider.notifier).state = completedMetrics;

    await _setLiveAnalysisScreenAwake(false);
    if (!mounted) return;
    final retryRequested = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WorkoutSummaryScreen()),
    );

    if (!mounted) return;

    sessionLifecycle.completeFinishFlow();
    ref.read(livePauseControllerProvider.notifier).reset();
    ref.read(preparationCameraControllerProvider.notifier).clear();

    if (retryRequested == true && _hasAnalysisSelection()) {
      // Only an explicit retry starts a fresh analysis session. A normal
      // summary dismiss keeps the completed-session guard intact.
      _startSessionLifecycle();
      ref.read(workoutLiveMetricsProvider.notifier).reset();
      ref.read(liveRangeRepOutcomeProvider.notifier).reset();
      ref.invalidate(workoutControllerProvider);
      unawaited(_setLiveAnalysisScreenAwake(true));
    }

    setState(() {});
  }

  Future<void> _handlePlannedSetCompleted(
    WorkoutEngineSnapshot snapshot,
  ) async {
    if (!mounted || _isPlanTransitionLocked) {
      return;
    }

    setState(() {
      _isPlanTransitionLocked = true;
      _planAdvanceFailed = false;
    });
    ref
        .read(workoutControllerProvider.notifier)
        .handleLifecycleInterruption(reason: 'planned set completed');
    final feedbackDelivery = ref.read(feedbackDeliveryProvider);
    await feedbackDelivery.stop();
    feedbackDelivery.reset();
    await _stopImageStreamIfNeeded();
    if (!mounted) {
      return;
    }

    if (snapshot.completedSets >= snapshot.totalSets) {
      setState(() {});
      return;
    }

    if (snapshot.restAfterSet.compareTo(Duration.zero) <= 0) {
      _startPlannedResumeCountdown();
      return;
    }

    final planController = ref.read(workoutPlanSessionProvider.notifier);
    final nextExercise = planController.nextExerciseAfterCompletedSet;
    if (nextExercise == null || _isRestRouteVisible) {
      _startPlannedResumeCountdown();
      return;
    }

    final localizations = AppLocalizations.of(context);
    final planName = ref.read(workoutPlanSessionProvider).plan?.name.trim();
    final nextSetNumber =
        nextExercise == snapshot.currentExercise &&
            snapshot.setNumber < snapshot.setsInCurrentExercise
        ? snapshot.setNumber + 1
        : 1;

    _isRestRouteVisible = true;
    await Navigator.of(context).push<WorkoutRestResult>(
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
    if (!mounted || !ref.read(workoutPlanSessionProvider).isSetCompleted) {
      return;
    }
    _startPlannedResumeCountdown();
  }

  void _startPlannedResumeCountdown() {
    _plannedResumeCountdownTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() => _plannedResumeCountdownValue = 3);
    _announcePlannedResumeCountdown(3);
    _plannedResumeCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (!mounted || !_isPlanTransitionLocked) {
        timer.cancel();
        return;
      }
      final currentValue = _plannedResumeCountdownValue;
      if (currentValue == null || currentValue <= 1) {
        timer.cancel();
        unawaited(_advanceAfterPlannedTransition());
        return;
      }
      final nextValue = currentValue - 1;
      setState(() => _plannedResumeCountdownValue = nextValue);
      _announcePlannedResumeCountdown(nextValue);
    });
  }

  void _announcePlannedResumeCountdown(int value) {
    unawaited(
      ref
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

  Future<void> _advanceAfterPlannedTransition() async {
    final WorkoutState? finalState =
        _completedPlannedSetState ?? ref.read(workoutControllerProvider);
    if (finalState == null) {
      if (mounted) {
        setState(() {
          _plannedResumeCountdownValue = null;
          _planAdvanceFailed = true;
        });
      }
      return;
    }

    final activeExercise = ref.read(activeAnalysisExerciseProvider);
    final nextExercise = ref
        .read(workoutPlanSessionProvider.notifier)
        .nextExerciseAfterCompletedSet;
    final changesExercise =
        nextExercise == null || nextExercise != activeExercise;
    final advanced = await _advancePlannedWorkout(finalState);
    if (!mounted) {
      return;
    }
    if (!advanced) {
      setState(() {
        _plannedResumeCountdownValue = null;
        _planAdvanceFailed = true;
      });
      return;
    }
    if (ref.read(workoutPlanSessionProvider).isWorkoutCompleted) {
      return;
    }

    if (!changesExercise) {
      ref.read(workoutControllerProvider.notifier).handleManualResume();
    }
    ref.read(feedbackDeliveryProvider).reset();
    setState(() {
      _plannedResumeCountdownValue = null;
      _completedPlannedSetState = null;
      _planAdvanceFailed = false;
      _isPlanTransitionLocked = false;
    });
  }

  Future<void> _retryPlannedAdvance() async {
    if (!_isPlanTransitionLocked) {
      return;
    }
    await _advanceAfterPlannedTransition();
  }

  Future<bool> _finishPlannedExerciseSession(WorkoutState workoutState) async {
    ref.read(livePauseControllerProvider.notifier).cancelResume();
    final sessionLifecycle = _sessionLifecycle;
    if (sessionLifecycle == null || !sessionLifecycle.beginFinish()) {
      return false;
    }

    setState(() {});
    final result = await sessionLifecycle.finishSession(
      finalState: workoutState,
    );
    if (!mounted) {
      return false;
    }
    setState(() {});

    switch (result.failure) {
      case FinishWorkoutSessionFailure.missingOwner:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).plannedStepMissingUser),
          ),
        );
        return false;
      case FinishWorkoutSessionFailure.missingExercise:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).plannedStepMissingExercise,
            ),
          ),
        );
        return false;
      case FinishWorkoutSessionFailure.persistenceFailure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).plannedStepSaveFailed),
          ),
        );
        return false;
      case FinishWorkoutSessionFailure.alreadyFinishing:
      case FinishWorkoutSessionFailure.alreadySaved:
        return false;
      case null:
        return true;
    }
  }

  Future<bool> _advancePlannedWorkout(WorkoutState workoutState) async {
    final planState = ref.read(workoutPlanSessionProvider);
    if (!planState.isSetCompleted) {
      return false;
    }

    final activeExercise = ref.read(activeAnalysisExerciseProvider);
    final planController = ref.read(workoutPlanSessionProvider.notifier);
    final nextExercise = planController.nextExerciseAfterCompletedSet;
    final changesExercise =
        nextExercise == null || nextExercise != activeExercise;

    if (changesExercise) {
      await _stopImageStreamIfNeeded();
      if (!mounted) {
        return false;
      }
      final saved = await _finishPlannedExerciseSession(workoutState);
      if (!saved || !mounted) {
        return false;
      }
      _sessionLifecycle?.completeFinishFlow();
    }

    final nextSnapshot = planController.advance(
      resumeState: ref.read(workoutControllerProvider),
    );
    if (nextSnapshot.isWorkoutCompleted) {
      await _setLiveAnalysisScreenAwake(false);
      if (!mounted) {
        return false;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WorkoutPlanSummaryScreen()),
      );
      return true;
    }

    if (changesExercise && nextExercise != null) {
      ref.read(livePauseControllerProvider.notifier).reset();
      ref.read(preparationCameraControllerProvider.notifier).clear();
      ref.read(completedSessionMetricsProvider.notifier).state = null;
      ref.read(selectedExerciseProvider.notifier).state = nextExercise;
      _sessionLifecycle?.startSession(exercise: nextExercise);
    }
    return true;
  }

  void _showDiagnosticsPanel() {
    if (!workoutDeveloperUiEnabled) {
      return;
    }
    final controller = ref.read(workoutControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => WorkoutDiagnosticsPanel(
        snapshotReader: controller.diagnosticsSnapshot,
        onReset: controller.resetDiagnostics,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final pauseState = ref.watch(livePauseControllerProvider);
    ref.listen<LivePauseState>(livePauseControllerProvider, (previous, next) {
      if (previous?.isCountingDown == true && next.isActive) {
        ref.read(preparationCameraControllerProvider.notifier).clear();
        ref.read(workoutControllerProvider.notifier).handleManualResume();
      }
    });
    final selectedExercise = ref.watch(selectedExerciseProvider);
    final activeExercise = ref.watch(activeAnalysisExerciseProvider);

    if (selectedExercise == null || activeExercise == null) {
      return _buildExitGuard(
        Scaffold(
          backgroundColor: Colors.black,
          body: AnalysisSelectionRequiredView(
            title: localizations.liveAnalysisSelectionTitle,
            message: localizations.liveAnalysisSelectionMessage,
            onSelectExercise: _goToExerciseSelectionScreen,
          ),
        ),
      );
    }

    final sessionLifecycle = _sessionLifecycle;
    if (sessionLifecycle == null) {
      return _buildExitGuard(
        const Scaffold(
          backgroundColor: Colors.black,
          body: CameraRecoveryView(),
        ),
      );
    }

    if (sessionLifecycle.isFinishing) {
      return _buildExitGuard(
        const Scaffold(
          backgroundColor: Colors.black,
          body: CameraRecoveryView(),
        ),
      );
    }

    final configState = ref.watch(exerciseConfigProvider);
    if (configState.isLoading) {
      return _buildExitGuard(
        const Scaffold(
          backgroundColor: Colors.black,
          body: ExerciseConfigLoadingView(),
        ),
      );
    }
    if (configState.hasError) {
      return _buildExitGuard(
        Scaffold(
          backgroundColor: Colors.black,
          body: ExerciseConfigErrorView(
            onRetry: () => ref.invalidate(exerciseConfigProvider),
          ),
        ),
      );
    }

    final cameraState = ref.watch(cameraProvider);
    final hasWorkoutPlan = ref.watch(
      workoutPlanSessionProvider.select((state) => state.hasPlan),
    );
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top;
    final viewportOrientation = mediaQuery.orientation;

    return _buildExitGuard(
      Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final layout = AppLayout.of(context, constraints: constraints);
            final cameraLayout = AppCameraLayoutSpec.resolve(
              layout: layout,
              constraints: constraints,
            );

            return cameraState.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              data: (controller) {
                // Riverpod can keep the previous controller during refresh;
                // hide the preview while recovery is active so a disposing
                // controller is not used.
                if (_isRecoveringCamera || cameraState.isLoading) {
                  return const CameraRecoveryView();
                }

                final controllerValue = _safeControllerValue(controller);
                final cameraGeometry = const PreparationCameraGeometryResolver()
                    .resolve(
                      previewSize: controllerValue?.previewSize,
                      deviceOrientation: _displayDeviceOrientation,
                      viewportOrientation: viewportOrientation,
                    );

                if (controllerValue == null ||
                    !controllerValue.isInitialized ||
                    cameraGeometry == null) {
                  return const CameraRecoveryView();
                }

                final imageSize = cameraGeometry.imageSize;
                final isMirrored =
                    controller.description.lensDirection ==
                    CameraLensDirection.front;
                final readinessRequest = (
                  imageWidth: imageSize.width,
                  imageHeight: imageSize.height,
                  mirrorHorizontally: isMirrored,
                );
                _ensureImageStream(controller, sessionLifecycle);

                void toggleCalibration() {
                  setState(
                    () => _showCalibrationPanel = !_showCalibrationPanel,
                  );
                }

                final cameraStage = Stack(
                  key: const ValueKey<String>('live-camera-stage'),
                  fit: StackFit.expand,
                  children: <Widget>[
                    CameraPreview(controller),
                    if (pauseState.isActive)
                      WorkoutPoseOverlay(
                        imageSize: imageSize,
                        isMirrored: isMirrored,
                        showDebugLandmarks:
                            workoutDeveloperUiEnabled && _showCalibrationPanel,
                      )
                    else
                      PausedPoseOverlay(
                        imageSize: imageSize,
                        isMirrored: isMirrored,
                      ),
                    if (pauseState.isActive)
                      const LiveTrackingRecoveryOverlay(),
                    if (pauseState.isPaused)
                      LivePauseOverlay(
                        readinessRequest: readinessRequest,
                        onResume: () => _requestResume(readinessRequest),
                        onCancelResume: _cancelResume,
                      ),
                    if (workoutDeveloperUiEnabled && pauseState.isActive)
                      Positioned(
                        top: topInset + (layout.isLandscape ? 8 : 12),
                        left: layout.isLandscape ? 10 : 14,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const ValueKey<String>(
                              'live-diagnostics-button',
                            ),
                            tooltip: 'Beta Diagnostics',
                            onPressed: sessionLifecycle.isFinishing
                                ? null
                                : _showDiagnosticsPanel,
                            color: Colors.white,
                            iconSize: layout.isLandscape ? 18 : 24,
                            visualDensity: layout.isLandscape
                                ? VisualDensity.compact
                                : VisualDensity.standard,
                            constraints: BoxConstraints.tightFor(
                              width: layout.isLandscape ? 40 : 48,
                              height: layout.isLandscape ? 40 : 48,
                            ),
                            icon: const Icon(Icons.bug_report_outlined),
                          ),
                        ),
                      ),
                    if (workoutDeveloperUiEnabled &&
                        _showCalibrationPanel &&
                        pauseState.isActive)
                      CalibrationPanelOverlay(
                        topInset: topInset,
                        compact: layout.isLandscape,
                        onClose: () {
                          setState(() => _showCalibrationPanel = false);
                        },
                      ),
                  ],
                );

                final useSidePanel =
                    pauseState.isActive && cameraLayout.usesSidePanel;
                if (useSidePanel) {
                  final panelWidth = cameraLayout.sidePanelWidth!;
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Row(
                        key: const ValueKey<String>('live-side-panel-layout'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(child: cameraStage),
                          SizedBox(
                            width: panelWidth,
                            child: hasWorkoutPlan
                                ? PlannedWorkoutLiveHud(
                                    topInset: 0,
                                    compact: true,
                                    sidePanel: true,
                                    isFinishing: sessionLifecycle.isFinishing,
                                    onPause: () =>
                                        _pauseAnalysis(readinessRequest),
                                    onFinish: () =>
                                        unawaited(_requestSessionExit()),
                                  )
                                : LiveAnalysisSidePanel(
                                    isFinishing: sessionLifecycle.isFinishing,
                                    onPause: () =>
                                        _pauseAnalysis(readinessRequest),
                                    onFinish: () =>
                                        unawaited(_requestSessionExit()),
                                    onToggleCalibration:
                                        workoutDeveloperUiEnabled
                                        ? toggleCalibration
                                        : null,
                                    showNonFinalSet: _planAdvanceFailed,
                                    onAdvance: () =>
                                        unawaited(_retryPlannedAdvance()),
                                  ),
                          ),
                        ],
                      ),
                      if (pauseState.isActive && hasWorkoutPlan)
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: panelWidth + 12,
                          child: WorkoutSetCompletedSection(
                            compact: true,
                            showNonFinal: _planAdvanceFailed,
                            onAdvance: () => unawaited(_retryPlannedAdvance()),
                          ),
                        ),
                      if (_plannedResumeCountdownValue != null)
                        PlannedResumeCountdownOverlay(
                          value: _plannedResumeCountdownValue!,
                        ),
                    ],
                  );
                }

                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    cameraStage,
                    if (pauseState.isActive && !hasWorkoutPlan)
                      LiveWorkoutTopBarOverlay(
                        topInset: topInset,
                        compact: layout.isLandscape,
                        reserveLeadingDeveloperControl:
                            workoutDeveloperUiEnabled,
                        isFinishing: sessionLifecycle.isFinishing,
                        onPause: () => _pauseAnalysis(readinessRequest),
                        onFinish: () => unawaited(_requestSessionExit()),
                      )
                    else if (!hasWorkoutPlan || pauseState.isPaused)
                      FinishSessionButton(
                        topInset: topInset,
                        compact: layout.isLandscape,
                        isFinishing: sessionLifecycle.isFinishing,
                        onFinish: () => unawaited(_requestSessionExit()),
                      ),
                    if (pauseState.isActive && hasWorkoutPlan)
                      Positioned.fill(
                        child: PlannedWorkoutLiveHud(
                          topInset: topInset,
                          compact: layout.isLandscape,
                          isFinishing: sessionLifecycle.isFinishing,
                          reserveLeadingDeveloperControl:
                              workoutDeveloperUiEnabled,
                          onPause: () => _pauseAnalysis(readinessRequest),
                          onFinish: () => unawaited(_requestSessionExit()),
                        ),
                      ),
                    if (pauseState.isActive && !hasWorkoutPlan)
                      if (layout.isLandscape)
                        LandscapeWorkoutMetricsOverlay(
                          topInset: topInset,
                          onToggleCalibration: workoutDeveloperUiEnabled
                              ? toggleCalibration
                              : null,
                        )
                      else
                        PrimaryWorkoutMetricsOverlay(
                          topInset: topInset,
                          onToggleCalibration: workoutDeveloperUiEnabled
                              ? toggleCalibration
                              : null,
                        ),
                    if (workoutDeveloperUiEnabled &&
                        pauseState.isActive &&
                        !layout.isLandscape)
                      CanonicalMetricsOverlay(topInset: topInset),
                    if (pauseState.isActive && !hasWorkoutPlan)
                      Positioned(
                        bottom: layout.isLandscape ? 12 : 40,
                        left: layout.isLandscape ? 12 : 20,
                        right: layout.isLandscape ? 12 : 20,
                        child: FractionallySizedBox(
                          widthFactor: layout.isLandscape ? 0.76 : 1,
                          child: Column(
                            children: <Widget>[
                              WorkoutSetCompletedSection(
                                compact: layout.isLandscape,
                                showNonFinal: _planAdvanceFailed,
                                onAdvance: () =>
                                    unawaited(_retryPlannedAdvance()),
                              ),
                              RangeRepSideTrackingIndicator(
                                compact: layout.isLandscape,
                              ),
                              WorkoutFeedbackStatus(
                                compact: layout.isLandscape,
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (pauseState.isActive && hasWorkoutPlan)
                      Positioned(
                        bottom: layout.isLandscape ? 122 : 232,
                        left: layout.isLandscape ? 12 : 20,
                        right: layout.isLandscape ? 12 : 20,
                        child: WorkoutSetCompletedSection(
                          compact: layout.isLandscape,
                          showNonFinal: _planAdvanceFailed,
                          onAdvance: () => unawaited(_retryPlannedAdvance()),
                        ),
                      ),
                    if (_plannedResumeCountdownValue != null)
                      PlannedResumeCountdownOverlay(
                        value: _plannedResumeCountdownValue!,
                      ),
                  ],
                );
              },
              loading: () => const CameraRecoveryView(),
              error: (error, _) {
                final failure = presentWorkoutCameraError(
                  error: error,
                  localizations: localizations,
                );
                if (failure.requiresPermissionAction) {
                  return CameraPermissionFallback(
                    onPressed: _goToPermissionScreen,
                  );
                }

                if (_isRecoveringCamera &&
                    isTransientWorkoutCameraLifecycleError(error)) {
                  return const CameraRecoveryView();
                }

                return LiveCameraFailureView(
                  message: failure.message,
                  actionLabel: failure.actionLabel,
                  onRetry: () => unawaited(_recoverCameraIfAllowed()),
                );
              },
            );
          },
        ),
      ),
    );
  }

  CameraValue? _safeControllerValue(CameraController controller) {
    try {
      return controller.value;
    } catch (_) {
      return null;
    }
  }

  void _ensureImageStream(
    CameraController controller,
    WorkoutSessionLifecycleOwner sessionLifecycle,
  ) {
    _observeCameraGeometry(controller);
    _imageStreamCoordinator.ensureStarted(
      controller: controller,
      shouldStart: () =>
          mounted &&
          !_isRecoveringCamera &&
          !_isPlanTransitionLocked &&
          !sessionLifecycle.isFinishing &&
          _hasAnalysisSelection(),
      onFrame: (image, streamController) {
        if (!mounted || _isPlanTransitionLocked) {
          return;
        }
        if (ref.read(livePauseControllerProvider).isActive) {
          ref
              .read(workoutControllerProvider.notifier)
              .processCameraImage(
                image,
                streamController.description.sensorOrientation,
                cameraLensDirection: streamController.description.lensDirection,
                deviceOrientation: _displayDeviceOrientation,
              );
          return;
        }

        ref
            .read(preparationCameraControllerProvider.notifier)
            .processCameraImage(
              image,
              streamController.description.sensorOrientation,
              lensDirection: streamController.description.lensDirection,
              deviceOrientation: _displayDeviceOrientation,
            );
      },
      onError: (_, _) => _markCameraRecoveringAfterFrame(),
    );
  }

  void _observeCameraGeometry(CameraController controller) {
    if (identical(_observedCameraController, controller)) {
      return;
    }

    _stopObservingCameraGeometry();
    _observedCameraController = controller;
    final value = _safeControllerValue(controller);
    _observedDeviceOrientation = value?.deviceOrientation;
    _observedPreviewSize = value?.previewSize;
    controller.addListener(_handleObservedCameraGeometryChanged);
  }

  void _handleObservedCameraGeometryChanged() {
    final controller = _observedCameraController;
    if (!mounted || controller == null) {
      return;
    }

    final value = _safeControllerValue(controller);
    final nextOrientation = value?.deviceOrientation;
    final nextPreviewSize = value?.previewSize;
    if (_observedDeviceOrientation == nextOrientation &&
        _observedPreviewSize == nextPreviewSize) {
      return;
    }

    _observedDeviceOrientation = nextOrientation;
    _observedPreviewSize = nextPreviewSize;
    setState(() {});
  }

  void _stopObservingCameraGeometry() {
    _observedCameraController?.removeListener(
      _handleObservedCameraGeometryChanged,
    );
    _observedCameraController = null;
    _observedDeviceOrientation = null;
    _observedPreviewSize = null;
  }

  void _markCameraRecoveringAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCameraRecovering();
    });
  }
}
