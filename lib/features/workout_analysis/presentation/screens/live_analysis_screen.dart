import 'dart:async';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/localization/app_localizations.dart';

import '../../application/engine_kind.dart';
import '../../application/workout_engine.dart';
import '../../application/workout_session_lifecycle_controller.dart';
import '../../application/workout_state.dart';
import '../../domain/models/exercise_config.dart';
import '../../domain/models/setup_readiness_state.dart';
import '../camera_image_stream_coordinator.dart';
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
import '../providers/live_pause_controller.dart';
import '../providers/live_range_rep_outcome_controller.dart';
import '../providers/live_tracking_controller.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/preparation_countdown_feedback.dart';
import '../providers/preparation_readiness_controller.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/screen_awake_controller.dart';
import '../providers/workout_controller.dart';
import '../providers/workout_plan_session_provider.dart';
import '../providers/workout_session_lifecycle_controller_provider.dart';
import '../mappers/setup_readiness_ui_mapper.dart';
import '../widgets/analysis_selection_required_view.dart';
import '../widgets/pose_painter.dart';
import '../widgets/workout_diagnostics_panel.dart';
import 'camera_permission_screen.dart';
import 'exercise_selection_screen.dart';
import 'workout_plan_summary_screen.dart';
import 'workout_summary_screen.dart';

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
  Size? _observedPreviewSize;
  late final CameraImageStreamCoordinator _imageStreamCoordinator;
  late final ScreenAwakeController _screenAwakeController;
  WorkoutSessionLifecycleOwner? _sessionLifecycle;
  ProviderSubscription<WorkoutSessionLifecycleOwner>?
  _sessionLifecycleSubscription;
  Timer? _recoveryTimer;
  ProviderSubscription<AsyncValue<ExerciseConfig>>? _exerciseConfigSubscription;
  ProviderSubscription<WorkoutState>? _workoutStateSubscription;

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
        if (activeExercise != null) {
          ref
              .read(workoutPlanSessionProvider.notifier)
              .observe(exercise: activeExercise, workoutState: next);
        }
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
      Navigator.of(context).pop();
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

  Future<bool> _discardCompletedSessionForRetry() async {
    final sessionLifecycle = _sessionLifecycle;
    if (!mounted || sessionLifecycle == null) {
      return false;
    }

    final result = await sessionLifecycle.discardSavedSession();
    if (!mounted) {
      return false;
    }

    switch (result.failure) {
      case DiscardWorkoutSessionFailure.noSavedSession:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).noCompletedSessionToDelete,
            ),
          ),
        );
        return false;
      case DiscardWorkoutSessionFailure.persistenceFailure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).previousSessionDeleteFailed,
            ),
          ),
        );
        return false;
      case null:
        return true;
    }
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
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          onRetryRequested: _discardCompletedSessionForRetry,
        ),
      ),
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

  Future<void> _advancePlannedWorkout(WorkoutState workoutState) async {
    final planState = ref.read(workoutPlanSessionProvider);
    if (!planState.isSetCompleted) {
      return;
    }

    final activeExercise = ref.read(activeAnalysisExerciseProvider);
    final planController = ref.read(workoutPlanSessionProvider.notifier);
    final nextExercise = planController.nextExerciseAfterCompletedSet;
    final changesExercise =
        nextExercise == null || nextExercise != activeExercise;

    if (changesExercise) {
      await _stopImageStreamIfNeeded();
      if (!mounted) {
        return;
      }
      final saved = await _finishPlannedExerciseSession(workoutState);
      if (!saved || !mounted) {
        return;
      }
      _sessionLifecycle?.completeFinishFlow();
    }

    final nextSnapshot = planController.advance();
    if (nextSnapshot.isWorkoutCompleted) {
      await _setLiveAnalysisScreenAwake(false);
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WorkoutPlanSummaryScreen()),
      );
      return;
    }

    if (changesExercise && nextExercise != null) {
      ref.read(livePauseControllerProvider.notifier).reset();
      ref.read(preparationCameraControllerProvider.notifier).clear();
      ref.read(completedSessionMetricsProvider.notifier).state = null;
      ref.read(selectedExerciseProvider.notifier).state = nextExercise;
      _sessionLifecycle?.startSession(exercise: nextExercise);
    }
  }

  void _showDiagnosticsPanel() {
    if (!workoutDiagnosticsUiEnabled) {
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
      final countdownChanged =
          next.isCountingDown &&
          (previous?.isCountingDown != true ||
              previous?.countdownValue != next.countdownValue);
      if (countdownChanged) {
        unawaited(ref.read(preparationCountdownFeedbackProvider).tick());
      }

      if (previous?.isCountingDown == true && next.isActive) {
        unawaited(ref.read(preparationCountdownFeedbackProvider).complete());
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
    final topInset = MediaQuery.paddingOf(context).top;
    final viewportOrientation = MediaQuery.orientationOf(context);
    final isLandscape = viewportOrientation == Orientation.landscape;

    return _buildExitGuard(
      Scaffold(
        backgroundColor: Colors.black,
        body: cameraState.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (controller) {
            // Riverpod can keep the previous controller during refresh; hide the
            // preview while recovery is active so a disposing controller is not used.
            if (_isRecoveringCamera || cameraState.isLoading) {
              return const _CameraRecoveryView();
            }

            final controllerValue = _safeControllerValue(controller);
            final cameraGeometry = const PreparationCameraGeometryResolver()
                .resolve(
                  previewSize: controllerValue?.previewSize,
                  deviceOrientation: controllerValue?.deviceOrientation,
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

            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                if (pauseState.isActive)
                  _WorkoutPoseOverlay(
                    imageSize: imageSize,
                    isMirrored: isMirrored,
                    showDebugLandmarks: _showCalibrationPanel,
                  )
                else
                  _PausedPoseOverlay(
                    imageSize: imageSize,
                    isMirrored: isMirrored,
                  ),
                if (pauseState.isActive) const _LiveTrackingRecoveryOverlay(),
                if (pauseState.isPaused)
                  _LivePauseOverlay(
                    readinessRequest: readinessRequest,
                    onResume: () => _requestResume(readinessRequest),
                    onCancelResume: _cancelResume,
                  ),
                _FinishSessionButton(
                  topInset: topInset,
                  compact: isLandscape,
                  isFinishing: sessionLifecycle.isFinishing,
                  onFinish: () => unawaited(_requestSessionExit()),
                ),
                if (pauseState.isActive)
                  _PauseSessionButton(
                    topInset: topInset,
                    compact: isLandscape,
                    onPause: () => _pauseAnalysis(readinessRequest),
                  ),
                if (workoutDiagnosticsUiEnabled && pauseState.isActive)
                  Positioned(
                    top: topInset + (isLandscape ? 8 : 12),
                    left: isLandscape ? 10 : 14,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Beta Diagnostics',
                        onPressed: sessionLifecycle.isFinishing
                            ? null
                            : _showDiagnosticsPanel,
                        color: Colors.white,
                        iconSize: isLandscape ? 18 : 24,
                        visualDensity: isLandscape
                            ? VisualDensity.compact
                            : VisualDensity.standard,
                        constraints: BoxConstraints.tightFor(
                          width: isLandscape ? 40 : 48,
                          height: isLandscape ? 40 : 48,
                        ),
                        icon: const Icon(Icons.bug_report_outlined),
                      ),
                    ),
                  ),
                if (pauseState.isActive && isLandscape)
                  _LandscapeWorkoutMetricsOverlay(
                    topInset: topInset,
                    onToggleCalibration: () {
                      setState(
                        () => _showCalibrationPanel = !_showCalibrationPanel,
                      );
                    },
                  ),
                if (pauseState.isActive && !isLandscape)
                  _PrimaryWorkoutMetricsOverlay(
                    topInset: topInset,
                    onToggleCalibration: () {
                      setState(
                        () => _showCalibrationPanel = !_showCalibrationPanel,
                      );
                    },
                  ),
                if (pauseState.isActive && !isLandscape)
                  _CanonicalMetricsOverlay(topInset: topInset),
                if (pauseState.isActive)
                  _PlannedWorkoutProgressOverlay(
                    topInset: topInset,
                    compact: isLandscape,
                  ),
                if (_showCalibrationPanel && pauseState.isActive)
                  _CalibrationPanelOverlay(
                    topInset: topInset,
                    compact: isLandscape,
                    onClose: () {
                      setState(() => _showCalibrationPanel = false);
                    },
                  ),
                if (pauseState.isActive)
                  Positioned(
                    bottom: isLandscape ? 12 : 40,
                    left: isLandscape ? 12 : 20,
                    right: isLandscape ? 12 : 20,
                    child: FractionallySizedBox(
                      widthFactor: isLandscape ? 0.76 : 1,
                      child: Column(
                        children: [
                          _WorkoutSetCompletedSection(
                            compact: isLandscape,
                            onAdvance: () => unawaited(
                              _advancePlannedWorkout(
                                ref.read(workoutControllerProvider),
                              ),
                            ),
                          ),
                          _RangeRepSideTrackingIndicator(compact: isLandscape),
                          _WorkoutFeedbackStatus(compact: isLandscape),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const _CameraRecoveryView(),
          error: (error, _) {
            if (error is CameraException && error.code == 'cameraPermission') {
              return _CameraPermissionFallback(
                onPressed: _goToPermissionScreen,
              );
            }

            if (_isRecoveringCamera &&
                _isTransientCameraLifecycleError(error)) {
              return const _CameraRecoveryView();
            }

            return Center(child: Text(localizations.cameraOpenFailed(error)));
          },
        ),
      ),
    );
  }

  bool _isTransientCameraLifecycleError(Object error) {
    final message = error.toString().toLowerCase();

    return message.contains('dispose') ||
        message.contains('disposed') ||
        message.contains('controller') ||
        message.contains('initialize') ||
        message.contains('camera is closed') ||
        message.contains('camera closed');
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
          !sessionLifecycle.isFinishing &&
          _hasAnalysisSelection(),
      onFrame: (image, streamController) {
        if (!mounted) {
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
                deviceOrientation: cameraValue?.deviceOrientation,
              );
          return;
        }

        ref
            .read(preparationCameraControllerProvider.notifier)
            .processCameraImage(
              image,
              streamController.description.sensorOrientation,
              lensDirection: streamController.description.lensDirection,
              deviceOrientation: cameraValue?.deviceOrientation,
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

class _PauseSessionButton extends StatelessWidget {
  const _PauseSessionButton({
    required this.topInset,
    required this.compact,
    required this.onPause,
  });

  final double topInset;
  final bool compact;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Positioned(
      top: topInset + (compact ? 8 : 12),
      left: workoutDiagnosticsUiEnabled
          ? (compact ? 58 : 68)
          : (compact ? 10 : 14),
      child: TextButton.icon(
        key: const ValueKey<String>('live-pause-button'),
        onPressed: onPause,
        icon: Icon(Icons.pause_circle_outline_rounded, size: compact ? 16 : 18),
        label: Text(
          localizations.pauseWorkout,
          style: TextStyle(fontSize: compact ? 14 : 15),
        ),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.black54,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          visualDensity: compact ? VisualDensity.compact : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
          ),
        ),
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
      child: TextButton.icon(
        onPressed: isFinishing ? null : onFinish,
        icon: Icon(Icons.stop_circle_outlined, size: compact ? 16 : 18),
        label: Text(
          hasPlan ? localizations.endWorkout : localizations.finish,
          style: TextStyle(fontSize: compact ? 14 : 15),
        ),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.black54,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          visualDensity: compact ? VisualDensity.compact : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
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
  final VoidCallback onToggleCalibration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveMetrics = ref.watch(workoutLiveMetricsProvider);
    final hasCanonicalMetrics =
        liveMetrics.angleDegrees != null ||
        liveMetrics.tempo != null ||
        liveMetrics.stabilityScore != null ||
        liveMetrics.asymmetryScore != null;

    return Positioned(
      top: topInset + 56,
      left: 14,
      right: 14,
      child: GestureDetector(
        key: const ValueKey<String>('live-performance-header'),
        behavior: HitTestBehavior.opaque,
        onLongPress: onToggleCalibration,
        child: SizedBox(
          height: 76,
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
  final VoidCallback onToggleCalibration;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topInset + 72,
      left: 16,
      right: 16,
      child: GestureDetector(
        key: const ValueKey<String>('live-performance-header'),
        behavior: HitTestBehavior.opaque,
        onLongPress: onToggleCalibration,
        child: const SizedBox(
          height: 116,
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
      accentColor: Colors.greenAccent,
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
          : localizations.scoreMetric,
      value: value,
      valueStyle: TextStyle(
        color: isHoldAnalysis || hasRepScore
            ? isLowConfidenceLastRep
                  ? Colors.amberAccent
                  : Colors.greenAccent
            : Colors.white54,
        fontSize: compact ? 24 : 31,
        height: 1,
        fontWeight: FontWeight.w800,
      ),
      accentColor: isHoldAnalysis || hasRepScore
          ? isLowConfidenceLastRep
                ? Colors.amberAccent
                : Colors.greenAccent
          : Colors.white30,
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
    required this.accentColor,
    this.emphasize = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;
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
          horizontal: compact ? (emphasize ? 14 : 12) : (emphasize ? 20 : 16),
          vertical: compact ? 8 : 14,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: emphasize ? 0.62 : 0.54),
          borderRadius: BorderRadius.circular(compact ? 18 : 24),
          border: Border.all(
            color: accentColor.withValues(alpha: emphasize ? 0.52 : 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black38,
              blurRadius: compact ? 12 : 18,
              offset: Offset(0, compact ? 4 : 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: compact
                      ? (emphasize ? 14 : 11)
                      : (emphasize ? 18 : 14),
                  height: 3,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: compact ? 9 : 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: compact ? 1.05 : 1.35,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 4 : 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
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
                      style: valueStyle,
                    ),
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

class _CanonicalMetricsOverlay extends ConsumerWidget {
  const _CanonicalMetricsOverlay({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveMetrics = ref.watch(workoutLiveMetricsProvider);
    return Positioned(
      top: topInset + 202,
      left: 20,
      right: 20,
      child: _LiveCanonicalMetricsBar(metrics: liveMetrics),
    );
  }
}

class _PlannedWorkoutProgressOverlay extends ConsumerWidget {
  const _PlannedWorkoutProgressOverlay({
    required this.topInset,
    required this.compact,
  });

  final double topInset;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(
      workoutPlanSessionProvider.select(
        (state) => (
          snapshot: state.snapshot,
          isWorkoutCompleted: state.isWorkoutCompleted,
        ),
      ),
    );
    final snapshot = plan.snapshot;
    if (snapshot == null || plan.isWorkoutCompleted) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: topInset + (compact ? 140 : 258),
      left: compact ? 14 : 20,
      right: compact ? 14 : 20,
      child: _PlannedWorkoutProgressBar(snapshot: snapshot, compact: compact),
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
      top: topInset + (compact ? (hasPlan ? 192 : 140) : (hasPlan ? 330 : 258)),
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

class _WorkoutSetCompletedSection extends ConsumerWidget {
  const _WorkoutSetCompletedSection({
    required this.compact,
    required this.onAdvance,
  });

  final bool compact;
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

    return Column(
      children: [
        _WorkoutSetCompletedCard(
          snapshot: snapshot,
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
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(compact ? 14 : 17),
          border: Border.all(color: accentColor.withValues(alpha: 0.62)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              hasSelectedSide
                  ? Icons.directions_walk_rounded
                  : Icons.swap_horiz_rounded,
              size: compact ? 17 : 20,
              color: accentColor,
            ),
            SizedBox(width: compact ? 7 : 9),
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
                  fontSize: compact ? 12 : 13,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutFeedbackStatus extends StatelessWidget {
  const _WorkoutFeedbackStatus({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _WorkoutFeedbackMessage(compact: compact);
  }
}

class _WorkoutFeedbackMessage extends ConsumerWidget {
  const _WorkoutFeedbackMessage({required this.compact});

  final bool compact;

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

    return AnimatedContainer(
      key: const ValueKey<String>('live-feedback-message-card'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 9, 14, 10)
          : const EdgeInsets.fromLTRB(16, 13, 18, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(color: accentColor.withValues(alpha: 0.58)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 32 : 38,
            height: compact ? 32 : 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              presentation.icon,
              color: accentColor,
              size: compact ? 19 : 22,
            ),
          ),
          SizedBox(width: compact ? 9 : 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  key: const ValueKey<String>('live-analysis-status-line'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentColor.withValues(alpha: 0.9),
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    presentation.message,
                    key: ValueKey<String>(presentation.message),
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 16 : 18,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
        accentColor: Colors.greenAccent,
        icon: Icons.check_circle_rounded,
      ),
      RangeRepOutcomeTone.caution => _FeedbackPresentation(
        title: repOutcome.title,
        message: repOutcome.message,
        accentColor: Colors.amberAccent,
        icon: Icons.info_rounded,
      ),
      RangeRepOutcomeTone.invalid => _FeedbackPresentation(
        title: repOutcome.title,
        message: repOutcome.message,
        accentColor: Colors.orangeAccent,
        icon: Icons.replay_rounded,
      ),
    };
  }

  return _FeedbackPresentation(
    title: localizations.workoutPhaseLabel(feedback.currentPhase),
    message: feedback.message,
    accentColor: feedback.isFormBad ? Colors.amberAccent : Colors.greenAccent,
    icon: feedback.isFormBad ? Icons.tune_rounded : Icons.check_rounded,
  );
}

class _FeedbackPresentation {
  const _FeedbackPresentation({
    required this.title,
    required this.message,
    required this.accentColor,
    required this.icon,
  });

  final String title;
  final String message;
  final Color accentColor;
  final IconData icon;
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

class _PlannedWorkoutProgressBar extends StatelessWidget {
  const _PlannedWorkoutProgressBar({
    required this.snapshot,
    required this.compact,
  });

  final WorkoutEngineSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final target = snapshot.targetRepetitions != null
        ? localizations.repetitionProgress(
            snapshot.currentRepetitions,
            snapshot.targetRepetitions!,
          )
        : '${_formatPlanDuration(snapshot.currentHoldDuration)} / ${_formatPlanDuration(snapshot.targetHoldDuration ?? Duration.zero)}';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(compact ? 18 : 14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.plannedWorkoutProgress(
                    round: snapshot.roundNumber,
                    totalRounds: snapshot.totalRounds,
                    set: snapshot.setNumber,
                    totalSets: snapshot.setsInCurrentExercise,
                  ),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                target,
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 7),
          LinearProgressIndicator(
            value: snapshot.progress,
            minHeight: compact ? 4 : 5,
            backgroundColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}

class _WorkoutSetCompletedCard extends StatelessWidget {
  const _WorkoutSetCompletedCard({
    required this.snapshot,
    required this.compact,
    required this.onAdvance,
  });

  final WorkoutEngineSnapshot snapshot;
  final bool compact;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isFinalSet = snapshot.completedSets >= snapshot.totalSets;
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

String _formatPlanDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
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
