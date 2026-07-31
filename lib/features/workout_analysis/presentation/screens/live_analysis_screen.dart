import 'dart:async';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/layout/app_layout.dart';
import '../../../../app/layout/camera_layout_spec.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../core/orientation/app_display_orientation.dart';

import '../../application/engine_kind.dart';
import '../../application/feedback_delivery_controller.dart';
import '../../application/workout_developer_ui_config.dart';
import '../../application/workout_engine.dart';
import '../../application/workout_session_lifecycle_controller.dart';
import '../../application/workout_state.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/setup_readiness_state.dart';
import '../camera_image_stream_coordinator.dart';
import '../errors/workout_camera_error_presentation.dart';
import '../models/live_pause_state.dart';
import '../models/preparation_camera_geometry.dart';
import '../models/range_rep_outcome_view_data.dart';
import '../models/live_tracking_state.dart';
import '../models/setup_readiness_view_data.dart';
import '../models/workout_live_metric_display_state.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/completed_session_metrics_provider.dart';
import '../providers/exercise_config_provider.dart';
import '../providers/feedback_delivery_provider.dart';
import '../providers/live_pause_controller.dart';
import '../providers/live_range_rep_outcome_controller.dart';
import '../providers/live_tracking_controller.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/preparation_readiness_controller.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/screen_awake_controller.dart';
import '../providers/workout_controller.dart';
import '../providers/workout_plan_session_provider.dart';
import '../providers/workout_session_lifecycle_controller_provider.dart';
import '../mappers/setup_readiness_ui_mapper.dart';
import '../widgets/analysis_selection_required_view.dart';
import '../widgets/planned_workout_live_hud.dart';
import '../widgets/pose_painter.dart';
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

const Color _liveHudAccent = Color(0xFF61E6BE);
const Color _liveHudSurface = Color(0xD91A2026);
const Color _liveHudSurfaceStrong = Color(0xE6171D23);
const Color _liveHudMetricSurface = Color(0x8F1A2026);
const Color _liveHudMetricSurfaceStrong = Color(0xA6171D23);

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
          body: _CameraRecoveryView(),
        ),
      );
    }

    if (sessionLifecycle.isFinishing) {
      return _buildExitGuard(
        const Scaffold(
          backgroundColor: Colors.black,
          body: _CameraRecoveryView(),
        ),
      );
    }

    final configState = ref.watch(exerciseConfigProvider);
    if (configState.isLoading) {
      return _buildExitGuard(
        const Scaffold(
          backgroundColor: Colors.black,
          body: _ExerciseConfigLoadingView(),
        ),
      );
    }
    if (configState.hasError) {
      return _buildExitGuard(
        Scaffold(
          backgroundColor: Colors.black,
          body: _ExerciseConfigErrorView(
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
                  return const _CameraRecoveryView();
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
                  return const _CameraRecoveryView();
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
                      _WorkoutPoseOverlay(
                        imageSize: imageSize,
                        isMirrored: isMirrored,
                        showDebugLandmarks:
                            workoutDeveloperUiEnabled && _showCalibrationPanel,
                      )
                    else
                      _PausedPoseOverlay(
                        imageSize: imageSize,
                        isMirrored: isMirrored,
                      ),
                    if (pauseState.isActive)
                      const _LiveTrackingRecoveryOverlay(),
                    if (pauseState.isPaused)
                      _LivePauseOverlay(
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
                      _CalibrationPanelOverlay(
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
                                : _LiveAnalysisSidePanel(
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
                          child: _WorkoutSetCompletedSection(
                            compact: true,
                            showNonFinal: _planAdvanceFailed,
                            onAdvance: () => unawaited(_retryPlannedAdvance()),
                          ),
                        ),
                      if (_plannedResumeCountdownValue != null)
                        _PlannedResumeCountdownOverlay(
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
                      _LiveWorkoutTopBarOverlay(
                        topInset: topInset,
                        compact: layout.isLandscape,
                        reserveLeadingDeveloperControl:
                            workoutDeveloperUiEnabled,
                        isFinishing: sessionLifecycle.isFinishing,
                        onPause: () => _pauseAnalysis(readinessRequest),
                        onFinish: () => unawaited(_requestSessionExit()),
                      )
                    else if (!hasWorkoutPlan || pauseState.isPaused)
                      _FinishSessionButton(
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
                        _LandscapeWorkoutMetricsOverlay(
                          topInset: topInset,
                          onToggleCalibration: workoutDeveloperUiEnabled
                              ? toggleCalibration
                              : null,
                        )
                      else
                        _PrimaryWorkoutMetricsOverlay(
                          topInset: topInset,
                          onToggleCalibration: workoutDeveloperUiEnabled
                              ? toggleCalibration
                              : null,
                        ),
                    if (workoutDeveloperUiEnabled &&
                        pauseState.isActive &&
                        !layout.isLandscape)
                      _CanonicalMetricsOverlay(topInset: topInset),
                    if (pauseState.isActive && !hasWorkoutPlan)
                      Positioned(
                        bottom: layout.isLandscape ? 12 : 40,
                        left: layout.isLandscape ? 12 : 20,
                        right: layout.isLandscape ? 12 : 20,
                        child: FractionallySizedBox(
                          widthFactor: layout.isLandscape ? 0.76 : 1,
                          child: Column(
                            children: <Widget>[
                              _WorkoutSetCompletedSection(
                                compact: layout.isLandscape,
                                showNonFinal: _planAdvanceFailed,
                                onAdvance: () =>
                                    unawaited(_retryPlannedAdvance()),
                              ),
                              _RangeRepSideTrackingIndicator(
                                compact: layout.isLandscape,
                              ),
                              _WorkoutFeedbackStatus(
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
                        child: _WorkoutSetCompletedSection(
                          compact: layout.isLandscape,
                          showNonFinal: _planAdvanceFailed,
                          onAdvance: () => unawaited(_retryPlannedAdvance()),
                        ),
                      ),
                    if (_plannedResumeCountdownValue != null)
                      _PlannedResumeCountdownOverlay(
                        value: _plannedResumeCountdownValue!,
                      ),
                  ],
                );
              },
              loading: () => const _CameraRecoveryView(),
              error: (error, _) {
                final failure = presentWorkoutCameraError(
                  error: error,
                  localizations: localizations,
                );
                if (failure.requiresPermissionAction) {
                  return _CameraPermissionFallback(
                    onPressed: _goToPermissionScreen,
                  );
                }

                if (_isRecoveringCamera &&
                    isTransientWorkoutCameraLifecycleError(error)) {
                  return const _CameraRecoveryView();
                }

                return _LiveCameraFailureView(
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
        final cameraValue = _safeControllerValue(streamController);
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

class _PausedPoseOverlay extends ConsumerWidget {
  const _PausedPoseOverlay({required this.imageSize, required this.isMirrored});

  final Size imageSize;
  final bool isMirrored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landmarks = ref.watch(
      preparationCameraControllerProvider.select((state) => state.landmarks),
    );
    if (landmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: PosePainter(
        landmarks,
        imageSize,
        isFormBad: false,
        isMirrored: isMirrored,
      ),
    );
  }
}

class _LivePauseOverlay extends ConsumerWidget {
  const _LivePauseOverlay({
    required this.readinessRequest,
    required this.onResume,
    required this.onCancelResume,
  });

  final SetupReadinessRequest readinessRequest;
  final VoidCallback onResume;
  final VoidCallback onCancelResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pauseState = ref.watch(livePauseControllerProvider);
    if (pauseState.isActive) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);
    final readinessProvider = preparationReadinessStateProvider(
      readinessRequest,
    );
    ref.listen<SetupReadinessSnapshot>(readinessProvider, (_, next) {
      ref.read(livePauseControllerProvider.notifier).updateReadiness(next);
    });
    final readiness = ref.watch(readinessProvider);
    final readinessView = mapSetupReadinessToViewData(
      localizations: localizations,
      readinessSnapshot: readiness,
    );
    final presentation = _livePausePresentation(
      state: pauseState,
      readinessView: readinessView,
      localizations: localizations,
    );

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.46),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 96, 24, 36),
              child: Container(
                key: const ValueKey<String>('live-pause-overlay'),
                constraints: const BoxConstraints(maxWidth: 430),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: presentation.color.withValues(alpha: 0.62),
                    width: 1.4,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 26,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: presentation.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        presentation.icon,
                        color: presentation.color,
                        size: 31,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      presentation.title,
                      key: const ValueKey<String>('live-pause-title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      presentation.message,
                      key: const ValueKey<String>('live-pause-message'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pauseState.isCountingDown) ...<Widget>[
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Text(
                          '${pauseState.countdownValue ?? ''}',
                          key: ValueKey<String>(
                            'live-resume-countdown-${pauseState.countdownValue}',
                          ),
                          semanticsLabel: localizations
                              .liveResumeCountdownSemantics(
                                pauseState.countdownValue ?? 0,
                              ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    if (pauseState.phase == LivePausePhase.paused)
                      FilledButton.icon(
                        key: const ValueKey<String>('live-resume-button'),
                        onPressed: onResume,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(localizations.resumeWorkout),
                      )
                    else
                      OutlinedButton.icon(
                        key: const ValueKey<String>(
                          'live-cancel-resume-button',
                        ),
                        onPressed: onCancelResume,
                        icon: const Icon(Icons.pause_rounded),
                        label: Text(localizations.returnToPause),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveWorkoutTopBarOverlay extends StatelessWidget {
  const _LiveWorkoutTopBarOverlay({
    required this.topInset,
    required this.compact,
    required this.reserveLeadingDeveloperControl,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
  });

  final double topInset;
  final bool compact;
  final bool reserveLeadingDeveloperControl;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final horizontalInset = compact ? 12.0 : 16.0;
    final leftInset = reserveLeadingDeveloperControl
        ? (compact ? 58.0 : 68.0)
        : horizontalInset;

    return Positioned(
      key: const ValueKey<String>('live-workout-top-bar-overlay'),
      top: topInset + (compact ? 8 : 12),
      left: leftInset,
      right: horizontalInset,
      child: _LiveWorkoutTopBar(
        compact: compact,
        isFinishing: isFinishing,
        onPause: onPause,
        onFinish: onFinish,
      ),
    );
  }
}

class _LiveWorkoutTopBar extends StatelessWidget {
  const _LiveWorkoutTopBar({
    required this.compact,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
  });

  final bool compact;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return SizedBox(
      key: const ValueKey<String>('live-workout-top-bar'),
      height: compact ? 42 : 54,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _LiveHudActionButton(
                key: const ValueKey<String>('live-pause-button'),
                compact: compact,
                label: localizations.pauseWorkout,
                icon: Icons.pause_rounded,
                accentColor: _liveHudAccent,
                onPressed: onPause,
              ),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          const Expanded(flex: 3, child: _ActiveExerciseTitle()),
          SizedBox(width: compact ? 6 : 10),
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child: _LiveHudActionButton(
                key: const ValueKey<String>('live-finish-button'),
                compact: compact,
                label: localizations.finish,
                icon: Icons.stop_rounded,
                accentColor: Colors.white70,
                onPressed: isFinishing ? null : onFinish,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_LivePausePresentation _livePausePresentation({
  required LivePauseState state,
  required SetupReadinessViewData readinessView,
  required AppLocalizations localizations,
}) {
  return switch (state.phase) {
    LivePausePhase.active => _LivePausePresentation(
      title: '',
      message: '',
      color: Colors.greenAccent,
      icon: Icons.play_arrow_rounded,
    ),
    LivePausePhase.paused => _LivePausePresentation(
      title: localizations.workoutPausedTitle,
      message: localizations.workoutPausedMessage,
      color: Colors.cyanAccent,
      icon: Icons.pause_rounded,
    ),
    LivePausePhase.resumeMonitoring => _LivePausePresentation(
      title: localizations.resumeReadinessTitle,
      message: readinessView.message,
      color:
          readinessView.visualState == SetupReadinessVisualState.needsAdjustment
          ? Colors.amberAccent
          : Colors.cyanAccent,
      icon:
          readinessView.visualState == SetupReadinessVisualState.needsAdjustment
          ? Icons.center_focus_weak_rounded
          : Icons.track_changes_rounded,
    ),
    LivePausePhase.resumeCountingDown => _LivePausePresentation(
      title: localizations.resumeCountdownTitle,
      message: localizations.resumeCountdownMessage,
      color: Colors.greenAccent,
      icon: Icons.play_arrow_rounded,
    ),
  };
}

class _LivePausePresentation {
  const _LivePausePresentation({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;
}

class _WorkoutPoseOverlay extends ConsumerWidget {
  const _WorkoutPoseOverlay({
    required this.imageSize,
    required this.isMirrored,
    required this.showDebugLandmarks,
  });

  final Size imageSize;
  final bool isMirrored;
  final bool showDebugLandmarks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pose = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          landmarks: state.landmarks,
          isFormBad: state.isFormBad,
          movementSelectedSide:
              state.calibrationMetrics.rangeRepMovementSelectedSide,
        ),
      ),
    );
    final landmarks = pose.landmarks;
    if (landmarks == null || landmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: PosePainter(
        landmarks,
        imageSize,
        isFormBad: pose.isFormBad,
        isMirrored: isMirrored,
        showDebugLandmarks: showDebugLandmarks,
        emphasizedSide: pose.movementSelectedSide,
      ),
    );
  }
}

class _LiveTrackingRecoveryOverlay extends ConsumerWidget {
  const _LiveTrackingRecoveryOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(
      liveTrackingControllerProvider.select((state) => state.phase),
    );
    if (phase == LiveTrackingPhase.tracking) {
      return const SizedBox.shrink();
    }

    final presentation = _liveTrackingPresentation(
      phase,
      AppLocalizations.of(context),
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Container(
                key: ValueKey<LiveTrackingPhase>(phase),
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: presentation.color.withValues(alpha: 0.72),
                    width: 1.4,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: presentation.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        presentation.icon,
                        color: presentation.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      presentation.title,
                      key: const ValueKey<String>(
                        'live-tracking-overlay-title',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      presentation.message,
                      key: const ValueKey<String>(
                        'live-tracking-overlay-message',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinishSessionButton extends ConsumerWidget {
  const _FinishSessionButton({
    required this.topInset,
    required this.compact,
    required this.isFinishing,
    required this.onFinish,
  });

  final double topInset;
  final bool compact;
  final bool isFinishing;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPlan = ref.watch(
      workoutPlanSessionProvider.select((state) => state.hasPlan),
    );
    final localizations = AppLocalizations.of(context);

    return Positioned(
      top: topInset + (compact ? 8 : 12),
      right: compact ? 10 : 14,
      child: _LiveHudActionButton(
        key: const ValueKey<String>('live-finish-button'),
        compact: compact,
        label: hasPlan ? localizations.endWorkout : localizations.finish,
        icon: Icons.stop_rounded,
        accentColor: Colors.white70,
        onPressed: isFinishing ? null : onFinish,
      ),
    );
  }
}

class _LiveAnalysisSidePanel extends ConsumerWidget {
  const _LiveAnalysisSidePanel({
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
    required this.onToggleCalibration,
    required this.showNonFinalSet,
    required this.onAdvance,
  });

  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final VoidCallback? onToggleCalibration;
  final bool showNonFinalSet;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final liveMetrics = ref.watch(workoutLiveMetricsProvider);
    final hasCanonicalMetrics =
        workoutDeveloperUiEnabled &&
        (liveMetrics.angleDegrees != null ||
            liveMetrics.tempo != null ||
            liveMetrics.stabilityScore != null ||
            liveMetrics.asymmetryScore != null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useStackedLayout = constraints.maxWidth < 320 || textScale >= 1.5;

        return ColoredBox(
          key: const ValueKey<String>('live-analysis-side-panel'),
          color: const Color(0xF0161B20),
          child: SafeArea(
            left: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _LiveSidePanelToolbar(
                    stacked: useStackedLayout,
                    pauseLabel: localizations.pauseWorkout,
                    finishLabel: localizations.finish,
                    isFinishing: isFinishing,
                    onPause: onPause,
                    onFinish: onFinish,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey<String>('live-side-panel-scroll'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const _WorkoutFeedbackStatus(
                            compact: true,
                            sidePanel: true,
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            key: const ValueKey<String>(
                              'live-performance-header',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onLongPress: onToggleCalibration,
                            child: useStackedLayout
                                ? const Column(
                                    key: ValueKey<String>(
                                      'live-hud-stacked-metrics',
                                    ),
                                    children: <Widget>[
                                      SizedBox(
                                        height: 86,
                                        child: _PrimaryWorkoutMetricCard(
                                          compact: true,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      SizedBox(
                                        height: 86,
                                        child: _SecondaryWorkoutMetricCard(
                                          compact: true,
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox(
                                    height: 78,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        Expanded(
                                          flex: 3,
                                          child: _PrimaryWorkoutMetricCard(
                                            compact: true,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: _SecondaryWorkoutMetricCard(
                                            compact: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          if (hasCanonicalMetrics) ...<Widget>[
                            const SizedBox(height: 8),
                            _LiveCanonicalMetricsBar(
                              metrics: liveMetrics,
                              compact: true,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _WorkoutSetCompletedSection(
                            compact: true,
                            showNonFinal: showNonFinalSet,
                            onAdvance: onAdvance,
                          ),
                          const SizedBox(height: 6),
                          const _RangeRepSideTrackingIndicator(compact: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiveSidePanelToolbar extends StatelessWidget {
  const _LiveSidePanelToolbar({
    required this.stacked,
    required this.pauseLabel,
    required this.finishLabel,
    required this.isFinishing,
    required this.onPause,
    required this.onFinish,
  });

  final bool stacked;
  final String pauseLabel;
  final String finishLabel;
  final bool isFinishing;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Column(
        key: const ValueKey<String>('live-hud-stacked-header'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(
            height: 42,
            child: _ActiveExerciseTitle(compact: true, maxLines: 2),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _LiveHudActionButton(
                  key: const ValueKey<String>('live-pause-button'),
                  compact: true,
                  label: pauseLabel,
                  icon: Icons.pause_rounded,
                  accentColor: _liveHudAccent,
                  onPressed: onPause,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LiveHudActionButton(
                  key: const ValueKey<String>('live-finish-button'),
                  compact: true,
                  label: finishLabel,
                  icon: Icons.stop_rounded,
                  accentColor: Colors.white70,
                  onPressed: isFinishing ? null : onFinish,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _LiveHudActionButton(
                key: const ValueKey<String>('live-pause-button'),
                compact: true,
                label: pauseLabel,
                icon: Icons.pause_rounded,
                accentColor: _liveHudAccent,
                onPressed: onPause,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: _ActiveExerciseTitle(compact: true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: Align(
              alignment: Alignment.centerRight,
              child: _LiveHudActionButton(
                key: const ValueKey<String>('live-finish-button'),
                compact: true,
                label: finishLabel,
                icon: Icons.stop_rounded,
                accentColor: Colors.white70,
                onPressed: isFinishing ? null : onFinish,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveHudActionButton extends StatelessWidget {
  const _LiveHudActionButton({
    super.key,
    required this.compact,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
  });

  final bool compact;
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: compact ? 7 : 10,
            ),
            decoration: BoxDecoration(
              color: _liveHudSurface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: accentColor.withValues(
                  alpha: onPressed == null ? 0.18 : 0.48,
                ),
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: compact ? 160 : 220),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: compact ? 24 : 30,
                    height: compact ? 24 : 30,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: onPressed == null ? Colors.white30 : accentColor,
                      size: compact ? 15 : 18,
                    ),
                  ),
                  SizedBox(width: compact ? 7 : 9),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: onPressed == null
                              ? Colors.white38
                              : Colors.white,
                          fontSize: compact ? 12 : 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandscapeWorkoutMetricsOverlay extends ConsumerWidget {
  const _LandscapeWorkoutMetricsOverlay({
    required this.topInset,
    required this.onToggleCalibration,
  });

  final double topInset;
  final VoidCallback? onToggleCalibration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveMetrics = ref.watch(workoutLiveMetricsProvider);
    final hasCanonicalMetrics =
        workoutDeveloperUiEnabled &&
        (liveMetrics.angleDegrees != null ||
            liveMetrics.tempo != null ||
            liveMetrics.stabilityScore != null ||
            liveMetrics.asymmetryScore != null);

    return Positioned(
      top: topInset + 58,
      left: 14,
      right: 14,
      child: GestureDetector(
        key: const ValueKey<String>('live-performance-header'),
        behavior: HitTestBehavior.opaque,
        onLongPress: onToggleCalibration,
        child: SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(
                flex: 3,
                child: _PrimaryWorkoutMetricCard(compact: true),
              ),
              const SizedBox(width: 8),
              const Expanded(
                flex: 2,
                child: _SecondaryWorkoutMetricCard(compact: true),
              ),
              if (hasCanonicalMetrics) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: _LiveCanonicalMetricsBar(
                    metrics: liveMetrics,
                    compact: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryWorkoutMetricsOverlay extends StatelessWidget {
  const _PrimaryWorkoutMetricsOverlay({
    required this.topInset,
    required this.onToggleCalibration,
  });

  final double topInset;
  final VoidCallback? onToggleCalibration;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topInset + 82,
      left: 16,
      right: 16,
      child: GestureDetector(
        key: const ValueKey<String>('live-performance-header'),
        behavior: HitTestBehavior.opaque,
        onLongPress: onToggleCalibration,
        child: const SizedBox(
          height: 104,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _PrimaryWorkoutMetricCard()),
              SizedBox(width: 10),
              Expanded(flex: 2, child: _SecondaryWorkoutMetricCard()),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveExerciseTitle extends ConsumerWidget {
  const _ActiveExerciseTitle({this.compact = false, this.maxLines = 1});

  final bool compact;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(activeAnalysisExerciseProvider);
    if (exercise == null) {
      return const SizedBox.shrink();
    }

    final title = AppLocalizations.of(context).exerciseTitle(exercise.id);
    final titleText = Text(
      title,
      key: const ValueKey<String>('live-active-exercise-name'),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: compact ? 18 : 25,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
    );

    return Semantics(
      label: title,
      header: true,
      excludeSemantics: true,
      child: maxLines > 1
          ? Center(child: titleText)
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: titleText,
            ),
    );
  }
}

class _PrimaryWorkoutMetricCard extends ConsumerWidget {
  const _PrimaryWorkoutMetricCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          analysisKind: state.analysisKind,
          repCount: state.repCount,
          holdSeconds: _displayWholeSeconds(state.currentHoldSeconds),
        ),
      ),
    );
    final isHoldAnalysis = metric.analysisKind == EngineKind.hold;
    final localizations = AppLocalizations.of(context);
    final value = isHoldAnalysis
        ? _formatHoldSeconds(metric.holdSeconds)
        : metric.repCount.toString();

    return _LiveMetricSurface(
      key: const ValueKey<String>('live-primary-metric-card'),
      label: isHoldAnalysis
          ? localizations.holdMetric
          : localizations.repMetric,
      value: value,
      valueStyle: TextStyle(
        color: Colors.white,
        fontSize: compact ? 34 : 52,
        height: 0.96,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
      ),
      icon: isHoldAnalysis ? Icons.timer_outlined : Icons.repeat_rounded,
      accentColor: _liveHudAccent,
      emphasize: true,
      compact: compact,
    );
  }
}

class _SecondaryWorkoutMetricCard extends ConsumerWidget {
  const _SecondaryWorkoutMetricCard({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          analysisKind: state.analysisKind,
          repCount: state.repCount,
          bestHoldSeconds: _displayWholeSeconds(state.bestHoldSeconds),
          lastRepScore: _displayScore(state.lastRepScore),
          lastValidationStatus:
              state.calibrationMetrics.lastRangeRepValidationStatus,
        ),
      ),
    );
    final isHoldAnalysis = metric.analysisKind == EngineKind.hold;
    final localizations = AppLocalizations.of(context);
    final isInvalidLastAttempt = metric.lastValidationStatus == 'invalid';
    final isLowConfidenceLastRep =
        metric.lastValidationStatus == 'low confidence' ||
        metric.lastValidationStatus == 'lowConfidence';
    final hasRepScore = metric.repCount > 0 && !isInvalidLastAttempt;
    final String value;
    if (isHoldAnalysis) {
      value = _formatHoldSeconds(metric.bestHoldSeconds);
    } else if (hasRepScore) {
      value = metric.lastRepScore.toString();
    } else {
      value = '—';
    }

    return _LiveMetricSurface(
      key: const ValueKey<String>('live-secondary-metric-card'),
      label: isHoldAnalysis
          ? localizations.bestMetric
          : localizations.formRangeScoreMetric,
      value: value,
      valueStyle: TextStyle(
        color: isHoldAnalysis || hasRepScore
            ? isLowConfidenceLastRep
                  ? Colors.amberAccent
                  : _liveHudAccent
            : Colors.white54,
        fontSize: compact ? 24 : 31,
        height: 1,
        fontWeight: FontWeight.w800,
      ),
      icon: Icons.star_rounded,
      accentColor: isHoldAnalysis || hasRepScore
          ? isLowConfidenceLastRep
                ? Colors.amberAccent
                : _liveHudAccent
          : Colors.white38,
      compact: compact,
    );
  }
}

class _LiveMetricSurface extends StatelessWidget {
  const _LiveMetricSurface({
    super.key,
    required this.label,
    required this.value,
    required this.valueStyle,
    required this.icon,
    required this.accentColor,
    this.emphasize = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;
  final IconData icon;
  final Color accentColor;
  final bool emphasize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: 8,
          vertical: compact ? 8 : 12,
        ),
        decoration: _liveHudSurfaceDecoration(
          accentColor: accentColor,
          strong: emphasize,
          radius: compact ? 18 : 25,
          surfaceColor: emphasize
              ? _liveHudMetricSurfaceStrong
              : _liveHudMetricSurface,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: compact ? 28 : 36,
              height: compact ? 28 : 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: emphasize ? 0.65 : 0.42),
                ),
              ),
              child: Icon(icon, color: accentColor, size: compact ? 16 : 21),
            ),
            SizedBox(width: compact ? 7 : 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.92,
                                    end: 1,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            value,
                            key: ValueKey<String>(value),
                            maxLines: 1,
                            style: valueStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _sentenceCaseLiveMetricLabel(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accentColor == Colors.white38
                          ? Colors.white38
                          : Colors.white70,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanonicalMetricsOverlay extends ConsumerWidget {
  const _CanonicalMetricsOverlay({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveMetrics = ref.watch(workoutLiveMetricsProvider);
    return Positioned(
      top: topInset + 190,
      left: 20,
      right: 20,
      child: _LiveCanonicalMetricsBar(metrics: liveMetrics),
    );
  }
}

class _CalibrationPanelOverlay extends ConsumerWidget {
  const _CalibrationPanelOverlay({
    required this.topInset,
    required this.compact,
    required this.onClose,
  });

  final double topInset;
  final bool compact;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutState = ref.watch(workoutControllerProvider);
    final hasPlan = ref.watch(
      workoutPlanSessionProvider.select((state) => state.hasPlan),
    );

    return Positioned(
      top: topInset + (compact ? (hasPlan ? 192 : 140) : (hasPlan ? 366 : 294)),
      bottom: compact ? 88 : null,
      left: compact ? 14 : 20,
      right: compact ? 14 : 20,
      child: _CalibrationDebugPanel(
        workoutState: workoutState,
        onClose: onClose,
      ),
    );
  }
}

class _PlannedResumeCountdownOverlay extends StatelessWidget {
  const _PlannedResumeCountdownOverlay({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.62),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.nextSetStarting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  liveRegion: true,
                  label: '$value',
                  child: Text(
                    '$value',
                    key: ValueKey<String>('planned-resume-countdown-$value'),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 104,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutSetCompletedSection extends ConsumerWidget {
  const _WorkoutSetCompletedSection({
    required this.compact,
    required this.showNonFinal,
    required this.onAdvance,
  });

  final bool compact;
  final bool showNonFinal;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(
      workoutPlanSessionProvider.select(
        (state) =>
            (isSetCompleted: state.isSetCompleted, snapshot: state.snapshot),
      ),
    );
    final snapshot = plan.snapshot;
    if (!plan.isSetCompleted || snapshot == null) {
      return const SizedBox.shrink();
    }

    final isFinalSet = snapshot.completedSets >= snapshot.totalSets;
    if (!isFinalSet && !showNonFinal) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _WorkoutSetCompletedCard(
          key: ValueKey<String>(
            'planned-set-${snapshot.roundNumber}-${snapshot.exerciseIndex}-${snapshot.setNumber}-${snapshot.completedSets}',
          ),
          isFinalSet: isFinalSet,
          compact: compact,
          onAdvance: onAdvance,
        ),
        SizedBox(height: compact ? 6 : 10),
      ],
    );
  }
}

class _RangeRepSideTrackingIndicator extends ConsumerWidget {
  const _RangeRepSideTrackingIndicator({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sideState = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          analysisKind: state.analysisKind,
          enabled:
              state.calibrationMetrics.rangeRepAutomaticSideSelectionEnabled,
          movementSelectedSide:
              state.calibrationMetrics.rangeRepMovementSelectedSide,
        ),
      ),
    );
    final trackingPhase = ref.watch(
      liveTrackingControllerProvider.select((state) => state.phase),
    );
    if (sideState.analysisKind != EngineKind.rangeRep ||
        !sideState.enabled ||
        trackingPhase != LiveTrackingPhase.tracking) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);
    final selectedSide = sideState.movementSelectedSide;
    final hasSelectedSide = selectedSide != null;
    final accentColor = hasSelectedSide
        ? const Color(0xFF65D8FF)
        : Colors.white70;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 9),
      child: AnimatedContainer(
        key: const ValueKey<String>('live-range-rep-side-indicator'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 14,
          vertical: compact ? 7 : 9,
        ),
        decoration: _liveHudSurfaceDecoration(
          accentColor: accentColor,
          radius: compact ? 17 : 21,
          surfaceColor: _liveHudSurface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: compact ? 32 : 38,
              height: compact ? 32 : 38,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withValues(alpha: 0.55)),
              ),
              child: Icon(
                hasSelectedSide
                    ? Icons.directions_walk_rounded
                    : Icons.swap_horiz_rounded,
                size: compact ? 18 : 22,
                color: accentColor,
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Flexible(
              child: Text(
                hasSelectedSide
                    ? localizations.trackedLeg(selectedSide)
                    : localizations.automaticLegSelectionPrompt,
                key: const ValueKey<String>(
                  'live-range-rep-side-indicator-text',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 13 : 15,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _WorkoutFeedbackKind { coaching, repOutcome }

class _WorkoutFeedbackStatus extends StatelessWidget {
  const _WorkoutFeedbackStatus({required this.compact, this.sidePanel = false});

  final bool compact;
  final bool sidePanel;

  @override
  Widget build(BuildContext context) {
    return _WorkoutFeedbackMessage(compact: compact, sidePanel: sidePanel);
  }
}

class _WorkoutFeedbackMessage extends ConsumerWidget {
  const _WorkoutFeedbackMessage({
    required this.compact,
    this.sidePanel = false,
  });

  final bool compact;
  final bool sidePanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(
      workoutControllerProvider.select(
        (state) => (
          message: state.feedbackMessage,
          isFormBad: state.isFormBad,
          currentPhase: state.currentPhase,
        ),
      ),
    );
    final repOutcome = ref.watch(liveRangeRepOutcomeProvider);
    final trackingPhase = ref.watch(
      liveTrackingControllerProvider.select((state) => state.phase),
    );
    if (trackingPhase != LiveTrackingPhase.tracking) {
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context);
    final presentation = _feedbackPresentation(
      feedback: feedback,
      repOutcome: repOutcome,
      localizations: localizations,
    );
    final accentColor = presentation.accentColor;
    final isRepOutcome = presentation.kind == _WorkoutFeedbackKind.repOutcome;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${presentation.title}. ${presentation.message}',
      excludeSemantics: true,
      child: AnimatedContainer(
        key: const ValueKey<String>('live-feedback-message-card'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 10 : 14,
        ),
        decoration: _liveHudSurfaceDecoration(
          accentColor: accentColor,
          strong: isRepOutcome,
          radius: compact ? 18 : 24,
          surfaceColor: isRepOutcome ? _liveHudSurfaceStrong : _liveHudSurface,
        ),
        child: sidePanel
            ? Column(
                key: const ValueKey<String>('live-feedback-side-panel-content'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        key: ValueKey<String>(
                          'live-feedback-kind-${presentation.kind.name}',
                        ),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentColor.withValues(
                              alpha: isRepOutcome ? 0.85 : 0.62,
                            ),
                            width: isRepOutcome ? 1.5 : 1.2,
                          ),
                        ),
                        child: Icon(
                          presentation.icon,
                          color: accentColor,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          presentation.title,
                          key: const ValueKey<String>(
                            'live-analysis-status-line',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor.withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      presentation.message,
                      key: ValueKey<String>(presentation.message),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    key: ValueKey<String>(
                      'live-feedback-kind-${presentation.kind.name}',
                    ),
                    width: compact ? 40 : 50,
                    height: compact ? 40 : 50,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(
                          alpha: isRepOutcome ? 0.85 : 0.62,
                        ),
                        width: isRepOutcome ? 1.5 : 1.2,
                      ),
                    ),
                    child: Icon(
                      presentation.icon,
                      color: accentColor,
                      size: compact ? 23 : 30,
                    ),
                  ),
                  SizedBox(width: compact ? 10 : 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          presentation.title,
                          key: const ValueKey<String>(
                            'live-analysis-status-line',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor.withValues(alpha: 0.92),
                            fontSize: compact ? 12 : 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.05,
                          ),
                        ),
                        SizedBox(height: compact ? 3 : 5),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            presentation.message,
                            key: ValueKey<String>(presentation.message),
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 18 : 22,
                              height: 1.16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

BoxDecoration _liveHudSurfaceDecoration({
  required Color accentColor,
  required double radius,
  bool strong = false,
  Color? surfaceColor,
}) {
  return BoxDecoration(
    color: surfaceColor ?? (strong ? _liveHudSurfaceStrong : _liveHudSurface),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: accentColor.withValues(alpha: strong ? 0.48 : 0.28),
    ),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 7)),
    ],
  );
}

String _sentenceCaseLiveMetricLabel(String value) {
  if (value.isEmpty) {
    return value;
  }
  final lower = value.toLowerCase();
  return '${lower.substring(0, 1).toUpperCase()}${lower.substring(1)}';
}

_FeedbackPresentation _feedbackPresentation({
  required ({String message, bool isFormBad, String currentPhase}) feedback,
  required RangeRepOutcomeViewData? repOutcome,
  required AppLocalizations localizations,
}) {
  if (repOutcome != null) {
    return switch (repOutcome.tone) {
      RangeRepOutcomeTone.positive => _FeedbackPresentation(
        title: repOutcome.title,
        message: repOutcome.message,
        accentColor: _liveHudAccent,
        icon: Icons.check_circle_rounded,
        kind: _WorkoutFeedbackKind.repOutcome,
      ),
      RangeRepOutcomeTone.caution => _FeedbackPresentation(
        title: repOutcome.title,
        message: repOutcome.message,
        accentColor: Colors.amberAccent,
        icon: Icons.info_rounded,
        kind: _WorkoutFeedbackKind.repOutcome,
      ),
      RangeRepOutcomeTone.invalid => _FeedbackPresentation(
        title: repOutcome.title,
        message: repOutcome.message,
        accentColor: Colors.orangeAccent,
        icon: Icons.replay_rounded,
        kind: _WorkoutFeedbackKind.repOutcome,
      ),
    };
  }

  return _FeedbackPresentation(
    title: localizations.workoutPhaseLabel(feedback.currentPhase),
    message: feedback.message,
    accentColor: feedback.isFormBad ? Colors.amberAccent : _liveHudAccent,
    icon: feedback.isFormBad ? Icons.tune_rounded : Icons.check_rounded,
    kind: _WorkoutFeedbackKind.coaching,
  );
}

class _FeedbackPresentation {
  const _FeedbackPresentation({
    required this.title,
    required this.message,
    required this.accentColor,
    required this.icon,
    required this.kind,
  });

  final String title;
  final String message;
  final Color accentColor;
  final IconData icon;
  final _WorkoutFeedbackKind kind;
}

_LiveTrackingPresentation _liveTrackingPresentation(
  LiveTrackingPhase phase,
  AppLocalizations localizations,
) {
  return switch (phase) {
    LiveTrackingPhase.tracking => _LiveTrackingPresentation(
      title: '',
      message: '',
      color: Colors.greenAccent,
      icon: Icons.check_rounded,
    ),
    LiveTrackingPhase.temporarilyLost => _LiveTrackingPresentation(
      title: localizations.liveTrackingTemporarilyLostTitle,
      message: localizations.liveTrackingTemporarilyLostMessage,
      color: Colors.amberAccent,
      icon: Icons.visibility_off_outlined,
    ),
    LiveTrackingPhase.repositionRequired => _LiveTrackingPresentation(
      title: localizations.liveTrackingRepositionTitle,
      message: localizations.liveTrackingRepositionMessage,
      color: Colors.orangeAccent,
      icon: Icons.center_focus_weak_rounded,
    ),
    LiveTrackingPhase.reacquiring => _LiveTrackingPresentation(
      title: localizations.liveTrackingReacquiringTitle,
      message: localizations.liveTrackingReacquiringMessage,
      color: Colors.cyanAccent,
      icon: Icons.track_changes_rounded,
    ),
  };
}

class _LiveTrackingPresentation {
  const _LiveTrackingPresentation({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;
}

int _displayWholeSeconds(double seconds) {
  if (!seconds.isFinite || seconds <= 0) {
    return 0;
  }
  return Duration(milliseconds: (seconds * 1000).round()).inSeconds;
}

int _displayScore(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return value.toInt();
}

String _formatHoldSeconds(int seconds) {
  final duration = Duration(seconds: seconds);
  final minutes = duration.inMinutes;
  final remainingSeconds = duration.inSeconds
      .remainder(60)
      .toString()
      .padLeft(2, '0');
  return '$minutes:$remainingSeconds';
}

class _WorkoutSetCompletedCard extends StatelessWidget {
  const _WorkoutSetCompletedCard({
    super.key,
    required this.isFinalSet,
    required this.compact,
    required this.onAdvance,
  });

  final bool isFinalSet;
  final bool compact;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xE6112A20),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: compact ? 20 : 24,
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Text(
              isFinalSet
                  ? localizations.finalSetCompleted
                  : localizations.setCompletedContinue,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          ElevatedButton(
            onPressed: onAdvance,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            child: Text(
              isFinalSet ? localizations.finish : localizations.continueLabel,
              style: TextStyle(fontSize: compact ? 12 : 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseConfigLoadingView extends StatelessWidget {
  const _ExerciseConfigLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.greenAccent),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).analysisConfigLoading,
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ExerciseConfigErrorView extends StatelessWidget {
  const _ExerciseConfigErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune_rounded, color: Colors.greenAccent, size: 42),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).analysisConfigLoadFailed,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).analysisConfigRequiredMessage,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context).retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraRecoveryView extends StatelessWidget {
  const _CameraRecoveryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.greenAccent),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).cameraRecovering,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveCameraFailureView extends StatelessWidget {
  const _LiveCameraFailureView({
    required this.message,
    required this.actionLabel,
    required this.onRetry,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey<String>('live-camera-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: Colors.greenAccent,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _CameraPermissionFallback extends StatelessWidget {
  const _CameraPermissionFallback({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: Colors.greenAccent,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).cameraPermissionRequired,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).cameraPermissionFallbackBody,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 15,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(AppLocalizations.of(context).checkPermission),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCanonicalMetricsBar extends StatelessWidget {
  const _LiveCanonicalMetricsBar({required this.metrics, this.compact = false});

  final WorkoutLiveMetricDisplayState metrics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final items = <MapEntry<String, String>>[];

    final angleDegrees = metrics.angleDegrees;
    if (angleDegrees != null) {
      items.add(
        MapEntry<String, String>(localizations.angleMetric, '$angleDegrees°'),
      );
    }

    final tempo = metrics.tempo;
    if (tempo != null) {
      items.add(
        MapEntry<String, String>(
          localizations.tempoMetric,
          _formatMetricDuration(localizations, tempo),
        ),
      );
    }

    final stabilityScore = metrics.stabilityScore;
    if (stabilityScore != null) {
      items.add(
        MapEntry<String, String>(
          localizations.stabilityMetric,
          stabilityScore.toString(),
        ),
      );
    }

    final asymmetryScore = metrics.asymmetryScore;
    if (asymmetryScore != null) {
      items.add(
        MapEntry<String, String>(
          localizations.asymmetryMetric,
          asymmetryScore.toString(),
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const ValueKey<String>('live-canonical-metrics-bar'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(compact ? 18 : 14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.take(3).length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[index].key,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: compact ? 8 : 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[index].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatMetricDuration(
  AppLocalizations localizations,
  Duration duration,
) {
  if (duration.inMilliseconds < 1000) {
    return '${duration.inMilliseconds} ms';
  }
  return localizations.secondsValue(duration.inMilliseconds / 1000);
}

class _CalibrationDebugPanel extends StatelessWidget {
  const _CalibrationDebugPanel({
    required this.workoutState,
    required this.onClose,
  });

  final WorkoutState workoutState;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final metrics = workoutState.calibrationMetrics;
    final isHoldAnalysis = workoutState.analysisKind == EngineKind.hold;
    final scrollMaxHeight = MediaQuery.of(context).size.height * 0.42;

    final holdRows = <Widget>[
      _DebugMetricRow(
        label: 'body line',
        value: _formatOptionalAngle(
          metrics.currentBodyLineAngle,
          isAvailable: metrics.hasBodyLineAngle,
        ),
      ),
      _DebugMetricRow(
        label: 'arm support',
        value: _formatOptionalAngle(
          metrics.currentArmSupportAngle,
          isAvailable: metrics.hasArmSupportAngle,
        ),
      ),
      _DebugMetricRow(
        label: 'leg extension',
        value: _formatOptionalAngle(
          metrics.currentLegExtensionAngle,
          isAvailable: metrics.hasLegExtensionAngle,
        ),
      ),
      _DebugMetricRow(label: 'coverage', value: _formatHoldCoverage(metrics)),
      _DebugMetricRow(
        label: 'body target',
        value: _formatAngle(metrics.formThreshold),
      ),
      _DebugMetricRow(
        label: 'isFormBad',
        value: workoutState.isFormBad ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'isHolding',
        value: workoutState.isHolding ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'hold break',
        value: workoutState.hadHoldFormBreak ? 'true' : 'false',
      ),
    ];

    final rangeRepCoreRows = <Widget>[
      _DebugMetricRow(
        label: 'primary/current',
        value: _formatAngle(workoutState.currentAngle),
      ),
      _DebugMetricRow(
        label: 'form/current',
        value: _formatAngle(metrics.currentBackAngle),
      ),
      _DebugMetricRow(
        label: 'threshold',
        value: _formatAngle(metrics.formThreshold),
      ),
      _DebugMetricRow(
        label: 'isFormBad',
        value: workoutState.isFormBad ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'frame valid',
        value: metrics.isRangeRepFrameValid ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'selected side',
        value: metrics.selectedRangeRepSide ?? '--',
      ),
      _DebugMetricRow(
        label: 'side reason',
        value: metrics.rangeRepSideSelectionReason ?? '--',
      ),
      if (metrics.rangeRepSideHysteresisStatus != null)
        _DebugMetricRow(
          label: 'SideHys',
          value: metrics.rangeRepSideHysteresisStatus!,
        ),
      if (metrics.rangeRepSideConsistencyStatus != null)
        _DebugMetricRow(
          label: 'SideRep',
          value: metrics.rangeRepSideConsistencyStatus!,
        ),
      _DebugMetricRow(
        label: 'invalid reason',
        value: metrics.rangeRepInvalidReason ?? '--',
      ),
      _DebugMetricRow(
        label: 'visibility',
        value: metrics.rangeRepVisibilityStatus,
      ),
      _DebugMetricRow(
        label: 'invalid streak',
        value: metrics.rangeRepInvalidFrameStreak.toString(),
      ),
      _DebugMetricRow(
        label: 'invalid duration',
        value: _formatMilliseconds(metrics.rangeRepInvalidDurationMs),
      ),
      _DebugMetricRow(
        label: 'resync triggered',
        value: metrics.rangeRepResyncTriggered ? 'true' : 'false',
      ),
      _DebugMetricRow(
        label: 'resync reason',
        value: metrics.rangeRepResyncReason ?? '--',
      ),
      _DebugMetricRow(
        label: 'phase gate',
        value: metrics.rangeRepPhaseGateStatus,
      ),
      _DebugMetricRow(
        label: 'pending transition',
        value: metrics.rangeRepPendingTransition ?? '--',
      ),
      _DebugMetricRow(
        label: 'last transition',
        value: metrics.rangeRepLastConfirmedTransition ?? '--',
      ),
      _DebugMetricRow(
        label: 'coverage',
        value: _formatRangeRepCoverage(metrics),
      ),
      _DebugMetricRow(
        label: 'side coverage',
        value: _formatRangeRepSideCoverage(metrics),
      ),
      if (metrics.leftRangeRepSideConfidence != null)
        _DebugMetricRow(
          label: 'L Conf',
          value: _formatTelemetryValue(metrics.leftRangeRepSideConfidence!),
        ),
      if (metrics.rightRangeRepSideConfidence != null)
        _DebugMetricRow(
          label: 'R Conf',
          value: _formatTelemetryValue(metrics.rightRangeRepSideConfidence!),
        ),
    ];

    final signalRows = <Widget>[
      if (metrics.currentTorsoAngle != null)
        _DebugMetricRow(
          label: 'Torso',
          value: _formatTelemetryValue(metrics.currentTorsoAngle!),
        ),
      if (metrics.currentDepthMetric != null)
        _DebugMetricRow(
          label: 'Depth',
          value: _formatTelemetryValue(metrics.currentDepthMetric!),
        ),
      if (metrics.currentAlignmentMetric != null)
        _DebugMetricRow(
          label: 'Align',
          value: _formatTelemetryValue(metrics.currentAlignmentMetric!),
        ),
      if (metrics.currentStabilityMetric != null)
        _DebugMetricRow(
          label: 'Stability',
          value: _formatTelemetryValue(metrics.currentStabilityMetric!),
        ),
      if (metrics.currentLockoutMetric != null)
        _DebugMetricRow(
          label: 'Lockout',
          value: _formatTelemetryValue(metrics.currentLockoutMetric!),
        ),
      if (metrics.currentBottomControlMetric != null)
        _DebugMetricRow(
          label: 'BottomCtrl',
          value: _formatTelemetryValue(metrics.currentBottomControlMetric!),
        ),
    ];

    final thresholdRows = <Widget>[
      _DebugMetricRow(
        label: 'Current',
        value: _formatThresholdCurrent(metrics),
      ),
      _DebugMetricRow(
        label: 'Decision',
        value: _formatThresholdDecisionMeta(metrics),
      ),
      _DebugMetricRow(
        label: 'Session',
        value: _formatThresholdDecisionSummary(metrics),
      ),
    ];

    final validationRows = <Widget>[
      _DebugMetricRow(
        label: 'ValidCount',
        value: metrics.rangeRepValidatedCount.toString(),
      ),
      _DebugMetricRow(
        label: 'LowConfCount',
        value: metrics.rangeRepLowConfidenceCount.toString(),
      ),
      _DebugMetricRow(
        label: 'InvalidCount',
        value: metrics.rangeRepInvalidCount.toString(),
      ),
      if (metrics.hasLastRangeRepValidation) ...[
        _DebugMetricRow(
          label: 'Validation',
          value: metrics.lastRangeRepValidationStatus ?? '--',
        ),
        if (metrics.lastRangeRepValidatedRepIndex != null)
          _DebugMetricRow(
            label: 'Rep',
            value: metrics.lastRangeRepValidatedRepIndex.toString(),
          ),
        if (metrics.lastRangeRepValidationReasons.isNotEmpty)
          _DebugMetricRow(
            label: 'Reasons',
            value: metrics.lastRangeRepValidationReasons.join(', '),
          ),
      ],
    ];

    final phaseRows = <Widget>[
      if (metrics.descendingPhaseDurationMs != null)
        _DebugMetricRow(
          label: 'DescMs',
          value: metrics.descendingPhaseDurationMs.toString(),
        ),
      if (metrics.peakPhaseDurationMs != null)
        _DebugMetricRow(
          label: 'PeakMs',
          value: metrics.peakPhaseDurationMs.toString(),
        ),
      if (metrics.ascendingPhaseDurationMs != null)
        _DebugMetricRow(
          label: 'AscMs',
          value: metrics.ascendingPhaseDurationMs.toString(),
        ),
      if (metrics.descendingPhaseWorstFormMetric != null)
        _DebugMetricRow(
          label: 'DescForm',
          value: _formatPhaseFormTelemetry(
            metrics.descendingPhaseWorstFormMetric,
            metrics.descendingPhaseHadFormViolation,
          ),
        ),
      if (metrics.peakPhaseWorstFormMetric != null)
        _DebugMetricRow(
          label: 'PeakForm',
          value: _formatPhaseFormTelemetry(
            metrics.peakPhaseWorstFormMetric,
            metrics.peakPhaseHadFormViolation,
          ),
        ),
      if (metrics.ascendingPhaseWorstFormMetric != null)
        _DebugMetricRow(
          label: 'AscForm',
          value: _formatPhaseFormTelemetry(
            metrics.ascendingPhaseWorstFormMetric,
            metrics.ascendingPhaseHadFormViolation,
          ),
        ),
      _DebugMetricRow(label: 'DescQ', value: metrics.descendingPhaseStatus),
      if (metrics.descendingPhaseIssues.isNotEmpty)
        _DebugMetricRow(
          label: 'DescIssues',
          value: metrics.descendingPhaseIssues.join(', '),
        ),
      _DebugMetricRow(label: 'PeakQ', value: metrics.peakPhaseStatus),
      if (metrics.peakPhaseIssues.isNotEmpty)
        _DebugMetricRow(
          label: 'PeakIssues',
          value: metrics.peakPhaseIssues.join(', '),
        ),
      _DebugMetricRow(label: 'AscQ', value: metrics.ascendingPhaseStatus),
      if (metrics.ascendingPhaseIssues.isNotEmpty)
        _DebugMetricRow(
          label: 'AscIssues',
          value: metrics.ascendingPhaseIssues.join(', '),
        ),
      if (metrics.phaseQualityPenalty != null)
        _DebugMetricRow(
          label: 'PhasePenalty',
          value: _formatTelemetryValue(metrics.phaseQualityPenalty!),
        ),
      if (metrics.phaseAdjustedScore != null)
        _DebugMetricRow(
          label: 'PhaseScore',
          value: _formatTelemetryValue(metrics.phaseAdjustedScore!),
        ),
      if (metrics.phaseFeedbackCandidate != null)
        _DebugMetricRow(
          label: 'PhaseCue',
          value: metrics.phaseFeedbackCandidate!,
        ),
    ];

    final lastRepRows = <Widget>[
      if (metrics.hasLastRangeRepSummary) ...[
        if (metrics.lastRangeRepSummaryMinAngle != null)
          _DebugMetricRow(
            label: 'MinAngle',
            value: _formatTelemetryValue(metrics.lastRangeRepSummaryMinAngle!),
          ),
        if (metrics.lastRangeRepSummaryWorstFormMetric != null)
          _DebugMetricRow(
            label: 'WorstForm',
            value: _formatTelemetryValue(
              metrics.lastRangeRepSummaryWorstFormMetric!,
            ),
          ),
        if (metrics.lastRangeRepSummaryDescentMillis != null)
          _DebugMetricRow(
            label: 'DescentMs',
            value: metrics.lastRangeRepSummaryDescentMillis.toString(),
          ),
        if (metrics.lastRangeRepSummaryAscentMillis != null)
          _DebugMetricRow(
            label: 'AscentMs',
            value: metrics.lastRangeRepSummaryAscentMillis.toString(),
          ),
        _DebugMetricRow(
          label: 'FormBreak',
          value: metrics.lastRangeRepSummaryHadFormViolation ? 'true' : 'false',
        ),
        _DebugMetricRow(
          label: 'CoverageDrop',
          value: metrics.lastRangeRepSummaryHadCoverageDrop ? 'true' : 'false',
        ),
        _DebugMetricRow(
          label: 'SideSwitch',
          value: metrics.lastRangeRepSummarySwitchedSideDuringRep
              ? 'true'
              : 'false',
        ),
        _DebugMetricRow(
          label: 'FullPhase',
          value: metrics.lastRangeRepSummaryCompletedPhaseSequence
              ? 'true'
              : 'false',
        ),
        _DebugMetricRow(
          label: 'Side',
          value: metrics.lastRangeRepSummarySelectedSideLabel ?? '--',
        ),
      ],
      _DebugMetricRow(
        label: 'rep worst back',
        value: _formatAngle(metrics.currentRepWorstBackAngle),
      ),
      _DebugMetricRow(
        label: 'rep violation',
        value: metrics.currentRepHadFormViolation ? 'true' : 'false',
      ),
      if (metrics.hasLastRepBreakdown) ...[
        const Divider(color: Colors.white24, height: 14),
        Text(
          'last rep: score ${workoutState.lastRepScore.toStringAsFixed(1)} | '
          'rom ${metrics.lastRepRomScore.toStringAsFixed(1)} | '
          'desc ${metrics.lastRepDescentScore.toStringAsFixed(1)} | '
          'asc ${metrics.lastRepAscentScore.toStringAsFixed(1)}',
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          'last form: worst ${_formatAngle(metrics.lastRepWorstBackAngle)} | '
          'violation ${metrics.lastRepHadFormViolation ? 'true' : 'false'}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.45)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Calibration',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: scrollMaxHeight),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isHoldAnalysis)
                        _DebugSection(title: 'Hold', children: holdRows)
                      else ...[
                        _DebugSection(
                          title: 'Core',
                          children: rangeRepCoreRows,
                        ),
                        if (signalRows.isNotEmpty)
                          _DebugSection(title: 'Signals', children: signalRows),
                        _DebugSection(
                          title: 'Validation',
                          children: validationRows,
                        ),
                        _DebugSection(
                          title: 'Threshold',
                          children: thresholdRows,
                        ),
                        _DebugSection(title: 'Phase', children: phaseRows),
                        _DebugSection(title: 'Last Rep', children: lastRepRows),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatOptionalAngle(double? value, {required bool isAvailable}) {
  if (!isAvailable || value == null) {
    return '--';
  }

  return _formatAngle(value);
}

String _formatTelemetryValue(double value) {
  return value.toStringAsFixed(1);
}

String _formatHoldCoverage(WorkoutCalibrationMetrics metrics) {
  final bodyCoverage = metrics.hasBodyLineAngle ? 'body ok' : 'body missing';
  final armCoverage = metrics.hasArmSupportAngle ? 'arm ok' : 'arm missing';
  final legCoverage = metrics.hasLegExtensionAngle ? 'leg ok' : 'leg missing';

  return '$bodyCoverage / $armCoverage / $legCoverage';
}

String _formatRangeRepCoverage(WorkoutCalibrationMetrics metrics) {
  final primaryCoverage = metrics.hasPrimaryAngle
      ? 'primary ok'
      : 'primary missing';
  final formCoverage = metrics.hasFormMetric ? 'form ok' : 'form missing';

  return '$primaryCoverage / $formCoverage';
}

String _formatRangeRepSideCoverage(WorkoutCalibrationMetrics metrics) {
  return 'L ${metrics.leftRangeRepCoverage}/2 / '
      'R ${metrics.rightRangeRepCoverage}/2';
}

String _formatThresholdCurrent(WorkoutCalibrationMetrics metrics) {
  final baseThreshold = metrics.baseFormThreshold ?? metrics.formThreshold;
  final effectiveThreshold =
      metrics.effectiveFormThreshold ?? metrics.formThreshold;
  final parts = <String>[
    'base ${_formatAngle(baseThreshold)}',
    'eff ${_formatAngle(effectiveThreshold)}',
  ];

  if (metrics.calibrationThresholdOffsetCandidate != null) {
    final offset = metrics.calibrationThresholdOffsetCandidate!;
    final sign = offset >= 0 ? '+' : '';
    parts.add('off $sign${_formatTelemetryValue(offset)}');
  }

  return parts.join(' | ');
}

String _formatThresholdDecisionMeta(WorkoutCalibrationMetrics metrics) {
  final parts = <String>[
    metrics.calibrationThresholdOffsetFallbackReason ?? '--',
  ];

  if (metrics.calibrationThresholdOffsetSampleCount != null) {
    parts.add('n ${metrics.calibrationThresholdOffsetSampleCount}');
  }
  if (metrics.calibrationThresholdOffsetBaselineSideLabel != null) {
    parts.add('side ${metrics.calibrationThresholdOffsetBaselineSideLabel}');
  }

  return parts.join(' | ');
}

String _formatThresholdDecisionSummary(WorkoutCalibrationMetrics metrics) {
  return 'all ${metrics.calibrationThresholdDecisionCount} | '
      'ap ${metrics.calibrationThresholdAppliedCount} | '
      'nb ${metrics.calibrationThresholdNoBaselineCount} | '
      'ins ${metrics.calibrationThresholdInsufficientSamplesCount} | '
      'miss ${metrics.calibrationThresholdMissingFormBaselineCount} | '
      'side ${metrics.calibrationThresholdSideMismatchCount} | '
      'small ${metrics.calibrationThresholdOffsetTooSmallCount}';
}

String _formatMilliseconds(int milliseconds) {
  return '${milliseconds}ms';
}

String _formatPhaseFormTelemetry(
  double? worstFormMetric,
  bool hadFormViolation,
) {
  final worstValue = worstFormMetric == null
      ? '--'
      : _formatTelemetryValue(worstFormMetric);

  return '$worstValue / ${hadFormViolation ? 'true' : 'false'}';
}

class _DebugSection extends StatelessWidget {
  const _DebugSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _DebugMetricRow extends StatelessWidget {
  const _DebugMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAngle(double value) {
  return '${value.toStringAsFixed(1)}°';
}
